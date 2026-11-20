# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- Time-sortable UUIDv8 ids whose payload encodes the facts a support developer
  needs: creation time plus fields you declare, such as model, tenant and node.
- One format per organisation, declared with `IronLion.configure` in a
  name-first DSL (`tenant bits: 20`). Field kinds: values, counters, random
  bits, alphanumeric text (`chars:`), and H3 (`h3:`) and geohash (`geohash:`)
  locations.
- Values resolve from an explicit argument, then the record, then a `from:`
  resolver, then `ENV["IRON_LION_<FIELD>"]`.
- `IronLion.parse` and `IronLion::Id`, which read every field back and find the
  id's record.
- Postgres generation: `iron_lion_uuid(...)` and an insert trigger mint the
  same ids as Ruby.
- Rails integration: an install generator, triggers that reinstall themselves
  after migrations and schema loads, and model numbers kept in
  `config/iron_lion.yml`.
- Every error IronLion raises is an `IronLion::Error`.
