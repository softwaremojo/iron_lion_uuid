## Implementation Prompts

### Prompt 1: Project Setup and Basic Structure

```
# IronLionUUID Project: Initial Setup

You're building a Ruby gem called IronLionUUID that generates customizable UUID v8 identifiers. Let's set up the project structure and implement the basic UUID representation.

## Tasks:

1. Create the basic gem structure with Bundler, including:
   - A proper gemspec with metadata and dependencies
   - RSpec for testing
   - Basic module definition and version constant

2. Implement a BitOps module with methods for bit manipulation:
   - extract_bits(value, pos, n): Extract n bits starting at position pos from value
   - set_bits(value, pos, n, new_bits): Set n bits at position pos in value to new_bits
   - mask(n): Create a mask of n bits (all 1s)

3. Implement a basic UUID class that represents a 128-bit UUID:
   - Initialize with a 128-bit value
   - Convert to standard UUID string format (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)
   - Implement equality comparison (==, eql?, hash)

4. Write comprehensive tests for all implemented functionality.

## Technical Requirements:

- Use proper Ruby coding conventions
- Ensure all methods have clear and specific responsibilities
- Use BigInt/Fixnum for precise bit operations when needed
- Make the UUID class immutable (value objects)

Start by implementing the basic gem structure and the BitOps module, then move on to the UUID class. Include thorough tests for each component.
```

### Prompt 2: Error and Warning Classes

```
# IronLionUUID Project: Error and Warning Classes

Now that you have the basic UUID structure implemented, let's add the error and warning classes that will be used throughout the library.

## Tasks:

1. Implement the error class hierarchy:
   - Error (base class inheriting from StandardError)
   - ConfigurationError (inherits from Error)
   - FrozenConfigurationError (inherits from ConfigurationError)
   - InvalidBitWidthError (inherits from ConfigurationError)
   - MissingEnvironmentError (inherits from ConfigurationError)
   - ValueTooLargeError (inherits from ConfigurationError)

2. Implement the warning class hierarchy:
   - Warning (base class inheriting from StandardError)
   - TimestampPrecisionWarning (inherits from Warning)

3. Ensure each error and warning class has a descriptive default message.

4. Write tests for each error and warning class, verifying that they can be properly raised and caught.

## Technical Requirements:

- Place all error and warning classes in the IronLionUUID namespace
- Include descriptive default messages for each error type
- Ensure errors can be properly raised and rescued

Design these error classes to provide clear, actionable error messages for users of the library. The errors should help users understand what went wrong and how to fix the issue.
```

### Prompt 3: Configuration DSL Basic Structure

```
# IronLionUUID Project: Configuration DSL

Let's implement the configuration DSL for defining UUID attribute structures. This is a core part of the library that allows users to customize their UUIDs.

## Tasks:

1. Create a Configuration class to store attribute definitions:
   - It should allow adding attribute definitions
   - It should track the total bit usage
   - It should validate that the total bit count doesn't exceed 122 bits (6 bits are reserved for version and variant)
   - It should be freezable to prevent modifications after initial setting

2. Implement the IronLionUUID.configure method that accepts a block.

3. Implement freezing of the configuration to prevent modifications after initial setting:
   - Calling configure after configuration is frozen should raise FrozenConfigurationError
   - The configuration should be automatically frozen after the initial configuration block

4. Write tests for the configuration functionality:
   - Test the block-style configuration syntax
   - Test configuration freezing
   - Test bit width validation

## Technical Requirements:

- The configuration should be stored as a class variable in the IronLionUUID module
- The configure method should yield a Configuration instance to the block
- The configuration should be validated and frozen after the block is executed
- Don't implement specific attribute types yet - focus on the configuration container

Remember that the configuration will be the foundation for all UUID generation, so it's important to get this right.
```

### Prompt 4: Attribute Base Class and Registry

```
# IronLionUUID Project: Attribute Base Class and Registry

Now let's implement the base Attribute class and the attribute registry mechanism in the Configuration class. This will form the foundation for implementing specific attribute types.

## Tasks:

1. Create a base Attribute class that all attribute types will inherit from:
   - It should store bit width, name, and position
   - It should validate that the bit width is positive
   - It should provide methods for setting position within the UUID
   - It should provide methods for extracting attribute values from a complete UUID
   - It should provide methods for applying attribute values to a UUID

2. Update the Configuration class to include a attribute registry:
   - Track all configured attributes and their positions
   - Calculate attribute positions based on the order they are added
   - Ensure attribute positions don't overlap with reserved bits (version and variant)

3. Implement position calculation logic in the Configuration class:
   - attributes should be positioned consecutively in the order they are added
   - Version bits (48-51) and variant bits (64-65) should be reserved
   - Handle positioning around these reserved bits

4. Write tests for the Attribute class and attribute registry:
   - Test attribute creation with valid parameters
   - Test attribute bit width validation
   - Test attribute positioning within the UUID structure
   - Test extraction of attribute values from a complete UUID

## Technical Requirements:

- The Attribute class should be abstract, with subclasses implementing specific attribute types
- Attribute positioning should be handled by the Configuration class, not by individual attributes
- Attribute positions should be in bits from 0 to 127 (128 bits total)
- Reserved positions are bits 48-51 (version) and 64-65 (variant)

This base class and registry will be the foundation for implementing specific attribute types in subsequent steps.
```

### Prompt 5: Random Attribute Implementation

```
# IronLionUUID Project: Random Attribute Type

Let's implement the Random attribute type, which is the simplest attribute type as it just generates random bits. This will establish the pattern for attribute type implementations.

## Tasks:

1. Implement the RandomAttribute class that inherits from Attribute:
   - Accept a 'bits' parameter specifying how many random bits to generate
   - Accept an optional 'name' parameter (default to :random)
   - Generate cryptographically secure random bits when a UUID is created
   - Properly position these bits in the UUID structure

2. Extend the Configuration DSL to support the random attribute type.

3. Begin implementing the UUID generation logic:
   - Create a Generator class that uses the configured attributes
   - Implement basic UUID generation with just random attributes
   - Set version (8) and variant bits correctly

4. Write tests for the RandomAttribute:
   - Test configuration syntax
   - Test random value generation
   - Test bit positioning
   - Test extraction of the random value from a generated UUID

## Technical Requirements:

- Use SecureRandom for cryptographically secure random number generation
- Ensure random values are properly constrained to the specified bit width
- Make sure version (bits 48-51 = 8) and variant (bits 64-65 = 2) are set correctly

This implementation will serve as a foundation for understanding the attribute implementation pattern before moving to more complex attribute types.
```

### Prompt 6: Parameter Attribute Implementation

```
# IronLionUUID Project: Parameter Attribute Type

Now let's implement the Parameter attribute type, which accepts user-provided values at UUID generation time.

## Tasks:

1. Implement the ParameterAttribute class that inherits from Attribute:
   - Accept a 'bits' parameter specifying how many bits to use
   - Accept a 'name' parameter for accessing the value later (required)
   - Handle both integer and string input values
   - Convert string values from base36 to base10
   - Validate that input values fit within the specified bit width
   - Raise ValueTooLargeError if a value exceeds the available bits

2. Extend the Configuration DSL to support the parameter attribute type.

3. Update the UUID generator to accept parameters for parameter attributes.

4. Implement accessor methods for retrieving attribute values from a UUID.

5. Write tests for the ParameterAttribute:
   - Test configuration syntax
   - Test integer value handling
   - Test string value conversion
   - Test value validation
   - Test error handling for values too large for the bit width
   - Test accessor method generation

## Technical Requirements:

- Parameter names must be valid Ruby method names (symbols)
- String values should be converted from base36 to base10
- Parameters should be passed to the generate method in the same order they were configured
- Validate that parameter values fit within their allocated bit width
- Generate accessor methods for each named attribute

This attribute type introduces value validation and conversion, which will be important for subsequent attribute types as well.
```

### Prompt 7: Environment Variable Attribute Implementation

```
# IronLionUUID Project: Environment Variable Attribute Type

Let's implement the Environment Variable attribute type, which retrieves values from environment variables.

## Tasks:

1. Implement the EnvAttribute class that inherits from Attribute:
   - Accept a 'bits' parameter specifying how many bits to use
   - Accept a 'name' parameter for accessing the value later (required)
   - Accept a 'key' parameter specifying which environment variable to use (required)
   - Handle both numeric and string environment variable values
   - Convert numeric strings directly to integers
   - Convert other strings from base36 to base10
   - Validate that environment variable values fit within the specified bit width
   - Raise MissingEnvironmentError if the specified environment variable is not set
   - Raise ValueTooLargeError if a value exceeds the available bits

2. Extend the Configuration DSL to support the environment variable attribute type.

3. Update the UUID generator to retrieve environment variables:
   - Ensure environment variables are retrieved at UUID generation time, not at configuration time
   - Add appropriate error handling for missing environment variables

4. Write tests for the EnvAttribute:
   - Test configuration syntax
   - Test environment variable retrieval
   - Test numeric value handling
   - Test string value conversion
   - Test error handling for missing environment variables
   - Test error handling for values too large for the bit width
   - Test accessor method generation for retrieving attribute values

## Technical Requirements:

- Environment variable values should be retrieved at UUID generation time, not at configuration time
- Use appropriate mocking in tests to set and clear environment variables
- Numeric strings should be treated as integers directly (e.g., "123" becomes 123)
- Other strings should be converted from base36 to base10
- Validate that environment variable values fit within their allocated bit width

Remember that environment variables are often used for node or machine identifiers in distributed systems, so this attribute type is important for those use cases.
```

### Prompt 8: Timestamp Attribute Implementation

```
# IronLionUUID Project: Timestamp Attribute Type

Let's implement the Timestamp attribute type, which embeds the current time in the UUID.

## Tasks:

1. Implement the TimestampAttribute class that inherits from Attribute:
   - Accept a 'bits' parameter specifying how many bits to use
   - Accept a 'precision' parameter specifying the time precision (second, millisecond, microsecond, nanosecond)
   - Accept an optional 'name' parameter (default to :timestamp)
   - Validate that the system clock supports the requested precision
   - Emit a TimestampPrecisionWarning if the system clock doesn't support the requested precision
   - Calculate a numeric timestamp value based on the current time and requested precision
   - Validate that the timestamp value fits within the specified bit width

2. Extend the Configuration DSL to support the timestamp attribute type.

3. Update the UUID generator to handle timestamp attributes:
   - Ensure timestamps are generated at UUID generation time, not at configuration time
   - Handle any potential errors or warnings related to timestamp generation

4. Write tests for the TimestampAttribute:
   - Test configuration syntax
   - Test time precision handling
   - Test warning generation for unsupported precision
   - Test timestamp value calculation
   - Test value validation
   - Test extraction of timestamp values from a generated UUID
   - Test accessor method generation for retrieving attribute values

## Technical Requirements:

- Support the following precision values: :second, :millisecond, :microsecond, :nanosecond
- Use Time.now for timestamp generation
- Check system clock precision to ensure it supports the requested precision
- Use appropriate time mocking in tests to ensure reliable test execution
- Validate that timestamp values fit within their allocated bit width

Timestamps are often a core component of UUIDs, providing both uniqueness and ordering, so this attribute type is particularly important.
```

### Prompt 9: Sequence Attribute Implementation with Thread Safety

```
# IronLionUUID Project: Sequence Attribute Type with Thread Safety

Let's implement the Sequence attribute type, which provides an auto-incrementing sequence number with thread safety.

## Tasks:

1. Implement the SequenceAttribute class that inherits from Attribute:
   - Accept a 'bits' parameter specifying how many bits to use
   - Accept an optional 'name' parameter (default to :sequence)
   - Use atomic operations for thread-safe sequence generation
   - Wrap around to zero when the maximum value for the bit width is reached
   - Validate that the sequence value fits within the specified bit width

2. Add the concurrent-ruby gem as a dependency:
   - Update the gemspec to include concurrent-ruby

3. Implement the atomic counter using Concurrent::AtomicFixnum.

4. Extend the Configuration DSL to support the sequence attribute type.

5. Update the UUID generator to handle sequence attributes:
   - Ensure sequence numbers are generated at UUID generation time
   - Handle sequence number wrapping correctly

6. Write tests for the SequenceAttribute:
   - Test configuration syntax
   - Test sequence generation
   - Test wrapping behavior
   - Test thread safety using multiple threads
   - Test extraction of sequence values from a generated UUID
   - Test accessor method generation for retrieving attribute values

## Technical Requirements:

- Use concurrent-ruby for thread-safe operations
- Test thread safety by generating UUIDs concurrently in multiple threads
- Ensure sequence numbers wrap correctly when they reach the maximum value
- Validate that sequence values fit within their allocated bit width

The sequence attribute is important for high-volume UUID generation scenarios, as it helps ensure uniqueness even when many UUIDs are generated in a short time period.
```

### Prompt 10: UUID Generation Logic Integration

```
# IronLionUUID Project: UUID Generation Logic Integration

Now let's integrate all attribute types into a complete UUID generation system.

## Tasks:

1. Implement the main `IronLionUUID.generate` method:
   - Accept parameters for parameter attributes in the order they were configured
   - Retrieve values from environment variables, generate timestamps, random data, and increment sequences as needed
   - Combine all attribute values into a single 128-bit UUID with proper positioning
   - Set the UUID version (8) and variant bits correctly
   - Return a UUID object with accessor methods for each configured attribute

2. Enhance the UUID class to create a CustomUUID class:
   - Include accessor methods for each configured attribute
   - Implement additional methods: `to_s`, `inspect`, `hash`, `==`, `eql?`
   - Add conversion methods: `to_uuid`, `to_standard_uuid`
   - Implement Comparable for sorting

3. Implement the `IronLionUUID.from_string` method:
   - Parse a UUID string into a 128-bit value
   - Create a UUID object with the current configuration
   - Extract attribute values based on the configuration

4. Implement the `IronLionUUID.valid?` method:
   - Check if a string or object is a valid IronLionUUID
   - Validate the format and structure

5. Write comprehensive tests for the integrated UUID generation:
   - Test complete UUID generation with all attribute types
   - Test parameter handling
   - Test attribute value extraction
   - Test UUID string formatting
   - Test UUID comparison and sorting
   - Test UUID creation from string

## Technical Requirements:

- Ensure UUID version (bits 48-51 = 8) and variant (bits 64-65 = 2) are set correctly
- Generate accessor methods for each named attribute
- Implement proper value object semantics (immutability, equality, hash)
- Make UUIDs comparable for sorting (lexicographic order)
- Handle invalid input gracefully with clear error messages

This step brings together all the previous work into a complete UUID generation system.
```

### Prompt 11: Rails Integration - ActiveRecord Type

```
# IronLionUUID Project: Rails Integration - ActiveRecord Type

Let's implement the ActiveRecord type casting for IronLionUUID to integrate with Rails applications.

## Tasks:

1. Implement the ActiveRecord type casting for IronLionUUID.

2. Implement a concern for easy inclusion in ActiveRecord models.

3. Register the IronLionUUID type with ActiveRecord.

4. Write tests for the ActiveRecord integration:
   - Test type casting from various input types
   - Test serialization to database format
   - Test deserialization from database format
   - Test integration with ActiveRecord models

## Technical Requirements:

- Make the ActiveRecord integration optional so the gem can be used without Rails
- Ensure proper handling of nil values
- Support both string and binary UUID representations
- Implement proper ActiveRecord type casting conventions

This integration allows IronLionUUID to be used seamlessly with Rails and ActiveRecord, making it easy to use in web applications.
```

### Prompt 12: SQL Generation Framework

```
# IronLionUUID Project: SQL Generation Framework

Let's implement the SQL generation framework for creating database functions that match the Ruby-side UUID generation.

## Tasks:

1. Implement the SQLGenerator class for generating database functions.

2. Implement basic versions of the database-specific function generators:
   - PostgreSQL using native UUID type and functions
   - MySQL using CHAR(36) or BINARY(16)
   - SQLite using TEXT

3. Design the SQL functions to match the Ruby-side configuration:
   - Accept parameters for parameter attributes
   - Generate timestamps, random data, and sequences in SQL
   - Set version and variant bits correctly
   - Return properly formatted UUIDs

4. Write tests for the SQL generation framework:
   - Test SQL generation for each supported database
   - Test parameter handling in SQL functions
   - Test generated SQL syntax

## Technical Requirements:

- Generate SQL that matches the Ruby-side UUID generation exactly
- Handle the differences in bit manipulation capabilities across databases
- Support all attribute types in each database (where possible)
- Handle environment variables appropriately (noting they can't be accessed in SQL)

The SQL functions allow database-side generation of UUIDs that match the Ruby-side configuration, which is useful for default values and bulk operations.
```

### Prompt 13: Database-Specific SQL Implementations

```
# IronLionUUID Project: Database-Specific SQL Implementations

Now let's implement the database-specific SQL function generators for PostgreSQL, MySQL, and SQLite in detail.

## Tasks:

1. Implement the PostgreSQL function generator:
   - Use PostgreSQL's native UUID type
   - Implement bit manipulation for all attribute types
   - Create a sequence for SequenceAttribute if needed
   - Set version and variant bits correctly
   - Format the result as a standard UUID

2. Implement the MySQL function generator:
   - Use CHAR(36) for UUID representation
   - Implement bit manipulation using bitwise operators
   - Create a sequence table for SequenceAttribute if needed
   - Set version and variant bits correctly
   - Format the result as a standard UUID

3. Implement the SQLite function generator:
   - Use TEXT for UUID representation
   - Implement bit manipulation using SQLite's limited bitwise functions
   - Create a sequence table for SequenceAttribute if needed
   - Set version and variant bits correctly
   - Format the result as a standard UUID

4. Implement helpers for common SQL operations:
   - Bit extraction
   - Bit setting
   - Random number generation
   - Timestamp conversion
   - UUID formatting

5. Write tests for the database-specific SQL implementations:
   - Test SQL generation for each supported database
   - Test attribute handling for each attribute type
   - Test sequence creation
   - Test UUID formatting

## Technical Requirements:

- Generate SQL that matches the Ruby-side UUID generation exactly
- Handle the differences in bit manipulation capabilities across databases
- Ensure proper error handling in the generated SQL functions
- Use database-specific features when appropriate for better performance

These database-specific implementations allow UUID generation directly in the database, which is important for default values, bulk inserts, and other database operations.
```

### Prompt 14: Rails Generators and Railtie

```
# IronLionUUID Project: Rails Generators and Railtie

Let's implement the Rails generators and Railtie for easy integration with Rails applications.

## Tasks:

1. Implement the Rails install generator.

2. Create the migration template:
   - Create a template that generates database-specific SQL
   - Support multiple databases with the `on_database` method
   - Include proper up and down migrations

3. Implement the Railtie for automatic Rails integration.

4. Write tests for the Rails integration:
   - Test generator functionality
   - Test migration template rendering
   - Test Railtie initialization

## Technical Requirements:

- Make the Rails integration optional so the gem can be used without Rails
- Support multiple databases in Rails applications
- Generate appropriate migrations for each supported database type
- Ensure compatibility with different Rails versions

The Rails generators and Railtie make it easy for Rails developers to integrate IronLionUUID into their applications with minimal effort.
```

### Prompt 15: Documentation and Examples

```
# IronLionUUID Project: Documentation and Examples

Let's create comprehensive documentation for the IronLionUUID library, including usage examples and integration guides.

## Tasks:

1. Implement YARD documentation for all public classes and methods:
   - Add documentation comments to all public methods
   - Include examples for common use cases
   - Document parameters, return values, and raised exceptions
   - Document all configuration options

2. Create a README.md with basic usage examples:
   - Installation instructions
   - Basic configuration examples
   - UUID generation examples
   - Rails integration examples

3. Create a CHANGELOG.md to track changes between versions:
   - Document initial version features
   - Set up structure for future versions

4. Create a Rails integration guide:
   - Installation instructions
   - Configuration examples
   - Database setup instructions
   - Model integration examples
   - Advanced usage patterns

5. Create a database migration guide:
   - Setting up databases for UUID support
   - Migrating from standard UUIDs to IronLionUUID
   - Using IronLionUUID functions in queries
   - Database-specific considerations

## Technical Requirements:

- Use YARD documentation format for code documentation
- Include examples for all public methods
- Create separate guides for different aspects of the library
- Include troubleshooting sections in guides
- Ensure documentation is accurate and comprehensive

Good documentation is essential for the adoption and effective use of the library, so it's important to invest time in creating clear, comprehensive documentation with helpful examples.
```

## Review and Final Implementation Plan

Breaking down the IronLionUUID project into these step-by-step prompts provides a clear path for implementation. Each prompt builds on the previous ones, ensuring that the project evolves in a logical and manageable way.

The key strengths of this approach are:

1. **Incremental Development**: Starting with core functionality and basic structures before adding complexity.
2. **Test-Driven Development**: Each prompt includes thorough testing requirements.
3. **Clear Dependencies**: Each step clearly depends on and builds upon previous steps.
4. **Proper Abstraction**: The design maintains clean separations between different components.
5. **Good Documentation**: Documentation is treated as a first-class concern.

This implementation plan should result in a high-quality, well-tested, and well-documented UUID library that matches the specification provided. The step sizes are appropriate - each is substantial enough to make progress but small enough to implement and test thoroughly.
