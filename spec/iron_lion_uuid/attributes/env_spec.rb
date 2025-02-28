# frozen_string_literal: true

require "spec_helper"

RSpec.describe IronLionUUID::Attributes::Env do
  describe "#initialize" do
    it "creates an env attribute with bits, name, and key" do
      attr = described_class.new(bits: 12, name: :node, key: :NODE_ID)

      expect(attr.type).to eq(:env)
      expect(attr.bits).to eq(12)
      expect(attr.name).to eq(:node)
      expect(attr[:key]).to eq(:NODE_ID)
    end

    it "raises an error if bit width is not provided" do
      # :bits is nil
      expect do
        described_class.new(name: :node, key: :NODE_ID)
      end.to raise_error(NoMethodError)
    end

    it "raises an error if name is not provided" do
      expect do
        described_class.new(bits: 12,
                            key: :NODE_ID)
      end.to raise_error(IronLionUUID::ConfigurationError)
    end

    it "raises an error if key is not provided" do
      expect do
        described_class.new(bits: 12,
                            name: :node)
      end.to raise_error(IronLionUUID::ConfigurationError)
    end
  end

  describe "#generate_value" do
    let(:attr) { described_class.new(bits: 8, name: :node, key: :NODE_ID) }

    around do |example|
      # Save original environment variables
      old_env = ENV.to_hash

      # Run the test
      example.run

      # Restore environment variables
      ENV.clear
      old_env.each { |k, v| ENV[k] = v }
    end

    it "retrieves numeric values from the environment" do
      ENV["NODE_ID"] = "123"
      expect(attr.generate_value).to eq(123)
    end

    it "converts string values from base36 to base10" do
      ENV["NODE_ID"] = "a"
      expect(attr.generate_value).to eq(10)

      ENV["NODE_ID"] = "z"
      expect(attr.generate_value).to eq(35)

      ENV["NODE_ID"] = "10"
      expect(attr.generate_value).to eq(36)
    end

    it "raises an error if the environment variable is not set" do
      ENV.delete("NODE_ID")
      expect { attr.generate_value }.to raise_error(IronLionUUID::MissingEnvironmentError)
    end

    it "raises an error if the environment variable is empty" do
      ENV["NODE_ID"] = ""
      expect { attr.generate_value }.to raise_error(IronLionUUID::MissingEnvironmentError)
    end

    it "raises an error if the value exceeds the bit width" do
      # Max value for 8 bits is 255
      ENV["NODE_ID"] = "256"
      expect { attr.generate_value }.to raise_error(IronLionUUID::ValueTooLargeError)

      ENV["NODE_ID"] = "7o" # Base36 "7o" > 255
      expect { attr.generate_value }.to raise_error(IronLionUUID::ValueTooLargeError)
    end

    it "handles string keys" do
      attr = described_class.new(bits: 8, name: :node, key: "NODE_ID")
      ENV["NODE_ID"] = "123"
      expect(attr.generate_value).to eq(123)
    end
  end

  describe "integration with Configuration" do
    it "can be added through the configuration DSL" do
      config = IronLionUUID::Configuration.new
      config.env(bits: 12, name: :node, key: :NODE_ID)

      attr = config.attributes.first
      expect(attr).to be_a(described_class)
      expect(attr.bits).to eq(12)
      expect(attr.name).to eq(:node)
      expect(attr[:key]).to eq(:NODE_ID)
    end

    it "validates required options" do
      config = IronLionUUID::Configuration.new

      expect { config.env(bits: 12, name: :node) }
        .to raise_error(IronLionUUID::ConfigurationError)

      expect { config.env(bits: 12, key: :NODE_ID) }
        .to raise_error(IronLionUUID::ConfigurationError)

      expect { config.env(name: :node, key: :NODE_ID) }
        .to raise_error(IronLionUUID::ConfigurationError)
    end
  end
end
