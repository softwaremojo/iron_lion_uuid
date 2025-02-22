# frozen_string_literal: true

class IronLionUUID
  # Functionality for generating SQL code
  module Generator
    ADAPTERS = %i[postgresql mysql2 sqlite].freeze
    VERSION = 0b1000
    VARIANT = 0b10

    class << self
      def call(definition, adapter: :postgresql)
        unless ADAPTERS.include? adapter
          raise UnsupportedAdapterError, "IronLionUUID does not support #{adapter}"
        end

        const_get(Inflector.classify(adapter)).call(definition)
      end
    end

    # Base class for SQL generator
    class Base
      def self.call(...)
        new(...).call
      end

      def initialize(definition)
        @definition = definition
      end

      def call
        raise
      end

      def vervar_mask
        ~vervar_bits
      end

      def vervar_bits
        (VERSION << 48) | (VARIANT << 64)
      end
    end

    # PostgreSQL SQL generator
    class PostgreSQL < Base
      def call
        <<~SQL
          #{index.sql_dependencies}

          CREATE OR REPLACE FUNCTION iron_lion_uuid()
          RETURNS UUID AS $$
          DECLARE
            index     BIT(122);
            iron_lion BIT(128);
          BEGIN
            index := #{index.sql_values(:postgresql)};

            iron_lion :=
              (index & #{vervar_mask}) | #{vervar_bits};

            RETURN encode(decode(to_hex(iron_lion), 'hex'), 'hex')::UUID;
          END;
          $$ LANGUAGE plpgsql;
        SQL
      end
    end

    # MySQL SQL generator
    class Mysql2 < Base
      def call
        <<~SQL
          #{index.sql_dependencies}

          DELIMITER $$
          CREATE FUNCTION iron_lion_uuid()
          RETURNS CHAR(36)
          BEGIN
            DECLARE index BIGINT UNSIGNED;
            DECLARE iron_lion BINARY(16);

            SET index = #{index.sql_values(:mysql2)};

            SET iron_lion =
              (index & #{vervar_mask}) | #{vervar_bits};

            RETURN LOWER(CONCAT(
              LPAD(HEX(iron_lion >> 96), 8, '0'), '-',
              LPAD(HEX(iron_lion >> 80 & 0xFFFF), 4, '0'), '-',
              LPAD(HEX(iron_lion >> 64 & 0xFFFF), 4, '0'), '-',
              LPAD(HEX(iron_lion >> 48 & 0xFFFF), 4, '0'), '-',
              LPAD(HEX(iron_lion & 0xFFFFFFFFFFFF), 12, '0')
            ));
          END$$
          DELIMITER ;
        SQL
      end
    end

    # SQLite SQL generator
    class SQLite < Base
      def call
        <<~SQL
          #{index.sql_dependencies}

          CREATE TABLE IF NOT EXISTS iron_lion_uuid (
            uuid TEXT DEFAULT (
              (#{index.sql_values(:sqlite)} & #{vervar_mask}) |
              #{vervar_bits}
            )
          );
        SQL
      end

      def vervar_mask
        "~(#{vervar_bits})"
      end

      def vervar_bits
        "(#{VERSION} << 48) | (#{VARIANT} << 64)"
      end
    end
  end
end
