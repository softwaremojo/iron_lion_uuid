# frozen_string_literal: true

require_relative "lib/iron_lion/version"

Gem::Specification.new do |spec|
  spec.name = "iron_lion_uuid"
  spec.version = IronLion::VERSION
  spec.authors = ["Software Mojo"]
  spec.email = ["sauce@softwaremojo.com"]

  spec.summary = "Time-sortable UUIDv8s that carry the information you need to debug them"

  spec.description = <<~DESCRIPTION
    IronLion generates UUIDv8 identifiers whose bits encode the facts a
    developer needs when supporting users: when the record was created,
    which model it belongs to, which node minted it, which tenant owns it.
    Configure one format for your organisation, then decode any id back
    into those fields.
  DESCRIPTION

  spec.homepage = "https://github.com/softwaremojo/iron_lion_uuid"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["rubygems_mfa_required"] = "true"
  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) ||
        f.match(%r{\A(?:(?:bin|test|spec|features|rubocop)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end

  spec.require_paths = ["lib"]
end
