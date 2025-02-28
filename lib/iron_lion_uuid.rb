# frozen_string_literal: true

# lib/iron_lion_uuid.rb
require_relative "iron_lion_uuid/version"
require_relative "iron_lion_uuid/bit_ops"
require_relative "iron_lion_uuid/errors"
require_relative "iron_lion_uuid/inflector"
require_relative "iron_lion_uuid/uuid"
require_relative "iron_lion_uuid/custom_uuid"
require_relative "iron_lion_uuid/attribute"
require_relative "iron_lion_uuid/attributes/env"
require_relative "iron_lion_uuid/attributes/parameter"
require_relative "iron_lion_uuid/attributes/random"
require_relative "iron_lion_uuid/attributes/sequence"
require_relative "iron_lion_uuid/attributes/timestamp"
require_relative "iron_lion_uuid/configuration"
require_relative "iron_lion_uuid/generator"
require_relative "iron_lion_uuid/sql_generator"
require_relative "iron_lion_uuid/postgresql_generator"
require_relative "iron_lion_uuid/mysql_generator"
require_relative "iron_lion_uuid/sqlite_generator"

# Conditionally load Rails integration
require_relative "iron_lion_uuid/rails_integration"

# Main module
module IronLionUUID
  # Store the configuration
  @configuration = nil
  @generator = nil

  # Try to load Rails integration
  RailsIntegration.load if defined?(RailsIntegration)

  # Configure the UUID structure
  # @param block [Proc] Configuration block
  # @yield [Configuration] Configuration instance
  # @raise [FrozenConfigurationError] If already configured
  # @return [Configuration] The configuration
  def self.configure
    # If configuration is already set, it can't be modified
    raise FrozenConfigurationError if @configuration&.frozen?

    # Create a new configuration
    @configuration = Configuration.new

    # Yield to the block for configuration
    yield @configuration if block_given?

    # Validate and freeze the configuration
    @configuration.validate!
    @configuration.freeze!

    # Create a generator with this configuration
    @generator = Generator.new(@configuration)

    @configuration
  end

  # Get the current configuration
  # @return [Configuration, nil] The current configuration or nil if not configured
  def self.configuration
    @configuration
  end

  # Main method to generate a new UUID
  # @param args [Array] Arguments for parameter attributes
  # @return [UUID] The generated UUID
  def self.generate(*)
    raise ConfigurationError, "UUID structure not configured" unless @configuration

    # Create and use a generator if we don't have one yet
    @generator ||= Generator.new(@configuration)

    # Generate the UUID
    @generator.generate(*)
  end

  # Create a UUID from a string representation
  # @param string [String] The UUID string
  # @return [UUID] The parsed UUID
  def self.from_string(string)
    return nil if string.blank?

    # Remove any hyphens and convert to an integer
    hex = string.delete("-")

    # Handle potential invalid formats
    begin
      value = hex.to_i(16)
    rescue ArgumentError
      raise ArgumentError, "Invalid UUID format: #{string}"
    end

    # Create and return the UUID
    if @configuration
      # If configuration exists, create a CustomUUID with accessors
      CustomUUID.new(value, @configuration.attributes)
    else
      # Otherwise create a basic UUID
      UUID.new(value)
    end
  end

  # Check if a string or object is a valid IronLionUUID
  # @param value [String, UUID, Object] The value to check
  # @return [Boolean] true if valid, false otherwise
  def self.valid?(value)
    case value
    when UUID
      true
    when String
      # Check if it's a valid UUID string format
      return false if value.blank?

      value.match?(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i) ||
        value.match?(/^[0-9a-f]{32}$/i)
    else
      false
    end
  end

  # Generate SQL for database-side UUID generation
  # @param dialect [Symbol] The database dialect (:postgresql, :mysql, :sqlite)
  # @param options [Hash] Options for SQL generation
  # @return [String] The generated SQL
  def self.generate_sql(dialect, **options)
    generator = SQLGenerator.for_dialect(dialect, @configuration)
    generator.generate_function(options)
  end

  # Generate SQL to drop the database function
  # @param dialect [Symbol] The database dialect (:postgresql, :mysql, :sqlite)
  # @param options [Hash] Options for SQL generation
  # @return [String] The generated SQL
  def self.generate_drop_sql(dialect, **options)
    generator = SQLGenerator.for_dialect(dialect, @configuration)
    generator.generate_drop_function(options)
  end
end
