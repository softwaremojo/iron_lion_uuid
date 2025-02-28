# frozen_string_literal: true

require "spec_helper"

RSpec.describe IronLionUUID::Attributes::Parameter do
  describe "#initialize" do
    it "creates a parameter attribute with bits and name" do
      attr = described_class.new(bits: 16, name: :model)

      expect(attr.type).to eq(:parameter)
      expect(attr.bits).to eq(16)
      expect(attr.name).to eq(:model)
    end

    it "raises an error if bit width is not provided" do
      # :bits is nil
      expect do
        described_class.new(name: :model)
      end.to raise_error(NoMethodError)
    end

    it "raises an error if name is not provided" do
      expect do
        described_class.new(bits: 16)
      end.to raise_error(IronLionUUID::ConfigurationError)
    end
  end

  describe "#generate_value" do
    let(:attr) { described_class.new(bits: 8, name: :test) }

    it "returns integer values as-is" do
      expect(attr.generate_value(123)).to eq(123)
    end

    it "converts string values from base36 to base10" do
      expect(attr.generate_value("a")).to eq(10)
      expect(attr.generate_value("z")).to eq(35)
      expect(attr.generate_value("10")).to eq(36)
    end

    it "attempts to convert other types to string then base36" do
      # Using a class that converts to a simple string with to_s
      obj = Class.new do
        def to_s
          "a" # Base36 'a' = Base10 10
        end
      end.new

      expect(attr.generate_value(obj)).to eq(10)
    end

    it "raises an error if no value is provided" do
      expect { attr.generate_value }.to raise_error(ArgumentError)
    end

    it "raises an error if the value exceeds the bit width" do
      # Max value for 8 bits is 255
      expect { attr.generate_value(256) }.to raise_error(IronLionUUID::ValueTooLargeError)
      # Base36 "7o" > 255
      expect do
        attr.generate_value("7o")
      end.to raise_error(IronLionUUID::ValueTooLargeError)
    end
  end

  describe "integration with Configuration" do
    it "can be added through the configuration DSL" do
      config = IronLionUUID::Configuration.new
      config.parameter(bits: 16, name: :model)

      attr = config.attributes.first
      expect(attr).to be_a(described_class)
      expect(attr.bits).to eq(16)
      expect(attr.name).to eq(:model)
    end

    it "validates required options" do
      config = IronLionUUID::Configuration.new

      expect do
        config.parameter(bits: 16)
      end.to raise_error(IronLionUUID::ConfigurationError)
      expect do
        config.parameter(name: :model)
      end.to raise_error(IronLionUUID::ConfigurationError)
    end
  end
end
