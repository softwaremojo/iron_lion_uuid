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

Most files in `lib/iron_lion/` are named for what they do. The ones that aren't:

- `declaration.rb`: DSL line parsing and whole-format arrangement; `builder.rb` is the
  BasicObject DSL receiver
- `layout.rb`: bit placement around the version/variant bits, and string forms
- `clock.rb`: monotonic (ms, sequence) pairs
- `model_table.rb`: append-only model-number table (YAML)
- `base36.rb`, `h3.rb`, `geohash.rb`: packing for `chars:`, `h3:` and `geohash:` fields

Before changing Postgres generation or its specs, read `docs/postgres.md`. Before
changing the Railtie, installer, `RecordIds` or generator, read `docs/rails.md`.

## Commands

```bash
bundle exec rake      # specs + RuboCop (default task)
bundle exec rspec
bundle exec rubocop
```

`.envrc` exports `IRON_LION_NODE=53` for local experiments. The spec suite
clears all `IRON_LION_*` variables around each example.

Postgres specs are tagged `:postgres` (and `:active_record` for the installer); see
README.md § Development. Locally, Homebrew's `postgresql@17` is running but keg-only:
its binaries are in `/opt/homebrew/opt/postgresql@17/bin`.

## Roadmap

Ruby core, Postgres generation and Rails integration are done. Next: a Rust crate
(H3 via `h3o`) sharing a test-vector suite with Ruby and SQL.

License: MIT.

## Agent skills

- Issues: GitHub Issues for softwaremojo/iron_lion_uuid, via the gh CLI. See `docs/agents/issue-tracker.md`.
- Triage labels: needs-triage, needs-info, ready-for-agent, ready-for-human, wontfix. See `docs/agents/triage-labels.md`.
- Domain docs: single-context, `GLOSSARY.md` and `docs/adr/` at the repo root, created lazily. See `docs/agents/domain.md`.
- Workflow: one session per `ready-for-agent` issue, coordinated by an orchestrator
  session. Sessions merge their own PR once CI is green and the orchestrator has
  checked the acceptance criteria. See `docs/agents/workflow.md`.
