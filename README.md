# IronLion

Time-sortable UUIDv8s that carry the facts you need to debug them.

When a user reports a problem, they hand you an id and a story that doesn't
match it. IronLion puts the facts in the id itself, so you can ask it directly:
when was this created, which model is it, which node minted it, which tenant
owns it.

```ruby
IronLion.parse("01a1e923-e9f8-8010-9cc0-10d400348597")
# => #<IronLion::Id 01a1e923-e9f8-8010-9cc0-10d400348597
#      created_at=2026-11-17 10:53:27.416 UTC tenant=4211 model=Order node=53 sequence=0>
```

## Configure once

Your organisation has one format. Declare its fields, name first:

```ruby
# config/initializers/iron_lion.rb
IronLion.configure do
  tenant   bits: 20
  model    bits: 10
  node     bits: 10
  sequence bits: 12
end
```

That is the whole format. IronLion fills in what you didn't say:

- **`created_at` comes first, always.** It is 48 bits of milliseconds unless
  you declare it yourself (`created_at bits: 44, epoch: "2026-01-01"`), so ids
  sort by creation time.
- **Leftover bits become `random`.** You never have to count to 122.
- **Line order is bit order.** Earlier fields sort before later ones.

### Field kinds

The keyword gives the kind and its value gives the width:

| Declaration | Kind | Value |
|---|---|---|
| `tenant bits: 20` | value | supplied by you, the record or the environment |
| `minted_at time: 46` | time | milliseconds since `epoch:` (default: Unix epoch) |
| `serial counter: 12` | counter | increases within a millisecond, per process |
| `salt random: 8` | random | secure random bits |
| `subdomain chars: 6` | text | an alphanumeric string of up to 6 characters |
| `cell h3: 9` | h3 | an [H3](https://h3geo.org) cell at resolution 9 |
| `spot geohash: 8` | geohash | a position, rounded to an 8-character geohash cell |

The last three size themselves from the precision you give.

**Text fields:** 5 characters take 26 bits and 6 take 32. Strings are
case-insensitive and decode in lowercase. They use bijective base 36, so
`"abc"` and `"0abc"` stay distinct. Hyphens and other punctuation are rejected.

**H3 fields** store only what varies at their resolution: the base cell plus 3
bits per level, so `h3: 7` takes 28 bits, `h3: 9` 34 and `h3: 12` 43. They take
a cell index as an integer or hex string. A finer cell is trimmed to its parent.
They decode to the cell's canonical H3 string (`"8928308280fffff"`). To store
coordinates, convert them to a cell first, for example with the `h3` gem in a
`from:` resolver.

**Geohash fields** take 5 bits per character and accept a geohash string,
`[lat, lon]`, `{lat:, lon:}` or anything that responds to
`latitude`/`longitude`, `lat`/`lng` or `lat`/`lon`. A record with its own
coordinates fills the field without being asked. They decode to an
`IronLion::Location`, the cell's centre, with `lat`, `lon`, `to_a`, the
`geohash` string and the error in each direction.

| `geohash:` | Bits | Cell size |
|---|---|---|
| 6 | 30 | 1.2 km × 0.6 km |
| 7 | 35 | 153 m × 153 m |
| 8 | 40 | 38 m × 19 m |
| 9 | 45 | 4.8 m × 4.8 m |

Some names come with built-in behaviour when declared with `bits:`:

| Name | Behaviour |
|---|---|
| `created_at` | the time field |
| `sequence` | the counter |
| `random` | random bits; also absorbs leftover bits when declared last |
| `model` | the record's class, numbered by a model table, decoded back to the class |

A format has exactly one time field, which must come first, and at most one
counter.

## Generate

```ruby
IronLion.generate(order)            # infers everything it can
IronLion.generate(model: "Order", tenant: 7)
```

Each value field takes the first answer from:

1. an explicit value, as in `generate(tenant: 7)`
2. the record: `#iron_lion_tenant`, then `#tenant_id`, then `#tenant`
   (an object with an `#id` counts as its id)
3. a resolver in the format, as in `tenant bits: 20, from: -> { Current.tenant_id }`
   (a resolver that takes an argument receives the record)
4. the environment: `ENV["IRON_LION_TENANT"]`

`nil` means "ask the next source". If nothing answers, the error lists every
place IronLion looked.

You can pass `created_at:` to backdate an id. Counter and random fields are
always generated.

## Parse

```ruby
id = IronLion.parse(params[:id])   # any case, with or without hyphens, braces or urn:uuid:
id.created_at   # => 2026-11-17 10:53:27.416 UTC
id.model        # => Order
id[:tenant]     # => 4211
id.to_h         # every field
id.to_s         # canonical string; ids also work wherever a String is expected
```

IronLion never guesses the format; it uses the configured one. To decode an id
from elsewhere, pass a different one:

```ruby
IronLion.parse(id, format: IronLion.define { shard bits: 74 })
```

When the format has a `model` field, an id can fetch its own record:

```ruby
IronLion.find("01A1F64F-62A3-8004-8010-1073676D6B05")   # => #<Order id: "01a1f64f-…">
IronLion.parse(id).record                              # the same
```

## Models

Each model gets a small permanent number that fits the `model` field. Point the
field at a checked-in table:

```ruby
model bits: 10, table: "config/iron_lion.yml"
```

```yaml
models:
  "User": 1
  "Order": 2
```

New models are numbered the first time they're seen, and the file is
append-only: a number is never reused. Use `IronLion::ModelTable.new(path,
assign: false)` where the table must be read-only, such as production; there,
an unknown model raises. A class can choose its own number by defining
`.iron_lion_model_id`.

## Rails

```bash
bin/rails generate iron_lion:install
```

This writes `config/initializers/iron_lion.rb` (your format) and
`config/iron_lion.yml` (model numbers). After that, a table gets IronLion ids by
having a uuid primary key with no default:

```ruby
create_table :orders, id: :uuid, default: nil do |t|
  t.bigint :tenant_id
end
```

```ruby
order = Order.create!(tenant_id: 4211)
IronLion.parse(order.id)
# => #<IronLion::Id 01a1f64f-… created_at=2026-11-20 00:16:00.163 UTC model=Order tenant=4211 sequence=1>
```

There is nothing to add to models. Postgres assigns the id when the row is
inserted, and ActiveRecord reads it back (unless the format has `from:`
resolvers; see below).

- **Triggers maintain themselves.** After every migration and schema load,
  IronLion reinstalls its functions and puts a trigger on each table whose model
  has a uuid key with no default. `schema.rb` doesn't record functions or
  triggers, so this keeps a test database loaded from `schema.rb` working.
  `bin/rails iron_lion:install` does the same by hand and reports each table.
- **Default uuid keys are left alone.** A uuid key that defaults to
  `gen_random_uuid()` (Rails' default for `id: :uuid`) keeps its default. The
  install report names those tables, so an omission is easy to spot.
- **Single-table inheritance uses the base class.** A `Car < Vehicle` row gets
  `Vehicle`'s model number, from Ruby and Postgres alike, and
  `IronLion.find(id)` still returns the `Car`.
- **Model numbers come from `config/iron_lion.yml`.** New models are numbered in
  development and test. Everywhere else the file is read-only, and a model that
  was never numbered raises with instructions. Commit the file.
- **`from:` resolvers mint in Ruby.** A resolver such as
  `tenant bits: 20, from: -> { Current.tenant_id }` is Ruby, and the database
  can't run it. So when the format has any `from:` field, every model on an
  IronLion table mints its id in Ruby just before create, and the install report
  says so. The trigger stays, and still fills ids for raw SQL and bulk inserts
  (`insert_all`), which don't run resolvers: give those the value as a column
  or an `iron_lion.<field>` setting.

## Postgres

Outside Rails, generate the SQL yourself. Postgres can mint the same ids from the same format, so rows inserted
anywhere (by ActiveRecord, raw SQL, bulk loads or other services) get proper
ids.

```ruby
postgres = IronLion::Postgres.new(IronLion.format)
execute postgres.install_sql                       # functions and iron_lion_seq
execute postgres.trigger_sql("orders", model: Order)
```

The trigger fills the id when an insert leaves it NULL, which is what
ActiveRecord does; Rails then reads the id back with `RETURNING`. An id
that was supplied is kept. Values come from the same places as in Ruby, adapted
to the database:

1. the inserted row: `iron_lion_tenant`, then `tenant_id`, then `tenant`. A
   `geohash:` field also reads the row's `latitude`/`longitude`. An H3 field
   accepts hex text or a bigint column.
2. the model number: an integer `iron_lion_model` column on the row, else the
   one written into each table's trigger by `trigger_sql`
3. a setting, which is the database's ENV:
   `ALTER DATABASE app SET iron_lion.node = '53'`, or per transaction with
   `SET LOCAL iron_lion.tenant = '7'`

The time comes from the database clock, random bits from `gen_random_uuid()`,
and the counter field from the shared `iron_lion_seq` sequence. The sequence
keeps ids unique across every connection without relying on node bits.

You can also mint an id by hand:

```sql
SELECT iron_lion_uuid(tenant => 7, model => 3, subdomain => 'acme');
```

`install_sql` is safe to run again after the format changes, and
`uninstall_sql` removes everything. Postgres 13 or later is required for
`gen_random_uuid()`. Other databases use Ruby generation.

## Guarantees

- Valid RFC 9562 UUIDv8: 122 payload bits laid out around the version and
  variant bits.
- Ids sort by creation time, to the millisecond, from either back end.
- Ruby: within a process, ids strictly increase. If a millisecond's sequence
  runs out, or the system clock steps backwards, IronLion borrows the next
  millisecond instead of blocking. Across processes, the time, node and random
  bits keep ids unique.
- Postgres: the counter is the shared `iron_lion_seq` sequence modulo 2^bits,
  so ids are unique across every connection while fewer than 2^bits are made
  per millisecond. They sort by millisecond; within one millisecond their order
  is arbitrary, since concurrent transactions have no meaningful order. The
  sequence is lock-free and never blocks.
- An explicit `created_at` (a backdated id) gets a random counter value in
  both back ends, and leaves `iron_lion_seq` untouched.
- Ruby and Postgres pack bits identically. The spec suite checks this against a
  real database.
- `IronLion.format.to_h` describes the format as plain data.

## Development

```bash
bundle install
createdb iron_lion_test   # optional: enables the Postgres specs
bundle exec rake          # specs and RuboCop
```

The Postgres specs use `IRON_LION_TEST_DATABASE_URL` (default
`postgres:///iron_lion_test`). Each example runs in a transaction that is rolled back.
Without a database they are skipped.
