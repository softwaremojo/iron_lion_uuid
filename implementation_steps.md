## Refined Implementation Steps

### Phase 1: Core UUID Functionality

#### Step 1.1: Project Setup and Basic Structure

```
Create a new Ruby gem called IronLionUUID with the basic structure. Initialize the project with Bundler and set up RSpec for testing. Create the initial module structure and namespace.

Your implementation should include:
1. A properly structured gemspec with necessary dependencies
2. Basic module definition and version constant
3. RSpec setup with a single passing test
4. A README with a basic overview of the project goals

Don't implement any functionality yet - just set up the project structure.
```

#### Step 1.2: Bit Manipulation Utilities

```
Implement the core bit manipulation utilities that will be used throughout the library. Create a BitOps module with methods for manipulating bits within integers:
```

```ruby
module IronLionUUID
  module BitOps
    module_function

    # Extract n bits starting at position pos from value
    def extract_bits(value, pos, n)
      # Implementation
    end

    # Set n bits at position pos in value to new_bits
    def set_bits(value, pos, n, new_bits)
      # Implementation
    end

    # Create a mask of n bits (all 1s)
    def mask(n)
      # Implementation
    end
  end
end
```

```
Write comprehensive tests for the BitOps module, covering:
- Extraction of bits from different positions
- Setting bits at different positions
- Handling of edge cases (0 bits, maximum bit width)
- Handling of boundary conditions

This utility module will be used by all subsequent parts of the library, so ensure it's robust and well-tested.
```

#### Step 1.3: Basic UUID Value Object

```
Implement a basic UUID value object that represents a 128-bit UUID. Focus on the fundamental representation and operations, not the customizable structure yet.
```

```ruby
module IronLionUUID
  class UUID
    attr_reader :value

    def initialize(value)
      @value = value
    end

    def to_s
      # Format as standard UUID string: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    end

    def ==(other)
      # Equality comparison
    end

    def eql?(other)
      # Ruby hash equality
    end

    def hash
      # Hash code for hash tables
    end
  end
end
```

```
Implement methods for converting between the integer value and the standard UUID string format. Include proper handling of the UUID version (bits 48-51) and variant (bits 64-65).

Write tests for the UUID class, covering:
- Creation with various values
- String conversion
- Equality comparison
- Hash code generation

This basic UUID class will be extended later to support the customizable structure.
```

#### Step 1.4: Error and Warning Classes

```
Implement the error and warning class hierarchy as specified:
```

```ruby
module IronLionUUID
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class FrozenConfigurationError < ConfigurationError; end
  class InvalidBitWidthError < ConfigurationError; end
  class MissingEnvironmentError < ConfigurationError; end
  class ValueTooLargeError < ConfigurationError; end

  class Warning < StandardError; end
  class TimestampPrecisionWarning < Warning; end
end
```

```
Write basic tests for each error and warning class, ensuring they can be properly raised and caught. Include descriptive error messages for each error type.

These error classes will be used throughout the library to provide clear error messages for various error conditions.
```

### Phase 2: Configuration System

#### Step 2.1: Configuration Container

```
Implement the basic configuration container that will hold the field definitions:
```

```ruby
module IronLionUUID
  class Configuration
    attr_reader :fields, :frozen

    def initialize
      @fields = []
      @frozen = false
    end

    def freeze!
      @frozen = true
      self
    end

    def validate!
      # Validate total bit width
      total_bits = @fields.sum(&:bits)
      if total_bits > 122
        raise InvalidBitWidthError, "Total bit width (#{total_bits}) exceeds 122 bits"
      end
    end
  end

  class << self
    attr_accessor :configuration

    def configure
      raise FrozenConfigurationError, "Configuration is frozen" if @configuration&.frozen
      @configuration ||= Configuration.new
      yield @configuration if block_given?
      @configuration.validate!
      @configuration.freeze!
      @configuration
    end
  end
end
```

```
Write tests for the Configuration class, covering:
- Creation of a new configuration
- Freezing the configuration
- Validation of total bit width
- Prevention of modifications after freezing

This configuration container will be extended in subsequent steps to support the various field types.
```

#### Step 2.2: Field Base Class

```
Implement the base Field class that all field types will inherit from:
```

```ruby
module IronLionUUID
  class Field
    attr_reader :bits, :name, :position

    def initialize(options)
      @bits = options.fetch(:bits)
      @name = options.fetch(:name, nil)

      validate_bits!
    end

    def validate_bits!
      unless @bits.is_a?(Integer) && @bits > 0
        raise InvalidBitWidthError, "Bit width must be a positive integer, got #{@bits.inspect}"
      end
    end

    def set_position(position)
      @position = position
      self
    end

    def extract_from(uuid_value)
      BitOps.extract_bits(uuid_value, @position, @bits)
    end

    def apply_to(uuid_value, field_value)
      BitOps.set_bits(uuid_value, @position, @bits, field_value)
    end
  end
end
```

```
Update the Configuration class to track field positions:
```

```ruby
def add_field(field)
  raise FrozenConfigurationError, "Configuration is frozen" if @frozen

  # Calculate position based on existing fields
  position = calculate_next_position

  # Set field position and add to fields array
  @fields << field.set_position(position)

  self
end

def calculate_next_position
  # Calculate position based on existing fields and reserved bits
  # (version and variant)
end
```

```
Write tests for the Field base class, covering:
- Initialization with various options
- Bit width validation
- Position setting
- Value extraction from a UUID
- Value application to a UUID

This base class will be used by all field type implementations in subsequent steps.
```

#### Step 2.3: Field Registry and DSL Methods

```
Implement the field registry and DSL methods for registering fields in the configuration:

Update the Configuration class to include methods for each field type:
```

```ruby
module IronLionUUID
  class Configuration
    # Existing code...

    def parameter(options)
      add_field(ParameterField.new(options))
    end

    def env(options)
      add_field(EnvField.new(options))
    end

    def timestamp(options)
      add_field(TimestampField.new(options))
    end

    def random(options)
      add_field(RandomField.new(options))
    end

    def sequence(options)
      add_field(SequenceField.new(options))
    end
  end
end
```

```
Create placeholder classes for each field type that inherit from Field:
```

```ruby
module IronLionUUID
  class ParameterField < Field; end
  class EnvField < Field; end
  class TimestampField < Field; end
  class RandomField < Field; end
  class SequenceField < Field; end
end
```

```
Write tests for the field registry and DSL methods, covering:
- Registration of fields of each type
- Position calculation for fields
- Configuration validation with multiple fields

This step sets up the structure for the field type implementations in subsequent steps.
```

### Phase 3: Field Type Implementations

#### Step 3.1: Random Field Implementation

```
Implement the RandomField class for generating random bits:
```

```ruby
module IronLionUUID
  class RandomField < Field
    def value
      SecureRandom.random_number(1 << @bits)
    end
  end
end
```

```
Update the configuration DSL to support the random field type:
```

```ruby
def random(options)
  options = {name: :random}.merge(options)
  add_field(RandomField.new(options))
end
```

```
Write tests for the RandomField, covering:
- Random value generation
- Bit width constraints
- Integration with the configuration DSL

This simple field type serves as a foundation for understanding the field implementation pattern.
```

#### Step 3.2: Parameter Field Implementation

```
Implement the ParameterField class for user-provided values:
```

```ruby
module IronLionUUID
  class ParameterField < Field
    def initialize(options)
      super
      @name = options.fetch(:name) # Name is required for parameters
    end

    def value(param_value)
      value = convert_value(param_value)
      validate_value!(value)
      value
    end

    def convert_value(value)
      case value
      when Integer
        value
      when String
        # Convert from base36 to base10
        value.to_i(36)
      else
        raise ArgumentError, "Parameter value must be an Integer or String, got #{value.class}"
      end
    end

    def validate_value!(value)
      max_value = (1 << @bits) - 1
      if value > max_value
        raise ValueTooLargeError, "Value #{value} exceeds maximum value #{max_value} for #{@bits} bits"
      end
    end
  end
end
```

```
Update the configuration DSL to support the parameter field type:
```

```ruby
def parameter(options)
  add_field(ParameterField.new(options))
end
```

```
Write tests for the ParameterField, covering:
- Parameter value conversion
- Value validation
- Error handling for values too large for the bit width
- Integration with the configuration DSL

This field type introduces value validation and conversion logic.
```

#### Step 3.3: Environment Variable Field Implementation

```
Implement the EnvField class for environment variable values:
```

```ruby
module IronLionUUID
  class EnvField < Field
    def initialize(options)
      super
      @name = options.fetch(:name) # Name is required
      @key = options.fetch(:key) # Environment variable key is required
    end

    def value
      env_value = ENV[@key.to_s]

      if env_value.nil?
        raise MissingEnvironmentError, "Environment variable #{@key} is not set"
      end

      value = convert_value(env_value)
      validate_value!(value)
      value
    end

    def convert_value(value)
      # If value looks like a number, convert it as a number
      if value =~ /\A\d+\z/
        value.to_i
      else
        # Otherwise, treat as base36
        value.to_i(36)
      end
    end

    def validate_value!(value)
      max_value = (1 << @bits) - 1
      if value > max_value
        raise ValueTooLargeError, "Environment value #{value} exceeds maximum value #{max_value} for #{@bits} bits"
      end
    end
  end
end
```

```
Update the configuration DSL to support the environment variable field type:
```

```ruby
def env(options)
  add_field(EnvField.new(options))
end
```

```
Write tests for the EnvField, covering:
- Environment variable retrieval
- Value conversion
- Value validation
- Error handling for missing environment variables
- Error handling for values too large for the bit width
- Integration with the configuration DSL

Use appropriate mocking in tests to set and clear environment variables.
```

#### Step 3.4: Timestamp Field Implementation

```
Implement the TimestampField class for embedding timestamps:
```

```ruby
module IronLionUUID
  class TimestampField < Field
    PRECISIONS = {
      second: 1,
      millisecond: 1000,
      microsecond: 1_000_000,
      nanosecond: 1_000_000_000
    }.freeze

    def initialize(options)
      super
      @name = options.fetch(:name, :timestamp)
      @precision = options.fetch(:precision, :millisecond)

      unless PRECISIONS.key?(@precision)
        raise ArgumentError, "Invalid precision: #{@precision}. Must be one of: #{PRECISIONS.keys.join(', ')}"
      end

      check_system_precision!
    end

    def check_system_precision!
      # Check if system clock supports the requested precision
      # Emit a warning if not
    end

    def value
      now = Time.now

      case @precision
      when :second
        value = now.to_i
      when :millisecond
        value = (now.to_f * 1000).to_i
      when :microsecond
        value = (now.to_f * 1_000_000).to_i
      when :nanosecond
        value = (now.to_f * 1_000_000_000).to_i
      end

      validate_value!(value)
      value
    end

    def validate_value!(value)
      max_value = (1 << @bits) - 1
      if value > max_value
        raise ValueTooLargeError, "Timestamp value #{value} exceeds maximum value #{max_value} for #{@bits} bits"
      end
    end
  end
end
```

```
Update the configuration DSL to support the timestamp field type:
```

```ruby
def timestamp(options)
  add_field(TimestampField.new(options))
end
```

```
Write tests for the TimestampField, covering:
- Time precision handling
- Warning generation for unsupported precision
- Timestamp value calculation
- Value validation
- Integration with the configuration DSL

Use time mocking in tests to ensure reliable test execution.
```

#### Step 3.5: Sequence Field Implementation

```
Implement the SequenceField class for auto-incrementing sequences:
```

```ruby
require 'concurrent'

module IronLionUUID
  class SequenceField < Field
    def initialize(options)
      super
      @name = options.fetch(:name, :sequence)
      @counter = Concurrent::AtomicFixnum.new(0)
      @max_value = (1 << @bits) - 1
    end

    def value
      @counter.increment % (@max_value + 1)
    end
  end
end
```

```
Update the configuration DSL to support the sequence field type:
```

```ruby
def sequence(options)
  add_field(SequenceField.new(options))
end
```

```
Add the concurrent-ruby gem as a dependency:
```

```ruby
# In the gemspec
spec.add_dependency "concurrent-ruby", "~> 1.1"
```

```
Write tests for the SequenceField, covering:
- Sequence generation
- Wrapping behavior
- Thread safety
- Integration with the configuration DSL

Use multiple threads in tests to verify thread safety.
```

### Phase 4: UUID Generation Integration

#### Step 4.1: UUID Generator Class

```
Implement the UUID generator class that combines all field types:
```

```ruby
module IronLionUUID
  class Generator
    def initialize(configuration)
      @configuration = configuration
    end

    def generate(*args)
      # Start with a blank 128-bit value
      uuid_value = 0

      # Keep track of parameter index
      param_index = 0

      # Process each field
      @configuration.fields.each do |field|
        field_value = case field
        when ParameterField
          # Parameter fields take values from args
          raise ArgumentError, "Missing parameter for #{field.name}" if param_index >= args.length
          field.value(args[param_index])
          param_index += 1
        when EnvField, TimestampField, RandomField, SequenceField
          # Other fields generate their own values
          field.value
        end

        # Apply field value to the UUID
        uuid_value = field.apply_to(uuid_value, field_value)
      end

      # Apply version and variant bits for UUID v8
      uuid_value = BitOps.set_bits(uuid_value, 48, 4, 8)  # Version 8
      uuid_value = BitOps.set_bits(uuid_value, 64, 2, 2)  # Variant 1

      # Create UUID instance
      create_uuid(uuid_value)
    end

    private

    def create_uuid(value)
      CustomUUID.new(value, @configuration)
    end
  end
end
```

```
Write tests for the Generator class, covering:
- UUID generation with various field combinations
- Parameter handling
- Version and variant bit setting
- Error handling for missing parameters

This generator class brings together all the field types to create complete UUIDs.
```

#### Step 4.2: Enhanced UUID Class with Field Access

```
Implement an enhanced UUID class (CustomUUID) that provides access to field values:
```

```ruby
module IronLionUUID
  class CustomUUID < UUID
    attr_reader :fields

    def initialize(value, configuration)
      super(value)
      @configuration = configuration
      @fields = {}

      # Extract field values
      extract_fields
    end

    def extract_fields
      @configuration.fields.each do |field|
        if field.name
          field_value = field.extract_from(@value)
          @fields[field.name] = field_value

          # Define accessor method for this field
          self.class.class_eval do
            define_method(field.name) do
              @fields[field.name]
            end unless method_defined?(field.name)
          end
        end
      end
    end

    # Add comparison support
    include Comparable

    def <=>(other)
      return nil unless other.is_a?(CustomUUID)
      @value <=> other.value
    end
  end
end
```

```
Update the IronLionUUID module with methods for generating and parsing UUIDs:
```

```ruby
module IronLionUUID
  class << self
    def generate(*args)
      ensure_configured
      generator.generate(*args)
    end

    def from_string(string)
      ensure_configured

      # Parse string UUID into integer value
      value = parse_uuid_string(string)

      # Create UUID with current configuration
      generator.send(:create_uuid, value)
    end

    def valid?(obj)
      case obj
      when CustomUUID, UUID
        true
      when String
        uuid_string_pattern =~ obj
      else
        false
      end
    end

    private

    def ensure_configured
      raise ConfigurationError, "IronLionUUID is not configured" unless @configuration
    end

    def generator
      @generator ||= Generator.new(@configuration)
    end

    def parse_uuid_string(string)
      unless uuid_string_pattern =~ string
        raise ArgumentError, "Invalid UUID string: #{string}"
      end

      # Remove hyphens and convert from hex to integer
      string.gsub('-', '').to_i(16)
    end

    def uuid_string_pattern
      /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
    end
  end
end
```

```
Write tests for the enhanced UUID functionality, covering:
- Field value extraction
- Accessor method generation
- UUID comparison
- UUID parsing from string
- UUID validation

This step completes the core UUID generation functionality.
```

### Phase 5: Rails Integration

#### Step 5.1: ActiveRecord Type Casting

```
Implement the ActiveRecord type casting for IronLionUUID:
```

```ruby
module IronLionUUID
  class Type < ActiveRecord::Type::Binary
    def cast(value)
      case value
      when CustomUUID, UUID
        value
      when String
        IronLionUUID.from_string(value)
      when nil
        nil
      else
        raise ArgumentError, "Cannot cast #{value.class} to IronLionUUID"
      end
    end

    def serialize(value)
      return if value.nil?
      value.to_s
    end

    def deserialize(value)
      return if value.nil?
      IronLionUUID.from_string(value)
    end
  end

  # Register type with ActiveRecord if available
  if defined?(ActiveRecord)
    ActiveRecord::Type.register(:iron_lion_uuid, Type)
  end
end
```

Implement the HasIronLionId concern for easy inclusion in ActiveRecord models:

```ruby
module IronLionUUID
  module HasIronLionId
    extend ActiveSupport::Concern

    included do
      # Get all UUID attributes from model
      uuid_attributes = attributes_with_uuid_type

      # Apply IronLionUUID type to UUID attributes
      uuid_attributes.each do |attribute|
        attribute(attribute, :iron_lion_uuid)
      end
    end

    class_methods do
      def attributes_with_uuid_type
        # Find all attributes with UUID type
        columns.select { |c| c.type == :uuid }.map(&:name)
      end
    end
  end
end
```

```
Write tests for the ActiveRecord integration, covering:
- Type casting from various input types
- Serialization to database format
- Deserialization from database format
- Integration with ActiveRecord models

Use the ActiveRecord::Test::Case framework for testing the ActiveRecord integration.
```

#### Step 5.2: SQL Generation Framework

```
Implement the SQL generation framework for database functions:
```

```ruby
module IronLionUUID
  class SQLGenerator
    attr_reader :dialect

    def initialize(dialect)
      @dialect = dialect

      # Validate dialect
      unless [:postgresql, :mysql, :sqlite].include?(@dialect)
        raise ArgumentError, "Unsupported SQL dialect: #{@dialect}"
      end
    end

    def generate_function
      case @dialect
      when :postgresql
        generate_postgresql_function
      when :mysql
        generate_mysql_function
      when :sqlite
        generate_sqlite_function
      end
    end

    private

    def generate_postgresql_function
      # Generate PostgreSQL function
    end

    def generate_mysql_function
      # Generate MySQL function
    end

    def generate_sqlite_function
      # Generate SQLite function
    end

    def parameter_fields
      IronLionUUID.configuration.fields.select { |f| f.is_a?(ParameterField) }
    end
  end
end
```

```
Implement basic versions of the database-specific function generators:
```

```ruby
def generate_postgresql_function
  param_list = parameter_fields.map { |f| "#{f.name} INTEGER" }.join(", ")

  <<~SQL
    CREATE OR REPLACE FUNCTION generate_iron_lion_uuid(#{param_list})
    RETURNS UUID AS $$
    DECLARE
      result UUID;
    BEGIN
      -- Basic implementation placeholder
      -- Will be expanded in subsequent steps
      RETURN '00000000-0000-0000-0000-000000000000'::UUID;
    END;
    $$ LANGUAGE plpgsql;
  SQL
end
```

```
Write tests for the SQL generation framework, covering:
- SQL generation for each supported database
- Parameter handling in SQL functions

Use string comparison or SQL parsing to verify the generated SQL functions.
```

#### Step 5.3: Database-Specific SQL Implementations

```
Implement database-specific SQL function generators for each supported database:

PostgreSQL:
```

```ruby
def generate_postgresql_function
  param_list = parameter_fields.map { |f| "#{f.name} INTEGER" }.join(", ")

  function_body = []
  function_body << "DECLARE"
  function_body << "  result UUID;"
  function_body << "  value BIGINT := 0;"

  function_body << "BEGIN"

  # Process each field to build up the UUID value
  IronLionUUID.configuration.fields.each do |field|
    case field
    when ParameterField
      function_body << "  -- Parameter field: #{field.name}"
      function_body << "  value := value | ((#{field.name} & #{BitOps.mask(field.bits)})::BIGINT << #{field.position});"
    when EnvField
      function_body << "  -- Environment variable field: #{field.name}"
      function_body << "  -- Note: Environment variables cannot be accessed in SQL"
      function_body << "  value := value | (0::BIGINT << #{field.position});"
    when TimestampField
      function_body << "  -- Timestamp field: #{field.name}"
      timestamp_expr = case field.instance_variable_get(:@precision)
                       when :second
                         "EXTRACT(EPOCH FROM CURRENT_TIMESTAMP)::BIGINT"
                       when :millisecond
                         "EXTRACT(EPOCH FROM CURRENT_TIMESTAMP)::BIGINT * 1000"
                       when :microsecond
                         "EXTRACT(EPOCH FROM CURRENT_TIMESTAMP)::BIGINT * 1000000"
                       when :nanosecond
                         "EXTRACT(EPOCH FROM CURRENT_TIMESTAMP)::BIGINT * 1000000000"
                       end
      function_body << "  value := value | ((#{timestamp_expr} & #{BitOps.mask(field.bits)})::BIGINT << #{field.position});"
    when RandomField
      function_body << "  -- Random field: #{field.name}"
      function_body << "  value := value | ((floor(random() * #{1 << field.bits})::BIGINT & #{BitOps.mask(field.bits)}) << #{field.position});"
    when SequenceField
      function_body << "  -- Sequence field: #{field.name}"
      function_body << "  -- Note: Using a PostgreSQL sequence"
      function_body << "  value := value | ((nextval('iron_lion_uuid_seq') & #{BitOps.mask(field.bits)})::BIGINT << #{field.position});"
    end
  end

  # Set version and variant bits
  function_body << "  -- Set version bits (UUID v8)"
  function_body << "  value := value | (8::BIGINT << 48);"
  function_body << "  -- Set variant bits"
  function_body << "  value := value | (2::BIGINT << 64);"

  # Convert to UUID
  function_body << "  -- Convert to UUID string"
  function_body << "  result := lpad(to_hex(value), 32, '0');"
  function_body << "  result := substring(result, 1, 8) || '-' ||"
  function_body << "            substring(result, 9, 4) || '-' ||"
  function_body << "            substring(result, 13, 4) || '-' ||"
  function_body << "            substring(result, 17, 4) || '-' ||"
  function_body << "            substring(result, 21);"

  function_body << "  RETURN result;"
  function_body << "END;"

  <<~SQL
    CREATE OR REPLACE FUNCTION generate_iron_lion_uuid(#{param_list})
    RETURNS UUID AS $$
    #{function_body.join("\n")}
    $$ LANGUAGE plpgsql;

    -- Create sequence for sequence fields if needed
    DO $$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM pg_sequences WHERE sequencename = 'iron_lion_uuid_seq') THEN
        CREATE SEQUENCE iron_lion_uuid_seq;
      END IF;
    END
    $$;
  SQL
end
```

```
Implement similar functions for MySQL and SQLite, adjusting for their specific SQL dialects and capabilities.

Write tests for the database-specific SQL implementations, covering:
- SQL generation for each supported database
- Field handling for each field type
- Sequence creation

Use database-specific testing frameworks or mocks to verify the generated SQL functions.
```

#### Step 5.4: Rails Generators

```
Implement the Rails generators for installing IronLionUUID in a Rails application:
```

```ruby
require 'rails/generators'

module IronLionUUID
  module Generators
    class InstallGenerator < Rails::Generators::Base
      desc "Creates database migrations for IronLionUUID functions"

      class_option :databases, type: :array, default: ["primary"],
                   desc: "Which database connections to install functions for"

      def create_migration_file
        migration_template "migration.rb.erb", "db/migrate/create_iron_lion_uuid_functions.rb"
      end

      def self.source_root
        File.join(File.dirname(__FILE__), "templates")
      end
    end
  end
end
```

```
Create the migration template that will generate the database functions:
```

```erb
class CreateIronLionUuidFunctions < ActiveRecord::Migration[<%= ActiveRecord::Migration.current_version %>]
  def up
    <% options[:databases].each do |database| %>
    # <%= database %> database
    <%= database == "primary" ? "" : "on_database(:#{database}) do" %>
      # Determine database type
      db_type = case connection.adapter_name.downcase
                when /postgresql/
                  :postgresql
                when /mysql/
                  :mysql
                when /sqlite/
                  :sqlite
                else
                  raise "Unsupported database type: #{connection.adapter_name}"
                end

      # Generate and execute SQL for the current database
      sql = IronLionUUID::SQLGenerator.new(db_type).generate_function
      execute(sql)
    <%= database == "primary" ? "" : "end" %>
    <% end %>
  end

  def down
    <% options[:databases].each do |database| %>
    # <%= database %> database
    <%= database == "primary" ? "" : "on_database(:#{database}) do" %>
      case connection.adapter_name.downcase
      when /postgresql/
        execute("DROP FUNCTION IF EXISTS generate_iron_lion_uuid")
      when /mysql/
        execute("DROP FUNCTION IF EXISTS generate_iron_lion_uuid")
      when /sqlite/
        execute("DROP FUNCTION IF EXISTS generate_iron_lion_uuid")
      end
    <%= database == "primary" ? "" : "end" %>
    <% end %>
  end
end
```

```
Implement the Railtie for automatic Rails integration:
```

```ruby
module IronLionUUID
  class Railtie < Rails::Railtie
    initializer "iron_lion_uuid.configure_rails" do
      ActiveSupport.on_load(:active_record) do
        # Register UUID type with ActiveRecord
        ActiveRecord::Type.register(:iron_lion_uuid, IronLionUUID::Type)
      end
    end

    # Register generators
    generators do
      require "iron_lion_uuid/generators/install_generator"
    end
  end
end
```

```
Write tests for the Rails integration, covering:
- Generator functionality
- Migration template rendering
- Railtie initialization

Use the Rails generator testing framework to verify the generators.
```

### Phase 6: Documentation and Finalization

#### Step 6.1: Documentation Generation

```
Implement comprehensive documentation for the IronLionUUID library using YARD:

First, add the YARD gem as a development dependency:
```

```ruby
# In the gemspec
spec.add_development_dependency "yard", "~> 0.9"
```

```
Add YARD documentation to all public classes and methods. Here's an example for the main module:
```

```ruby
# File: lib/iron_lion_uuid.rb

##
# IronLionUUID is a Ruby library that generates customizable UUID v8 identifiers.
#
# @example Basic configuration
#   IronLionUUID.configure do |uuid|
#     uuid.parameter bits: 16, name: :model
#     uuid.timestamp precision: :millisecond, bits: 36
#     uuid.random bits: 32
#   end
#
#   # Generate a UUID
#   uuid = IronLionUUID.generate(123)
#   puts uuid.to_s
#   puts uuid.model  # => 123
#
module IronLionUUID
  # Version number
  VERSION = "0.1.0"

  class << self
    ##
    # Configure the UUID structure
    #
    # @example
    #   IronLionUUID.configure do |uuid|
    #     uuid.parameter bits: 16, name: :model
    #     uuid.env bits: 12, name: :node, key: :NODE_ID
    #     uuid.timestamp precision: :millisecond, bits: 36
    #     uuid.random bits: 32
    #     uuid.sequence bits: 16
    #   end
    #
    # @yield [configuration] Configuration object
    # @yieldparam configuration [Configuration] Configuration instance
    # @return [Configuration] Frozen configuration instance
    # @raise [FrozenConfigurationError] If configuration is already frozen
    #
    def configure
      # Implementation...
    end

    ##
    # Generate a new UUID with the current configuration
    #
    # @example
    #   uuid = IronLionUUID.generate(123)
    #
    # @param args [Array<Integer, String>] Values for parameter fields
    # @return [CustomUUID] Generated UUID instance
    # @raise [ConfigurationError] If IronLionUUID is not configured
    # @raise [MissingEnvironmentError] If a required environment variable is missing
    # @raise [ValueTooLargeError] If a value exceeds its allocated bit width
    #
    def generate(*args)
      # Implementation...
    end

    # Additional methods...
  end
end
```

```
Document all other classes and methods in a similar manner. Ensure that all public interfaces have proper documentation with examples.

Create a README.md with basic usage examples and installation instructions.

Create a CHANGELOG.md to track changes between versions.

Create a CONTRIBUTING.md with guidelines for contributors.
```

#### Step 6.2: Usage Examples

```
Create comprehensive usage examples for the IronLionUUID library in the documentation:
```

```ruby
# Basic configuration and usage
IronLionUUID.configure do |uuid|
  uuid.parameter bits: 16, name: :model
  uuid.timestamp precision: :millisecond, bits: 36
  uuid.random bits: 32
end

# Generate a UUID with a model parameter
uuid = IronLionUUID.generate(123)
puts uuid.to_s  # => "8a7b9c1d-2e3f-8123-9678-abcdef012345"
puts uuid.model  # => 123

# Using with ActiveRecord
class Product < ApplicationRecord
  include IronLionUUID::HasIronLionId
end

# Creating a product with an IronLionUUID
product = Product.create!(name: "Example Product", model_type: 42)
product.id  # => #<IronLionUUID::CustomUUID:0x...>
product.id.model  # => 42

# Using the database function in a migration
class CreateProducts < ActiveRecord::Migration[6.1]
  def change
    create_table :products, id: :uuid do |t|
      t.string :name
      t.integer :model_type
      t.timestamps
    end

    # Use the database function for the primary key
    execute <<~SQL
      ALTER TABLE products
      ALTER COLUMN id
      SET DEFAULT generate_iron_lion_uuid(0);
    SQL
  end
end
```

```
Create examples for each supported database type, including configuration and usage.

Create examples for different UUID structure configurations, showing how to balance between different field types and bit allocations.

Include examples for advanced use cases, such as distributed systems with node identifiers, multi-tenant applications with tenant identifiers, and high-throughput applications with sequence numbers.
```

#### Step 6.3: Rails Integration Guide

```
Create a comprehensive Rails integration guide:
```

```markdown
# IronLionUUID Rails Integration Guide

## Installation

Add the gem to your Gemfile:

``ruby
gem 'iron_lion_uuid'
``

Run the bundle command:

``bash
bundle install
``

## Configuration

Create an initializer at `config/initializers/iron_lion_uuid.rb`:

``ruby
IronLionUUID.configure do |uuid|
  uuid.parameter bits: 16, name: :model
  uuid.env bits: 12, name: :node, key: :node_id
  uuid.timestamp precision: :millisecond, bits: 36
  uuid.random bits: 32
  uuid.sequence bits: 16
end
``

## Database Setup

Run the IronLionUUID install generator to create a migration for the database functions:

``bash
bin/rails generate iron_lion_uuid:install
``

If you have multiple databases, you can specify which ones to include:

``bash
bin/rails generate iron_lion_uuid:install --databases=primary,analytics
``

Run the migration to create the database functions:

``bash
bin/rails db:migrate
``

## Model Integration

Include the `HasIronLionId` concern in your models:

``ruby
class Product < ApplicationRecord
  include IronLionUUID::HasIronLionId
end
``

Create a migration for your model with a UUID primary key:

``ruby
class CreateProducts < ActiveRecord::Migration[6.1]
  def change
    create_table :products, id: :uuid do |t|
      t.string :name
      t.integer :model_type
      t.timestamps
    end

    # Use the database function for the primary key
    execute <<~SQL
      ALTER TABLE products
      ALTER COLUMN id
      SET DEFAULT generate_iron_lion_uuid(0);
    SQL
  end
end
``

## Usage

Create records with IronLionUUIDs:

``ruby
product = Product.create!(name: "Example Product", model_type: 42)
product.id  # => #<IronLionUUID::CustomUUID:0x...>
product.id.model  # => 42
``

Query records by UUID:

``ruby
Product.find("8a7b9c1d-2e3f-8123-9678-abcdef012345")
``

Generate UUIDs in Ruby:

``ruby
uuid = IronLionUUID.generate(42)
``

Generate UUIDs in SQL:

``ruby
ActiveRecord::Base.connection.execute("SELECT generate_iron_lion_uuid(42)")
``
```

```
Include additional sections for advanced usage, performance considerations, and troubleshooting.
```

#### Step 6.4: Database Migration Guide

```
Create a comprehensive database migration guide:
```

```markdown
# IronLionUUID Database Migration Guide

## Setting Up Your Database for UUID Support

### PostgreSQL

PostgreSQL has native UUID support. To enable it, you need the `uuid-ossp` extension:

``sql
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
``

In your Rails migration:

``ruby
class EnableUuidExtension < ActiveRecord::Migration[6.1]
  def change
    enable_extension 'uuid-ossp'
  end
end
``

### MySQL

MySQL doesn't have a native UUID type. You can use either `CHAR(36)` or `BINARY(16)`:

``sql
-- Using CHAR(36)
CREATE TABLE products (
  id CHAR(36) PRIMARY KEY,
  -- other columns
);

-- Using BINARY(16)
CREATE TABLE products (
  id BINARY(16) PRIMARY KEY,
  -- other columns
);
``

In your Rails migration:

``ruby
class CreateProducts < ActiveRecord::Migration[6.1]
  def change
    # For MySQL, Rails will use CHAR(36) for UUID columns
    create_table :products, id: :uuid do |t|
      -- other columns
    end
  end
end
``

### SQLite

SQLite doesn't have a native UUID type. You can use `TEXT`:

``sql
CREATE TABLE products (
  id TEXT PRIMARY KEY,
  -- other columns
);
``

In your Rails migration:

``ruby
class CreateProducts < ActiveRecord::Migration[6.1]
  def change
    # For SQLite, Rails will use TEXT for UUID columns
    create_table :products, id: :uuid do |t|
      -- other columns
    end
  end
end
``

## Migrating from Standard UUIDs to IronLionUUID

If you have existing tables with standard UUIDs and want to migrate to IronLionUUID, you'll need to:

1. Install the IronLionUUID database functions
2. Update your models to use IronLionUUID
3. Update the default value for new records

### Step 1: Install the Database Functions

``bash
bin/rails generate iron_lion_uuid:install
bin/rails db:migrate
``

### Step 2: Update Your Models

``ruby
class Product < ApplicationRecord
  include IronLionUUID::HasIronLionId
end
``

### Step 3: Update the Default Value

``ruby
class UpdateProductIdDefault < ActiveRecord::Migration[6.1]
  def change
    # For PostgreSQL
    execute <<~SQL
      ALTER TABLE products
      ALTER COLUMN id
      SET DEFAULT generate_iron_lion_uuid(0);
    SQL

    # For MySQL
    # execute <<~SQL
    #   ALTER TABLE products
    #   MODIFY id CHAR(36) DEFAULT (generate_iron_lion_uuid(0));
    # SQL

    # For SQLite
    # execute <<~SQL
    #   -- SQLite doesn't support ALTER COLUMN DEFAULT
    #   -- You'll need to use triggers instead
    # SQL
  end
end
``

## Using IronLionUUID Functions in Queries

### PostgreSQL

``sql
-- Generate a new UUID
SELECT generate_iron_lion_uuid(42);

-- Use in an INSERT
INSERT INTO products (id, name)
VALUES (generate_iron_lion_uuid(42), 'Example Product');

-- Find records by model parameter
SELECT * FROM products
WHERE id::text::uuid_split_parts ->> 'model' = '42';
``

### MySQL

``sql
-- Generate a new UUID
SELECT generate_iron_lion_uuid(42);

-- Use in an INSERT
INSERT INTO products (id, name)
VALUES (generate_iron_lion_uuid(42), 'Example Product');

-- Find records by model parameter
-- (MySQL doesn't have UUID parsing functions,
-- so you'll need to use your own implementation)
``

### SQLite

``sql
-- Generate a new UUID
SELECT generate_iron_lion_uuid(42);

-- Use in an INSERT
INSERT INTO products (id, name)
VALUES (generate_iron_lion_uuid(42), 'Example Product');

-- Find records by model parameter
-- (SQLite doesn't have UUID parsing functions,
-- so you'll need to use your own implementation)
``
```

```
Include additional sections for troubleshooting, performance considerations, and database-specific quirks.
```
