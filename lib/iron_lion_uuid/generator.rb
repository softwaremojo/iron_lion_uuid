# frozen_string_literal: true

module IronLionUUID
  # Handles UUID generation based on configured attributes
  class Generator
    # UUID version and variant constants
    VERSION_UUID_V8 = 8
    VARIANT_RFC_4122 = 2

    # Version bit position (4 bits)
    VERSION_POSITION = 48
    VERSION_BITS = 4

    # Variant bit position (2 bits)
    VARIANT_POSITION = 64
    VARIANT_BITS = 2

    # Initialize a new Generator
    # @param configuration [Configuration] The UUID structure configuration
    def initialize(configuration)
      @configuration = configuration
    end

    # Generate a new UUID based on the configuration
    # @param args [Array] Arguments for parameter attributes
    # @return [UUID] The generated UUID
    def generate(*args)
      # Start with a zero value
      uuid_value = 0

      # Set the UUID version (version 8 for custom UUIDs)
      uuid_value = BitOps.set_bits(uuid_value, VERSION_POSITION, VERSION_BITS,
                                   VERSION_UUID_V8)

      # Set the variant (RFC 4122 variant)
      uuid_value = BitOps.set_bits(uuid_value, VARIANT_POSITION, VARIANT_BITS,
                                   VARIANT_RFC_4122)

      # Process all attributes
      @configuration.attributes.each do |attr|
        # Generate value based on attribute type
        value = attr.generate_value(*args)

        # Apply value to the UUID
        uuid_value = attr.apply_to(uuid_value, value)
      end

      # Create the UUID object
      UUID.new(uuid_value)
    end
  end
end
