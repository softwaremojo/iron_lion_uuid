# frozen_string_literal: true

require "spec_helper"

RSpec.describe "IronLionUUID Integration" do
  # Reset configuration before each test
  before do
    if IronLionUUID.instance_variable_defined?(:@configuration)
      IronLionUUID.remove_instance_variable(:@configuration)
    end
    if IronLionUUID.instance_variable_defined?(:@generator)
      IronLionUUID.remove_instance_variable(:@generator)
    end
  end

  describe "Random attribute integration" do
    it "configures UUIDs with random attributes" do
      IronLionUUID.configure do |uuid|
        uuid.random(bits: 32, name: :r1)
        uuid.random(bits: 32, name: :r2)
      end

      config = IronLionUUID.configuration
      expect(config.attributes.size).to eq(3) # 2 defined, 1 auto-added

      # Check specific attributes
      r1 = config.attribute_by_name(:r1)
      expect(r1).to be_a(IronLionUUID::RandomAttribute)
      expect(r1.bits).to eq(32)

      r2 = config.attribute_by_name(:r2)
      expect(r2).to be_a(IronLionUUID::RandomAttribute)
      expect(r2.bits).to eq(32)

      # Third attribute should be auto-added random for remaining bits
      auto_random = config.attributes.last
      expect(auto_random).to be_a(IronLionUUID::RandomAttribute)
      expect(auto_random.bits).to eq(122 - 64) # Remaining bits
    end

    it "generates UUIDs with random attributes" do
      IronLionUUID.configure do |uuid|
        uuid.random(bits: 32, name: :r1)
        uuid.random(bits: 32, name: :r2)
      end

      # Generate multiple UUIDs
      uuid1 = IronLionUUID.generate
      uuid2 = IronLionUUID.generate

      # Basic validations
      expect(uuid1).to be_a(IronLionUUID::UUID)
      expect(uuid2).to be_a(IronLionUUID::UUID)

      # UUIDs should be different (extremely high probability)
      expect(uuid1.value).not_to eq(uuid2.value)

      # Check version and variant bits
      expect(IronLionUUID::BitOps.extract_bits(uuid1.value, 48, 4)).to eq(8) # Version
      expect(IronLionUUID::BitOps.extract_bits(uuid1.value, 64, 2)).to eq(2) # Variant
    end

    it "auto-fills remaining bits with random data" do
      # Configure with just a small attribute
      IronLionUUID.configure do |uuid|
        uuid.random(bits: 16)
      end

      config = IronLionUUID.configuration

      # Should have 2 attributes - our 16-bit one and an auto-added one
      expect(config.attributes.size).to eq(2)

      # Second attribute should be random for remaining bits
      auto_random = config.attributes.last
      expect(auto_random).to be_a(IronLionUUID::RandomAttribute)
      expect(auto_random.bits).to eq(122 - 16) # Remaining bits

      # Generate UUIDs to make sure it works
      uuid = IronLionUUID.generate
      expect(uuid).to be_a(IronLionUUID::UUID)
    end

    it "handles full bit allocation" do
      # Configure with attributes that use exactly all available bits
      IronLionUUID.configure do |uuid|
        uuid.random(bits: 60)
        uuid.random(bits: 62)
      end

      config = IronLionUUID.configuration

      # Should have exactly 2 attributes - no auto-added ones
      expect(config.attributes.size).to eq(2)
      expect(config.total_bits).to eq(122)
      expect(config.remaining_bits).to eq(0)

      # Generate UUIDs to make sure it works
      uuid = IronLionUUID.generate
      expect(uuid).to be_a(IronLionUUID::UUID)
    end

    it "validates string UUIDs" do
      # First configure and generate a valid UUID
      IronLionUUID.configure do |uuid|
        uuid.random(bits: 122)
      end

      uuid = IronLionUUID.generate
      uuid_str = uuid.to_s

      # Test string validation
      expect(IronLionUUID.valid?(uuid_str)).to be true
      expect(IronLionUUID.valid?(uuid)).to be true
      expect(IronLionUUID.valid?("not-a-uuid")).to be false
    end
  end
end
