# frozen_string_literal: true

module IronLion
  # Wires IronLion into a Rails app with nothing to configure:
  #
  # - The model table lives in config/iron_lion.yml. New models are numbered in
  #   development and test; elsewhere the file is read-only, so a model that
  #   was never numbered (and committed) raises instead of being guessed.
  # - Models mint their own ids in Ruby when the format has `from:` resolvers,
  #   which the database can't run (IronLion::RecordIds).
  # - After every migration and schema load, the Postgres functions and
  #   triggers are (re)installed. schema.rb does not record functions or
  #   triggers, so this is what keeps a freshly loaded test database working.
  # - `bin/rails iron_lion:install` does the same by hand.
  class Railtie < ::Rails::Railtie
    initializer "iron_lion.model_table", before: :load_config_initializers do |app|
      ModelTable.default_path = app.root.join("config", "iron_lion.yml")
      ModelTable.default_assign = ::Rails.env.local?
    end

    initializer "iron_lion.record_ids" do
      ActiveSupport.on_load(:active_record) { include IronLion::RecordIds }
    end

    initializer "iron_lion.database_tasks" do
      ActiveSupport.on_load(:active_record) do
        ActiveRecord::Tasks::DatabaseTasks.singleton_class.prepend(IronLion::DatabaseTasks)
      end
    end

    rake_tasks do
      load File.expand_path("tasks/iron_lion.rake", __dir__)
    end
  end

  # Reinstalls after Rails changes a database's schema.
  module DatabaseTasks
    def migrate(...)
      super.tap { IronLion::DatabaseTasks.install(migration_connection_pool) }
    end

    def load_schema(...)
      super.tap { IronLion::DatabaseTasks.install(migration_connection_pool) }
    end

    def self.install(pool)
      return unless IronLion.configured?

      ::Rails.application.eager_load!
      report = pool.with_connection { Installer.new(_1).call }
      return if report.installed.empty? && report.skipped.empty?

      $stdout.puts("IronLion:\n#{report}") if ActiveRecord::Migration.verbose
    end
  end
end
