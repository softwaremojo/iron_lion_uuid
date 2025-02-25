# IronLionUUID Implementation Checklist

## Phase 1: Core UUID Functionality

### 1.1 Project Setup and Basic Structure
- [ ] Create gem structure with Bundler
- [ ] Set up gemspec with proper metadata
  - [ ] Add name, version, authors, email
  - [ ] Add summary and description
  - [ ] Add homepage (e.g., GitHub repo)
  - [ ] Add license (e.g., MIT)
- [ ] Add development dependencies
  - [ ] RSpec for testing
  - [ ] Add any other development dependencies
- [ ] Set up RSpec
  - [ ] Create spec_helper.rb
  - [ ] Set up test configuration
- [ ] Create initial module structure
  - [ ] Create lib/iron_lion_uuid.rb
  - [ ] Define IronLionUUID module
  - [ ] Create version constant
- [ ] Create README with basic overview
- [ ] Write passing smoke test

### 1.2 Bit Manipulation Utilities
- [ ] Create BitOps module
  - [ ] Implement extract_bits(value, pos, n) method
  - [ ] Implement set_bits(value, pos, n, new_bits) method
  - [ ] Implement mask(n) method
- [ ] Test BitOps module
  - [ ] Test extraction of bits from different positions
  - [ ] Test setting bits at different positions
  - [ ] Test edge cases (0 bits, maximum bit width)
  - [ ] Test boundary conditions

### 1.3 Basic UUID Value Object
- [ ] Create UUID class
  - [ ] Implement initialize with 128-bit value
  - [ ] Implement to_s method for standard UUID format
  - [ ] Implement == method for equality comparison
  - [ ] Implement eql? method for Ruby hash equality
  - [ ] Implement hash method for hash tables
- [ ] Test UUID class
  - [ ] Test creation with various values
  - [ ] Test string conversion
  - [ ] Test equality comparison
  - [ ] Test hash code generation

### 1.4 Error and Warning Classes
- [ ] Create Error class hierarchy
  - [ ] Implement Error (base class inheriting from StandardError)
  - [ ] Implement ConfigurationError (inherits from Error)
  - [ ] Implement FrozenConfigurationError (inherits from ConfigurationError)
  - [ ] Implement InvalidBitWidthError (inherits from ConfigurationError)
  - [ ] Implement MissingEnvironmentError (inherits from ConfigurationError)
  - [ ] Implement ValueTooLargeError (inherits from ConfigurationError)
- [ ] Create Warning class hierarchy
  - [ ] Implement Warning (base class inheriting from StandardError)
  - [ ] Implement TimestampPrecisionWarning (inherits from Warning)
- [ ] Add descriptive default messages to each error/warning class
- [ ] Test error and warning classes
  - [ ] Test raising and catching each error type
  - [ ] Verify error messages are descriptive

## Phase 2: Configuration System

### 2.1 Configuration Container
- [ ] Create Configuration class
  - [ ] Implement fields collection
  - [ ] Implement freeze! method
  - [ ] Implement validate! method to check total bit width
- [ ] Implement IronLionUUID.configure method
  - [ ] Accept a block and yield configuration instance
  - [ ] Handle already frozen configurations
  - [ ] Validate and freeze configuration after block execution
- [ ] Test Configuration class
  - [ ] Test creation of new configuration
  - [ ] Test freezing the configuration
  - [ ] Test validation of total bit width
  - [ ] Test prevention of modifications after freezing

### 2.2 Field Base Class
- [ ] Create Field base class
  - [ ] Implement initialize with options hash
  - [ ] Store bit width, name, and position
  - [ ] Implement validate_bits! method
  - [ ] Implement set_position method
  - [ ] Implement extract_from method using BitOps
  - [ ] Implement apply_to method using BitOps
- [ ] Update Configuration class for field positioning
  - [ ] Implement add_field method
  - [ ] Implement calculate_next_position method
  - [ ] Handle positioning around reserved bits
- [ ] Test Field base class
  - [ ] Test initialization with various options
  - [ ] Test bit width validation
  - [ ] Test position setting
  - [ ] Test value extraction and application

### 2.3 Field Registry and DSL Methods
- [ ] Update Configuration class with field type methods
  - [ ] Implement parameter method
  - [ ] Implement env method
  - [ ] Implement timestamp method
  - [ ] Implement random method
  - [ ] Implement sequence method
- [ ] Create placeholder field type classes
  - [ ] Create ParameterField class
  - [ ] Create EnvField class
  - [ ] Create TimestampField class
  - [ ] Create RandomField class
  - [ ] Create SequenceField class
- [ ] Test field registry and DSL methods
  - [ ] Test registration of fields of each type
  - [ ] Test position calculation for fields
  - [ ] Test configuration validation with multiple fields

## Phase 3: Field Type Implementations

### 3.1 Random Field Implementation
- [ ] Implement RandomField class
  - [ ] Implement initialize method
  - [ ] Implement value method using SecureRandom
- [ ] Update Configuration DSL for random field
- [ ] Create Generator class with basic functionality
  - [ ] Implement initialize with configuration
  - [ ] Implement basic generate method
- [ ] Test RandomField
  - [ ] Test configuration syntax
  - [ ] Test random value generation
  - [ ] Test bit width constraints
  - [ ] Test integration with configuration

### 3.2 Parameter Field Implementation
- [ ] Implement ParameterField class
  - [ ] Implement initialize with required name
  - [ ] Implement value method accepting parameter
  - [ ] Implement convert_value method
  - [ ] Implement validate_value! method
- [ ] Update Configuration DSL for parameter field
- [ ] Update Generator to handle parameter fields
- [ ] Test ParameterField
  - [ ] Test configuration syntax
  - [ ] Test integer value handling
  - [ ] Test string value conversion
  - [ ] Test value validation
  - [ ] Test error handling for large values

### 3.3 Environment Variable Field Implementation
- [ ] Implement EnvField class
  - [ ] Implement initialize with required name and key
  - [ ] Implement value method for environment lookup
  - [ ] Implement convert_value method
  - [ ] Implement validate_value! method
- [ ] Update Configuration DSL for environment variable field
- [ ] Update Generator to handle environment fields
- [ ] Test EnvField
  - [ ] Test configuration syntax
  - [ ] Test environment variable retrieval
  - [ ] Test numeric value handling
  - [ ] Test string value conversion
  - [ ] Test error handling for missing variables
  - [ ] Test error handling for large values

### 3.4 Timestamp Field Implementation
- [ ] Implement TimestampField class
  - [ ] Define PRECISIONS constant
  - [ ] Implement initialize with precision option
  - [ ] Implement check_system_precision! method
  - [ ] Implement value method for timestamp generation
  - [ ] Implement validate_value! method
- [ ] Update Configuration DSL for timestamp field
- [ ] Update Generator to handle timestamp fields
- [ ] Test TimestampField
  - [ ] Test configuration syntax
  - [ ] Test time precision handling
  - [ ] Test warning generation for unsupported precision
  - [ ] Test timestamp value calculation
  - [ ] Test value validation

### 3.5 Sequence Field Implementation
- [ ] Add concurrent-ruby dependency to gemspec
- [ ] Implement SequenceField class
  - [ ] Implement initialize with atomic counter
  - [ ] Implement value method for atomic increment
  - [ ] Handle wrapping at maximum value
- [ ] Update Configuration DSL for sequence field
- [ ] Update Generator to handle sequence fields
- [ ] Test SequenceField
  - [ ] Test configuration syntax
  - [ ] Test sequence generation
  - [ ] Test wrapping behavior
  - [ ] Test thread safety with multiple threads

## Phase 4: UUID Generation Integration

### 4.1 UUID Generator Class
- [ ] Enhance Generator class
  - [ ] Complete generate method for all field types
  - [ ] Handle parameter fields with argument values
  - [ ] Apply all field values to UUID
  - [ ] Set version and variant bits
  - [ ] Return UUID with field values
- [ ] Test Generator class
  - [ ] Test UUID generation with various field combinations
  - [ ] Test parameter handling
  - [ ] Test version and variant bit setting
  - [ ] Test error handling for missing parameters

### 4.2 Enhanced UUID Class with Field Access
- [ ] Create CustomUUID class extending UUID
  - [ ] Store field values and configuration
  - [ ] Implement extract_fields method
  - [ ] Define accessor methods for fields
  - [ ] Implement Comparable for sorting
- [ ] Update IronLionUUID module with main methods
  - [ ] Implement generate method
  - [ ] Implement from_string method
  - [ ] Implement valid? method
- [ ] Test UUID enhancements
  - [ ] Test field value extraction
  - [ ] Test accessor methods
  - [ ] Test UUID comparison
  - [ ] Test UUID parsing from string
  - [ ] Test UUID validation

## Phase 5: Rails Integration

### 5.1 ActiveRecord Type Casting
- [ ] Create Type class for ActiveRecord
  - [ ] Implement cast method
  - [ ] Implement serialize method
  - [ ] Implement deserialize method
- [ ] Implement HasIronLionId concern
  - [ ] Implement included hook
  - [ ] Find UUID attributes
  - [ ] Apply IronLionUUID type
- [ ] Add conditional ActiveRecord registration
- [ ] Test ActiveRecord integration
  - [ ] Test type casting
  - [ ] Test serialization
  - [ ] Test deserialization
  - [ ] Test model integration

### 5.2 SQL Generation Framework
- [ ] Create SQLGenerator class
  - [ ] Implement initialize with dialect
  - [ ] Implement generate_function method
  - [ ] Create skeleton for database-specific generators
- [ ] Test SQL generation framework
  - [ ] Test SQL generation for each supported database
  - [ ] Test parameter handling in SQL

### 5.3 Database-Specific SQL Implementations
- [ ] Implement PostgreSQL function generator
  - [ ] Handle all field types
  - [ ] Set version and variant bits
  - [ ] Format UUID correctly
- [ ] Implement MySQL function generator
  - [ ] Handle all field types
  - [ ] Set version and variant bits
  - [ ] Format UUID correctly
- [ ] Implement SQLite function generator
  - [ ] Handle all field types
  - [ ] Set version and variant bits
  - [ ] Format UUID correctly
- [ ] Test database-specific implementations
  - [ ] Test SQL syntax for each database
  - [ ] Test field handling
  - [ ] Test UUID formatting

### 5.4 Rails Generators and Railtie
- [ ] Create InstallGenerator class
  - [ ] Add database options
  - [ ] Implement create_migration_file method
- [ ] Create migration template
  - [ ] Handle multiple databases
  - [ ] Generate database-specific SQL
  - [ ] Include up and down migrations
- [ ] Implement Railtie
  - [ ] Register UUID type with ActiveRecord
  - [ ] Register generators
- [ ] Test Rails integration
  - [ ] Test generator functionality
  - [ ] Test migration template
  - [ ] Test Railtie initialization

## Phase 6: Documentation and Finalization

### 6.1 Code Documentation
- [ ] Add YARD as development dependency
- [ ] Document IronLionUUID module
- [ ] Document Configuration class
- [ ] Document Field classes
- [ ] Document Generator class
- [ ] Document UUID classes
- [ ] Document Rails integration classes
- [ ] Document SQL generation classes

### 6.2 README and Usage Examples
- [ ] Create comprehensive README
  - [ ] Add installation instructions
  - [ ] Add basic usage examples
  - [ ] Add configuration examples
  - [ ] Add Rails integration instructions
- [ ] Create CHANGELOG.md
- [ ] Create CONTRIBUTING.md

### 6.3 Rails Integration Guide
- [ ] Create Rails integration guide
  - [ ] Add installation instructions
  - [ ] Add configuration examples
  - [ ] Add database setup instructions
  - [ ] Add model integration examples
  - [ ] Add advanced usage patterns
  - [ ] Add troubleshooting section

### 6.4 Database Migration Guide
- [ ] Create database migration guide
  - [ ] Add PostgreSQL setup instructions
  - [ ] Add MySQL setup instructions
  - [ ] Add SQLite setup instructions
  - [ ] Add migration instructions
  - [ ] Add usage examples
  - [ ] Add troubleshooting section

## Final Steps

- [ ] Review entire codebase for consistency
- [ ] Ensure all tests are passing
- [ ] Check documentation coverage
- [ ] Prepare for initial release
- [ ] Create example applications
- [ ] Set up CI/CD pipeline
