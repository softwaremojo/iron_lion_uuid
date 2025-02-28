# frozen_string_literal: true

require_relative "lib/iron_lion_uuid/version"

Gem::Specification.new do |spec|
  spec.name          = "iron_lion_uuid"
  spec.version       = IronLionUUID::VERSION
  spec.authors       = [ "Sauce Bernays" ]
  spec.email         = [ "sauce@softwaremojo.com" ]

  spec.summary       = "Customizable UUID v8 identifiers with database integration"
  spec.description   = "IronLionUUID is a Ruby library that generates customizable " \
                       "UUID v8 ids with both pure Ruby and database function " \
                       "(PostgreSQL, MySQL, SQLite) implementations. The library " \
                       "allows developers to customize the bit structure of UUIDs " \
                       "while maintaining RFC compliance."
  spec.homepage      = "https://github.com/yourusername/iron_lion_uuid"
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 3.3.0")

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.glob("{lib}/**/*") + [ "LICENSE.txt", "README.md" ]
  spec.require_paths = [ "lib" ]

  # Runtime dependencies
  spec.add_dependency "concurrent-ruby", "~> 1.2"
  spec.add_dependency "dry-inflector", "~> 1"
end
