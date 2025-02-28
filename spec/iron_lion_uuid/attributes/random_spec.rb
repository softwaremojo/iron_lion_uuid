# frozen_string_literal: true

require "spec_helper"

RSpec.describe IronLionUUID::Attributes::Random do
  describe "#initialize" do
    it "creates a random attribute with bits and optional name" do
      attr = described_class.new(bits: 32)

      expect(attr.type).to eq(:random)
      expect(attr.bits).to eq(32)
      expect(attr.name).to eq(:random) # Default name

      attr_with_name = described_class.new(bits: 16, name: :my_random)

      expect(attr_with_name.type).to eq(:random)
      expect(attr_with_name.bits).to eq(16)
      expect(attr_with_name.name).to eq(:my_random)
    end

    it "raises an error if bit width is not provided" do
      expect { described_class.new }.to raise_error(NoMethodError) # :bits is nil
    end
  end

  describe "#generate_value" do
    it "generates random values within the specified bit width" do
      attr = described_class.new(bits: 8)

      100.times do
        value = attr.generate_value
        expect(value).to be >= 0
        expect(value).to be <= 255 # Max value for 8 bits
      end
    end

    it "generates different values on consecutive calls" do
      attr = described_class.new(bits: 16)

      values = Array.new(20) { attr.generate_value }

      # It's astronomically improbable to get the same value 20 times
      # Even with just 16 bits
      expect(values.uniq.size).to be > 1
    end

    it "respects the configured bit width" do
      # Test with different bit widths
      [ 8, 16, 24, 32, 64 ].each do |bits|
        attr = described_class.new(bits: bits)
        max_value = (1 << bits) - 1

        20.times do
          value = attr.generate_value
          expect(value).to be >= 0
          expect(value).to be <= max_value
        end
      end
    end
  end

  describe "integration with UUID generation" do
    before do
      # Configure with just a random attribute
      IronLionUUID.configure do |uuid|
        uuid.random(bits: 32, name: :test_random)
      end
    end

    after do
      # Reset configuration between tests
      if IronLionUUID.instance_variable_defined?(:@configuration)
        IronLionUUID.remove_instance_variable(:@configuration)
      end
    end

    it "creates a UUID with random bits" do
      # Set up the generator (assuming this is how it will work)
      generator = IronLionUUID::Generator.new(IronLionUUID.configuration)

      # Generate a UUID
      uuid = generator.generate

      # Basic assertions
      expect(uuid).to be_a(IronLionUUID::UUID)

      # Check version and variant (these will be set by the generator)
      version_bits = IronLionUUID::BitOps.extract_bits(uuid.value, 48, 4)
      variant_bits = IronLionUUID::BitOps.extract_bits(uuid.value, 64, 2)

      expect(version_bits).to eq(8)  # UUID v8
      expect(variant_bits).to eq(2)  # RFC 4122 variant
    end
  end
end
