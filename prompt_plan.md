# IronLionUUID Project Implementation Blueprint

## Project Overview

IronLionUUID is a Ruby library that generates configurable UUID v8 identifiers with both Ruby-side and database-side implementations. The core functionality allows developers to customize the bit structure of UUIDs while maintaining RFC compliance.

## High-Level Architecture

1. **Core UUID Structure & Generation**
   - Configuration DSL
   - Bit manipulation utilities
   - UUID value object

2. **Field Type Implementations**
   - Parameter field
   - Environment variable field
   - Timestamp field
   - Random field
   - Sequence field

3. **Integration Components**
   - ActiveRecord type casting
   - Database function generation
   - Rails integration (generators, Railtie)

4. **Error Handling & Validation**
   - Error classes hierarchy
   - Configuration validation
   - Runtime validation

## Implementation Strategy

Now I'll break down the implementation into small, iterative steps that build upon each other.

### Step 1: Project Setup and Base UUID Structure

```
Create a new Ruby gem called IronLionUUID with the basic structure including README, LICENSE, and gemspec. Set up the project with Bundler, RSpec for testing, and the initial module structure. Implement the basic UUID class that will store the 128-bit value and handle standard UUID operations like conversion to string, comparison, and equality.

First, create a simple module that handles the basic bit manipulation needed for UUID generation. Include methods for packing and unpacking bits, and ensure they work with different bit positions and widths.

Write tests for the bit manipulation methods, covering various scenarios including edge cases.

Implement just enough of the UUID value object to represent a 128-bit identifier and convert it to a standard UUID string format. Don't worry about the configuration or field types yet - just focus on the fundamental representation and operations.
```

### Step 2: Error Handling Framework

```
Implement the error class hierarchy as specified in the IronLionUUID specification. Create the following error classes:

- Error (base class inheriting from StandardError)
- ConfigurationError
- FrozenConfigurationError
- InvalidBitWidthError
- MissingEnvironmentError
- ValueTooLargeError

Also implement the warning hierarchy:
- Warning (base class inheriting from StandardError)
- TimestampPrecisionWarning

Write tests for each error class to ensure they can be properly raised and caught. These tests should verify that the error messages are descriptive and helpful.

Keep the implementation minimal for now - we'll expand functionality as we integrate these error classes with the configuration and field implementations.
```

### Step 3: Configuration DSL - Basic Structure

```
Implement the basic configuration DSL structure that will allow users to define the UUID field layout. Create a Configuration class that will store the field definitions and validate the overall structure.

The configuration should support the block-style syntax shown in the specification:
```
```ruby
IronLionUUID.configure do |uuid|
  # Field definitions will go here
end
```
```
Implement the configuration freezing mechanism that prevents modifications after initial setting. Add validation to ensure the total bit count doesn't exceed 122 bits (as 6 bits are reserved for UUID version and variant).

Write tests for the configuration class, focusing on:
- Basic configuration block functionality
- Configuration freezing
- Total bit width validation

Do not implement the individual field types yet - just create the structure that will hold them. We'll implement the field types in subsequent steps.
```

### Step 4: Field Base Class and Field Registry

```
Create a base Field class that all field types will inherit from. This base class should handle common functionality such as:

- Bit width validation
- Position calculation within the UUID
- Value extraction from a complete UUID

Implement a field registry mechanism in the Configuration class that tracks all configured fields and their positions within the UUID.

The base Field class should validate that:
- The bit width is positive
- The bit width doesn't exceed the available space
- The field's position doesn't overlap with reserved bits (version and variant)

Write tests for the base Field class and field registry, covering:
- Field creation with valid parameters
- Field bit width validation
- Field positioning within the UUID structure
- Extraction of field values from a complete UUID

This step establishes the foundation for implementing specific field types in the following steps.
```

### Step 5: Implement Random Field Type

```
Implement the Random field type, which is the simplest field type as it just generates random bits. The Random field should:

- Accept a 'bits' parameter specifying how many random bits to generate
- Generate cryptographically secure random bits when a UUID is created
- Properly position these bits in the UUID structure

Extend the Configuration DSL to support the random field type:
```
```ruby
IronLionUUID.configure do |uuid|
  uuid.random bits: 32
end
```
```
Update the UUID generation logic to incorporate random fields when creating new UUIDs.

Write tests for the Random field, covering:
- Configuration syntax
- Random value generation
- Bit positioning
- Extraction of the random value from a generated UUID

This field type provides a foundation for understanding the field implementation pattern before moving to more complex field types.
```

### Step 6: Implement Parameter Field Type

```
Implement the Parameter field type, which accepts user-provided values at UUID generation time. The Parameter field should:

- Accept a 'bits' parameter specifying how many bits to use
- Accept a 'name' parameter for accessing the value later
- Handle both integer and string input values (converting string values from base36 to base10)
- Validate that input values fit within the specified bit width
- Raise ValueTooLargeError if a value exceeds the available bits

Extend the Configuration DSL to support the parameter field type:
```
```ruby
IronLionUUID.configure do |uuid|
  uuid.parameter bits: 16, name: :model
end
```
```
Update the UUID generation method to accept parameters corresponding to the configured parameter fields:
```
```ruby
IronLionUUID.generate(model_value)
```
```
Write tests for the Parameter field, covering:
- Configuration syntax
- Integer value handling
- String value conversion
- Value validation
- Error handling for values too large for the bit width
- Extraction of parameter values from a generated UUID
- Accessor method generation for retrieving field values (e.g., uuid.model)

This field type introduces value validation and conversion, which will be important for subsequent field types as well.
```

### Step 7: Implement Environment Variable Field Type

```
Implement the Environment Variable field type, which retrieves values from environment variables. The Env field should:

- Accept a 'bits' parameter specifying how many bits to use
- Accept a 'name' parameter for accessing the value later
- Accept a 'key' parameter specifying which environment variable to use
- Handle both numeric and string environment variable values (converting as needed)
- Validate that environment variable values fit within the specified bit width
- Raise MissingEnvironmentError if the specified environment variable is not set
- Raise ValueTooLargeError if a value exceeds the available bits

Extend the Configuration DSL to support the environment variable field type:
```
```ruby
IronLionUUID.configure do |uuid|
  uuid.env bits: 12, name: :node, key: :NODE_ID
end
```
```
Write tests for the Env field, covering:
- Configuration syntax
- Environment variable retrieval
- Numeric value handling
- String value conversion
- Error handling for missing environment variables
- Error handling for values too large for the bit width
- Extraction of environment variable values from a generated UUID
- Accessor method generation for retrieving field values (e.g., uuid.node)

Make sure to properly mock environment variables in tests to ensure reliable test execution.
```

### Step 8: Implement Timestamp Field Type

```
Implement the Timestamp field type, which embeds the current time in the UUID. The Timestamp field should:

- Accept a 'bits' parameter specifying how many bits to use
- Accept a 'precision' parameter specifying the time precision (second, millisecond, microsecond, nanosecond)
- Validate that the system clock supports the requested precision
- Emit a TimestampPrecisionWarning if the system clock doesn't support the requested precision
- Calculate a numeric timestamp value based on the current time and requested precision
- Validate that the timestamp value fits within the specified bit width

Extend the Configuration DSL to support the timestamp field type:
```
```ruby
IronLionUUID.configure do |uuid|
  uuid.timestamp precision: :millisecond, bits: 36
end
```
```
Write tests for the Timestamp field, covering:
- Configuration syntax
- Time precision handling
- Warning generation for unsupported precision
- Timestamp value calculation
- Value validation
- Extraction of timestamp values from a generated UUID
- Accessor method generation for retrieving field values (e.g., uuid.timestamp)

Consider using time mocking in tests to ensure reliable test execution regardless of when tests are run.
```

### Step 9: Implement Sequence Field Type with Thread Safety

```
Implement the Sequence field type, which provides an auto-incrementing sequence number. The Sequence field should:

- Accept a 'bits' parameter specifying how many bits to use
- Use atomic operations for thread-safe sequence generation
- Wrap around to zero when the maximum value for the bit width is reached
- Validate that the sequence value fits within the specified bit width

Extend the Configuration DSL to support the sequence field type:
```
```ruby
IronLionUUID.configure do |uuid|
  uuid.sequence bits: 16
end
```
```
Use the concurrent-ruby gem to implement the atomic counter:
```
```ruby
require 'concurrent'

class SequenceField < Field
  def initialize(options)
    super
    @counter = Concurrent::AtomicFixnum.new(0)
    @max_value = (1 << @bits) - 1
  end

  def value
    @counter.increment % (@max_value + 1)
  end
end
```
```
Write tests for the Sequence field, covering:
- Configuration syntax
- Sequence generation
- Wrapping behavior
- Thread safety (using multiple threads to generate UUIDs concurrently)
- Extraction of sequence values from a generated UUID
- Accessor method generation for retrieving field values (e.g., uuid.sequence)

This field type introduces thread safety concerns, which are important for production use of the library.
```

### Step 10: UUID Generation Logic Integration

```
Integrate all field types into a complete UUID generation system. Implement the main `IronLionUUID.generate` method that:

- Accepts parameters for parameter fields in the order they were configured
- Retrieves values from environment variables, generates timestamps, random data, and increments sequences as needed
- Combines all field values into a single 128-bit UUID with proper positioning
- Sets the UUID version (8) and variant bits correctly
- Returns a UUID object with accessor methods for each configured field

Update the UUID value object to include:
- Accessor methods for each configured field
- Standard methods: `to_s`, `inspect`, `hash`, `==`, `eql?`
- Conversion methods: `to_uuid`, `to_standard_uuid`
- Implementation of Comparable for sorting

Implement the `IronLionUUID.from_string` method that creates a UUID object from a string representation, extracting field values based on the configuration.

Write comprehensive tests for the integrated UUID generation, covering:
- Complete UUID generation with all field types
- Parameter handling
- Field value extraction
- UUID string formatting
- UUID comparison and sorting
- UUID creation from string

This step brings together all the previous work into a complete UUID generation system.
```

### Step 11: Rails Integration - ActiveRecord Type

```
Implement the ActiveRecord type casting for IronLionUUID. Create a Type class that handles conversion between database representations and Ruby objects:
```
```ruby
module IronLionUUID
  class Type < ActiveRecord::Type::Binary
    def cast(value)
      case value
      when IronLionUUID
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
end
```
```
Implement the HasIronLionId concern for easy inclusion in ActiveRecord models:
```
```ruby
module IronLionUUID
  module HasIronLionId
    extend ActiveSupport::Concern

    included do
      # Apply IronLionUUID type to primary keys and foreign keys of type UUID
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

Use the ActiveRecord::Test::Case framework for testing the ActiveRecord integration to ensure compatibility.
```

### Step 12: Rails Integration - Database Functions

```
Implement the database function generation for PostgreSQL, MySQL, and SQLite. Create templates for each database type that match the Ruby-side configuration:

For PostgreSQL:
```
```sql
CREATE OR REPLACE FUNCTION generate_iron_lion_uuid(param1 INTEGER, param2 INTEGER)
RETURNS UUID AS $$
BEGIN
  -- UUID generation logic matching Ruby implementation
END;
$$ LANGUAGE plpgsql;
```
```
For MySQL:
```
```sql
DELIMITER //
CREATE FUNCTION generate_iron_lion_uuid(param1 INTEGER, param2 INTEGER)
RETURNS CHAR(36)
BEGIN
  -- UUID generation logic matching Ruby implementation
  RETURN result;
END //
DELIMITER ;
```
```
For SQLite:
```
```sql
CREATE FUNCTION generate_iron_lion_uuid(param1 INTEGER, param2 INTEGER)
RETURNS TEXT AS
BEGIN
  -- UUID generation logic matching Ruby implementation
  RETURN result;
END;
```
```
Create a DatabaseFunctionGenerator class that:
- Analyzes the current configuration
- Determines the database type
- Generates appropriate SQL for the current configuration and database
- Handles differences in bit manipulation capabilities across databases

Write tests for the database function generation, covering:
- SQL generation for each supported database
- Parameter handling in SQL functions
- Bit manipulation in SQL

Use appropriate database-specific testing frameworks or mocks to verify the generated SQL functions.
```

### Step 13: Rails Integration - Generators and Railtie

```
Implement the Rails generators for installing IronLionUUID in a Rails application:
```
```ruby
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
Create the Railtie for automatic Rails integration:
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
      require "generators/iron_lion_uuid/install_generator"
    end
  end
end
```
```
Create the migration template that will generate the database functions.

Write tests for the Rails integration, covering:
- Generator functionality
- Migration template rendering
- Railtie initialization

Use the Rails generator testing framework to verify the generators.
```

### Step 14: Documentation and Examples

```
Create comprehensive documentation for the IronLionUUID library using YARD or RDoc:

- Document all public methods with descriptions, parameters, return values, and examples
- Create usage examples for common scenarios
- Document the configuration DSL with all available options
- Document the Rails integration with setup instructions
- Document the database function generation with migration examples

Create a Rails integration guide that shows:
- How to install the gem
- How to configure UUID generation
- How to use the Rails generators
- How to integrate with ActiveRecord models
- How to use the database functions

Create a database migration guide that shows:
- How to set up the database for UUID support
- How to migrate from standard UUIDs to IronLionUUID
- How to use the database functions in queries and inserts

Ensure all documentation is accurate, comprehensive, and follows Ruby documentation best practices.
```
