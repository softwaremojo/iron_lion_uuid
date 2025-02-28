# frozen_string_literal: true

module IronLionUUID
  module Attributes
    # Parameter - accepts user-provided values at UUID generation time
    class Parameter < Attribute
      # Initialize a new Parameter
      # @param options [Hash] Options for this attribute
      # @option options [Integer] :bits Number of bits to use (required)
      # @option options [Symbol] :name Name for this attribute (required)
      def initialize(options = {})
        # Ensure name is provided
        unless options[:name]
          raise ConfigurationError,
                "Parameter attribute requires a name"
        end

        super(:parameter, options[:bits], options)
      end

      # Generate a value using the provided parameter
      # @param args [Array] Arguments passed to the generator
      # @return [Integer] The parameter value, converted if necessary
      # @raise [ArgumentError] If no parameter value is provided
      # @raise [ValueTooLargeError] If the parameter value exceeds the bit width
      def generate_value(*args)
        # We expect the parameter value to be the first argument
        if args.empty?
          raise ArgumentError, "No value provided for parameter #{name || 'unnamed'}"
        end

        # Get the parameter value
        param_value = args.first

        # Convert to integer if it's a string
        value = convert_value(param_value)

        # Validate the value
        validate_value!(value)

        value
      end

      private

      # Convert parameter value to integer if needed
      # @param value [Integer, String] The parameter value
      # @return [Integer] The converted value
      def convert_value(value)
        case value
        when Integer then value
        when String  then value.to_i(36)
        else              value.to_s.to_i(36)
        end
      end
    end
  end
end
