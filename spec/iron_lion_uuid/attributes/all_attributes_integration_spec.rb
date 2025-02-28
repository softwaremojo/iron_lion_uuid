# frozen_string_literal: true

require "spec_helper"

RSpec.describe "All Attributes Integration" do
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

  describe "Integration of Parameter and Environment attributes" do
    it "configures and generates UUIDs with both parameter and environment attributes" do
      # Set up environment variables
      ENV["NODE_ID"] = "42"

      IronLionUUID.configure do |uuid|
        uuid.parameter(bits: 16, name: :model)
        uuid.env(bits: 12, name: :node, key: :NODE_ID)
        uuid.random(bits: 32, name: :random_part)
      end

      # Generate a UUID with a parameter
      uuid = IronLionUUID.generate(101)

      # Check attributes were applied correctly
      expect(uuid.model).to eq(101)
      expect(uuid.node).to eq(42)
      expect(uuid.random_part).to be_a(Integer)

      # Generate another UUID with a different parameter
      uuid2 = IronLionUUID.generate(202)

      # Model value should change
      expect(uuid2.model).to eq(202)

      # Node value should remain the same
      expect(uuid2.node).to eq(42)

      # Random value should be different
      expect(uuid2.random_part).to be_a(Integer)
      expect(uuid2.random_part).not_to eq(uuid.random_part)

      # Change environment variable
      ENV["NODE_ID"] = "99"

      # Generate another UUID
      uuid3 = IronLionUUID.generate(101)

      # Model value should be the same as the first UUID
      expect(uuid3.model).to eq(101)

      # Node value should change
      expect(uuid3.node).to eq(99)

      # Overall UUID values should be different
      expect(uuid3.value).not_to eq(uuid.value)
      expect(uuid3.value).not_to eq(uuid2.value)
    end

    it "handles different attribute orders in configuration" do
      # Set up environment variables
      ENV["NODE_ID"] = "42"
      ENV["ENV_TYPE"] = "1"

      # Configure with attributes in a specific order
      IronLionUUID.configure do |uuid|
        uuid.env(bits: 12, name: :node, key: :NODE_ID)
        uuid.parameter(bits: 16, name: :model)
        uuid.env(bits: 8, name: :env_type, key: :ENV_TYPE)
      end

      # Generate a UUID
      uuid = IronLionUUID.generate(101)

      # All attributes should be correctly applied
      expect(uuid.node).to eq(42)
      expect(uuid.model).to eq(101)
      expect(uuid.env_type).to eq(1)

      # Configure with a different order
      if IronLionUUID.instance_variable_defined?(:@configuration)
        IronLionUUID.remove_instance_variable(:@configuration)
      end
      if IronLionUUID.instance_variable_defined?(:@generator)
        IronLionUUID.remove_instance_variable(:@generator)
      end

      IronLionUUID.configure do |config|
        config.parameter(bits: 16, name: :model)
        config.env(bits: 8, name: :env_type, key: :ENV_TYPE)
        config.env(bits: 12, name: :node, key: :NODE_ID)
      end

      # Generate another UUID
      uuid2 = IronLionUUID.generate(101)

      # All attributes should still be correctly applied
      expect(uuid2.node).to eq(42)
      expect(uuid2.model).to eq(101)
      expect(uuid2.env_type).to eq(1)
    end

    it "handles error cases from both attribute types" do
      # Set up environment variables
      ENV["NODE_ID"] = "42"

      IronLionUUID.configure do |uuid|
        uuid.parameter(bits: 8, name: :status)
        uuid.env(bits: 12, name: :node, key: :NODE_ID)
      end

      # Missing parameter
      expect { IronLionUUID.generate }.to raise_error(ArgumentError)

      # Parameter too large
      expect do
        IronLionUUID.generate(256)
      end.to raise_error(IronLionUUID::ValueTooLargeError)

      # Generate a valid UUID
      uuid = IronLionUUID.generate(1)
      expect(uuid.status).to eq(1)
      expect(uuid.node).to eq(42)

      # Missing environment variable
      ENV.delete("NODE_ID")
      expect do
        IronLionUUID.generate(1)
      end.to raise_error(IronLionUUID::MissingEnvironmentError)

      # Set environment variable to a value that's too large
      ENV["NODE_ID"] = "4096" # Max for 12 bits is 4095
      expect { IronLionUUID.generate(1) }.to raise_error(IronLionUUID::ValueTooLargeError)
    end
  end

  describe "UUID uniqueness and randomness" do
    it "generates unique UUIDs even with the same parameter and environment values" do
      # Set up environment variables
      ENV["NODE_ID"] = "42"

      IronLionUUID.configure do |uuid|
        uuid.parameter(bits: 16, name: :model)
        uuid.env(bits: 12, name: :node, key: :NODE_ID)
        # The rest will be filled with random data
      end

      # Generate multiple UUIDs with the same parameter
      uuids = Array.new(100) { IronLionUUID.generate(101) }

      # All UUIDs should have the same parameter and environment values
      uuids.each do |uuid|
        expect(uuid.model).to eq(101)
        expect(uuid.node).to eq(42)
      end

      # But all UUIDs should be unique due to random bits
      expect(uuids.map(&:to_s).uniq.size).to eq(100)
    end

    it "preserves the configured bit structure" do
      # Set up environment variables
      ENV["NODE_ID"] = "42"

      # Configure with specific bit allocations
      IronLionUUID.configure do |uuid|
        uuid.parameter(bits: 16, name: :model)
        uuid.env(bits: 12, name: :node, key: :NODE_ID)
        uuid.random(bits: 32, name: :r1)
      end

      # Generate a UUID
      uuid = IronLionUUID.generate(101)

      # Check attribute values
      expect(uuid.model).to eq(101)
      expect(uuid.node).to eq(42)
      expect(uuid.r1).to be_a(Integer)

      # Model should fit in 16 bits
      expect(uuid.model).to be < (1 << 16)

      # Node should fit in 12 bits
      expect(uuid.node).to be < (1 << 12)

      # r1 should fit in 32 bits
      expect(uuid.r1).to be < (1 << 32)
    end
  end
end
