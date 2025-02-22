# frozen_string_literal: true

require "spec_helper"

RSpec.describe IronLionUUID do
  describe "#data" do
    let(:test_uuid) { "00112233-4455-8667-8899-aabbccddeeff" }
    subject(:uuid) { described_class.new(test_uuid) }

    it "correctly extracts bits from the middle" do
      # In the test UUID, bits 64-75 (12 bits) are 8899 in hex
      # 8899 in binary is 1000 1000 1001 1001
      # The variant bits (64-65) are masked out, so it should be 0000 1000 1001
      expect(uuid.data(75, 12)).to eq(0x099)
    end

    it "correctly extracts bits from the start" do
      # First 16 bits of 00112233 = 0011 = decimal 17
      expect(uuid.data(127, 16)).to eq(0x0011)
    end

    it "correctly extracts bits from the end" do
      # Last 16 bits of ccddeeff = 0xeeff = decimal 61183
      expect(uuid.data(15, 16)).to eq(0xeeff)
    end
  end

  describe "#initialize" do
    it "correctly masks out version bits" do
      uuid = described_class.new("00000000-0000-8000-0000-000000000000")
      # Version bits (48-51) should be masked out
      expect(uuid.data(51, 4)).to eq(0)
    end

    it "correctly masks out variant bits" do
      uuid = described_class.new("00000000-0000-0000-8000-000000000000")
      # Variant bits (64-65) should be masked out
      expect(uuid.data(65, 2)).to eq(0)
    end
  end
end
