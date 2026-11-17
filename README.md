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

## Guarantees

- Valid RFC 9562 UUIDv8: 122 payload bits laid out around the version and
  variant bits.
- Within a process, ids strictly increase. If a millisecond's sequence runs out,
  or the system clock steps backwards, IronLion borrows the next millisecond
  instead of blocking.
- Across processes, the time, node and random bits keep ids unique.
- `IronLion.format.to_h` describes the format as plain data, ready for the SQL
  and Rust back ends to come.

## Development

```bash
bundle install
bundle exec rake   # specs and RuboCop
```
