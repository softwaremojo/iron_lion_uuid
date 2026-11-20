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
- `lib/iron_lion/postgres.rb` + `postgres/helpers.sql`: SQL generation for Postgres
- `lib/iron_lion/layout.rb`: bit placement around the version/variant bits, string forms
- `lib/iron_lion/resolver.rb`: value resolution chain
- `lib/iron_lion/clock.rb`: monotonic (ms, sequence) pairs
- `lib/iron_lion/model_table.rb`: append-only model-number table (YAML)
- `lib/iron_lion/id.rb`: the id value object (`#record` finds its row)
- `lib/iron_lion/installer.rb`: installs functions + triggers through an ActiveRecord connection
- `lib/iron_lion/railtie.rb`, `tasks/iron_lion.rake`, `lib/generators/iron_lion/`: Rails integration

## Commands

```bash
bundle exec rake      # specs + RuboCop (default task)
bundle exec rspec
bundle exec rubocop
```

`.envrc` exports `IRON_LION_NODE=53` for local experiments. The spec suite
clears all `IRON_LION_*` variables around each example.

Postgres specs (tagged `:postgres`, and `:active_record` for the installer) run against `IRON_LION_TEST_DATABASE_URL`
(default `postgres:///iron_lion_test`), each in a rolled-back transaction with its
own schema, and are skipped without a database. Locally, Homebrew's
`postgresql@17` is running but keg-only: its binaries are in
`/opt/homebrew/opt/postgresql@17/bin`.

## Roadmap

1. Ruby core, including text and spatial kinds: done.
2. Postgres generation (`IronLion::Postgres`): done. Static helpers live in
   `lib/iron_lion/postgres/helpers.sql`; the `iron_lion_uuid(...)` function and
   the generic `iron_lion_assign_id()` trigger function are generated from the
   format. The trigger reads the row as jsonb using the Ruby resolver's column
   conventions; the model number and id column are trigger arguments.
   `iron_lion.<field>` settings play the role of ENV. ActiveRecord leaves a nil
   id to the database and reads it back with `RETURNING`. Postgres only; other
   databases fall back to Ruby generation.
3. Rails integration: done. `IronLion::Railtie` points the default model table at
   `config/iron_lion.yml` (assigning only when `Rails.env.local?`) and prepends
   `IronLion::DatabaseTasks` to ActiveRecord's DatabaseTasks so `migrate` and
   `load_schema` rerun `IronLion::Installer`. The installer triggers every
   model table whose primary key is a uuid with no default. The generator
   (`lib/generators/iron_lion/`) writes the initializer and `config/iron_lion.yml`.
   `Id#record` / `IronLion.find` fetch an id's row through its model field.
4. Rust crate (H3 via `h3o`) sharing a test-vector suite with Ruby and SQL.

License: MIT.

To check the Rails integration end to end, generate a throwaway app outside the
repo (`rails new … --minimal --database=postgresql`). Add this gem by `path:`,
then run the generator, a migration and `bin/rails test`. The suite covers
everything except the Railtie, the generator and the schema-load hook.

## Agent skills

### Issue tracker

Issues live in GitHub Issues for softwaremojo/iron_lion_uuid, via the gh CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

The five default labels: needs-triage, needs-info, ready-for-agent, ready-for-human, wontfix. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `GLOSSARY.md` and `docs/adr/` at the repo root, created lazily. See `docs/agents/domain.md`.
