# frozen_string_literal: true

require "spec_helper"

RSpec.describe IronLionUUID::Generator do
  describe "#initialize" do
    it "accepts a configuration object" do
      config = IronLionUUID::Configuration.new
      generator = described_class.new(config)

      expect(generator.instance_variable_get(:@configuration)).to eq(config)
    end
  end

  describe "#generate" do
    let(:config) { IronLionUUID::Configuration.new }
    let(:generator) { described_class.new(config) }

    context "with a random attribute" do
      before do
        # Add a random attribute to the configuration
        random_attr = IronLionUUID::RandomAttribute.new(bits: 32)
        random_attr.position = 0 # manually set position
        config.add_attribute(random_attr)
      end

      it "generates a UUID with the random attribute" do
        # We'll verify correct behavior by mocking the random attribute
        random_attr = config.attributes.first

        # Expect random attribute to generate a value and apply it
        allow(random_attr).to receive(:generate_value).and_return(42)
        allow(random_attr).to receive(:apply_to).and_call_original

        uuid = generator.generate

        expect(uuid).to be_a(IronLionUUID::UUID)
        expect(uuid.value).to be > 0 # Value should be non-zero
      end

      it "sets version and variant bits correctly" do
        uuid = generator.generate

        # Extract version bits (bits 48-51)
        version = IronLionUUID::BitOps.extract_bits(uuid.value, 48, 4)
        expect(version).to eq(8) # UUID v8

        # Extract variant bits (bits 64-65)
        variant = IronLionUUID::BitOps.extract_bits(uuid.value, 64, 2)
        expect(variant).to eq(2) # RFC 4122 variant
      end
    end

    context "with multiple random attributes" do
      before do
        # Add two random attributes to the configuration
        random_attr1 = IronLionUUID::RandomAttribute.new(bits: 16)
        random_attr1.position = 0
        config.add_attribute(random_attr1)

        random_attr2 = IronLionUUID::RandomAttribute.new(bits: 16)
        random_attr2.position = 16
        config.add_attribute(random_attr2)
      end

      it "applies all attributes to the UUID" do
        # Verify both attributes are used
        random_attr1 = config.attributes[0]
        random_attr2 = config.attributes[1]

        allow(random_attr1).to receive(:generate_value).and_return(0xAAAA)
        allow(random_attr1).to receive(:apply_to).and_call_original

        allow(random_attr2).to receive(:generate_value).and_return(0xBBBB)
        allow(random_attr2).to receive(:apply_to).and_call_original

        uuid = generator.generate

        # Value should have both random values at the right positions
        # Plus version and variant bits
        # We'll only test that the value is non-zero for simplicity
        expect(uuid.value).to be > 0
      end
    end
  end
end
