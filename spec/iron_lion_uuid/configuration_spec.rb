# frozen_string_literal: true

require "spec_helper"
require "pry"

RSpec.describe IronLionUUID::Configuration do
  describe "#initialize" do
    it "creates an empty configuration" do
      config = described_class.new
      expect(config.attributes).to be_empty
      expect(config.total_bits).to eq(0)
      expect(config.frozen?).to be false
    end
  end

  describe "#add_attribute" do
    it "adds an attribute to the configuration" do
      config = described_class.new
      attribute = IronLionUUID::Attribute.new(:test, 16, name: :test_attribute)

      config.add_attribute(attribute)

      expect(config.attributes).to include(attribute)
      expect(config.total_bits).to eq(16)
    end

    it "raises an error if the configuration is frozen" do
      config = described_class.new
      config.freeze!

      expect do
        config.add_attribute(IronLionUUID::Attribute.new(:test, 16))
      end.to raise_error(IronLionUUID::FrozenConfigurationError)
    end
  end

  describe "#validate!" do
    it "passes if the total bits are within the limit" do
      config = described_class.new

      # Add attributes up to exactly the limit
      config.add_attribute(IronLionUUID::Attribute.new(:test1, 60))
      config.add_attribute(IronLionUUID::Attribute.new(:test2, 62))

      expect(config.total_bits).to eq(122)
      expect(config.validate!).to be true
    end

    it "raises an error if the total bits exceed the limit" do
      config = described_class.new

      # Add attributes that exceed the limit
      config.add_attribute(IronLionUUID::Attribute.new(:test1, 60))
      config.add_attribute(IronLionUUID::Attribute.new(:test2, 63))

      expect(config.total_bits).to eq(123)

      expect do
        config.validate!
      end.to raise_error(IronLionUUID::InvalidBitWidthError)
    end
  end

  describe "#freeze!" do
    it "freezes the configuration" do
      config = described_class.new
      config.freeze!

      expect(config.frozen?).to be true
    end

    it "returns self" do
      config = described_class.new
      expect(config.freeze!).to eq(config)
    end
  end

  describe "#remaining_bits" do
    it "returns the number of remaining bits" do
      config = described_class.new

      expect(config.remaining_bits).to eq(122)

      config.add_attribute(IronLionUUID::Attribute.new(:test1, 40))
      expect(config.remaining_bits).to eq(82)

      config.add_attribute(IronLionUUID::Attribute.new(:test2, 30))
      expect(config.remaining_bits).to eq(52)
    end
  end

  describe "attribute definition methods" do
    let(:config) { described_class.new }

    it "supports parameter attributes" do
      config.parameter(bits: 16, name: :model)

      attribute = config.attributes.last
      expect(attribute.type).to eq(:parameter)
      expect(attribute.bits).to eq(16)
      expect(attribute.name).to eq(:model)
    end

    it "supports env attributes" do
      config.env(bits: 12, name: :node, key: :NODE_ID)

      attribute = config.attributes.last
      expect(attribute.type).to eq(:env)
      expect(attribute.bits).to eq(12)
      expect(attribute.name).to eq(:node)
      expect(attribute[:key]).to eq(:NODE_ID)
    end

    it "supports timestamp attributes" do
      config.timestamp(bits: 36, precision: :millisecond)

      attribute = config.attributes.last
      expect(attribute.type).to eq(:timestamp)
      expect(attribute.bits).to eq(36)
      expect(attribute[:precision]).to eq(:millisecond)
    end

    it "supports random attributes" do
      config.random(bits: 32)

      attribute = config.attributes.last
      expect(attribute.type).to eq(:random)
      expect(attribute.bits).to eq(32)
    end

    it "supports sequence attributes" do
      config.sequence(bits: 16)

      attribute = config.attributes.last
      expect(attribute.type).to eq(:sequence)
      expect(attribute.bits).to eq(16)
    end
  end
end
