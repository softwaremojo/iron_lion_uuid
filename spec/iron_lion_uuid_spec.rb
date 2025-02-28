# frozen_string_literal: true

require "spec_helper"

RSpec.describe IronLionUUID do
  describe ".configure" do
    # Reset configuration before each test
    before do
      # Hack to reset the configuration between tests
      if described_class.instance_variable_defined?(:@configuration)
        described_class.remove_instance_variable(:@configuration)
      end
    end

    it "yields a Configuration instance to the block" do
      yielded_object = nil

      described_class.configure do |config|
        yielded_object = config
      end

      expect(yielded_object).to be_a(described_class::Configuration)
    end

    it "returns the configuration" do
      config = described_class.configure do |c|
        c.random(bits: 32)
      end

      expect(config).to be_a(described_class::Configuration)
      expect(config.attributes.size).to eq(1)
      expect(config.attributes.first.type).to eq(:random)
    end

    it "validates and freezes the configuration after the block" do
      config = described_class.configure do |c|
        c.random(bits: 32)
      end

      expect(config.frozen?).to be true
    end

    it "allows configuration with multiple attribute types" do
      described_class.configure do |uuid|
        uuid.parameter(bits: 16, name: :model)
        uuid.env(bits: 12, name: :node, key: :NODE_ID)
        uuid.timestamp(bits: 36, precision: :millisecond)
        uuid.random(bits: 32)
        uuid.sequence(bits: 16)
      end

      config = described_class.configuration
      expect(config.attributes.size).to eq(5)
      expect(config.total_bits).to eq(112)

      attribute_types = config.attributes.map(&:type)
      expect(attribute_types).to eq(%i[parameter env timestamp random sequence])
    end

    it "raises an error if total bits exceed the limit" do
      expect do
        described_class.configure do |uuid|
          uuid.random(bits: 123)
        end
      end.to raise_error(described_class::InvalidBitWidthError)
    end

    it "raises an error if configure is called again after initialization" do
      described_class.configure do |uuid|
        uuid.random(bits: 32)
      end

      expect do
        described_class.configure do |uuid|
          uuid.random(bits: 32)
        end
      end.to raise_error(described_class::FrozenConfigurationError)
    end
  end

  describe ".configuration" do
    before do
      # Hack to reset the configuration between tests
      if described_class.instance_variable_defined?(:@configuration)
        described_class.remove_instance_variable(:@configuration)
      end
    end

    it "returns nil if not configured" do
      expect(described_class.configuration).to be_nil
    end

    it "returns the configuration after configure is called" do
      described_class.configure do |uuid|
        uuid.random(bits: 32)
      end

      config = described_class.configuration
      expect(config).to be_a(described_class::Configuration)
      expect(config.attributes.size).to eq(1)
    end
  end
end
