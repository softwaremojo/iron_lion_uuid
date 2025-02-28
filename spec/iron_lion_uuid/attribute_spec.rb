# frozen_string_literal: true

require "spec_helper"

RSpec.describe IronLionUUID::Attribute do
  describe "#initialize" do
    it "creates an attribute with the given type and bits" do
      attribute = described_class.new(:test, 16)

      expect(attribute.type).to eq(:test)
      expect(attribute.bits).to eq(16)
      expect(attribute.name).to be_nil
      expect(attribute.position).to be_nil
    end

    it "sets the name if provided" do
      attribute = described_class.new(:test, 16, name: :test_attribute)

      expect(attribute.name).to eq(:test_attribute)
    end

    it "stores additional options" do
      attribute = described_class.new(:test, 16, foo: :bar, baz: 123)

      expect(attribute[:foo]).to eq(:bar)
      expect(attribute[:baz]).to eq(123)
    end

    it "raises an error if bit width is not positive" do
      expect do
        described_class.new(:test, 0)
      end.to raise_error(IronLionUUID::ConfigurationError)
      expect do
        described_class.new(:test, -1)
      end.to raise_error(IronLionUUID::ConfigurationError)
    end

    it "raises an error if bit width is too large" do
      expect do
        described_class.new(:test, 123)
      end.to raise_error(IronLionUUID::InvalidBitWidthError)
    end
  end

  describe "#position=" do
    let(:attribute) { described_class.new(:test, 16) }

    it "sets the position of the attribute" do
      attribute.position = 32
      expect(attribute.position).to eq(32)
    end

    it "raises an error if position is negative" do
      expect do
        attribute.position = -1
      end.to raise_error(IronLionUUID::ConfigurationError)
    end

    it "raises an error if position is too large" do
      expect do
        attribute.position = 128
      end.to raise_error(IronLionUUID::ConfigurationError)
    end
  end

  describe "#extract_from" do
    let(:attribute) { described_class.new(:test, 8) }

    before do
      attribute.position = 16
    end

    it "extracts the attribute value from a UUID" do
      # Create a UUID with a known pattern
      # Bits 16-23 set to 0xAB
      uuid_value = 0x0000AB0000000000000000000000000000

      expect(attribute.extract_from(uuid_value)).to eq(0xAB)
    end

    it "raises an error if position is not set" do
      attribute = described_class.new(:test, 8)

      expect do
        attribute.extract_from(0)
      end.to raise_error(IronLionUUID::ConfigurationError)
    end
  end

  describe "#apply_to" do
    let(:attribute) { described_class.new(:test, 8) }

    before do
      attribute.position = 16
    end

    it "applies the attribute value to a UUID" do
      # Start with all zeros
      uuid_value = 0

      # Apply the value 0xAB at position 16
      result = attribute.apply_to(uuid_value, 0xAB)

      # Expected: Bits 16-23 set to 0xAB
      expected = 0x0000AB0000000000000000000000000000

      expect(result).to eq(expected)
    end

    it "raises an error if position is not set" do
      attribute = described_class.new(:test, 8)

      expect do
        attribute.apply_to(0, 0xAB)
      end.to raise_error(IronLionUUID::ConfigurationError)
    end
  end

  describe "#validate_value!" do
    let(:attribute) { described_class.new(:test, 8) }

    it "passes for values within the bit width" do
      expect(attribute.validate_value!(0)).to be true
      expect(attribute.validate_value!(255)).to be true
    end

    it "raises an error for values that exceed the bit width" do
      expect do
        attribute.validate_value!(256)
      end.to raise_error(IronLionUUID::ValueTooLargeError)
    end
  end
end
