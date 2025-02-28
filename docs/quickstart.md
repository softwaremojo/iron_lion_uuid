# IronLionUUID Quick Start Guide

This guide will help you get up and running with IronLionUUID quickly. For more detailed information, refer to the other documentation.

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

## Basic Usage

### Step 1: Configure UUID Structure

First, configure the structure of your UUIDs by defining what information you want to embed and how many bits to allocate for each piece of information:

```ruby
# In a Ruby script or Rails initializer
require 'iron_lion_uuid'

IronLionUUID.configure do |uuid|
  # 16 bits for model type (up to 65,536 different models)
  uuid.parameter bits: 16, name: :model
  
  # 36 bits for timestamp at millisecond precision
  uuid.timestamp bits: 36, precision: :millisecond, name: :created_at
  
  # 32 bits for randomness
  uuid.random bits: 32, name: :random_part
  
  # The remaining 38 bits will be automatically filled with random data
end
```

### Step 2: Generate UUIDs

Once configured, you can generate UUIDs:

```ruby
# Generate a UUID with model type 1 (e.g., User)
uuid = IronLionUUID.generate(1)

puts uuid                  # => "10b72d14-8c21-8ce2-9012-ff3a35b81401"
puts uuid.model            # => 1
puts uuid.created_at       # => 1682625842123 (milliseconds since epoch)
puts Time.at(uuid.created_at / 1000.0)  # => 2023-04-27 15:04:02 -0700
```

### Step 3: Parse Existing UUIDs

You can parse UUID strings back into IronLionUUID objects:

```ruby
# Parse a UUID string
parsed_uuid = IronLionUUID.from_string("10b72d14-8c21-8ce2-9012-ff3a35b81401")

# Access embedded data
puts parsed_uuid.model     # => 1
puts parsed_uuid.created_at # => 1682625842123
```

## Rails Integration

### Step 1: Configure IronLionUUID

Create an initializer in `config/initializers/iron_lion_uuid.rb`:

```ruby
IronLionUUID.configure do |uuid|
  uuid.parameter bits: 16, name: :model
  uuid.timestamp bits: 36, precision: :millisecond
  uuid.random bits: 32
end
```

### Step 2: Define Model Codes

It's helpful to define constants for your model codes:

```ruby
# In config/initializers/model_codes.rb
module ModelCodes
  USER = 1
  PRODUCT = 2
  ORDER = 3
  # ...
end
```

### Step 3: Set Up Your Models

Include the `HasIronLionId` concern in your models:

```ruby
class User < ApplicationRecord
  include IronLionUUID::HasIronLionId
  
  before_create :set_uuid_if_nil
  
  private
  
  def set_uuid_if_nil
    self.set_uuid_if_nil(ModelCodes::USER)
  end
end
```

### Step 4: Set Up Your Database

For PostgreSQL:

```ruby
# In a migration
class CreateUsers < ActiveRecord::Migration[7.0]
  def change
    enable_extension 'uuid-ossp' unless extension_enabled?('uuid-ossp')
    
    create_table :users, id: :uuid do |t|
      t.string :name
      t.string :email
      t.timestamps
    end
  end
end
```

For MySQL:

```ruby
# In a migration
class CreateUsers < ActiveRecord::Migration[7.0]
  def change
    create_table :users, id: false do |t|
      t.string :id, limit: 36, primary_key: true
      t.string :name
      t.string :email
      t.timestamps
    end
  end
end
```

### Step 5: Install Database Functions (Optional)

Generate database functions that match your Ruby configuration:

```bash
bin/rails generate iron_lion_uuid:install
bin/rails db:migrate
```

## That's It!

You've now set up IronLionUUID for your application. Your UUIDs will contain embedded information that you can extract later.

For more detailed information, check out:

- [Complete Documentation](README.md)
- [Rails Integration Guide](rails_integration.md)
- [Database Migration Guide](database_migration.md)
- [Example Usage](examples.md)
