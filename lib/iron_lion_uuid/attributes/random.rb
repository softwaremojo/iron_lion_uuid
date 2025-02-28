# frozen_string_literal: true

module IronLionUUID
  module Attributes
    # Random - generates random bits for UUIDs
    class Random < Attribute
      # Initialize a new Random
      # @param options [Hash] Options for this attribute
      # @option options [Integer] :bits Number of bits to use (required)
      # @option options [Symbol] :name Name for this attribute (optional)
      def initialize(options = {})
        # Provide default name if not specified
        options[:name] ||= :random
        super(:random, options[:bits], options)
      end

      # Generate a random value of appropriate bit width
      # @param _args [Array] Arguments (unused for random attributes)
      # @return [Integer] Random value constrained to the configured bit width
      def generate_value(*_args)
        # Use SecureRandom for cryptographically secure random numbers
        require "securerandom"

        # Calculate how many bytes we need (rounding up)
        bytes_needed = (@bits + 7) / 8

        # Generate random bytes and convert to integer
        random_bytes = SecureRandom.random_bytes(bytes_needed)
        value = 0

        # Convert bytes to integer (big-endian)
        random_bytes.bytes.each do |byte|
          value = (value << 8) | byte
        end

        # Mask to the configured bit width to ensure it fits
        value & ((1 << @bits) - 1)
      end
    end
  end
end
