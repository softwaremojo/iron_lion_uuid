# frozen_string_literal: true

# Runs examples tagged :postgres against a real database, each inside a
# transaction (with its own schema) that is rolled back afterwards.
# Set IRON_LION_TEST_DATABASE_URL to point elsewhere; without a reachable
# database the examples are skipped.
module PostgresHelpers
  DATABASE = ENV.fetch("IRON_LION_TEST_DATABASE_URL", "dbname=iron_lion_test")

  def self.connection
    return @connection if defined?(@connection)

    @connection =
      begin
        require "pg"
        PG.connect(DATABASE).tap { |connection| connection.set_notice_processor { nil } }
      rescue LoadError, PG::Error
        nil
      end
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
      skip "no Postgres at #{PostgresHelpers::DATABASE}"
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
