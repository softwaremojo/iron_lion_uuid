# IronLionUUID Usage Examples

This document provides comprehensive examples of how to use IronLionUUID in various scenarios.

## Table of Contents

1. [Basic Configuration](#basic-configuration)
2. [Generating UUIDs](#generating-uuids)
3. [Accessing UUID Components](#accessing-uuid-components)
4. [Rails Integration](#rails-integration)
5. [Database Functions](#database-functions)
6. [Advanced Use Cases](#advanced-use-cases)

## Basic Configuration

### Minimal Configuration

```ruby
require 'iron_lion_uuid'

IronLionUUID.configure do |uuid|
  uuid.random bits: 122 # Use all bits for random data
end

# Generate a UUID
uuid = IronLionUUID.generate
puts uuid # => "a0b72d14-8c21-8ce2-9012-ff3a35b81401"
```

### Standard Configuration with Common Attributes

```ruby
require 'iron_lion_uuid'

IronLionUUID.configure do |uuid|
  # 16 bits for model type (65,536 possible values)
  uuid.parameter bits: 16, name: :model
  
  # 36 bits for timestamp at millisecond precision
  uuid.timestamp bits: 36, precision: :millisecond, name: :created_at
  
  # 32 bits for randomness
  uuid.random bits: 32, name: :random_part
  
  # The remaining 38 bits will be auto-filled with random data
end
```

### Complete Configuration Using All Attribute Types

```ruby
require 'iron_lion_uuid'

# Set an environment variable for the node ID
ENV["NODE_ID"] = "42"

IronLionUUID.configure do |uuid|
  # 16 bits for model type
  uuid.parameter bits: 16, name: :model
  
  # 8 bits for node/server ID from environment
  uuid.env bits: 8, name: :node, key: :NODE_ID
  
  # 36 bits for timestamp at millisecond precision
  uuid.timestamp bits: 36, precision: :millisecond, name: :created_at
  
  # 16 bits for sequence counter (auto-incrementing)
  uuid.sequence bits: 16, name: :seq
  
  # 16 bits for explicit randomness
  uuid.random bits: 16, name: :random_part
  
  # The remaining 30 bits will be auto-filled with random data
end
```

## Generating UUIDs

### Basic UUID Generation

```ruby
# With the configuration from above
uuid = IronLionUUID.generate(1) # 1 is the model parameter
puts uuid # => "10b72d14-8c21-8ce2-9012-ff3a35b81401"
```

### Multiple Parameters

```ruby
# Configuration with multiple parameters
IronLionUUID.configure do |uuid|
  uuid.parameter bits: 16, name: :model
  uuid.parameter bits: 8, name: :status
  uuid.random bits: 98
end

# Generate UUID with multiple parameters
uuid = IronLionUUID.generate(1, 2) # model=1, status=2
puts uuid # => "10220000-0000-8000-9000-000000000000"
```

### Parameter Types

```ruby
# Integer parameters
uuid1 = IronLionUUID.generate(42)

# String parameters (converted from base36 to base10)
uuid2 = IronLionUUID.generate("abc")

# Mixed parameters
uuid3 = IronLionUUID.generate(1, "active")
```

## Accessing UUID Components

```ruby
# Using the configuration from "Complete Configuration" above
uuid = IronLionUUID.generate(1)

# Access embedded data through accessor methods
puts uuid.model      # => 1
puts uuid.node       # => 42
puts uuid.seq        # => 1 (first in sequence)

# Convert timestamp to Time object
timestamp_ms = uuid.created_at
time = Time.at(timestamp_ms / 1000.0)
puts time.strftime("%Y-%m-%d %H:%M:%S.%L")
```

### Parsing Existing UUIDs

```ruby
# Parse an existing UUID string
uuid_string = "10b72d14-8c21-8ce2-9012-ff3a35b81401"
uuid = IronLionUUID.from_string(uuid_string)

# Access components (if they match the current configuration)
puts uuid.model      # => 1 (assuming model is at the right position)
puts uuid.created_at # => timestamp value
```

### Comparing UUIDs

```ruby
uuid1 = IronLionUUID.generate(1)
uuid2 = IronLionUUID.generate(1)

# Equality comparison
puts uuid1 == uuid2  # => false (different UUIDs)

# Lexicographical comparison (useful for timestamps)
puts uuid1 < uuid2   # => true (if uuid1 was created earlier)
```

## Rails Integration

### Configuration in Initializer

```ruby
# config/initializers/iron_lion_uuid.rb
IronLionUUID.configure do |uuid|
  uuid.parameter bits: 16, name: :model
  uuid.timestamp bits: 36, precision: :millisecond
  uuid.random bits: 32
end

# Define model codes as constants
module ModelCodes
  USER = 1
  PRODUCT = 2
  ORDER = 3
  ORDER_ITEM = 4
end
```

### Model Integration

```ruby
# app/models/product.rb
class Product < ApplicationRecord
  include IronLionUUID::HasIronLionId
  
  has_many :order_items
  has_many :orders, through: :order_items
  
  before_create :set_uuid_if_nil
  
  private
  
  def set_uuid_if_nil
    self.set_uuid_if_nil(ModelCodes::PRODUCT)
  end
end

# app/models/order.rb
class Order < ApplicationRecord
  include IronLionUUID::HasIronLionId
  
  has_many :order_items
  has_many :products, through: :order_items
  
  before_create :set_uuid_if_nil
  
  private
  
  def set_uuid_if_nil
    self.set_uuid_if_nil(ModelCodes::ORDER)
  end
end
```

### Migration Examples

```ruby
# PostgreSQL Migration
class CreateProducts < ActiveRecord::Migration[7.0]
  def change
    enable_extension 'uuid-ossp' unless extension_enabled?('uuid-ossp')
    
    create_table :products, id: :uuid do |t|
      t.string :name
      t.decimal :price, precision: 10, scale: 2
      t.timestamps
    end
    
    execute "ALTER TABLE products ALTER COLUMN id SET DEFAULT generate_iron_lion_uuid(#{ModelCodes::PRODUCT})"
  end
end

# MySQL Migration
class CreateOrders < ActiveRecord::Migration[7.0]
  def change
    create_table :orders, id: false do |t|
      t.string :id, limit: 36, primary_key: true
      t.string :customer_name
      t.string :status
      t.timestamps
    end
    
    # For MySQL 8.0+
    execute "ALTER TABLE orders ALTER COLUMN id SET DEFAULT (generate_iron_lion_uuid(#{ModelCodes::ORDER}))"
  end
end
```

### Controller Examples

```ruby
# app/controllers/products_controller.rb
class ProductsController < ApplicationController
  def index
    @products = Product.all
    
    # Find a product by ID
    if params[:id]
      @product = Product.find(params[:id])
      # The UUID is automatically typecast by ActiveRecord
    end
  end
  
  def create
    @product = Product.new(product_params)
    # UUID will be automatically set by the before_create callback
    
    if @product.save
      redirect_to @product, notice: 'Product was successfully created.'
    else
      render :new
    end
  end
end
```

## Database Functions

### Installing Database Functions with the Generator

```bash
# Basic installation
bin/rails generate iron_lion_uuid:install

# Installation for multiple databases
bin/rails generate iron_lion_uuid:install --databases=primary,analytics

# Installation with binary output for MySQL
bin/rails generate iron_lion_uuid:install --binary_output

# Installation with a specific dialect
bin/rails generate iron_lion_uuid:install --dialect=postgresql
```

### Manually Generating and Executing SQL

```ruby
# Generate PostgreSQL function
postgresql_sql = IronLionUUID.generate_sql(:postgresql)
ActiveRecord::Base.connection.execute(postgresql_sql)

# Generate MySQL function with binary output
mysql_sql = IronLionUUID.generate_sql(:mysql, binary_output: true)
ActiveRecord::Base.connection.execute(mysql_sql)

# Generate SQLite function
sqlite_sql = IronLionUUID.generate_sql(:sqlite)
ActiveRecord::Base.connection.execute(sqlite_sql)
```

### Using Database Functions in SQL

```sql
-- PostgreSQL: Generate a UUID for model code 1
SELECT generate_iron_lion_uuid(1);

-- PostgreSQL: Insert with generated UUID
INSERT INTO products (id, name, price)
VALUES (generate_iron_lion_uuid(1), 'Test Product', 19.99);

-- MySQL: Generate a UUID for model code 2
SELECT generate_iron_lion_uuid(2);

-- MySQL: Insert with generated UUID
INSERT INTO orders (id, customer_name, status)
VALUES (generate_iron_lion_uuid(2), 'John Doe', 'pending');

-- SQLite: Generate a UUID for model code 3
SELECT generate_iron_lion_uuid(3);

-- SQLite: Insert with generated UUID
INSERT INTO order_items (id, order_id, product_id, quantity)
VALUES (generate_iron_lion_uuid(3), '...', '...', 1);
```

## Advanced Use Cases

### High-Volume ID Generation

For high-volume ID generation, using database-side generation can be more efficient:

```sql
-- PostgreSQL bulk insert
INSERT INTO products (id, name, price)
SELECT generate_iron_lion_uuid(1), 'Product ' || i, 19.99 + (i * 0.1)
FROM generate_series(1, 10000) i;

-- MySQL bulk insert
INSERT INTO products (id, name, price)
VALUES (generate_iron_lion_uuid(1), 'Product 1', 19.99),
       (generate_iron_lion_uuid(1), 'Product 2', 20.99),
       /* ... more products ... */
       (generate_iron_lion_uuid(1), 'Product 1000', 119.99);
```

### Distributed System with Node IDs

For distributed systems, you can embed the node/server ID:

```ruby
# On server deployment, set the NODE_ID environment variable
# For example, in Kubernetes ConfigMap or Docker .env file
ENV["NODE_ID"] = "42" # Unique ID for this server

IronLionUUID.configure do |uuid|
  uuid.parameter bits: 16, name: :model
  uuid.env bits: 8, name: :node, key: :NODE_ID
  uuid.timestamp bits: 36, precision: :millisecond
  uuid.random bits: 32
end

# Each server will generate UUIDs with its node ID embedded
uuid = IronLionUUID.generate(1)
puts uuid.node # => 42 (the server ID)
```

### Time-Based Querying

Since timestamps are embedded in the UUIDs, you can use them for time-based lookups:

```ruby
# Configuration with timestamp
IronLionUUID.configure do |uuid|
  uuid.parameter bits: 16, name: :model
  uuid.timestamp bits: 36, precision: :millisecond, name: :created_at
  uuid.random bits: 32
end

# Extract timestamp range from UUIDs
def find_products_created_between(start_time, end_time)
  # Convert time objects to milliseconds since epoch
  start_ms = (start_time.to_f * 1000).to_i
  end_ms = (end_time.to_f * 1000).to_i
  
  # Find all products
  products = Product.all
  
  # Filter by timestamp embedded in UUID
  products.select do |product|
    timestamp = product.id.created_at
    timestamp >= start_ms && timestamp <= end_ms
  end
end

# Example usage
start_time = Time.new(2023, 1, 1)
end_time = Time.new(2023, 2, 1)
january_products = find_products_created_between(start_time, end_time)
```

### Custom Attribute Type

You can extend IronLionUUID with custom attribute types:

```ruby
module IronLionUUID
  # Custom attribute for embedding a geographic region
  class RegionAttribute < Attribute
    REGIONS = {
      north_america: 1,
      south_america: 2,
      europe: 3,
      asia: 4,
      africa: 5,
      oceania: 6
    }
    
    def initialize(options = {})
      super(:region, options[:bits], options)
    end
    
    def generate_value(*_args)
      # Get region from environment or configuration
      region_name = ENV["REGION"]&.to_sym || options[:default]&.to_sym || :north_america
      
      # Convert to integer code
      region_code = REGIONS[region_name] || REGIONS[:north_america]
      
      # Validate the value
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

# Usage
IronLionUUID.configure do |uuid|
  uuid.parameter bits: 16, name: :model
  uuid.region bits: 4, name: :region, default: :europe
  uuid.timestamp bits: 36, precision: :millisecond
  uuid.random bits: 32
end

uuid = IronLionUUID.generate(1)
puts uuid.region # => 3 (Europe)
```

### Testing with Mocked UUIDs

In your test environment, you might want deterministic UUIDs:

```ruby
# spec/support/iron_lion_uuid_helper.rb
module IronLionUUIDHelper
  def stub_uuid_generation(model_code)
    allow(SecureRandom).to receive(:random_bytes).and_return("\x00" * 16)
    allow(Time).to receive(:now).and_return(Time.new(2023, 1, 1, 12, 0, 0))
    allow_any_instance_of(IronLionUUID::SequenceAttribute).to receive(:generate_value).and_return(1)
    
    # Generate a predictable UUID
    IronLionUUID.generate(model_code)
  end
end

RSpec.configure do |config|
  config.include IronLionUUIDHelper
end

# In your test
RSpec.describe Product, type: :model do
  it "creates a product with a UUID" do
    mock_uuid = stub_uuid_generation(ModelCodes::PRODUCT)
    
    product = Product.create(name: "Test Product")
    expect(product.id).to eq(mock_uuid)
  end
end
```

This concludes our comprehensive examples documentation. These examples should cover most common use cases for IronLionUUID.
