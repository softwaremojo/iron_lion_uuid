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
  # A `from:` resolver only runs in Ruby, so when the format has one,
  # IronLion::RecordIds mints these tables' ids before create instead. The
  # trigger still fills ids for raw SQL and bulk inserts.
  #
  # Running it again is harmless; Rails runs it after every migration and
  # schema load.
  class Installer
    # from_fields names the format's fields with `from:` resolvers. When there
    # are any, IronLion::RecordIds mints ids in Ruby, and the report says why.
    Report = Data.define(:installed, :skipped, :from_fields) do
      def initialize(installed:, skipped:, from_fields: [])
        super
      end

      def to_s
        lines = installed.map { |table, model| "  #{table}: IronLion ids (#{model})#{minted_in_ruby}" }
        lines += skipped.map { |table, reason| "  #{table}: skipped, #{reason}" }
        lines.join("\n")
      end

      private

      def minted_in_ruby
        return "" if from_fields.empty?

        *others, last = from_fields.map(&:to_s)
        names = others.empty? ? last : "#{others.join(', ')} and #{last}"
        ", minted in Ruby because #{names} #{others.empty? ? 'uses' : 'use'} from:"
      end
    end

    # The IronLion table rule, kept in one place: the primary key is a uuid
    # with no default. Both the installer and IronLion::RecordIds ask it.
    def self.iron_lion_table?(connection, table)
      column = uuid_primary_key(connection, table)
      !column.nil? && column.default.nil? && column.default_function.nil?
    end

    # The table's primary key column when it is a uuid, otherwise nil.
    def self.uuid_primary_key(connection, table)
      key = connection.primary_key(table)
      return unless key.is_a?(String)

      column = connection.columns(table).find { _1.name == key }
      column if column&.sql_type == "uuid"
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

      Report.new(installed:, skipped:, from_fields: format.from_fields.map(&:name))
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
      column = self.class.uuid_primary_key(connection, table)
      return :not_uuid if column.nil?
      return nil if self.class.iron_lion_table?(connection, table)

      "its id defaults to #{column.default_function || column.default.inspect} " \
        "(create it with `id: :uuid, default: nil` for IronLion ids)"
    end
  end
end
