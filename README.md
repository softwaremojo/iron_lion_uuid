# IronLionUUID

[![Gem Version](https://badge.fury.io/rb/iron_lion_uuid.svg)](https://badge.fury.io/rb/iron_lion_uuid)
[![Build Status](https://github.com/yourusername/iron_lion_uuid/workflows/Ruby/badge.svg)](https://github.com/yourusername/iron_lion_uuid/actions)
[![Yard Docs](https://img.shields.io/badge/yard-docs-blue.svg)](https://rubydoc.info/gems/iron_lion_uuid)

IronLionUUID is a Ruby library that generates customizable UUID v8 identifiers with both Ruby-side and database-side implementations. The library allows developers to configure the internal structure of UUIDs to embed useful information like model type, timestamp, and sequence numbers, while maintaining RFC compliance.

## Features

- **Bit-level configuration** - Define the exact bit structure of your UUIDs
- **Multiple data source types** - Embed parameters, environment variables, timestamps, sequence numbers, and random data
- **Rails integration** - Seamless integration with ActiveRecord
- **Database functions** - Generate matching database functions for PostgreSQL, MySQL, and SQLite
- **Full RFC compliance** - All UUIDs are standard v8 UUIDs and work with existing UUID infrastructure

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'iron_lion_uuid'
```

And then execute:

```bash
$ bundle install
```

Or install it yourself as:

```bash
$ gem install iron_lion_uuid
```

## Quick Start

```ruby
# Configure the UUID structure
IronLionUUID.configure do |uuid|
  uuid.parameter bits: 16, name: :model      # 16 bits for model type
  uuid.timestamp bits: 36, precision: :millisecond  # 36 bits for timestamp
  uuid.random bits: 32                       # 32 bits of randomness
  # Remaining bits will automatically be filled with random data
end

# Generate a UUID with model parameter
uuid = IronLionUUID.generate(1)  # 1 is the model code (e.g., User = 1)

puts uuid  # => "a0b72d14-8c21-8ce2-9012-ff3a35b81401"
puts uuid.model  # => 1
puts Time.at(uuid.timestamp / 1000.0)  # => 2023-05-30 12:34:56.789 -0700
```

## Configuration

IronLionUUID is highly configurable, allowing you to decide exactly what data to embed in your UUIDs and how many bits to allocate to each piece of data.

### Field Types

1. **parameter** - User-provided value at UUID generation time
```ruby
uuid.parameter bits: 16, name: :model
```

2. **env** - Value from an environment variable
```ruby
uuid.env bits: 12, name: :node, key: :NODE_ID
```

3. **timestamp** - Current time at configured precision
```ruby
uuid.timestamp bits: 36, precision: :millisecond
```

4. **random** - Random data for uniqueness
```ruby
uuid.random bits: 32
```

5. **sequence** - Auto-incrementing sequence number
```ruby
uuid.sequence bits: 16
```

### Bit Allocation

- Total configurable bits: 122 (128 total minus 6 reserved bits)
- Version field (4 bits) and variant field (2 bits) are reserved for UUID v8 compliance
- If configured fields use fewer than 122 bits, remaining bits are automatically filled with random data

## Rails Integration

### Model Integration

```ruby
# In your model
class Product < ApplicationRecord
  include IronLionUUID::HasIronLionId

  before_create :set_uuid_if_nil

  private

  def set_uuid_if_nil
    self.set_uuid_if_nil(1)  # 1 is the model code for Product
  end
end
```

### Database Functions

Generate database functions that match your Ruby-side configuration:

```bash
bin/rails generate iron_lion_uuid:install
```

This creates migrations to add the appropriate functions to your database.

## Examples

### Basic Configuration

```ruby
IronLionUUID.configure do |uuid|
  uuid.parameter bits: 16, name: :model
  uuid.timestamp bits: 36, precision: :millisecond
  uuid.random bits: 32
end
```

### Generating UUIDs

```ruby
# With parameter
uuid = IronLionUUID.generate(1)  # 1 is the model parameter

# Access embedded data
puts uuid.model  # => 1
puts uuid.timestamp  # => 1685473562789 (milliseconds since epoch)
```

### ActiveRecord Integration

```ruby
# In an initializer
IronLionUUID.configure do |uuid|
  uuid.parameter bits: 16, name: :model
  uuid.timestamp bits: 36, precision: :millisecond
  uuid.random bits: 32
end

# In a migration
create_table :products, id: :string, limit: 36 do |t|
  t.string :name
  t.timestamps
end

# In your model
class Product < ApplicationRecord
  include IronLionUUID::HasIronLionId

  before_create :set_uuid_if_nil

  private

  def set_uuid_if_nil
    self.set_uuid_if_nil(1)  # 1 is the model code for Product
  end
end

# Using the model
product = Product.create(name: "Test Product")
puts product.id  # => "a0b72d14-8c21-8ce2-9012-ff3a35b81401"
```

## Use Cases

- **Sortable UUIDs** - Embedding timestamps makes UUIDs naturally sortable by creation time
- **Distributed Systems** - Embed node IDs to track which server generated each UUID
- **Database Sharding** - Use model type and timestamps for intelligent sharding
- **Debugging** - Extract creation time and source data directly from the UUID
- **Performance** - Generate UUIDs in the database without Ruby roundtrips

## Documentation

For detailed documentation, see:

- [Rails Integration Guide](docs/rails_integration.md)
- [Database Migration Guide](docs/database_migration.md)
- [YARD Documentation](https://rubydoc.info/gems/iron_lion_uuid)

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/yourusername/iron_lion_uuid.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
