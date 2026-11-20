# Postgres back end: internals

Read this before changing `lib/iron_lion/postgres.rb`, `lib/iron_lion/postgres/helpers.sql`
or the `:postgres` specs. README.md § Postgres and § Guarantees describe the behaviour
users see; this file covers how it is built and what is settled.

## Pieces

- `lib/iron_lion/postgres/helpers.sql` holds static helper functions that don't depend on
  the format.
- `IronLion::Postgres` (`lib/iron_lion/postgres.rb`) generates the rest from the format:
  the `iron_lion_uuid(...)` function and the generic `iron_lion_assign_id()` trigger
  function.
- One trigger function serves every table. Each table's trigger passes the model number
  and the id column as trigger arguments.

## Value resolution in SQL

- The trigger reads the inserted row as jsonb, using the same column conventions as the
  Ruby `Resolver`. An integer `iron_lion_model` column overrides the trigger's model number.
- `iron_lion.<field>` settings take the place of `ENV["IRON_LION_<FIELD>"]`.
- STI subclasses are numbered by their `base_class` in both back ends.

## Counter (settled)

The counter is the shared `iron_lion_seq` sequence modulo 2^bits, and it **stays
lock-free**. Ids are unique while fewer than 2^bits are made per millisecond, and sorted
by millisecond, but in arbitrary order within one. Only Ruby is strictly increasing, and
only within one process. An explicit `created_at` takes random counter bits in both back
ends.

## Scope

Postgres only. Other databases use Ruby generation. ActiveRecord leaves a nil id to the
database and reads it back with `RETURNING`.

## Specs

`:postgres` examples (and `:active_record` ones, for the installer) each run in a
transaction that is rolled back, with their own schema, so they can run in any order.
