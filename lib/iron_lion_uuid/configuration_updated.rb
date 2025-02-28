# frozen_string_literal: true

module IronLionUUID
  # Holds the configuration for UUID structure
  class Configuration
    # 128 - version(4) - variant(2)
    MAX_BITS = 122

    # Reserved bit positions
    VERSION_BITS = (48..51)
    VARIANT_BITS = (64..65)

    # Initialize a new Configuration
    def initialize
      @attributes = []
      @frozen = false
      @total_bits = 0
      @next_position = 0
    end

    # Add an attribute to the configuration
    # @param attribute [Attribute] The attribute to add
    # @raise [FrozenConfigurationError] If the configuration is frozen
    def add_attribute(attribute)
      raise FrozenConfigurationError if frozen?

      # Calculate and set the position if not already set
      if attribute.position.nil?
        position = calculate_next_position(attribute.bits)
        attribute.position = position
        @next_position = position + attribute.bits
      end

      @attributes << attribute
      @total_bits += attribute.bits
    end

    # Calculate the next available position for an attribute
    # @param bit_width [Integer] The width of the attribute in bits
    # @return [Integer] The calculated position
    def calculate_next_position(bit_width)
      position = @next_position

      # Check if the attribute would overlap with version bits
      if position <= VERSION_BITS.first && position + bit_width > VERSION_BITS.first
        # Skip version bits
        position = VERSION_BITS.last + 1
      end

      # Check if the attribute would overlap with variant bits
      if position <= VARIANT_BITS.first && position + bit_width > VARIANT_BITS.first
        # Skip variant bits
        position = VARIANT_BITS.last + 1
      end

      position
    end

    # Freeze the configuration to prevent further modifications
    # @return [Configuration] self
    def freeze!
      @frozen = true
      self
    end

    # Check if the configuration is frozen
    # @return [Boolean] true if frozen, false otherwise
    def frozen?
      @frozen
    end

    # Validate the configuration
    # @raise [InvalidBitWidthError] If the total bit count exceeds the available space
    def validate!
      raise InvalidBitWidthError, @total_bits if @total_bits > MAX_BITS

      # Calculate remaining bits and add a random attribute if needed
      if @total_bits < MAX_BITS
        remaining = MAX_BITS - @total_bits
        # Auto-add a random attribute for remaining bits
        random(bits: remaining)
      end

      true
    end

    # Get all configured attributes
    # @return [Array<Attribute>] Array of configured attributes
    def attributes
      @attributes.dup
    end

    # Get the total bits used
    # @return [Integer] Total bits used
    attr_reader :total_bits

    # Get the remaining available bits
    # @return [Integer] Remaining available bits
    def remaining_bits
      MAX_BITS - @total_bits
    end

    # Get all attributes of a specific type
    # @param type [Symbol] The attribute type
    # @return [Array<Attribute>] Array of attributes of the specified type
    def attributes_of_type(type)
      @attributes.select { |attr| attr.type == type }
    end

    # Get an attribute by name
    # @param name [Symbol] The attribute name
    # @return [Attribute, nil] The attribute or nil if not found
    def attribute_by_name(name)
      @attributes.find { |attr| attr.name == name }
    end

    # Add a random attribute to the configuration
    # @param options [Hash] Attribute options
    # @option options [Integer] :bits Number of bits to use
    # @option options [Symbol] :name Optional name for the attribute
    # @return [RandomAttribute] The created attribute
    def random(options = {})
      validate_options!(options, [ :bits ], [ :name ])
      attribute = RandomAttribute.new(options)
      add_attribute(attribute)
      attribute
    end

    # Validate required options
    # @param options [Hash] The options hash
    # @param required [Array<Symbol>] Required option keys
    # @param optional [Array<Symbol>] Optional option keys
    # @raise [ConfigurationError] If required options are missing
    def validate_options!(options, required, optional = [])
      required.each do |key|
        unless options.key?(key)
          raise ConfigurationError, "Missing required option: #{key}"
        end
      end

      # Add warning for unexpected options
      allowed = required + optional
      options.each_key do |key|
        unless allowed.include?(key)
          warn "Unexpected option: #{key} (allowed: #{allowed.join(', ')})"
        end
      end
    end

    # Placeholder method for parameter attributes (to be implemented later)
    def parameter(options = {})
      raise NotImplementedError, "Parameter attributes not yet implemented"
    end

    # Placeholder method for env attributes (to be implemented later)
    def env(options = {})
      raise NotImplementedError, "Environment variable attributes not yet implemented"
    end

    # Placeholder method for timestamp attributes (to be implemented later)
    def timestamp(options = {})
      raise NotImplementedError, "Timestamp attributes not yet implemented"
    end

    # Placeholder method for sequence attributes (to be implemented later)
    def sequence(options = {})
      raise NotImplementedError, "Sequence attributes not yet implemented"
    end

    # Maintain backwards compatibility with field-based naming
    alias fields attributes
    alias add_field add_attribute
  end
end
