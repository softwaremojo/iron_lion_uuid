# frozen_string_literal: true

require "spec_helper"

RSpec.describe IronLionUUID::Attributes::Sequence do
  describe "#initialize" do
    it "creates a sequence attribute with bits and optional name" do
      attr = described_class.new(bits: 16)

      expect(attr.type).to eq(:sequence)
      expect(attr.bits).to eq(16)
      expect(attr.name).to eq(:sequence) # Default name

      attr_with_name = described_class.new(bits: 8, name: :my_sequence)

      expect(attr_with_name.type).to eq(:sequence)
      expect(attr_with_name.bits).to eq(8)
      expect(attr_with_name.name).to eq(:my_sequence)
    end

    it "raises an error if bit width is not provided" do
      expect { described_class.new }.to raise_error(NoMethodError) # :bits is nil
    end

    it "initializes the counter and max value" do
      attr = described_class.new(bits: 8)

      # Access instance variables
      counter = attr.instance_variable_get(:@counter)
      max_value = attr.instance_variable_get(:@max_value)

      expect(counter).to be_a(Concurrent::AtomicFixnum)
      expect(counter.value).to eq(0)
      expect(max_value).to eq(255) # 2^8 - 1
    end
  end

  describe "#generate_value" do
    it "returns sequential values" do
      attr = described_class.new(bits: 16)

      # Generate a sequence of values
      values = Array.new(5) { attr.generate_value }

      # Values should be sequential starting from 1
      expect(values).to eq([ 1, 2, 3, 4, 5 ])
    end

    it "wraps around when reaching the maximum value" do
      # Use a small bit width for easier testing
      attr = described_class.new(bits: 3) # Max value is 7

      # Set counter to just below max value
      counter = attr.instance_variable_get(:@counter)
      counter.value = 7

      # Next value should wrap around to 0 and then increment to 1
      expect(attr.generate_value).to eq(0)
      expect(attr.generate_value).to eq(1)
    end
  end

  describe "thread safety" do
    it "generates unique values when called from multiple threads" do
      attr = described_class.new(bits: 16)

      # Create a bunch of threads to generate values
      thread_count = 100
      values_per_thread = 100
      all_values = Concurrent::Array.new

      threads = Array.new(thread_count) do
        Thread.new do
          values_per_thread.times do
            all_values << attr.generate_value
          end
        end
      end

      # Wait for all threads to complete
      threads.each(&:join)

      # Number of unique values should match the total number generated
      expect(all_values.uniq.size).to eq(thread_count * values_per_thread)

      # Values should be between 1 and (thread_count * values_per_thread)
      expect(all_values.min).to eq(1)
      expect(all_values.max).to eq(thread_count * values_per_thread)
    end

    it "wraps around correctly even with multiple threads" do
      # Use very few bits to ensure wrapping
      attr = described_class.new(bits: 3) # Max value is 7

      # Set counter close to max value
      counter = attr.instance_variable_get(:@counter)
      counter.value = 5

      # Generate enough values in multiple threads to ensure wrapping
      thread_count = 5
      values_per_thread = 10
      all_values = Concurrent::Array.new

      threads = Array.new(thread_count) do
        Thread.new do
          values_per_thread.times do
            all_values << attr.generate_value
          end
        end
      end

      # Wait for all threads to complete
      threads.each(&:join)

      # Should have wrapped around multiple times, so all values 0-7 should be present
      all_possible_values = (0..7).to_a
      expect(all_values.uniq.sort).to eq(all_possible_values)
    end
  end

  describe "integration with Configuration" do
    it "can be added through the configuration DSL" do
      config = IronLionUUID::Configuration.new
      config.sequence(bits: 16, name: :my_sequence)

      attr = config.attributes.first
      expect(attr).to be_a(described_class)
      expect(attr.bits).to eq(16)
      expect(attr.name).to eq(:my_sequence)
    end

    it "validates required options" do
      config = IronLionUUID::Configuration.new

      expect { config.sequence(name: :my_sequence) }
        .to raise_error(IronLionUUID::ConfigurationError, /Missing required option: bits/)
    end
  end
end
