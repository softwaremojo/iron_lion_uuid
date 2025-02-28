# frozen_string_literal: true

module IronLionUUID
  module Attributes
    # Sequence - provides auto-incrementing sequence numbers for UUIDs with thread safety
    class Sequence < Attribute
      # Initialize a new Sequence
      # @param options [Hash] Options for this attribute
      # @option options [Integer] :bits Number of bits to use (required)
      # @option options [Symbol] :name Name for this attribute (optional)
      def initialize(options = {})
        # Set default name if not provided
        options[:name] ||= :sequence

        super(:sequence, options[:bits], options)

        # Initialize the atomic counter for thread safety
        require "concurrent"
        @counter = Concurrent::AtomicFixnum.new(0)

        # Calculate the maximum value for the given bit width
        @max_value = (1 << @bits) - 1
      end

      # Generate the next sequence value with thread safety
      # @param _args [Array] Arguments passed to the generator
      #   (unused for sequence attributes)
      # @return [Integer] The next sequence value
      def generate_value(*)
        # Increment the counter and wrap around if needed
        @counter.update do |value|
          (value + 1) & @max_value
        end
      end
    end
  end
end
