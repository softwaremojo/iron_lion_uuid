# Rails integration: internals

Read this before changing `lib/iron_lion/railtie.rb`, `lib/iron_lion/installer.rb`,
`lib/iron_lion/record_ids.rb`, `tasks/iron_lion.rake` or `lib/generators/iron_lion/`.
README.md § Rails describes the behaviour users see; this file covers how it is wired.

## Wiring

- `IronLion::Railtie` points the default model table at `config/iron_lion.yml`. It may
  assign new numbers only when `Rails.env.local?`.
- The Railtie prepends `IronLion::DatabaseTasks` to ActiveRecord's DatabaseTasks, so
  `migrate` and `load_schema` rerun `IronLion::Installer`.
- `IronLion::Installer` installs the functions and triggers through an ActiveRecord
  connection. It triggers every model table whose primary key is a uuid with no default.
  That rule lives in `Installer.iron_lion_table?`.
- When the format has any `from:` field, `IronLion::RecordIds` (included into
  `ActiveRecord::Base` by the Railtie) mints ids in Ruby before create, because the
  trigger can't run Ruby resolvers. The trigger stays, for raw SQL.
- `Id#record` and `IronLion.find` fetch an id's row through its model field.
- The generator (`lib/generators/iron_lion/`) writes the initializer and
  `config/iron_lion.yml`.

## Checking end to end

The spec suite covers everything except the Railtie, the generator and the schema-load
hook. To check those, generate a throwaway app outside the repo
(`rails new … --minimal --database=postgresql`), add this gem by `path:`, then run the
generator, a migration and `bin/rails test`.
