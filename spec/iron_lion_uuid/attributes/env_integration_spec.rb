# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Environment Variable Attribute Integration" do
  # Reset configuration before each test
  before do
    if IronLionUUID.instance_variable_defined?(:@configuration)
      IronLionUUID.remove_instance_variable(:@configuration)
    end
    if IronLionUUID.instance_variable_defined?(:@generator)
      IronLionUUID.remove_instance_variable(:@generator)
    end
  end

  # Manage environment variables
  around do |example|
    # Save original environment variables
    old_env = ENV.to_hash

    # Run the test
    example.run

    # Restore environment variables
    ENV.clear
    old_env.each { |k, v| ENV[k] = v }
  end

  describe "UUID generation with environment variables" do
    it "configures UUIDs with environment variable attributes" do
      IronLionUUID.configure do |uuid|
        uuid.env(bits: 12, name: :node, key: :NODE_ID)
        uuid.env(bits: 8, name: :env_type, key: :ENV_TYPE)
      end

      config = IronLionUUID.configuration
      # 2 configured env attributes + auto-added random for remaining bits
      expect(config.attributes.size).to eq(3)

      # Check specific attributes
      node_attr = config.attribute_by_name(:node)
      expect(node_attr).to be_a(IronLionUUID::EnvAttribute)
      expect(node_attr.bits).to eq(12)
      expect(node_attr[:key]).to eq(:NODE_ID)

      env_type_attr = config.attribute_by_name(:env_type)
      expect(env_type_attr).to be_a(IronLionUUID::EnvAttribute)
      expect(env_type_attr.bits).to eq(8)
      expect(env_type_attr[:key]).to eq(:ENV_TYPE)
    end

    it "generates UUIDs with environment variable values" do
      # Set up environment variables
      ENV["NODE_ID"] = "42"
      ENV["ENV_TYPE"] = "1"

      IronLionUUID.configure do |uuid|
        uuid.env(bits: 12, name: :node, key: :NODE_ID)
        uuid.env(bits: 8, name: :env_type, key: :ENV_TYPE)
      end

      # Generate a UUID using environment variables
      uuid = IronLionUUID.generate

      # Basic validations
      expect(uuid).to be_a(IronLionUUID::CustomUUID)

      # Check version and variant bits
      expect(IronLionUUID::BitOps.extract_bits(uuid.value, 48, 4)).to eq(8) # Version
      expect(IronLionUUID::BitOps.extract_bits(uuid.value, 64, 2)).to eq(2) # Variant

      # Check environment variable values via accessor methods
      expect(uuid.node).to eq(42)
      expect(uuid.env_type).to eq(1)
    end

    it "handles string environment variables and converts them" do
      # Set up environment variable with a string value
      ENV["NODE_ID"] = "a1b2c3" # Base36 value

      IronLionUUID.configure do |uuid|
        uuid.env(bits: 32, name: :node, key: :NODE_ID)
      end

      # Generate a UUID with the environment variable
      uuid = IronLionUUID.generate

      # Check environment variable value via accessor method
      # "a1b2c3" in base36 will be converted to a base10 integer
      expect(uuid.node).to eq("a1b2c3".to_i(36))
    end

    it "raises an error if an environment variable is not set" do
      # Ensure the environment variable is not set
      ENV.delete("NODE_ID")

      IronLionUUID.configure do |uuid|
        uuid.env(bits: 12, name: :node, key: :NODE_ID)
      end

      # Should raise an error when generating a UUID
      expect do
        IronLionUUID.generate
      end.to raise_error(IronLionUUID::MissingEnvironmentError)
    end

    it "raises an error if an environment variable value is too large" do
      # Set environment variable to a value too large for 8 bits
      ENV["ENV_TYPE"] = "256" # Max for 8 bits is 255

      IronLionUUID.configure do |uuid|
        uuid.env(bits: 8, name: :env_type, key: :ENV_TYPE)
      end

      # Should raise an error when generating a UUID
      expect { IronLionUUID.generate }.to raise_error(IronLionUUID::ValueTooLargeError)
    end

    it "combines environment variable and parameter attributes" do
      # Set up environment variable
      ENV["NODE_ID"] = "42"

      IronLionUUID.configure do |uuid|
        uuid.env(bits: 12, name: :node, key: :NODE_ID)
        uuid.parameter(bits: 16, name: :model)
      end

      # Generate a UUID with a parameter
      uuid = IronLionUUID.generate(101)

      # Check values via accessor methods
      expect(uuid.node).to eq(42)
      expect(uuid.model).to eq(101)
    end

    it "combines environment variable and random attributes" do
      # Set up environment variable
      ENV["NODE_ID"] = "42"

      IronLionUUID.configure do |uuid|
        uuid.env(bits: 12, name: :node, key: :NODE_ID)
        uuid.random(bits: 32, name: :r1)
      end

      # Generate UUIDs with the same environment variable but different random values
      uuid1 = IronLionUUID.generate
      uuid2 = IronLionUUID.generate

      # Node values should be the same
      expect(uuid1.node).to eq(42)
      expect(uuid2.node).to eq(42)

      # Random values should be different (extremely high probability)
      expect(uuid1.r1).not_to eq(uuid2.r1)

      # Overall UUID values should be different
      expect(uuid1.value).not_to eq(uuid2.value)
    end
  end

  describe "environment variable accessor methods" do
    it "creates accessor methods for named environment variable attributes" do
      # Set up environment variables
      ENV["NODE_ID"] = "42"
      ENV["ENV_TYPE"] = "1"

      IronLionUUID.configure do |uuid|
        uuid.env(bits: 12, name: :node, key: :NODE_ID)
        uuid.env(bits: 8, name: :env_type, key: :ENV_TYPE)
      end

      # Generate a UUID
      uuid = IronLionUUID.generate

      # Should have accessor methods for all named attributes
      expect(uuid).to respond_to(:node)
      expect(uuid).to respond_to(:env_type)

      # Accessor methods should return the correct values
      expect(uuid.node).to eq(42)
      expect(uuid.env_type).to eq(1)
    end
  end
end
