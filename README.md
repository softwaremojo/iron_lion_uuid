# IronLionUUID

**IronLionUUID** is a robust, database-native UUID generation library designed to provide v8 UUIDs with unparalleled flexibility, performance, and ease of use. It enables the creation of customized UUIDs by combining components such as time, sequence, randomness, and user-defined parameters. It is compatible with PostgreSQL, MySQL, and SQLite, with fallback support for Ruby-based UUID generation.

Features
 * Modular Component System: Easily define custom UUID structures using reusable components.
 * Database-Native: Leverages native database functions for optimal performance.
 * Dynamic Configuration: Supports time, sequence, randomness, environment variables, and custom parameters in UUID generation.
 * Cross-Database Compatibility: Works seamlessly with PostgreSQL, MySQL, and SQLite.
 * Ruby Fallback: Provides a pure Ruby implementation when native database functions are unavailable.
 * Compliant with v8 UUID Specification: Guarantees efficient and unique identifier generation.

## Installation

Add this line to your application's Gemfile:
```ruby
gem 'iron_lion_uuid'
```

And then execute:
```sh
bundle install
```

Or install it yourself with:
```sh
gem install iron_lion_uuid
```

## Getting Started

### 1. Define Your Components

Components define the building blocks of your UUID. **IronLionUUID** comes with several prebuilt components:
 * Time: Encodes a high-resolution timestamp.
 * Sequence: Uses database-native sequences to ensure uniqueness.
 * Random: Adds random bits for entropy.
 * Environment Variables (Envar): Encodes values from system environment variables.
 * Parameter: Accepts user-provided strings and converts them to base36 integers.

Example:
```ruby
require 'iron_lion_uuid'

uuid_index = IronLionUUID::Index.new

uuid_index << IronLionUUID::Component::Time.new(bits: 32)
uuid_index << IronLionUUID::Component::Sequence.new(bits: 16)
uuid_index << IronLionUUID::Component::Random.new(bits: 74)
```

### 2. Rationalize Bit Allocation

Ensure all components fit within the 122-bit limit:
```ruby
uuid_index.rationalize!
```

### 3. Generate a UUID

Generate a UUID by combining the defined components:
```ruby
uuid = IronLionUUID.generate
puts uuid # Outputs a valid UUID
```

To pass a string parameter for inclusion in the UUID:
```ruby
uuid = IronLionUUID.generate("my_custom_param")
puts uuid # Outputs a UUID that incorporates the parameter
```
## Database Support

**IronLionUUID** provides out-of-the-box SQL for the following databases:

### PostgreSQL
```sql
CREATE OR REPLACE FUNCTION iron_lion_uuid()
RETURNS UUID AS $$
DECLARE
  index     BIT(122);
  iron_lion BIT(128);
BEGIN
  -- UUID generation logic here
  RETURN encode(decode(to_hex(iron_lion), 'hex'), 'hex')::UUID;
END;
$$ LANGUAGE plpgsql;
```

### MySQL

Uses AUTO_INCREMENT for sequences and custom SQL for UUID generation.

### SQLite

Includes logic to use sqlite_sequence for sequence-based components.

## Components

Prebuilt Components
  • Time: Encodes the current timestamp in nanoseconds.
  • Sequence: Uses database-native sequences for guaranteed uniqueness.
  • Random: Generates a random integer within the allocated bits.
  • Envar: Retrieves values from environment variables and encodes them.
  • Parameter: Accepts user-provided strings, converts them to base36 integers, and incorporates them into the UUID.

### Creating Custom Components

You can create custom components by subclassing IronLionUUID::Component::Base:
```ruby
class CustomComponent < IronLionUUID::Component::Base
  def value
    # Custom logic here
  end
end
```

Add it to your UUID definition:
```ruby
uuid_index << CustomComponent.new(bits: 20)
```

## Advanced Usage

### SQL Dependency Generation

Retrieve the SQL dependencies required for your UUID:
```ruby
puts uuid_index.sql_dependencies(:postgresql)
```

### SQL Value Generation

Get the SQL for the UUID’s components:
```ruby
puts uuid_index.sql_values(:postgresql)
```

### Ruby Fallback

When database-native functions are unavailable, **IronLionUUID** automatically falls back to a Ruby implementation.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/pbernays/iron_lion_uuid. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/pbernays/iron_lion_uuid/blob/main/CODE_OF_CONDUCT.md).

## Code of Conduct

Everyone interacting in the **IronLionUUID** project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/iron_lion_uuid/blob/main/CODE_OF_CONDUCT.md).

### Running Tests

Install dependencies and run the test suite:
```sh
bundle exec rspec
```

## License

This gem is available as open source under the terms of the [BSD License](https://github.com/pbernays/iron_lion_uuid/blob/main/LICENSE.txt).

## Acknowledgments

**IronLionUUID** was inspired by the need for high-performance, customizable UUIDs in database-heavy applications. Special thanks to the open-source community for providing tools and inspiration that made this project possible.
