# Rails Integration Guide

This guide provides detailed instructions for integrating IronLionUUID with Ruby on Rails applications.

## Table of Contents

1. [Installation](#installation)
2. [Configuration](#configuration)
3. [Database Setup](#database-setup)
4. [Model Integration](#model-integration)
5. [Generating Database Functions](#generating-database-functions)
6. [Custom Type Registration](#custom-type-registration)
7. [Associations](#associations)
8. [Using UUIDs as Default Values](#using-uuids-as-default-values)
9. [Bulk Operations](#bulk-operations)
10. [Troubleshooting](#troubleshooting)

## Installation

Add IronLionUUID to your Gemfile:

```ruby
gem 'iron_lion_uuid'
```

And then execute:

```bash
$ bundle install
```

## Configuration

Create an initializer in `config/initializers/iron_lion_uuid.rb`:

```ruby
IronLionUUID.configure do |uuid|
  # Model type parameter (16 bits = 65,536 possible models)
  uuid.parameter bits: 16, name: :model

  # Server/node ID from environment (8 bits = 256 possible servers)
  uuid.env bits: 8, name: :node, key: :NODE_ID if ENV['NODE_ID']

  # Timestamp at millisecond precision (36 bits = ~2,200 years of milliseconds)
  uuid.timestamp bits: 36, precision: :millisecond, name: :created_at

  # Sequence counter for uniqueness within the same millisecond (16 bits = 65,536 values)
  uuid.sequence bits: 16, name: :seq

  # The remaining bits will be automatically filled with random data
end
```

## Database Setup

### PostgreSQL

PostgreSQL has native UUID support:

```ruby
# In a migration
create_table :products, id: :uuid do |t|
  t.string :name
  t.timestamps
end
```

Ensure the `uuid-ossp` extension is installed:

```ruby
# In a migration
enable_extension 'uuid-ossp'
```

### MySQL

MySQL doesn't have a native UUID type, so use a string column:

```ruby
# In a migration
create_table :products, id: false do |t|
  t.string :id, limit: 36, primary_key: true
  t.string :name
  t.timestamps
end
```

For improved performance, you can use BINARY(16) instead:

```ruby
# In a migration
create_table :products, id: false do |t|
  t.binary :id, limit: 16, primary_key: true
  t.string :name
  t.timestamps
end
```

### SQLite

SQLite also uses string columns for UUIDs:

```ruby
# In a migration
create_table :products, id: false do |t|
  t.string :id, primary_key: true
  t.string :name
  t.timestamps
end
```

## Model Integration

Include the `HasIronLionId` concern in your models:

```ruby
class Product < ApplicationRecord
  include IronLionUUID::HasIronLionId

  before_create :set_uuid_if_nil

  private

  def set_uuid_if_nil
    self.set_uuid_if_nil(1) # 1 is the model code for Product
  end
end
```

This automatically:

1. Sets up type casting for UUID columns
2. Provides helper methods for generating and setting UUIDs

### Helper Methods

The `HasIronLionId` concern provides the following methods:

- `generate_uuid(*args)` - Class method to generate a new UUID for this model
- `set_uuid(*args)` - Instance method to set a new UUID (overwrites existing UUID)
- `set_uuid_if_nil(*args)` - Instance method to set a UUID only if not already present

### Model Parameter Codes

It's good practice to define constants for your model codes:

```ruby
# In an initializer
module ModelCodes
  USER = 1
  PRODUCT = 2
  ORDER = 3
  # ...
end

# In your models
class User < ApplicationRecord
  include IronLionUUID::HasIronLionId

  before_create :set_uuid_if_nil

  private

  def set_uuid_if_nil
    self.set_uuid_if_nil(ModelCodes::USER)
  end
end
```

## Generating Database Functions

Generate database functions that match your Ruby configuration:

```bash
bin/rails generate iron_lion_uuid:install
```

This creates a migration to add the appropriate functions to your database.

### Options

- `--databases=primary,analytics` - Install for multiple database connections
- `--dialect=postgresql` - Override the detected database dialect
- `--binary-output` - For MySQL, generate a function that returns BINARY(16) instead of CHAR(36)

### Multiple Databases

If your Rails application uses multiple databases:

```bash
bin/rails generate iron_lion_uuid:install --databases=primary,analytics
```

This will create separate migrations for each database.

## Custom Type Registration

The IronLionUUID type is automatically registered with ActiveRecord as `:iron_lion_uuid`. You can use this type directly:

```ruby
class Product < ApplicationRecord
  attribute :id, :iron_lion_uuid
end
```

If you need to register the type with a different name:

```ruby
# In an initializer
ActiveRecord::Type.register(:custom_uuid_type, IronLionUUID::Type)

# In your model
class Product < ApplicationRecord
  attribute :id, :custom_uuid_type
end
```

## Associations

When setting up associations between models using IronLionUUIDs:

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

## Using UUIDs as Default Values

### PostgreSQL

```ruby
# In a migration
create_table :products, id: :uuid do |t|
  t.string :name
  t.timestamps
end

# Set default value to use the database function
execute "ALTER TABLE products ALTER COLUMN id SET DEFAULT generate_iron_lion_uuid(#{ModelCodes::PRODUCT})"
```

### MySQL 8.0+

```ruby
create_table :products, id: false do |t|
  t.string :id, limit: 36, primary_key: true
  t.string :name
  t.timestamps
end

# Set default value to use the database function
execute "ALTER TABLE products ALTER COLUMN id SET DEFAULT (generate_iron_lion_uuid(#{ModelCodes::PRODUCT}))"
```

### SQLite

```ruby
# In a migration
create_table :products, id: false do |t|
  t.string :id, primary_key: true, default: -> { "generate_iron_lion_uuid(#{ModelCodes::PRODUCT})" }
  t.string :name
  t.timestamps
end
```

## Bulk Operations

For large-scale operations, generating UUIDs in the database can be more efficient:

### PostgreSQL Bulk Insert

```ruby
products = [
  { name: "Product 1" },
  { name: "Product 2" },
  # ...
]

sql = <<~SQL
  INSERT INTO products (id, name, created_at, updated_at)
  VALUES #{products.map { |p| "(generate_iron_lion_uuid(#{ModelCodes::PRODUCT}), '#{p[:name]}', NOW(), NOW())" }.join(", ")}
SQL

ActiveRecord::Base.connection.execute(sql)
```

### MySQL Bulk Insert

```ruby
products = [
  { name: "Product 1" },
  { name: "Product 2" },
  # ...
]

sql = <<~SQL
  INSERT INTO products (id, name, created_at, updated_at)
  VALUES #{products.map { |p| "(generate_iron_lion_uuid(#{ModelCodes::PRODUCT}), '#{p[:name]}', NOW(), NOW())" }.join(", ")}
SQL

ActiveRecord::Base.connection.execute(sql)
```

## Troubleshooting

### Missing UUID Extension in PostgreSQL

If you see the error:

```
PG::UndefinedFunction: ERROR: function uuid_generate_v4() does not exist
```

Ensure the `uuid-ossp` extension is installed:

```ruby
# In a migration
enable_extension 'uuid-ossp'
```

### DELIMITER Syntax Error in MySQL

If you see an error about DELIMITER syntax:

```
Mysql2::Error: You have an error in your SQL syntax; check the manual that corresponds to your MySQL server version for the right syntax to use near 'DELIMITER //' at line 1
```

When executing the function creation SQL from Ruby, you need to remove the DELIMITER statements. The `iron_lion_uuid:install` generator handles this automatically.

### Database Function Not Found

If you get an error that the `generate_iron_lion_uuid` function doesn't exist:

1. Make sure you've run the generator and migrations:
   ```bash
   bin/rails generate iron_lion_uuid:install
   bin/rails db:migrate
   ```

2. Check that the function was created in the correct database:
   ```sql
   -- PostgreSQL
   SELECT proname FROM pg_proc WHERE proname = 'generate_iron_lion_uuid';

   -- MySQL
   SHOW FUNCTION STATUS WHERE Name = 'generate_iron_lion_uuid';

   -- SQLite
   SELECT name FROM sqlite_master WHERE type = 'function' AND name = 'generate_iron_lion_uuid';
   ```

### Invalid UUID Format

If you see errors about invalid UUID format, ensure your database columns are the correct type:

- PostgreSQL: `uuid`
- MySQL: `varchar(36)` or `binary(16)`
- SQLite: `text`

### Timestamp Precision Warning

If you see a warning about timestamp precision:

```
IronLionUUID::TimestampPrecisionWarning: Requested timestamp precision 'nanosecond' exceeds system capability 'microsecond'
```

Your system may not support the requested precision. Consider using a lower precision:

```ruby
uuid.timestamp bits: 36, precision: :microsecond, name: :created_at
```

## Advanced Topics

### Extracting Data from Existing UUIDs

You can extract embedded data from any valid IronLionUUID:

```ruby
uuid = IronLionUUID.from_string("a0b72d14-8c21-8ce2-9012-ff3a35b81401")

puts uuid.model        # => model code
puts uuid.created_at   # => timestamp in configured precision
puts uuid.seq          # => sequence number
```

### Adding Custom Attributes

You can extend the library with custom attribute types by subclassing `IronLionUUID::Attribute`:

```ruby
module IronLionUUID
  class CustomAttribute < Attribute
    def initialize(options = {})
      super(:custom, options[:bits], options)
    end

    def generate_value(*args)
      # Custom logic here
    end
  end

  class Configuration
    def custom(options = {})
      validate_options!(options, [:bits, :name])
      attribute = CustomAttribute.new(options)
      add_attribute(attribute)
      attribute
    end
  end
end
```

### Testing with IronLionUUIDs

In your test environment, you might want to make UUID generation deterministic:

```ruby
# In spec/support/iron_lion_uuid_helper.rb
module IronLionUUIDHelper
  def stub_uuid_generation
    allow_any_instance_of(IronLionUUID::RandomAttribute).to receive(:generate_value).and_return(0)
    allow_any_instance_of(IronLionUUID::TimestampAttribute).to receive(:generate_value).and_return(1685473562789)
    allow_any_instance_of(IronLionUUID::SequenceAttribute).to receive(:generate_value).and_return(1)
  end
end

RSpec.configure do |config|
  config.include IronLionUUIDHelper
end

# In your tests
before do
  stub_uuid_generation
end
```

## Performance Considerations

UUIDs are generally larger than integer IDs, which can impact performance:

1. **Index Size**: UUID indexes require more storage than integer indexes
2. **JOIN Performance**: Joining on UUIDs is typically slower than joining on integers
3. **Storage Space**: UUIDs use more space per row

To mitigate these issues:

1. Ensure proper indexing on UUID columns
2. Consider using binary UUID storage in MySQL
3. For analytics-heavy applications, you might want to maintain a secondary integer ID for faster joins
