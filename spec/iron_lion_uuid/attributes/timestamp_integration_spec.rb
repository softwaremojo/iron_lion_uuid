# frozen_string_literal: true

require "spec_helper"
require "timecop"

RSpec.describe "Timestamp Attribute Integration" do
  # Reset configuration before each test
  before do
    if IronLionUUID.instance_variable_defined?(:@configuration)
      IronLionUUID.remove_instance_variable(:@configuration)
    end
    if IronLionUUID.instance_variable_defined?(:@generator)
      IronLionUUID.remove_instance_variable(:@generator)
    end
  end

  describe "UUID generation with timestamp" do
    it "configures UUIDs with timestamp attributes" do
      IronLionUUID.configure do |uuid|
        uuid.timestamp(bits: 36, precision: :millisecond, name: :created_at)
      end

      config = IronLionUUID.configuration
      # 1 configured timestamp + auto-added random for remaining bits
      expect(config.attributes.size).to eq(2)

      # Check specific attributes
      timestamp_attr = config.attribute_by_name(:created_at)
      expect(timestamp_attr).to be_a(IronLionUUID::TimestampAttribute)
      expect(timestamp_attr.bits).to eq(36)
      expect(timestamp_attr[:precision]).to eq(:millisecond)
    end

    it "generates UUIDs with timestamp values" do
      IronLionUUID.configure do |uuid|
        uuid.timestamp(bits: 36, precision: :millisecond, name: :created_at)
      end

      # Freeze time for predictable test
      fixed_time = Time.utc(2023, 1, 1, 12, 0, 0)
      Timecop.freeze(fixed_time) do
        # Generate a UUID with the fixed time
        uuid = IronLionUUID.generate

        # Calculate expected timestamp value
        expected_ms = (fixed_time.to_f * 1000).to_i

        # Check timestamp value via accessor method
        expect(uuid.created_at).to eq(expected_ms)
      end
    end

    it "advances timestamps over time" do
      IronLionUUID.configure do |uuid|
        uuid.timestamp(bits: 36, precision: :millisecond)
      end

      uuid1 = nil
      uuid2 = nil

      # Generate UUIDs at different times
      first_time = Time.utc(2023, 1, 1, 12, 0, 0)
      Timecop.freeze(first_time) do
        uuid1 = IronLionUUID.generate
      end

      second_time = Time.utc(2023, 1, 1, 12, 0, 1) # 1 second later
      Timecop.freeze(second_time) do
        uuid2 = IronLionUUID.generate
      end

      # Timestamps should be different and in chronological order
      expect(uuid2.timestamp).to be > uuid1.timestamp

      # The difference should be around 1000 milliseconds
      expect(uuid2.timestamp - uuid1.timestamp).to be_within(10).of(1000)
    end
  end

  describe "integration with other attribute types" do
    it "combines timestamp with parameter attributes" do
      IronLionUUID.configure do |uuid|
        uuid.timestamp(bits: 36, precision: :millisecond)
        uuid.parameter(bits: 16, name: :model)
      end

      # Freeze time for predictable test
      fixed_time = Time.utc(2023, 1, 1, 12, 0, 0)
      Timecop.freeze(fixed_time) do
        # Generate a UUID with a parameter
        uuid = IronLionUUID.generate(101)

        # Check values via accessor methods
        expect(uuid.timestamp).to eq((fixed_time.to_f * 1000).to_i)
        expect(uuid.model).to eq(101)
      end
    end

    it "combines timestamp, environment and parameter attributes" do
      # Set up environment variable
      ENV["NODE_ID"] = "42"

      IronLionUUID.configure do |uuid|
        uuid.timestamp(bits: 36, precision: :millisecond)
        uuid.env(bits: 12, name: :node, key: :NODE_ID)
        uuid.parameter(bits: 16, name: :model)
      end

      # Freeze time for predictable test
      fixed_time = Time.utc(2023, 1, 1, 12, 0, 0)
      Timecop.freeze(fixed_time) do
        # Generate a UUID with a parameter
        uuid = IronLionUUID.generate(101)

        # Check values via accessor methods
        expect(uuid.timestamp).to eq((fixed_time.to_f * 1000).to_i)
        expect(uuid.node).to eq(42)
        expect(uuid.model).to eq(101)
      end

      # Clean up environment
      ENV.delete("NODE_ID")
    end
  end

  describe "timestamp ordering" do
    it "maintains chronological ordering of UUIDs" do
      IronLionUUID.configure do |uuid|
        uuid.timestamp(bits: 48, precision: :millisecond)
      end

      # Generate UUIDs at sequential times
      times = [
        Time.utc(2023, 1, 1, 12, 0, 0),
        Time.utc(2023, 1, 1, 12, 0, 1),
        Time.utc(2023, 1, 1, 12, 0, 2),
        Time.utc(2023, 1, 1, 12, 0, 3),
        Time.utc(2023, 1, 1, 12, 0, 4)
      ]

      uuids = times.map do |time|
        Timecop.freeze(time) do
          IronLionUUID.generate
        end
      end

      # Shuffle the UUIDs
      shuffled_uuids = uuids.shuffle

      # Sort by UUID value, which should match chronological order
      sorted_uuids = shuffled_uuids.sort_by(&:value)

      # Should match the original order
      expect(sorted_uuids.map(&:timestamp)).to eq(uuids.map(&:timestamp))
    end
  end

  describe "different precision settings" do
    it "supports different precision levels" do
      # Test each precision level
      fixed_time = Time.utc(2023, 1, 1, 12, 0, 0)

      %i[second millisecond microsecond nanosecond].each do |precision|
        # Skip the test for nanosecond if system doesn't support it
        # to avoid unnecessary warnings in the test output
        next if precision == :nanosecond && !system_supports_nanosecond?

        # Reset config
        if IronLionUUID.instance_variable_defined?(:@configuration)
          IronLionUUID.remove_instance_variable(:@configuration)
        end

        # Configure with this precision
        IronLionUUID.configure do |uuid|
          uuid.timestamp(bits: 48, precision: precision)
        end

        Timecop.freeze(fixed_time) do
          uuid = IronLionUUID.generate

          # Calculate expected value based on precision
          multiplier = IronLionUUID::TimestampAttribute::PRECISION_MULTIPLIERS[precision]
          expected_value = (fixed_time.to_f * multiplier).to_i

          expect(uuid.timestamp).to eq(expected_value)
        end
      end
    end
  end

  # Helper method to check if system supports nanosecond precision
  def system_supports_nanosecond?
    times = Array.new(10) { Time.now.to_f }
    min_diff = times.each_cons(2).map { |a, b| (b - a).abs }.min
    min_diff < 0.000001
  end
end
