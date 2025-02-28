# frozen_string_literal: true

module IronLionUUID
  # :nodoc:
  class UUID
    # The raw 128-bit value of the UUID
    attr_reader :value

    # Initialize a new UUID with a 128-bit value
    # @param value [Integer] The 128-bit value for the UUID
    # @raise [ArgumentError] If the value is not an integer or exceeds 128 bits
    def initialize(value)
      unless value.is_a?(Integer)
        raise ArgumentError, "UUID value must be an integer, got #{value.class}"
      end

      if value.negative? || value >= (1 << 128)
        raise ArgumentError, "UUID value must be a 128-bit unsigned integer"
      end

      @value = value
    end

    # Convert the UUID to the standard hex format with hyphens
    # @return [String] The UUID string in the format
    #   "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
    def to_s
      hex = @value.to_s(16).rjust(32, "0")
      [
        hex[0..7],
        hex[8..11],
        hex[12..15],
        hex[16..19],
        hex[20..31]
      ].join("-")
    end

    # Convert the UUID to a raw hex string without hyphens
    # @return [String] The UUID string in the format "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
    def to_hex
      @value.to_s(16).rjust(32, "0")
    end

    # Check if two UUIDs are equal
    # @param other [Object] The object to compare with
    # @return [Boolean] True if the UUIDs are equal, false otherwise
    def ==(other)
      other.is_a?(UUID) && other.value == @value
    end

    # Check if two UUIDs are equal (used for hash keys)
    # @param other [Object] The object to compare with
    # @return [Boolean] True if the UUIDs are equal, false otherwise
    def eql?(other)
      self == other
    end

    # Calculate a hash code for the UUID
    # @return [Integer] A hash code
    def hash
      @value.hash
    end

    # Return a debug-friendly string representation of the UUID
    # @return [String] A string representation of the UUID
    def inspect
      "#<#{self.class}:#{object_id} value=#{self}>"
    end
  end
end
