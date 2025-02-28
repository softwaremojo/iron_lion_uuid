# frozen_string_literal: true

module IronLionUUID
  # Base class for all attribute types
  class Attribute
    # @return [Symbol] The attribute type
    attr_reader :type

    # @return [Integer] The number of bits used by this attribute
    attr_reader :bits

    # @return [Symbol, nil] The attribute name (if applicable)
    attr_reader :name

    # @return [Integer, nil] The position of this attribute in the UUID
    attr_reader :position

    # Initialize a new attribute
    # @param type [Symbol] The attribute type
    # @param bits [Integer] The number of bits
    # @param options [Hash] Additional options
    # @raise [ConfigurationError] If bit width is invalid
    def initialize(type, bits, options = {})
      @type = type
      @bits = bits
      @name = options[:name]
      @position = nil

      # Additional options can be stored here
      @options = options

      validate_bits!
    end

    # Validate that the bit width is valid
    # @raise [ConfigurationError] If bit width is invalid
    def validate_bits!
      unless @bits.is_a?(Integer) && @bits.positive?
        raise ConfigurationError, "Bit width must be a positive integer"
      end

      return unless @bits > 122

      raise InvalidBitWidthError, "Bit width #{@bits} is too large (maximum 122)"
    end

    # Set the position of this attribute in the UUID
    # @param pos [Integer] The position (0-127)
    # @raise [ConfigurationError] If the position is invalid
    def position=(pos)
      unless pos.is_a?(Integer) && pos >= 0
        raise ConfigurationError, "Position must be a non-negative integer"
      end

      raise ConfigurationError, "Position #{pos} is too large (maximum 127)" if pos > 127

      @position = pos
    end

    # Extract this attribute's value from a complete UUID
    # @param uuid_value [Integer] The 128-bit UUID value
    # @return [Integer] The extracted value
    def extract_from(uuid_value)
      raise ConfigurationError, "Attribute position not set" unless @position

      BitOps.extract_bits(uuid_value, @position, @bits)
    end

    # Apply this attribute's value to a UUID
    # @param uuid_value [Integer] The existing UUID value
    # @param attr_value [Integer] The attribute value to apply
    # @return [Integer] The updated UUID value
    def apply_to(uuid_value, attr_value)
      raise ConfigurationError, "Attribute position not set" unless @position

      BitOps.set_bits(uuid_value, @position, @bits, attr_value)
    end

    # Generate a value for this attribute
    # @param args [Array] Arguments passed to the generator
    # @return [Integer] The generated value
    # @note This is an abstract method that should be overridden by subclasses
    def generate_value(*args)
      raise NotImplementedError, "Subclasses must implement generate_value"
    end

    # Validate that a value fits within the configured bit width
    # @param value [Integer] The value to validate
    # @raise [ValueTooLargeError] If the value is too large
    def validate_value!(value)
      max_value = (1 << @bits) - 1
      raise ValueTooLargeError value, @bits if value > max_value

      true
    end

    # Get an option value
    # @param key [Symbol] The option key
    # @return [Object, nil] The option value or nil if not set
    def [](key)
      @options[key]
    end
  end
end
