# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Parameter Attribute Integration" do
  # Reset configuration before each test
  before do
    if IronLionUUID.instance_variable_defined?(:@configuration)
      IronLionUUID.remove_instance_variable(:@configuration)
    end
    if IronLionUUID.instance_variable_defined?(:@generator)
      IronLionUUID.remove_instance_variable(:@generator)
    end
  end

  describe "UUID generation with parameters" do
    it "configures UUIDs with parameter attributes" do
      IronLionUUID.configure do |uuid|
        uuid.parameter(bits: 16, name: :model)
        uuid.parameter(bits: 8, name: :status)
      end

      config = IronLionUUID.configuration
      # 2 configured parameters + auto-added random for remaining bits
      expect(config.attributes.size).to eq(3)

      # Check specific attributes
      model_attr = config.attribute_by_name(:model)
      expect(model_attr).to be_a(IronLionUUID::ParameterAttribute)
      expect(model_attr.bits).to eq(16)

      status_attr = config.attribute_by_name(:status)
      expect(status_attr).to be_a(IronLionUUID::ParameterAttribute)
      expect(status_attr.bits).to eq(8)
    end

    it "generates UUIDs with parameter values" do
      IronLionUUID.configure do |uuid|
        uuid.parameter(bits: 16, name: :model)
        uuid.parameter(bits: 8, name: :status)
      end

      # Generate a UUID with parameter values
      uuid = IronLionUUID.generate(42, 7)

      # Basic validations
      expect(uuid).to be_a(IronLionUUID::CustomUUID)

      # Check version and variant bits
      expect(IronLionUUID::BitOps.extract_bits(uuid.value, 48, 4)).to eq(8) # Version
      expect(IronLionUUID::BitOps.extract_bits(uuid.value, 64, 2)).to eq(2) # Variant

      # Check parameter values via accessor methods
      expect(uuid.model).to eq(42)
      expect(uuid.status).to eq(7)
    end

    it "accepts string parameters and converts them" do
      IronLionUUID.configure do |uuid|
        uuid.parameter(bits: 16, name: :model)
      end

      # Generate a UUID with a string parameter ("z" in base36 is 35 in base10)
      uuid = IronLionUUID.generate("z")

      # Check parameter value via accessor method
      expect(uuid.model).to eq(35)
    end

    it "raises an error if not enough parameters are provided" do
      IronLionUUID.configure do |uuid|
        uuid.parameter(bits: 16, name: :model)
        uuid.parameter(bits: 8, name: :status)
      end

      # Should require two parameters
      expect { IronLionUUID.generate(42) }.to raise_error(ArgumentError)
      expect { IronLionUUID.generate }.to raise_error(ArgumentError)
    end

    it "raises an error if parameter value is too large" do
      IronLionUUID.configure do |uuid|
        uuid.parameter(bits: 8, name: :status)
      end

      # Max value for 8 bits is 255
      expect do
        IronLionUUID.generate(256)
      end.to raise_error(IronLionUUID::ValueTooLargeError)
    end

    it "combines parameter and random attributes" do
      IronLionUUID.configure do |uuid|
        uuid.parameter(bits: 16, name: :model)
        uuid.random(bits: 32, name: :r1)
      end

      # Generate UUIDs with the same parameter but different random values
      uuid1 = IronLionUUID.generate(42)
      uuid2 = IronLionUUID.generate(42)

      # Model values should be the same
      expect(uuid1.model).to eq(42)
      expect(uuid2.model).to eq(42)

      # Random values should be different (extremely high probability)
      expect(uuid1.r1).not_to eq(uuid2.r1)

      # Overall UUID values should be different
      expect(uuid1.value).not_to eq(uuid2.value)
    end
  end

  describe "parameter accessor methods" do
    it "creates accessor methods for named attributes" do
      IronLionUUID.configure do |uuid|
        uuid.parameter(bits: 16, name: :model)
        uuid.parameter(bits: 8, name: :status)
        uuid.random(bits: 32, name: :r1)
      end

      # Generate a UUID
      uuid = IronLionUUID.generate(42, 7)

      # Should have accessor methods for all named attributes
      expect(uuid).to respond_to(:model)
      expect(uuid).to respond_to(:status)
      expect(uuid).to respond_to(:r1)

      # Accessor methods should return the correct values
      expect(uuid.model).to eq(42)
      expect(uuid.status).to eq(7)
      expect(uuid.r1).to be_a(Integer) # Random value
    end

    it "extracts parameter values correctly regardless of order" do
      IronLionUUID.configure do |uuid|
        # Add attributes in a different order from how bits are arranged
        uuid.random(bits: 32, name: :r1)
        uuid.parameter(bits: 16, name: :model)
        uuid.parameter(bits: 8, name: :status)
      end

      # Generate a UUID - parameters should be passed in the order they were configured
      uuid = IronLionUUID.generate(42, 7)

      # Values should be extracted correctly
      expect(uuid.model).to eq(42)
      expect(uuid.status).to eq(7)
    end
  end
end
