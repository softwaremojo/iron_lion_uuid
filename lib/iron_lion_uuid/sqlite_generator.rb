# frozen_string_literal: true

module IronLionUUID
  # SQLite-specific UUID function generator
  class SQLiteGenerator < SQLGenerator
    PRECISION_MULTIPLIERS = {
      second: 1,
      millisecond: 1_000,
      microsecond: 1_000_000,
      nanosecond: 1_000_000 # SQLite does not support this level of precision
    }.freeze

    def initialize(configuration = nil)
      super(:sqlite, configuration)
    end

    private

    # Generate SQLite function for UUID generation
    # @param options [Hash] Options for function generation
    # @return [String] The generated SQL function
    def generate_sqlite_function(options)
      function_name = options[:function_name]

      # Get parameter declarations
      params = parameter_declarations
      param_string = params.empty? ? "" : params.join(", ")

      # Build the function
      <<~SQL
        -- SQLite UUIDs are implemented as TEXT (strings)
        -- First, create helper functions for UUID bit manipulation

        -- Function to format a hexadecimal string as a UUID with hyphens
        CREATE OR REPLACE FUNCTION format_uuid(hex_str TEXT)
        RETURNS TEXT AS $
          SUBSTR(hex_str, 1, 8) || '-' ||
          SUBSTR(hex_str, 9, 4) || '-' ||
          SUBSTR(hex_str, 13, 4) || '-' ||
          SUBSTR(hex_str, 17, 4) || '-' ||
          SUBSTR(hex_str, 21)
        $;

        -- Function to set bits in a UUID hex string
        CREATE OR REPLACE FUNCTION set_uuid_bits(hex_str TEXT, position INTEGER, bits INTEGER, value INTEGER)
        RETURNS TEXT AS $
          -- This is a simplified version that works for small bit ranges
          -- In practice, you might need a more sophisticated implementation

          -- Calculate which hex characters are affected
          WITH RECURSIVE
            hex_positions(start_pos, end_pos) AS (
              SELECT (position / 4) + 1, ((position + bits - 1) / 4) + 1
            ),
            -- Generate sequence of positions to update
            positions(pos) AS (
              SELECT start_pos FROM hex_positions
              UNION ALL
              SELECT pos + 1 FROM positions, hex_positions
              WHERE pos < end_pos
            ),
            -- Calculate bit masks and values for each position
            masks(pos, bit_start, bit_end, mask, shift, hex_mask) AS (
              SELECT
                pos,
                CASE WHEN pos = (SELECT start_pos FROM hex_positions)
                     THEN position % 4 ELSE 0 END,
                CASE WHEN pos = (SELECT end_pos FROM hex_positions)
                     THEN (position + bits - 1) % 4 ELSE 3 END,
                (1 << ((CASE WHEN pos = (SELECT end_pos FROM hex_positions)
                           THEN (position + bits - 1) % 4 ELSE 3 END) + 1)) -
                (1 << (CASE WHEN pos = (SELECT start_pos FROM hex_positions)
                           THEN position % 4 ELSE 0 END)),
                (pos - (SELECT start_pos FROM hex_positions)) * 4 -
                (CASE WHEN pos = (SELECT start_pos FROM hex_positions)
                      THEN position % 4 ELSE 0 END),
                printf('%x', (1 << 4) - 1)
              FROM positions
            ),
            -- Extract existing values
            hex_values(pos, hex_val, curr_val) AS (
              SELECT
                pos,
                SUBSTR(hex_str, pos, 1),
                CASE
                  WHEN SUBSTR(hex_str, pos, 1) BETWEEN '0' AND '9'
                  THEN CAST(SUBSTR(hex_str, pos, 1) AS INTEGER)
                  ELSE CAST(INSTR('0123456789abcdef', LOWER(SUBSTR(hex_str, pos, 1))) AS INTEGER) - 1
                END
              FROM masks
            ),
            -- Calculate new values
            new_values(pos, new_val, hex_char) AS (
              SELECT
                pos,
                (curr_val & ~mask) | (((value >> shift) & mask) & 15),
                SUBSTR('0123456789abcdef', new_val+1, 1)
              FROM hex_values NATURAL JOIN masks
            ),
            -- Aggregate the results
            result(str, pos, done) AS (
              SELECT hex_str, 1, 0
              UNION ALL
              SELECT
                CASE WHEN pos IN (SELECT pos FROM new_values)
                     THEN SUBSTR(str, 1, pos-1) ||
                          (SELECT hex_char FROM new_values WHERE pos = result.pos) ||
                          SUBSTR(str, pos+1)
                     ELSE str END,
                pos + 1,
                pos = LENGTH(hex_str)
              FROM result
              WHERE NOT done
            )
          SELECT str FROM result WHERE done;
        $;

        -- Create the main UUID generation function
        CREATE OR REPLACE FUNCTION #{function_name}(#{param_string})
        RETURNS TEXT AS $
          WITH base_uuid(hex) AS (
            -- Start with all zeros
            SELECT LOWER(REPLACE(HEX(ZEROBLOB(16)), '00', '0'))
          ),
          -- Set version bits (v8) at positions 48-51 (hex position 12)
          versioned(hex) AS (
            SELECT SUBSTR(hex, 1, 12) || '8' || SUBSTR(hex, 14)
            FROM base_uuid
          ),
          -- Set variant bits (RFC 4122) at positions 64-65 (hex position 16)
          with_variant(hex) AS (
            SELECT SUBSTR(hex, 1, 16) || '8' || SUBSTR(hex, 18)
            FROM versioned
          )
          #{generate_attribute_bits}
          -- Format as standard UUID with hyphens
          SELECT format_uuid(hex)
          FROM final_uuid;
        $;
      SQL
    end

    # Generate SQL for dropping the SQLite function
    # @param options [Hash] Options for function dropping
    # @return [String] The SQL drop statement
    def drop_sqlite_function(options)
      function_name = options[:function_name]

      # Build the drop statement
      <<~SQL
        -- Drop the main function
        DROP FUNCTION IF EXISTS #{function_name};

        -- Drop helper functions if needed
        DROP FUNCTION IF EXISTS set_uuid_bits;
        DROP FUNCTION IF EXISTS format_uuid;
      SQL
    end

    # Generate SQL statements for setting attribute bits
    # @return [String] SQL statements
    def generate_attribute_bits
      statements = []

      statements << "-- Add attribute values as CTEs"

      # Set up initial CTE
      statements << ", final_uuid(hex) AS ("

      # Process each attribute
      ordered_attributes.each_with_index do |attr, index|
        statements << public_send(:"generate_#{attr.type}_bits", attr, index)
      end

      # Close the final CTE - use the last attribute or variant if no attributes
      statements << if ordered_attributes.empty?
        "  SELECT hex FROM with_variant"
      else
        "  SELECT hex FROM attr_#{ordered_attributes.size - 1}"
      end
      statements << ")"

      statements.join("\n")
    end

    # Generate SQL for parameter attribute
    # @param attr [ParameterAttribute] The parameter attribute
    # @param index [Integer] The attribute index for CTE naming
    # @return [String] SQL statement
    def generate_parameter_bits(attr, index)
      prev_cte = index.zero? ? "with_variant" : "attr_#{index - 1}"

      # Use SQLite's printf to convert parameter to hex, then use set_uuid_bits function
      <<~SQL
        -- Set bits for parameter attribute #{attr.name} (#{attr.bits} bits at position #{attr.position})
        attr_#{index}(hex) AS (
          SELECT
            CASE
              WHEN #{attr.name} >= POWER(2, #{attr.bits}) THEN
                RAISE(FAIL, 'Value exceeds maximum for #{attr.bits} bits')
              ELSE
                set_uuid_bits(hex, #{attr.position}, #{attr.bits}, #{attr.name})
            END
          FROM #{prev_cte}
        )
      SQL
    end

    # Generate SQL for env parameter attribute
    # @param attr [EnvAttribute] The environment variable attribute
    # @param index [Integer] The attribute index for CTE naming
    # @return [String] SQL statement
    def generate_env_bits(attr, index)
      prev_cte = index.zero? ? "with_variant" : "attr_#{index - 1}"

      # SQLite can't access environment variables directly
      <<~SQL
        -- Set bits for environment variable attribute #{attr.name} (#{attr.bits} bits at position #{attr.position})
        -- Note: SQLite doesn't support environment variables directly
        -- For environment variable '#{attr[:key]}', either:
        -- 1. Add a parameter to the function and pass the value
        -- 2. Or use a constant value set at database creation time

        -- Using placeholder value 0 for now
        attr_#{index}(hex) AS (
          SELECT set_uuid_bits(hex, #{attr.position}, #{attr.bits}, 0)
          FROM #{prev_cte}
        )
      SQL
    end

    # Generate SQL for timestamp attribute
    # @param attr [TimestampAttribute] The timestamp attribute
    # @param index [Integer] The attribute index for CTE naming
    # @return [String] SQL statement
    def generate_timestamp_bits(attr, index)
      prev_cte = index.zero? ? "with_variant" : "attr_#{index - 1}"
      precision = attr[:precision] || :millisecond

      # Get multiplier based on precision
      multiplier = PRECISION_MULTIPLIERS[precision]

      <<~SQL
        -- Set bits for timestamp attribute (#{attr.bits} bits at position #{attr.position}) at #{precision} precision
        attr_#{index}(hex, ts_value) AS (
          SELECT
            set_uuid_bits(
              hex,
              #{attr.position},
              #{attr.bits},
              CAST(unixepoch('now') * #{multiplier} AS INTEGER) & (POWER(2, #{attr.bits}) - 1)
            ),
            CAST(unixepoch('now') * #{multiplier} AS INTEGER) & (POWER(2, #{attr.bits}) - 1)
          FROM #{prev_cte}
        )
      SQL
    end

    # Generate SQL for sequence attribute
    # @param attr [SequenceAttribute] The sequence attribute
    # @param index [Integer] The attribute index for CTE naming
    # @return [String] SQL statement
    def generate_sequence_bits(attr, index)
      prev_cte = index.zero? ? "with_variant" : "attr_#{index - 1}"
      sequence_table = "#{attr.name}_sequence"
      max_value = (1 << attr.bits) - 1

      # SQLite doesn't have native sequences, so we need to use a sequence table
      # This creates the table if it doesn't exist
      <<~SQL
        -- Set bits for sequence attribute (#{attr.bits} bits at position #{attr.position})
        -- First ensure sequence table exists
        #{create_sequence_table(attr)},
        -- Get and increment sequence value
        seq_value(val) AS (
          SELECT COALESCE(
            (SELECT value FROM #{sequence_table}),
            0
          )
        ),
        increment_seq(new_val) AS (
          SELECT (val + 1) % #{max_value + 1} FROM seq_value
        ),
        update_seq(dummy) AS (
          UPDATE #{sequence_table} SET value = (SELECT new_val FROM increment_seq)
          RETURNING 1
        ),
        insert_seq(dummy) AS (
          INSERT INTO #{sequence_table} (value)
          SELECT new_val FROM increment_seq
          WHERE NOT EXISTS (SELECT 1 FROM update_seq)
          RETURNING 1
        ),
        attr_#{index}(hex) AS (
          SELECT set_uuid_bits(hex, #{attr.position}, #{attr.bits},
                 (SELECT COALESCE((SELECT new_val FROM increment_seq), 0)))
          FROM #{prev_cte}
        )
      SQL
    end

    # Generate SQL to create a sequence table if it doesn't exist
    # @param attr [SequenceAttribute] The sequence attribute
    # @return [String] SQL statement
    def create_sequence_table(attr)
      sequence_table = "#{attr.name}_sequence"

      <<~SQL
        -- Create sequence table if it doesn't exist
        create_seq_table(dummy) AS (
          WITH check_table(exists) AS (
            SELECT COUNT(*) FROM sqlite_master
            WHERE type='table' AND name='#{sequence_table}'
          )
          SELECT
            CASE
              WHEN (SELECT exists FROM check_table) = 0 THEN
                (SELECT 1 FROM (
                  CREATE TABLE #{sequence_table} (value INTEGER)
                ))
              ELSE 1
            END
        )
      SQL
    end

    # Generate SQL for random attribute
    # @param attr [RandomAttribute] The random attribute
    # @param index [Integer] The attribute index for CTE naming
    # @return [String] SQL statement
    def generate_random_bits(attr, index)
      prev_cte = index.zero? ? "with_variant" : "attr_#{index - 1}"

      # Use SQLite's random() function to generate random values
      <<~SQL
        -- Set bits for random attribute (#{attr.bits} bits at position #{attr.position})
        attr_#{index}(hex) AS (
          SELECT set_uuid_bits(hex, #{attr.position}, #{attr.bits},
                 CAST(random() * POWER(2, #{attr.bits}) AS INTEGER))
          FROM #{prev_cte}
        )
      SQL
    end
  end
end
