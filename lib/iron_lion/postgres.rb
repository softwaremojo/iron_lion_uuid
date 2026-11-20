# frozen_string_literal: true

module IronLion
  # Generates the SQL that lets Postgres mint the same ids as Ruby, from the
  # same format.
  #
  #   postgres = IronLion::Postgres.new(IronLion.format)
  #   execute postgres.install_sql                  # functions + iron_lion_seq
  #   execute postgres.trigger_sql("orders", model: Order)
  #
  # Inserts that leave the id NULL (as ActiveRecord does) get one from a
  # BEFORE INSERT trigger, which reads values from the row the same way the
  # Ruby resolver reads a record: iron_lion_<field>, <field>_id, <field>.
  # Anything the row lacks comes from a database setting such as
  # iron_lion.node, which is the database's ENV. The counter field draws from
  # the shared iron_lion_seq sequence, so ids are unique across every
  # connection without depending on node bits, while fewer than 2^bits are
  # made per millisecond. Within a millisecond their order is arbitrary.
  #
  # The installed functions:
  #
  #   iron_lion_uuid(tenant => 7, ...)  mint an id by hand
  #   iron_lion_assign_id()             the trigger function
  class Postgres
    HELPERS = File.read(File.join(__dir__, "postgres", "helpers.sql")).freeze

    FUNCTIONS = %w[
      iron_lion_uuid iron_lion_assign_id iron_lion_setting iron_lion_missing iron_lion_int_bits
      iron_lion_text_bits iron_lion_h3_bits iron_lion_geohash iron_lion_geohash_bits
      iron_lion_random_bits iron_lion_to_uuid iron_lion_row iron_lion_row_h3 iron_lion_row_geohash
      iron_lion_row_model
    ].freeze

    PARAMETER_TYPES = {
      time: "timestamptz", value: "numeric", text: "text", h3: "text", geohash: "text"
    }.freeze

    attr_reader :format

    def initialize(format = IronLion.format)
      @format = format
    end

    # Everything a database needs, safe to run again after the format changes.
    def install_sql
      <<~SQL
        #{HELPERS}
        DROP FUNCTION IF EXISTS iron_lion_uuid;

        #{uuid_function}

        #{trigger_function}
      SQL
    end

    def uninstall_sql
      drops = FUNCTIONS.map { "DROP FUNCTION IF EXISTS #{_1} CASCADE;" }
      "#{drops.join("\n")}\nDROP SEQUENCE IF EXISTS iron_lion_seq;\n"
    end

    # Gives a table ids on insert. `model` is the class (or name, or number)
    # whose number goes in the model field; `column` is the id column.
    def trigger_sql(table, model: nil, column: "id")
      <<~SQL
        DROP TRIGGER IF EXISTS iron_lion_id ON #{identifier(table)};
        CREATE TRIGGER iron_lion_id BEFORE INSERT ON #{identifier(table)}
          FOR EACH ROW EXECUTE FUNCTION iron_lion_assign_id(#{literal(column)}, #{literal(model_id(model))});
      SQL
    end

    def drop_trigger_sql(table)
      "DROP TRIGGER IF EXISTS iron_lion_id ON #{identifier(table)};\n"
    end

    private

    def inputs = format.fields.reject { %i[counter random].include?(_1.kind) }

    def uuid_function
      parameters = inputs.map { "#{identifier(_1.name)} #{parameter_type(_1)} DEFAULT NULL" }

      <<~SQL.chomp
        CREATE FUNCTION iron_lion_uuid(
          #{parameters.join(",\n  ")}
        ) RETURNS uuid
        LANGUAGE plpgsql VOLATILE AS $iron_lion$
        DECLARE
          _random varbit := iron_lion_random_bits();
        BEGIN
          RETURN iron_lion_to_uuid(
            #{random_offsets.map { |field, offset| encode(field, offset) }.join(" ||\n    ")}
          );
        END
        $iron_lion$;
      SQL
    end

    def trigger_function
      arguments = inputs.filter_map do |field|
        value = row_value(field) or next
        "#{identifier(field.name)} => #{value}"
      end

      <<~SQL.chomp
        CREATE OR REPLACE FUNCTION iron_lion_assign_id() RETURNS trigger
        LANGUAGE plpgsql AS $iron_lion$
        DECLARE
          _row jsonb := to_jsonb(NEW);
          _column text := coalesce(nullif(TG_ARGV[0], ''), 'id');
        BEGIN
          IF _row ->> _column IS NOT NULL THEN
            RETURN NEW;
          END IF;

          RETURN jsonb_populate_record(NEW, jsonb_build_object(_column, iron_lion_uuid(
            #{arguments.join(",\n      ")}
          )));
        END
        $iron_lion$;
      SQL
    end

    # Pairs each field with where its bits start in the random pool.
    def random_offsets
      pool = 1
      format.fields.map do |field|
        offset = pool
        pool += field.bits if field.kind == :random
        [field, offset]
      end
    end

    def encode(field, random_offset)
      case field.kind
      when :time, :counter, :random then encode_generated(field, random_offset)
      else encode_given(field)
      end
    end

    # Fields the database produces: its clock, iron_lion_seq, random bits.
    def encode_generated(field, random_offset)
      name = literal(field.name)

      case field.kind
      when :time
        now = "floor(extract(epoch FROM coalesce(#{identifier(field.name)}, clock_timestamp())) * 1000)"
        "iron_lion_int_bits(#{now} - #{field.options[:epoch_ms]}, #{field.bits}, #{name})"
      when :counter then encode_counter(field)
      else "substring(_random FROM #{random_offset} FOR #{field.bits})"
      end
    end

    # The next iron_lion_seq value, wrapped to the field's bits: unique while
    # fewer than 2^bits ids are made per millisecond, in no particular order
    # within one. A backdated id (created_at given) takes random bits instead,
    # as Ruby does, and leaves the sequence alone.
    def encode_counter(field)
      created_at = identifier(format.fields.first.name)
      wrapped = "nextval('iron_lion_seq') % (2::numeric ^ #{field.bits})"
      counted = "iron_lion_int_bits(#{wrapped}, #{field.bits}, #{literal(field.name)})"
      random = "substring(iron_lion_random_bits() FROM 1 FOR #{field.bits})"

      "CASE WHEN #{created_at} IS NULL THEN #{counted} ELSE #{random} END"
    end

    # Fields taken from the argument, else the iron_lion.<field> setting.
    def encode_given(field)
      name = literal(field.name)
      given = "coalesce(#{identifier(field.name)}, iron_lion_setting(#{name})"

      case field.kind
      when :value then "iron_lion_int_bits(#{given}::numeric), #{field.bits}, #{name})"
      when :text then "iron_lion_text_bits(#{given}), #{field.options[:chars]}, #{field.bits}, #{name})"
      when :h3 then "iron_lion_h3_bits(#{given}), #{field.options[:resolution]}, #{name})"
      else "iron_lion_geohash_bits(#{given}), #{field.options[:chars]}, #{name})"
      end
    end

    # How the trigger reads a field from the inserted row, mirroring Resolver.
    def row_value(field)
      columns = Resolver.record_methods(field).map { literal(_1) }.join(", ")

      case field.kind
      when :time then nil
      when :h3 then "iron_lion_row_h3(_row, #{columns})"
      when :geohash
        "coalesce(iron_lion_row(_row, #{columns}), iron_lion_row_geohash(_row, #{field.options[:chars]}))"
      when :value
        # The row's own model number wins over the table's, as in Ruby.
        return "coalesce(iron_lion_row_model(_row, #{columns}), nullif(TG_ARGV[1], '')::numeric)" if field.model?

        "iron_lion_row(_row, #{columns})::numeric"
      else "iron_lion_row(_row, #{columns})"
      end
    end

    def parameter_type(field) = PARAMETER_TYPES.fetch(field.kind)

    def model_id(model)
      case model
      when nil then nil
      when Integer then model
      else
        field = format.fields.find(&:model?) or
          raise ConfigurationError, "this format has no model field, so trigger_sql takes no model:"

        Resolver.model_id(field, model)
      end
    end

    def identifier(name) = %("#{name.to_s.gsub('"', '""')}")

    def literal(value)
      value.nil? ? "''" : "'#{value.to_s.gsub("'", "''")}'"
    end
  end
end
