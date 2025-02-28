# frozen_string_literal: true

module IronLionUUID
  module Attributes
    # Timestamp - embeds the current time in UUIDs at configurable precision
    class Timestamp < Attribute
      # Available precision levels
      PRECISIONS = %i[ second millisecond microsecond nanosecond ].freeze

      # Multipliers for converting time to the desired precision
      PRECISION_MULTIPLIERS = {
        second: 1,
        millisecond: 1_000,
        microsecond: 1_000_000,
        nanosecond: 1_000_000_000
      }.freeze

      # Initialize a new Timestamp
      # @param options [Hash] Options for this attribute
      # @option options [Integer] :bits Number of bits to use (required)
      # @option options [Symbol] :precision Time precision
      # @option options [Symbol] :name Name for this attribute (optional)
      def initialize(options = {})
        # Set default name if not provided
        options[:name] ||= :timestamp

        # Set default precision if not provided (millisecond)
        options[:precision] ||= :millisecond

        super(:timestamp, options[:bits], options)

        # Validate precision
        unless PRECISIONS.include?(self[:precision])
          raise(
            ConfigurationError,
            "Invalid timestamp precision: #{self[:precision]}, " \
            "must be one of #{PRECISIONS.join(', ')}"
          )
        end

        # Check if system supports the requested precision
        check_system_precision!
      end

      # Generate a timestamp value at the configured precision
      # @param _args [Array] Arguments passed to the generator
      # @return [Integer] The timestamp value
      # @raise [ValueTooLargeError] If the timestamp value exceeds the bit width
      def generate_value(*_args)
        # Get current time
        now = Time.now

        # Convert to the specified precision
        multiplier = PRECISION_MULTIPLIERS[self[:precision]]
        value = (now.to_f * multiplier).to_i

        # Validate the value
        validate_value!(value)

        value
      end

      private

      # Check if the system supports the requested precision
      # @raise [TimestampPrecisionWarning] If the system doesn't support the precision
      def check_system_precision!
        system_precision = detect_system_precision
        requested_precision = self[:precision]

        # Compare the available precision with the requested precision
        if PRECISIONS.index(system_precision) < PRECISIONS.index(requested_precision)
          # System precision is lower than requested precision
          warn TimestampPrecisionWarning.new(requested_precision, system_precision)
        end
      end

      # Detect the system's time precision capability
      # @return [Symbol] The detected precision
      def detect_system_precision
        # Take multiple time samples to detect precision
        samples = Array.new(10) { Time.now.to_f }

        # Calculate the minimum time difference
        min_diff = samples.each_cons(2).map { |a, b| (b - a).abs }.min

        # Determine precision based on the minimum difference
        if min_diff < 0.000001
          :nanosecond
        elsif min_diff < 0.001
          :microsecond
        elsif min_diff < 1
          :millisecond
        else
          :second
        end
      end
    end
  end
end
