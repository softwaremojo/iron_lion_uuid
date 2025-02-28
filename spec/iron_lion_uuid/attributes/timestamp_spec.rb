# frozen_string_literal: true

require "spec_helper"
require "timecop"

RSpec.describe IronLionUUID::Attributes::Timestamp do
  describe "#initialize" do
    it "creates a timestamp attribute with bits and optional parameters" do
      attr = described_class.new(bits: 36)

      expect(attr.type).to eq(:timestamp)
      expect(attr.bits).to eq(36)
      expect(attr.name).to eq(:timestamp) # Default name
      expect(attr[:precision]).to eq(:millisecond) # Default precision

      attr_with_options = described_class.new(
        bits: 32,
        name: :created_at,
        precision: :microsecond
      )

      expect(attr_with_options.type).to eq(:timestamp)
      expect(attr_with_options.bits).to eq(32)
      expect(attr_with_options.name).to eq(:created_at)
      expect(attr_with_options[:precision]).to eq(:microsecond)
    end

    it "raises an error if bit width is not provided" do
      expect { described_class.new }.to raise_error(NoMethodError) # :bits is nil
    end

    it "raises an error if precision is invalid" do
      expect do
        described_class.new(bits: 36, precision: :invalid_precision)
      end.to raise_error(IronLionUUID::ConfigurationError, /Invalid timestamp precision/)
    end

    # rubocop:disable RSpec/AnyInstance
    it "warns if the system doesn't support the requested precision" do
      # Force the detection of system precision to be lower than requested
      allow_any_instance_of(described_class).to(
        receive(:detect_system_precision).and_return(:millisecond)
      )

      # Request a higher precision
      expect_any_instance_of(described_class).to receive(:warn).with(
        an_instance_of(IronLionUUID::TimestampPrecisionWarning)
      )

      described_class.new(bits: 36, precision: :nanosecond)
    end
    # rubocop:enable RSpec/AnyInstance
  end

  describe "#generate_value" do
    let(:attr) { described_class.new(bits: 36, precision: :millisecond) }

    it "generates a timestamp value at the configured precision" do
      # Freeze time for predictable test
      fixed_time = Time.utc(2023, 1, 1, 12, 0, 0)
      Timecop.freeze(fixed_time) do
        # Expected milliseconds since epoch
        expected_ms = (fixed_time.to_f * 1000).to_i

        expect(attr.generate_value).to eq(expected_ms)
      end
    end

    it "generates different timestamps on different calls" do
      # Small sleep to ensure time changes
      first = attr.generate_value
      sleep 0.01
      second = attr.generate_value

      expect(second).to be > first
    end

    it "respects different precision settings" do
      fixed_time = Time.utc(2023, 1, 1, 12, 0, 0)

      Timecop.freeze(fixed_time) do
        second_attr = described_class.new(bits: 32, precision: :second)
        millisecond_attr = described_class.new(bits: 36, precision: :millisecond)
        microsecond_attr = described_class.new(bits: 48, precision: :microsecond)

        # Expected values at different precisions
        expected_s = fixed_time.to_i
        expected_ms = (fixed_time.to_f * 1000).to_i
        expected_us = (fixed_time.to_f * 1_000_000).to_i

        expect(second_attr.generate_value).to eq(expected_s)
        expect(millisecond_attr.generate_value).to eq(expected_ms)
        expect(microsecond_attr.generate_value).to eq(expected_us)
      end
    end

    it "raises an error if the timestamp value exceeds the bit width" do
      # Create a timestamp attribute with a very small bit width
      small_attr = described_class.new(bits: 8, precision: :second)

      # Using a fixed time that would exceed 8 bits
      fixed_time = Time.utc(2023, 1, 1, 12, 0, 0)

      Timecop.freeze(fixed_time) do
        expect do
          small_attr.generate_value
        end.to raise_error(IronLionUUID::ValueTooLargeError)
      end
    end
  end

  describe "system precision detection" do
    let(:attr) { described_class.new(bits: 36) }

    it "detects the system's time precision" do
      # This is somewhat difficult to test reliably,
      # so we'll just ensure it returns a valid precision
      precision = attr.send(:detect_system_precision)
      expect(IronLionUUID::TimestampAttribute::PRECISIONS).to include(precision)
    end
  end

  describe "integration with Configuration" do
    it "can be added through the configuration DSL" do
      config = IronLionUUID::Configuration.new
      config.timestamp(bits: 36, precision: :millisecond)

      attr = config.attributes.first
      expect(attr).to be_a(described_class)
      expect(attr.bits).to eq(36)
      expect(attr[:precision]).to eq(:millisecond)
    end

    it "validates required options" do
      config = IronLionUUID::Configuration.new

      expect { config.timestamp(precision: :millisecond) }
        .to raise_error(IronLionUUID::ConfigurationError, /Missing required option: bits/)
    end
  end
end
