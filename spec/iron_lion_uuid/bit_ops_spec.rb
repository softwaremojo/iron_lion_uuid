# frozen_string_literal: true

require "spec_helper"

RSpec.describe IronLionUUID::BitOps do
  describe ".extract_bits" do
    it "extracts bits from the specified position" do
      value = 0b1010101010101010
      expect(described_class.extract_bits(value, 0, 4)).to eq(0b1010)
      expect(described_class.extract_bits(value, 4, 4)).to eq(0b1010)
      expect(described_class.extract_bits(value, 8, 4)).to eq(0b1010)
      expect(described_class.extract_bits(value, 12, 4)).to eq(0b1010)
    end

    it "handles cases where position is beyond the value size" do
      value = 0b1111
      expect(described_class.extract_bits(value, 4, 4)).to eq(0)
    end

    it "handles extracting 0 bits" do
      value = 0b1111
      expect(described_class.extract_bits(value, 0, 0)).to eq(0)
    end

    it "handles large bit widths" do
      value = (1 << 64) - 1 # All 1s in a 64-bit integer
      expect(described_class.extract_bits(value, 0, 64)).to eq(value)
    end
  end

  describe ".set_bits" do
    it "sets bits at the specified position" do
      value = 0
      expect(described_class.set_bits(value, 0, 4, 0b1010)).to eq(0b1010)
      expect(described_class.set_bits(value, 4, 4, 0b1010)).to eq(0b10100000)
      expect(described_class.set_bits(value, 8, 4, 0b1010)).to eq(0b1010000000)
    end

    it "replaces existing bits at the specified position" do
      value = 0b1111111111111111
      expect(described_class.set_bits(value, 4, 4, 0b0000)).to eq(0b111101111111)
      expect(described_class.set_bits(value, 8, 4, 0b0000)).to eq(0b11110000011111111)
    end

    it "handles setting 0 bits" do
      value = 0b1111
      expect(described_class.set_bits(value, 0, 0, 0b1010)).to eq(0b1111)
    end

    it "ignores extra bits in new_bits beyond the specified width" do
      value = 0
      expect(described_class.set_bits(value, 0, 4, 0b11111111)).to eq(0b1111)
    end
  end

  describe ".mask" do
    it "creates a mask with the specified number of bits" do
      expect(described_class.mask(0)).to eq(0)
      expect(described_class.mask(1)).to eq(0b1)
      expect(described_class.mask(4)).to eq(0b1111)
      expect(described_class.mask(8)).to eq(0b11111111)
      expect(described_class.mask(16)).to eq(0b1111111111111111)
    end

    it "handles large bit widths" do
      expect(described_class.mask(64)).to eq((1 << 64) - 1)
    end
  end
end
