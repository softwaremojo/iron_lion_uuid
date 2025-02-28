# Frequently Asked Questions (FAQ)

## General Questions

### What is IronLionUUID?

IronLionUUID is a Ruby library that generates customizable UUID v8 identifiers. It allows developers to embed useful information into UUIDs while maintaining full RFC compliance. With IronLionUUID, you can include data like model type, timestamp, environment information, and sequence numbers directly in your UUIDs.

### Why use IronLionUUID instead of standard UUIDs?

Standard UUIDs are opaque identifiers - they contain random data or MAC addresses with timestamps, but this information isn't easily extractable or customizable. IronLionUUID gives you:

1. **Embedded metadata** - Extract information directly from UUIDs without database lookups
2. **Chronological sorting** - UUIDs can be naturally sorted by creation time
3. **Custom data sources** - Embed any information that's useful for your application
4. **Database-side generation** - Generate UUIDs with the same structure directly in your database
5. **Full compatibility** - Still works with all existing UUID infrastructure

### Is IronLionUUID compatible with standard UUIDs?

Yes! IronLionUUID generates standard RFC-compliant UUIDs (specifically UUID v8). They have the same format and can be used anywhere standard UUIDs are used. The difference is in the internal bit structure, which allows for embedded information.

### How much information can I embed in a UUID?

A UUID has 128 bits in total. According to the UUID specification, 6 bits are reserved for the version (4 bits) and variant (2 bits), leaving 122 configurable bits. IronLionUUID lets you define how to use these 122 bits, and it will automatically fill any unused bits with random data.

### Does using IronLionUUID affect database performance?

There should be minimal performance impact compared to standard UUIDs. The storage requirements and index size are identical to regular UUIDs. The only potential overhead is in generating the UUIDs, but this is generally negligible.

## Configuration Questions

### How do I configure the bit structure of my UUIDs?

Use the configuration DSL to define your UUID structure:

```ruby
IronLionUUID.configure do |uuid|
  uuid.parameter bits: 16, name: :model
  uuid.timestamp bits: 36, precision: :millisecond
  uuid.random bits: 32
end
```

This example allocates 16 bits for a model parameter, 36 bits for a millisecond timestamp, and 32 bits for random data. The remaining 38 bits will be automatically filled with random data.

### Can I change the configuration after it's set?

No, the configuration becomes immutable after it's initially set. This prevents inconsistencies in UUID structure. If you need to change the configuration, you must restart your application.

### What attribute types can I use in my UUIDs?

IronLionUUID supports 5 attribute types:

1. **parameter** - User-provided value at UUID generation time
2. **env** - Value from an environment variable
3. **timestamp** - Current time at configured precision
4. **random** - Random data for uniqueness
5. **sequence** - Auto-incrementing sequence number

### What happens if I don't use all 122 available bits?

Any unused bits will be automatically filled with random data to ensure uniqueness. For example, if you only configure 84 bits explicitly, the remaining 38 bits will be random.

### Can I set the position of attributes manually?

No, attribute positions are calculated automatically to ensure they don't overlap and don't interfere with the reserved version and variant bits. Attributes are positioned in the order they are defined in the configuration.

## Usage Questions

### How do I generate a UUID with parameters?

To generate a UUID with parameters, pass the parameter values to the `generate` method:

```ruby
# With a single parameter
uuid = IronLionUUID.generate(1)  # 1 is the model parameter

# With multiple parameters
uuid = IronLionUUID.generate(1, 2)  # model=1, status=2
```

The parameters must be provided in the same order they were defined in the configuration.

### How do I access the embedded data in a UUID?

IronLionUUID creates accessor methods for each named attribute:

```ruby
uuid = IronLionUUID.generate(1)

puts uuid.model            # => 1
puts uuid.created_at       # => 1682625842123
puts uuid.random_part      # => 1234567890
```

These accessor methods are generated dynamically based on your configuration.

### Can I parse UUIDs created elsewhere?

Yes, you can parse any valid UUID string:

```ruby
uuid = IronLionUUID.from_string("10b72d14-8c21-8ce2-9012-ff3a35b81401")
```

If the UUID was generated with a different configuration, the accessor methods might return unexpected values, as the bit positions might not match. However, it will still be a valid UUID.

### How do I handle UUIDs in JSON?

UUIDs are serialized as strings in JSON:

```ruby
require 'json'

uuid = IronLionUUID.generate(1)
json = { id: uuid }.to_json
# => {"id":"10b72d14-8c21-8ce2-9012-ff3a35b81401"}
```

When deserializing, you can convert the string back to a UUID object:

```ruby
parsed = JSON.parse(json)
uuid = IronLionUUID.from_string(parsed["id"])
```

## Rails Integration Questions

### How do I use IronLionUUID with Rails?

1. Add IronLionUUID to your Gemfile
2. Create an initializer to configure the UUID structure
3. Include the `HasIronLionId` concern in your models
4. Add a `before_create` callback to set the UUID
5. Set up your database to use UUIDs
6. Optionally install database functions

See the [Rails Integration Guide](rails_integration.md) for detailed instructions.

### How do I set up my database for UUIDs?

#### PostgreSQL

```ruby
# In a migration
enable_extension 'uuid-ossp' unless extension_enabled?('uuid-ossp')

create_table :products, id: :uuid do |t|
  t.string :name
  t.timestamps
end
```

#### MySQL

```ruby
# In a migration
create_table :products, id: false do |t|
  t.string :id, limit: 36, primary_key: true
  t.string :name
  t.timestamps
end
```

#### SQLite

```ruby
# In a migration
create_table :products, id: false do |t|
  t.string :id, primary_key: true
  t.string :name
  t.timestamps
end
```

### How do I generate database functions?

Use the provided Rails generator:

```bash
bin/rails generate iron_lion_uuid:install
```

This will create a migration that adds the appropriate functions to your database. After generating the migration, run:

```bash
bin/rails db:migrate
```

### Can I use IronLionUUID with multiple databases?

Yes! You can install the database functions for multiple databases:

```bash
bin/rails generate iron_lion_uuid:install --databases=primary,analytics
```

This will create separate migrations for each database.

### How do I use UUIDs in associations?

Associations work just like with any other primary key type:

```ruby
class Order < ApplicationRecord
  include IronLionUUID::HasIronLionId
  belongs_to :product
  
  before_create :set_uuid_if_nil
  
  private
  
  def set_uuid_if_nil
    self.set_uuid_if_nil(ModelCodes::ORDER)
  end
end

class Product < ApplicationRecord
  include IronLionUUID::HasIronLionId
  has_many :orders
  
  before_create :set_uuid_if_nil
  
  private
  
  def set_uuid_if_nil
    self.set_uuid_if_nil(ModelCodes::PRODUCT)
  end
end
```

The `HasIronLionId` concern automatically handles the type casting for foreign keys.

## Troubleshooting Questions

### Why am I getting a "UUID structure not configured" error?

This error means you haven't called `IronLionUUID.configure` before generating UUIDs. Make sure you set up your configuration before calling `IronLionUUID.generate`.

### Why am I getting a "Not enough arguments" error?

This error occurs when you don't provide enough parameters when generating a UUID. If your configuration has parameter attributes, you must provide values for all of them:

```ruby
# Configuration
IronLionUUID.configure do |uuid|
  uuid.parameter bits: 16, name: :model
  uuid.parameter bits: 8, name: :status
end

# This will raise an error - missing the status parameter
uuid = IronLionUUID.generate(1)

# This is correct
uuid = IronLionUUID.generate(1, 2)
```

### Why am I getting a "Value exceeds maximum" error?

This error means you're trying to store a value that's too large for the configured bit width. For example, if you allocate 8 bits for a parameter, the maximum value is 255:

```ruby
# 8 bits = values from 0 to 255
uuid.parameter bits: 8, name: :status

# This will raise an error - 300 exceeds the maximum of 255
uuid = IronLionUUID.generate(1, 300)
```

### Why am I getting a "Missing environment variable" error?

This error occurs when you're using an environment variable attribute, but the specified environment variable isn't set:

```ruby
# Configuration
IronLionUUID.configure do |uuid|
  uuid.env bits: 8, name: :node, key: :NODE_ID
end

# This will raise an error if NODE_ID isn't set
ENV.delete("NODE_ID")
uuid = IronLionUUID.generate
```

### Why does my timestamp precision warning appear?

If you request a timestamp precision that your system can't provide, IronLionUUID will issue a warning:

```ruby
IronLionUUID.configure do |uuid|
  # If your system doesn't support nanosecond precision
  uuid.timestamp bits: 48, precision: :nanosecond
end

# You might see:
# IronLionUUID::TimestampPrecisionWarning: Requested timestamp precision 'nanosecond' exceeds system capability 'microsecond'
```

You can either accept the warning (the library will use the best precision available) or change to a lower precision.

## Advanced Questions

### How do I extend IronLionUUID with custom attribute types?

You can create custom attribute types by subclassing `IronLionUUID::Attribute` and extending the `Configuration` class:

```ruby
module IronLionUUID
  # Custom attribute for embedding a geographic region
  class RegionAttribute < Attribute
    REGIONS = { north_america: 1, europe: 2, asia: 3 }
    
    def initialize(options = {})
      super(:region, options[:bits], options)
    end
    
    def generate_value(*_args)
      region_name = ENV["REGION"]&.to_sym || options[:default]&.to_sym || :north_america
      region_code = REGIONS[region_name] || REGIONS[:north_america]
      validate_value!(region_code)
      region_code
    end
  end
  
  # Add method to Configuration class
  class Configuration
    def region(options = {})
      validate_options!(options, [:bits], [:name, :default])
      attribute = RegionAttribute.new(options)
      add_attribute(attribute)
      attribute
    end
  end
end
```

### How do I make UUID generation deterministic for testing?

In your test environment, you can mock the attribute generation methods:

```ruby
# Mock random attribute
allow_any_instance_of(IronLionUUID::RandomAttribute).to receive(:generate_value).and_return(0)

# Mock timestamp attribute
allow_any_instance_of(IronLionUUID::TimestampAttribute).to receive(:generate_value).and_return(1682625842123)

# Mock sequence attribute
allow_any_instance_of(IronLionUUID::SequenceAttribute).to receive(:generate_value).and_return(1)
```

### Is IronLionUUID thread-safe?

Yes, IronLionUUID is designed to be thread-safe. The sequence counter uses atomic operations for thread safety, and all other operations are stateless.

### Can I use IronLionUUID without Rails?

Absolutely! While IronLionUUID includes Rails integration, it works perfectly fine in any Ruby application. Just require the gem and configure it:

```ruby
require 'iron_lion_uuid'

IronLionUUID.configure do |uuid|
  uuid.parameter bits: 16, name: :model
  uuid.timestamp bits: 36, precision: :millisecond
  uuid.random bits: 32
end

uuid = IronLionUUID.generate(1)
```

### Where can I get more help?

- Check the [complete documentation](README.md)
- Visit the [GitHub repository](https://github.com/yourusername/iron_lion_uuid)
- Look at the [examples](examples.md)
- Read the [Rails Integration Guide](rails_integration.md) and [Database Migration Guide](database_migration.md)
