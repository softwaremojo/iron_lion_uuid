# frozen_string_literal: true

module IronLionUUID
  # :nodoc:
  module BitOps
    # Extract n bits starting at position pos from value
    # @param value [Integer] The integer to extract bits from
    # @param pos [Integer] The position to start extraction
    #   (0-based, from right to left)
    # @param num [Integer] The number of bits to extract
    # @return [Integer] The extracted bits
    def self.extract_bits(value, pos, num)
      (value >> pos) & mask(num)
    end

    # Set n bits at position pos in value to new_bits
    # @param value [Integer] The integer to set bits in
    # @param pos [Integer] The position to start setting bits
    #   (0-based, from right to left)
    # @param num [Integer] The number of bits to set
    # @param new_bits [Integer] The bits to set
    # @return [Integer] The resulting integer with updated bits
    def self.set_bits(value, pos, num, new_bits)
      # First clear the bits at the target position
      cleared = value & ~(mask(num) << pos)
      # Then set the new bits
      cleared | ((new_bits & mask(num)) << pos)
    end

    # Create a mask of n bits (all 1s)
    # @param num [Integer] The number of bits in the mask
    # @return [Integer] A mask with n least significant bits set to 1
    def self.mask(num)
      (1 << num) - 1
    end
  end
end
