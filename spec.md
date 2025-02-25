# IronLionUUID Specification

## Overview

IronLionUUID is a Ruby library that generates customizable UUID v8 identifiers with both Ruby-side and database-side (PostgreSQL, MySQL, SQLite) implementations. The library allows developers to customize the bit structure of UUIDs while maintaining RFC compliance.

## Core Features

1. Bit-level configuration of UUID structure
2. Support for multiple data source types (parameters, environment variables, timestamps, etc.)
3. Rails integration with ActiveRecord type casting
4. SQL function generation for database-side ID creation
5. Compatibility with UUID standards and other Ruby UUID implementations

## Configuration Interface

The library uses a declarative configuration block style:

```ruby
IronLionUUID.configure do |uuid|
  uuid.parameter bits: 16, name: :model
  uuid.env bits: 12, name: :node, key: :node_id
  uuid.timestamp precision: :millisecond, bits: 36
  uuid.random bits: 32
  uuid.sequence bits: 16
end
```

### Field Types

1. **parameter**: User-provided value at UUID generation time
2. **env**: Value from an environment variable
3. **timestamp**: Current time at configured precision
4. **random**: Random data
5. **sequence**: Auto-incrementing sequence number

### Bit Allocation Requirements

- Total configurable bits: 122 (128 total minus 6 reserved bits)
- Version field (4 bits) and variant field (2 bits) are reserved for UUID v8 compliance
- If configured fields use fewer than 122 bits, remaining bits are automatically filled with random data

## UUID Generation

### Method Signature

```ruby
IronLionUUID.generate(param1, param2, ...)
```

- Positional arguments for parameters in the same order they were configured
- Parameters are required for each configured parameter field
- Environment variables are automatically retrieved
- Timestamps use the current time
- Random data is generated automatically
- Sequence is automatically incremented

### Value Handling

- **Integer parameters**: Used as-is
- **String parameters**: Converted from base36 to base10
- **Environment variables**:
  - Numeric strings treated as integers
  - Other strings treated as base36 and converted to base10
- **Values exceeding bit width**: Error is raised to ensure correctness

## Error Handling

### Error Hierarchy

```ruby
module IronLionUUID
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class FrozenConfigurationError < ConfigurationError; end
  class InvalidBitWidthError < ConfigurationError; end
  class MissingEnvironmentError < ConfigurationError; end
  class ValueTooLargeError < ConfigurationError; end
end
```

### Warning Hierarchy

```ruby
module IronLionUUID
  class Warning < StandardError; end
  class TimestampPrecisionWarning < Warning; end
end
```

### Configuration Validation

- Immediate validation when `configure` is called
- Configuration becomes immutable after initial setting
- Attempting to modify configuration after setting raises `FrozenConfigurationError`
- Total bit count exceeding 122 raises `InvalidBitWidthError`
- Missing environment variables raise `MissingEnvironmentError`
- Values too large for configured bit width raise `ValueTooLargeError`
- System clock precision limitations trigger `TimestampPrecisionWarning`

## UUID Object Interface

### Instance Methods

- Accessor methods for each configured field (e.g., `uuid.model`, `uuid.node`)
- Standard methods: `to_s`, `inspect`, `hash`, `==`, `eql?`
- Conversion methods: `to_uuid`, `to_standard_uuid`

### Class Methods

- `IronLionUUID.generate(*args)`: Creates a new UUID
- `IronLionUUID.from_string(string)`: Creates a UUID from a string representation
- `IronLionUUID.structure`: Returns the current UUID structure configuration
- `IronLionUUID.valid?(string_or_object)`: Checks if a string or object is a valid IronLionUUID

### Object Behavior

- Value objects with proper equality comparisons
- Sortable via Comparable module (lexicographic order)
- JSON, YAML, and Marshal serialization support

## Rails Integration

### ActiveRecord Type Casting

```ruby
# Type registration
IronLionUUID::Type.new

# Easy inclusion in models
module IronLionUUID::HasIronLionId
  extend ActiveSupport::Concern

  included do
    # Apply IronLionUUID type to primary keys and foreign keys of type UUID
  end
end

# Usage in model
class Product < ApplicationRecord
  include IronLionUUID::HasIronLionId
end
```

### Database Function Generation

Rails generator to create SQL functions that match Ruby-side configuration:

```bash
bin/rails generate iron_lion_uuid:install
bin/rails generate iron_lion_uuid:install --databases=primary,analytics
```

#### SQL Function Interface

Generated SQL functions match the Ruby-side interface with positional parameters:

```sql
-- PostgreSQL example
CREATE OR REPLACE FUNCTION generate_iron_lion_uuid(model INTEGER, status INTEGER)
RETURNS UUID AS $$
BEGIN
  -- UUID generation logic matching Ruby implementation
END;
$$ LANGUAGE plpgsql;
```

#### Database Support

- PostgreSQL: Native UUID type
- MySQL: CHAR(36) or binary(16)
- SQLite: TEXT or BLOB with appropriate functions

### Railtie Integration

- Registers generators automatically
- Detects database types when connections are established
- Configures UUID type handling via initializers
- Logs information about detected databases

## Thread Safety

- Uses atomic operations (`Concurrent::AtomicFixnum`) for sequence counters
- Ensures thread-safe access to shared state

## Performance Considerations

- Bit packing in the exact order fields are configured
- Optimized bit operations for performance
- Atomic sequence counter for high concurrency

## Testing Plan

### Test Organization

Shared examples for field behaviors:

1. `value_conversion`: Testing proper conversion of input values
2. `bit_width_validation`: Testing bit width validation
3. `field_positioning`: Testing correct bit positioning

### Test Coverage Requirements

- Configuration validation
- UUID generation with all field types
- Value conversion and validation
- Thread safety for sequence generation
- ActiveRecord integration
- Database function generation
- Error handling for all error cases
- Serialization/deserialization

## Implementation Timeline

1. Core Ruby-side UUID generation
2. Configuration DSL
3. ActiveRecord type integration
4. Database function generation
5. Rails generators and Railtie
6. Documentation and examples

## Documentation

- RDoc/YARD documentation for all public methods
- Example configurations for common use cases
- Rails integration guide
- Database migration guide
