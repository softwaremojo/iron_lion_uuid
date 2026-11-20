# frozen_string_literal: true

module IronLion
  # Installs IronLion into a Postgres database through an ActiveRecord
  # connection: the functions, then an insert trigger on every table that
  # wants IronLion ids.
  #
  # A table wants IronLion ids when its model's primary key is a uuid with no
  # default, which is what `create_table :orders, id: :uuid, default: nil`
  # makes. A uuid key that defaults to gen_random_uuid() keeps its default,
  # because Postgres fills the default before the trigger can tell the id
  # was left out.
  #
  # Running it again is harmless; Rails runs it after every migration and
  # schema load.
  class Installer
    Report = Data.define(:installed, :skipped) do
      def to_s
        lines = installed.map { |table, model| "  #{table}: IronLion ids (#{model})" }
        lines += skipped.map { |table, reason| "  #{table}: skipped, #{reason}" }
        lines.join("\n")
      end
    end

    attr_reader :connection, :format

    def initialize(connection, format: IronLion.format, models: nil)
      @connection = connection
      @format = format
      @models = models
    end

    def postgres? = connection.adapter_name.match?(/postg/i)

    def call
      return Report.new(installed: [], skipped: []) unless postgres?

      postgres = Postgres.new(format)
      connection.execute(postgres.install_sql)

      installed = []
      skipped = []

      models_by_table.each do |table, model|
        reason = skip_reason(table)
        next if reason == :not_uuid
        next skipped << [table, reason] if reason

        connection.execute(
          postgres.trigger_sql(table, model: (model if model_field?), column: connection.primary_key(table))
        )
        installed << [table, model.name]
      end

      Report.new(installed:, skipped:)
    end

    def uninstall
      connection.execute(Postgres.new(format).uninstall_sql) if postgres?
    end

    private

    def model_field? = format.fields.any?(&:model?)

    def models
      @models || ActiveRecord::Base.descendants
    end

    # One model per table: the base class of each concrete hierarchy.
    def models_by_table
      models
        .select { |model| !model.abstract_class? && model.base_class == model && model.name }
        .select { |model| connection.data_source_exists?(model.table_name) }
        .to_h { |model| [model.table_name, model] }
        .sort.to_h
    end

    # nil to install, :not_uuid to pass over quietly, or why a uuid table was left alone.
    def skip_reason(table)
      key = connection.primary_key(table)
      return :not_uuid unless key.is_a?(String)

      column = connection.columns(table).find { _1.name == key }
      return :not_uuid unless column.sql_type == "uuid"
      return nil if column.default.nil? && column.default_function.nil?

      "its id defaults to #{column.default_function || column.default.inspect} " \
        "(create it with `id: :uuid, default: nil` for IronLion ids)"
    end
  end
end
