# frozen_string_literal: true

module IronLionUUID
  module Attributes
    # Env - retrieves values from environment variables for UUIDs
    class Env < Attribute
      # Initialize a new EnvAttribute
      # @param options [Hash] Options for this attribute
      # @option options [Integer] :bits Number of bits to use (required)
      # @option options [Symbol] :name Name for this attribute (required)
      # @option options [Symbol, String] :key Environment variable key (required)
      def initialize(**options)
        unless options[:name]
          raise ConfigurationError, "Environment variable attribute requires a name"
        end

        unless options[:key]
          raise ConfigurationError, "Environment variable attribute requires a key"
        end

        super(:env, options[:bits], options)
      end

      # Generate a value by retrieving from the environment
      # @param _args [Array] Arguments passed to the generator (unused for env attributes)
      # @return [Integer] The environment variable value, converted if necessary
      # @raise [MissingEnvironmentError] If the environment variable is not set
      # @raise [ValueTooLargeError] If the environment variable value exceeds bit width
      def generate_value(*)
        # Get the environment variable key
        env_key = self[:key].to_s

        # Retrieve the environment variable value
        env_value = ENV.fetch(env_key, nil)

        # Raise error if not found or empty
        raise MissingEnvironmentError, env_key if env_value.blank?

        # Convert to integer if it's a numeric string, otherwise use base36
        convert_value(env_value).tap do |value|
          validate_value! value
        end
      end

      private

      # Convert environment variable value to integer
      # @param value [String] The environment variable value
      # @return [Integer] The converted value
      def convert_value(value)
        # If value looks like a number, convert directly to integer
        if /^\d+$/.match?(value)
          value.to_i
        else
          # Otherwise convert from base36 to base10
          value.to_i(36)
        end
      end
    end
  end
end
