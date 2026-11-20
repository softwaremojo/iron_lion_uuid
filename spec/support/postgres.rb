# frozen_string_literal: true

# Runs examples tagged :postgres against a real database, each inside a
# transaction (with its own schema) that is rolled back afterwards.
# Set IRON_LION_TEST_DATABASE_URL to point elsewhere; without a reachable
# database the examples are skipped. Set IRON_LION_REQUIRE_DATABASE (as CI
# does) to make them fail instead, so a broken database can't pass silently.
module PostgresHelpers
  DATABASE = ENV.fetch("IRON_LION_TEST_DATABASE_URL", "postgres:///iron_lion_test")
  # Read once at load time: spec_helper clears IRON_LION_* around each example.
  REQUIRE_DATABASE = ENV.key?("IRON_LION_REQUIRE_DATABASE")

  def self.connection
    return @connection if defined?(@connection)

    @connection =
      begin
        require "pg"
        PG.connect(DATABASE).tap { |connection| connection.set_notice_processor { nil } }
      rescue LoadError, PG::Error => e
        @error = e
        nil
      end
  end

  def self.error = @error

  # The reason to skip an example that needs the database, or a raise when
  # IRON_LION_REQUIRE_DATABASE is set.
  def self.unavailable(error)
    reason = "no Postgres at #{DATABASE}"
    return reason unless REQUIRE_DATABASE

    raise "IRON_LION_REQUIRE_DATABASE is set, but there is #{reason} " \
          "(IRON_LION_TEST_DATABASE_URL). #{error.class}: #{error.message.strip}"
  end

  def db = PostgresHelpers.connection

  def sql(statement, *params)
    result = params.empty? ? db.exec(statement) : db.exec_params(statement, params)
    result.values
  end

  def value(statement, *params) = sql(statement, *params).dig(0, 0)

  def install(format)
    db.exec(IronLion::Postgres.new(format).install_sql)
  end
end

RSpec.configure do |config|
  config.include PostgresHelpers, :postgres

  config.around(:each, :postgres) do |example|
    if PostgresHelpers.connection.nil?
      skip PostgresHelpers.unavailable(PostgresHelpers.error)
    else
      db.exec("BEGIN; CREATE SCHEMA iron_lion_spec; SET LOCAL search_path = iron_lion_spec, public")
      begin
        example.run
      ensure
        db.exec("ROLLBACK")
      end
    end
  end
end
