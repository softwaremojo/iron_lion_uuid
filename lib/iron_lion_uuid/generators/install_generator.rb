# frozen_string_literal: true

module IronLionUUID
  module Generators
    # Rails generator for installing IronLionUUID database functions
    class InstallGenerator < Rails::Generators::Base
      desc "Creates database migrations for IronLionUUID functions"

      source_root File.expand_path("templates", __dir__)

      class_option(
        :databases,
        type: :array,
        default: [ "primary" ],
        desc: "Which database connections to install functions for"
      )

      class_option(
        :dialect,
        type: :string,
        default: nil,
        desc: "Override the detected database adapter (postgresql, mysql, sqlite)"
      )

      class_option(
        :binary_output,
        type: :boolean,
        default: false,
        desc: "Generate binary UUIDs for MySQL (ignored for other databases)"
      )

      def create_migration_file
        # Ensure configuration exists
        unless IronLionUUID.configuration
          raise(
            IronLionUUID::ConfigurationError,
            "UUID structure not configured. Please configure IronLionUUID first."
          )
        end

        # Get database connections
        databases = options[:databases]

        # Create a migration for each database
        databases.each do |db_name|
          # Determine the database adapter
          adapter = detect_database_adapter(db_name)

          # Map adapter to dialect
          dialect = options[:dialect] || adapter_to_dialect(adapter)

          if dialect.nil?
            say_status(
              :error,
              "Unsupported database adapter: #{adapter}. " \
              "Supported adapters: postgresql, mysql2, sqlite3.",
              :red
            )
          end

          # Create the migration
          migration_template(
            "migration.rb.erb",
            "db/migrate/create_iron_lion_uuid_functions_for_#{db_name}.rb",
            migration_version: migration_version,
            dialect: dialect.to_sym,
            database: db_name,
            binary_output: options[:binary_output]
          )
        end
      end

      private

        # Detect the database adapter for a specific connection
        def detect_database_adapter(db_name)
          return unless defined?(Rails) && db_name

          config = Rails.configuration.database_configuration[Rails.env]

          if db_name == "primary"
            # Use the main database configuration
            config["adapter"]
          else
            # Look for a specific connection by name
            conn_config = config[db_name] || {}
            conn_config["adapter"]
          end
        end

        # Map database adapter to SQL dialect
        def adapter_to_dialect(adapter)
          adapter.gsub(/\d/, "").to_sym
        end

        # Get the current migration version
        def migration_version
          if Rails.version.start_with?("5")
            "[4.2]"
          elsif Rails.version.start_with?("6")
            "[6.0]"
          elsif Rails.version.start_with?("7")
            "[7.0]"
          else
            ""
          end
        end
    end
  end
end
