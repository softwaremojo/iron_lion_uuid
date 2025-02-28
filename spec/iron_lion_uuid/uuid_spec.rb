# frozen_string_literal: true

require "spec_helper"

RSpec.describe IronLionUUID::UUID do
  describe "#initialize" do
    it "creates a UUID with a valid 128-bit value" do
      uuid = described_class.new(0)
      expect(uuid.value).to eq(0)

      max_value = (1 << 128) - 1
      uuid = described_class.new(max_value)
      expect(uuid.value).to eq(max_value)
    end

    it "raises an error if the value is not an integer" do
      expect { described_class.new("not an integer") }.to(
        raise_error(ArgumentError, /must be an integer/)
      )
    end

    it "raises an error if the value is negative" do
      expect { described_class.new(-1) }.to(
        raise_error(ArgumentError, /must be a 128-bit unsigned integer/)
      )
    end

    it "raises an error if the value exceeds 128 bits" do
      expect { described_class.new(1 << 128) }.to(
        raise_error(ArgumentError, /must be a 128-bit unsigned integer/)
      )
    end
  end

  describe "#to_s" do
    it "returns a correctly formatted UUID string" do
      uuid = described_class.new(0)
      expect(uuid.to_s).to eq("00000000-0000-0000-0000-000000000000")

      # Create a UUID with a known pattern for easy verification
      value = 0x123456789abcdef0123456789abcdef0
      uuid = described_class.new(value)
      expect(uuid.to_s).to eq("12345678-9abc-def0-1234-56789abcdef0")
    end

    it "pads hex values with leading zeros" do
      uuid = described_class.new(1)
      expect(uuid.to_s).to eq("00000000-0000-0000-0000-000000000001")
    end
  end

  describe "#to_hex" do
    it "returns a raw hex string without hyphens" do
      uuid = described_class.new(0)
      expect(uuid.to_hex).to eq("00000000000000000000000000000000")

      # Create a UUID with a known pattern for easy verification
      value = 0x123456789abcdef0123456789abcdef0
      uuid = described_class.new(value)
      expect(uuid.to_hex).to eq("123456789abcdef0123456789abcdef0")
    end
  end

  describe "#==" do
    it "returns true for UUIDs with the same value" do
      uuid1 = described_class.new(123)
      uuid2 = described_class.new(123)
      expect(uuid1).to eq(uuid2)
    end

    it "returns false for UUIDs with different values" do
      uuid1 = described_class.new(123)
      uuid2 = described_class.new(456)
      expect(uuid1).not_to eq(uuid2)
    end

    it "returns false for non-UUID objects" do
      uuid = described_class.new(123)
      expect(uuid).not_to eq("not a uuid")
    end
  end

  describe "#eql?" do
    it "behaves the same as ==" do
      uuid1 = described_class.new(123)
      uuid2 = described_class.new(123)
      uuid3 = described_class.new(456)

      expect(uuid1.eql?(uuid2)).to be true
      expect(uuid1.eql?(uuid3)).to be false
      expect(uuid1.eql?("not a uuid")).to be false
    end
  end

  describe "#hash" do
    it "returns the same hash for UUIDs with the same value" do
      uuid1 = described_class.new(123)
      uuid2 = described_class.new(123)
      expect(uuid1.hash).to eq(uuid2.hash)
    end

    it "usually returns different hashes for UUIDs with different values" do
      uuid1 = described_class.new(123)
      uuid2 = described_class.new(456)
      expect(uuid1.hash).not_to eq(uuid2.hash)
    end

    it "allows UUIDs to be used as hash keys" do
      uuid1 = described_class.new(123)
      uuid2 = described_class.new(123)
      uuid3 = described_class.new(456)

      hash = { uuid1 => "value1" }
      expect(hash[uuid2]).to eq("value1")
      expect(hash[uuid3]).to be_nil
    end
  end

  describe "#inspect" do
    it "returns a debug-friendly string representation" do
      uuid = described_class.new(123)
      expect(uuid.inspect).to match(
        /#<IronLionUUID::UUID:[0-9a-fx]+ value=00000000-0000-0000-0000-00000000007b>/
      )
    end
  end
end
