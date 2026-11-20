# frozen_string_literal: true

# Examples tagged :active_record run through an ActiveRecord connection to
# the same test database as :postgres examples, inside a transaction with its
# own schema that is rolled back afterwards. Like :postgres examples they are
# skipped without a database, or fail when IRON_LION_REQUIRE_DATABASE is set.
module ActiveRecordHelpers
  def self.error = @error

  def self.connected?
    return @connected if defined?(@connected)

    @connected =
      begin
        require "active_record"
        ActiveRecord::Base.establish_connection(PostgresHelpers::DATABASE)
        ActiveRecord::Base.connection.verify!
        true
      rescue LoadError, StandardError => e
        @error = e
        false
      end
  end

  def connection = ActiveRecord::Base.connection

  def reset_schema_cache(*models)
    connection.schema_cache.clear!
    models.each(&:reset_column_information)
  end
end

RSpec.configure do |config|
  config.include ActiveRecordHelpers, :active_record

  config.around(:each, :active_record) do |example|
    if ActiveRecordHelpers.connected?
      connection = ActiveRecord::Base.connection
      connection.begin_transaction(joinable: false)
      connection.execute("CREATE SCHEMA iron_lion_spec; SET LOCAL search_path = iron_lion_spec, public")
      connection.schema_cache.clear!
      begin
        example.run
      ensure
        connection.rollback_transaction
        connection.schema_cache.clear!
      end
    else
      skip PostgresHelpers.unavailable(ActiveRecordHelpers.error)
    end
  end
end
