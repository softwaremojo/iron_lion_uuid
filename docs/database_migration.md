# Database Migration Guide

This guide covers how to set up your database to work with IronLionUUID and how to migrate from standard UUIDs to the customized IronLionUUID format.

## Table of Contents

1. [Database Setup](#database-setup)
   - [PostgreSQL Setup](#postgresql-setup)
   - [MySQL Setup](#mysql-setup)
   - [SQLite Setup](#sqlite-setup)
2. [Migrating from Standard UUIDs](#migrating-from-standard-uuids)
   - [Step 1: Add IronLionUUID to Your Application](#step-1-add-ironlionuuid-to-your-application)
   - [Step 2: Update Your Models](#step-2-update-your-models)
   - [Step 3: Migrate Existing Records](#step-3-migrate-existing-records)
3. [Using UUID Arrays](#using-uuid-arrays)
4. [Foreign Key Constraints](#foreign-key-constraints)
5. [Performance Considerations](#performance-considerations)
6. [Database-Specific Troubleshooting](#database-specific-troubleshooting)

## Database Setup

### PostgreSQL Setup

PostgreSQL has native UUID support, making it the ideal choice for IronLionUUID.

1. Ensure the `uuid-ossp` extension is installed:

```sql
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
```

In a Rails migration:

```ruby
class EnableUuidExtension < ActiveRecord::Migration[7.0]
  def change
    enable_extension 'uuid-ossp'
  end
end
```

2. Create tables with UUID primary keys:

```sql
CREATE TABLE products (
  id UUID PRIMARY KEY,
  name TEXT,
  created_at TIMESTAMP
);
```

In a Rails migration:

```ruby
class CreateProducts < ActiveRecord::Migration[7.0]
  def change
    create_table :products, id: :uuid do |t|
      t.string :name
      t.timestamps
    end
  end
end
```

3. Install the IronLionUUID function:

Using the Rails generator:

```bash
rails generate iron_lion_uuid:install
```

Or manually:

```ruby
# Generate the SQL
sql = IronLionUUID.generate_sql(:postgresql)

# Execute the SQL
ActiveRecord::Base.connection.execute(sql)
```

4. Set the function as a default value:

```sql
ALTER TABLE products 
ALTER COLUMN id SET DEFAULT generate_iron_lion_uuid(1);
```

In a Rails migration:

```ruby
class AddDefaultUuidToProducts < ActiveRecord::Migration[7.0]
  def up
    execute "ALTER TABLE products ALTER COLUMN id SET DEFAULT generate_iron_lion_uuid(1)"
  end
  
  def down
    execute "ALTER TABLE products ALTER COLUMN id DROP DEFAULT"
  end
end
```

### MySQL Setup

MySQL doesn't have a native UUID type, but UUIDs can be stored as CHAR(36) or BINARY(16).

1. Create tables with UUID columns:

```sql
-- String format (more readable)
CREATE TABLE products (
  id CHAR(36) PRIMARY KEY,
  name VARCHAR(255),
  created_at TIMESTAMP
);

-- Binary format (more efficient)
CREATE TABLE products_binary (
  id BINARY(16) PRIMARY KEY,
  name VARCHAR(255),
  created_at TIMESTAMP
);
```

In a Rails migration:

```ruby
class CreateProducts < ActiveRecord::Migration[7.0]
  def change
    # For string format
    create_table :products, id: false do |t|
      t.string :id, limit: 36, primary_key: true
      t.string :name
      t.timestamps
    end
    
    # OR for binary format
    create_table :products_binary, id: false do |t|
      t.binary :id, limit: 16, primary_key: true
      t.string :name
      t.timestamps
    end
  end
end
```

2. Install the IronLionUUID function:

Using the Rails generator:

```bash
# For string output
rails generate iron_lion_uuid:install

# For binary output
rails generate iron_lion_uuid:install --binary_output
```

Or manually:

```ruby
# Generate the SQL for string output
sql = IronLionUUID.generate_sql(:mysql)

# OR for binary output
sql = IronLionUUID.generate_sql(:mysql, binary_output: true)

# Execute the SQL
ActiveRecord::Base.connection.execute(sql)
```

3. Set the function as a default value (MySQL 8.0+):

```sql
-- For string format
ALTER TABLE products
ALTER COLUMN id SET DEFAULT (generate_iron_lion_uuid(1));

-- For binary format
ALTER TABLE products_binary
ALTER COLUMN id SET DEFAULT (generate_iron_lion_uuid_bin(1));
```

In a Rails migration (MySQL 8.0+):

```ruby
class AddDefaultUuidToProducts < ActiveRecord::Migration[7.0]
  def up
    execute "ALTER TABLE products ALTER COLUMN id SET DEFAULT (generate_iron_lion_uuid(1))"
  end
  
  def down
    execute "ALTER TABLE products ALTER COLUMN id DROP DEFAULT"
  end
end
```

For earlier MySQL versions, you'll need to set the UUID in your application code before saving.

### SQLite Setup

SQLite also doesn't have a native UUID type. UUIDs are stored as TEXT.

1. Create tables with UUID columns:

```sql
CREATE TABLE products (
  id TEXT PRIMARY KEY,
  name TEXT,
  created_at TIMESTAMP
);
```

In a Rails migration:

```ruby
class CreateProducts < ActiveRecord::Migration[7.0]
  def change
    create_table :products, id: false do |t|
      t.string :id, primary_key: true
      t.string :name
      t.timestamps
    end
  end
end
```

2. Install the IronLionUUID function:

Using the Rails generator:

```bash
rails generate iron_lion_uuid:install
```

Or manually:

```ruby
# Generate the SQL
sql = IronLionUUID.generate_sql(:sqlite)

# Execute the SQL
ActiveRecord::Base.connection.execute(sql)
```

3. Set the function as a default value:

```sql
CREATE TABLE products (
  id TEXT PRIMARY KEY DEFAULT (generate_iron_lion_uuid(1)),
  name TEXT,
  created_at TIMESTAMP
);
```

In a Rails migration:

```ruby
class CreateProducts < ActiveRecord::Migration[7.0]
  def change
    create_table :products, id: false do |t|
      t.string :id, primary_key: true, default: -> { "generate_iron_lion_uuid(1)" }
      t.string :name
      t.timestamps
    end
  end
end
```

## Migrating from Standard UUIDs

If you're already using standard UUIDs and want to migrate to IronLionUUID, follow these steps:

### Step 1: Add IronLionUUID to Your Application

1. Add the gem to your Gemfile and run `bundle install`
2. Configure IronLionUUID to match your needs
3. Install the database functions

```ruby
# In config/initializers/iron_lion_uuid.rb
IronLionUUID.configure do |uuid|
  uuid.parameter bits: 16, name: :model
  uuid.timestamp bits: 36, precision: :millisecond
  uuid.random bits: 32
end
```

```bash
rails generate iron_lion_uuid:install
rails db:migrate
```

### Step 2: Update Your Models

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

### Step 3: Migrate Existing Records (Optional)

If you want to convert existing UUIDs to the IronLionUUID format, you can create a migration:

```ruby
class MigrateToIronLionUuid < ActiveRecord::Migration[7.0]
  def up
    # For each record, generate a new IronLionUUID and update the ID
    Product.find_each do |product|
      # Remember old ID for updating relationships
      old_id = product.id
      
      # Generate new ID
      new_id = IronLionUUID.generate(1) # 1 is the model code for Product
      
      # Update directly in the database to bypass validations
      Product.where(id: old_id).update_all(id: new_id)
      
      # Update any relationships that reference this ID
      OrderItem.where(product_id: old_id).update_all(product_id: new_id)
    end
  end
  
  def down
    # Migrating back to standard UUIDs is generally not needed
    # but you could implement it here if necessary
  end
end
```

> **WARNING**: Migrating existing IDs is a high-risk operation. Always backup your database before proceeding and test thoroughly in a staging environment first.

#### Migration Strategy for Large Tables

For large tables, migrating all records at once may cause downtime. Consider a batched approach:

```ruby
class MigrateToIronLionUuidBatched < ActiveRecord::Migration[7.0]
  def up
    batch_size = 1000
    product_count = Product.count
    
    (0...product_count).step(batch_size) do |offset|
      Product.offset(offset).limit(batch_size).each do |product|
        old_id = product.id
        new_id = IronLionUUID.generate(1)
        
        Product.transaction do
          Product.where(id: old_id).update_all(id: new_id)
          OrderItem.where(product_id: old_id).update_all(product_id: new_id)
        end
      end
    end
  end
end
```

## Using UUID Arrays

If you're using PostgreSQL and need to store arrays of UUIDs:

```sql
CREATE TABLE product_collections (
  id UUID PRIMARY KEY DEFAULT generate_iron_lion_uuid(2),
  name TEXT,
  product_ids UUID[] -- Array of UUIDs
);
```

In your Rails migration:

```ruby
class CreateProductCollections < ActiveRecord::Migration[7.0]
  def change
    create_table :product_collections, id: :uuid do |t|
      t.string :name
      t.uuid :product_ids, array: true, default: []
      t.timestamps
    end
    
    execute "ALTER TABLE product_collections ALTER COLUMN id SET DEFAULT generate_iron_lion_uuid(2)"
  end
end
```

In your Rails model:

```ruby
class ProductCollection < ApplicationRecord
  include IronLionUUID::HasIronLionId
  
  before_create :set_uuid_if_nil
  
  private
  
  def set_uuid_if_nil
    self.set_uuid_if_nil(2) # 2 is the model code for ProductCollection
  end
  
  # Helper to add a product to the collection
  def add_product(product)
    self.product_ids = (product_ids || []) + [product.id]
    save
  end
end
```