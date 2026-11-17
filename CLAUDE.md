# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this is

IronLion (gem `iron_lion_uuid`, namespace `IronLion`) generates time-sortable
UUIDv8s whose payload encodes facts a support developer needs: creation time,
model, node, tenant, and so on. The readers are developers debugging and app
code, not SQL. See README.md for the public API.

## Design commitments

- **One format per organisation**, set with `IronLion.configure`. `parse` never
  guesses: it uses the configured format, or one passed as `format:` for debugging.
- **Always time-sortable.** A single time field leads every format (implied
  `created_at`, 48 bits of milliseconds).
- **Name-first DSL** (`tenant bits: 20`). The keyword gives the kind (`bits:` value,
  `time:`, `counter:`, `random:`), or a self-sizing kind declared by precision:
  `chars:` (alphanumeric text, bijective base 36), `h3:` (resolution; stores
  base cell + digits) and `geohash:` (characters; interleaved lat/lon bits). Built-in names: `created_at`, `sequence`,
  `random`, `model`.
- **Infer from the environment; minimise programmer input.** Values resolve
  from an explicit argument, then the record, then a `from:` resolver, then
  `ENV["IRON_LION_<FIELD>"]`.
- **API polish matters most.** Errors explain what was expected and where
  IronLion looked.
- **A format is data.** `Format#to_h` is the spec that future back ends consume:
  a generated Postgres function, and a Rust crate for high-volume generation
  (such as a game ECS). Rust replaced the earlier Crystal plan.

## Layout

- `lib/iron_lion.rb`: module API (`configure`, `define`, `generate`, `parse`)
- `lib/iron_lion/declaration.rb`: DSL line parsing and whole-format arrangement
- `lib/iron_lion/builder.rb`: BasicObject DSL receiver
- `lib/iron_lion/format.rb`: generation and decoding
- `lib/iron_lion/base36.rb`: string <-> integer packing for `chars:` fields
- `lib/iron_lion/h3.rb`: H3 cell <-> compact bits for `h3:` fields
- `lib/iron_lion/geohash.rb`: coordinates/geohash <-> bits, and `Location`, for `geohash:` fields
- `lib/iron_lion/layout.rb`: bit placement around the version/variant bits, string forms
- `lib/iron_lion/resolver.rb`: value resolution chain
- `lib/iron_lion/clock.rb`: monotonic (ms, sequence) pairs
- `lib/iron_lion/model_table.rb`: append-only model-number table (YAML)
- `lib/iron_lion/id.rb`: the id value object

## Commands

```bash
bundle exec rake      # specs + RuboCop (default task)
bundle exec rspec
bundle exec rubocop
```

`.envrc` exports `IRON_LION_NODE=53` for local experiments. The spec suite
clears all `IRON_LION_*` variables around each example.

## Roadmap

1. Ruby core, including text and spatial kinds: done.
2. Postgres generation from `Format#to_h`: one shared sequence feeding the
   counter, an `iron_lion_uuid(...)` function with the same bit packing as Ruby,
   and a `BEFORE INSERT` trigger per table that fills a NULL id from the row's
   own columns (same naming conventions as the Ruby resolver). The model number
   is fixed in each table's trigger, and `node` comes from a database setting
   (`iron_lion.node`). ActiveRecord leaves a nil id out of the INSERT and reads
   it back with `RETURNING`, so the database assigns ids in Rails. Postgres only
   for now; other databases fall back to Ruby generation.
3. Rails integration: `rails g iron_lion:install` migration, the model table at
   `config/iron_lion.yml` (read-only in production), and `id.record` lookup.
4. Rust crate (H3 via `h3o`) sharing a test-vector suite with Ruby and SQL.

License: MIT.
