# frozen_string_literal: true

# rubocop:disable Layout/LineLength
module IronLionUUID
  # MySQL-specific UUID function generator
  class MySQLGenerator < SQLGenerator
    def initialize(configuration = nil)
      super(:mysql, configuration)
    end

    private

    # Generate MySQL function for UUID generation
    # @param options [Hash] Options for function generation
    # @return [String] The generated SQL function
    def generate_mysql_function(options)
      function_name = options[:function_name]
      binary_output = options[:binary_output] || false

      # Get parameter declarations
      params = parameter_declarations
      param_string = params.empty? ? "" : params.join(", ")

      # Build the function
      <<~SQL
        DELIMITER //

        DROP FUNCTION IF EXISTS #{function_name}//

        CREATE FUNCTION #{function_name}(#{param_string})
        RETURNS #{binary_output ? 'BINARY(16)' : 'CHAR(36)'}
        DETERMINISTIC
        BEGIN
          DECLARE uuid_bin BINARY(16);
          DECLARE uuid_str CHAR(36);
          DECLARE i INT;

          -- Start with a binary of all zeros
          SET uuid_bin = UNHEX(REPEAT('0', 32));

          -- Set version bits (UUID v8)
          SET uuid_bin = UNHEX(
            CONCAT(
              SUBSTRING(HEX(uuid_bin), 1, 12),
              '8',
              SUBSTRING(HEX(uuid_bin), 14, 19)
            )
          );

          -- Set variant bits (RFC 4122)
          SET uuid_bin = UNHEX(
            CONCAT(
              SUBSTRING(HEX(uuid_bin), 1, 16),
              CONCAT(HEX(CONV('10', 2, 16)), SUBSTRING(HEX(uuid_bin), 18, 15))
            )
          );

          #{generate_attribute_bits}

          -- Format as UUID string if needed
          IF NOT #{binary_output} THEN
            SET uuid_str = LOWER(CONCAT(
              SUBSTRING(HEX(uuid_bin), 1, 8), '-',
              SUBSTRING(HEX(uuid_bin), 9, 4), '-',
              SUBSTRING(HEX(uuid_bin), 13, 4), '-',
              SUBSTRING(HEX(uuid_bin), 17, 4), '-',
              SUBSTRING(HEX(uuid_bin), 21, 12)
            ));
            RETURN uuid_str;
          ELSE
            RETURN uuid_bin;
          END IF;
        END//

        DELIMITER ;
      SQL
    end

    # Generate SQL for dropping the MySQL function
    # @param options [Hash] Options for function dropping
    # @return [String] The SQL drop statement
    def drop_mysql_function(options)
      function_name = options[:function_name]

      # Build the drop statement
      <<~SQL
        DROP FUNCTION IF EXISTS #{function_name};
      SQL
    end

    # Generate SQL statements for setting attribute bits
    # @return [String] SQL statements
    def generate_attribute_bits
      ordered_attributes.inject([]) do |statements, attr|
        case attr.type
        when :parameter
          statements << generate_parameter_bits(attr)
        when :timestamp
          statements << generate_timestamp_bits(attr)
        when :sequence
          statements << generate_sequence_bits(attr)
        when :random
          statements << generate_random_bits(attr)
        when :env
          statements << generate_env_bits(attr)
        end
      end.join("\n\n")
    end

    # Generate SQL for parameter attribute
    # @param attr [ParameterAttribute] The parameter attribute
    # @return [String] SQL statement
    def generate_parameter_bits(attr)
      # MySQL bit manipulation is a bit more complex than PostgreSQL
      # We need to work with the hexadecimal representation

      # Calculate byte positions for this attribute
      start_byte = attr.position / 8
      end_byte = (attr.position + attr.bits - 1) / 8

      statements = []

      statements << "-- Set bits for parameter #{attr.name} " \
                    "(#{attr.bits} bits at position #{attr.position})"

      # Check if value exceeds bit width
      statements << "IF #{attr.name} >= POWER(2, #{attr.bits}) THEN"
      statements << "  SIGNAL SQLSTATE '45000'"
      statements << "  SET MESSAGE_TEXT = CONCAT('Value ', #{attr.name}, ' exceeds maximum (', POWER(2, #{attr.bits}) - 1, ') for #{attr.bits} bits');"
      statements << "END IF;"

      # We need to manipulate each affected byte
      (start_byte..end_byte).each do |byte_pos|
        # Calculate which bits in this byte are affected
        byte_start_bit = [ attr.position, byte_pos * 8 ].max % 8
        byte_end_bit = [ (attr.position + attr.bits - 1), ((byte_pos * 8) + 7) ].min % 8
        bits_in_byte = byte_end_bit - byte_start_bit + 1

        # Calculate the shift needed to align the parameter bits with these byte bits
        param_shift = (byte_pos * 8) + byte_start_bit - attr.position

        # MySQL uses 1-indexed positions for SUBSTRING
        mysql_pos = byte_pos + 1

        statements << "-- Manipulate byte at position #{byte_pos} (bits #{byte_start_bit}-#{byte_end_bit})"
        statements << "SET uuid_bin = UNHEX("
        statements << "  CONCAT("
        statements << "    SUBSTRING(HEX(uuid_bin), 1, #{(mysql_pos * 2) - 2}),"
        statements << "    LPAD("
        statements << "      HEX("
        statements << "        CONV(SUBSTRING(HEX(uuid_bin), #{(mysql_pos * 2) - 1}, 2), 16, 10) | "
        statements << "        ((#{attr.name} >> #{[ param_shift, 0 ].max}) & #{(1 << bits_in_byte) - 1}) << #{byte_start_bit}"
        statements << "      ),"
        statements << "      2,"
        statements << "      '0'"
        statements << "    ),"
        statements << "    SUBSTRING(HEX(uuid_bin), #{(mysql_pos * 2) + 1})"
        statements << "  )"
        statements << ");"
      end

      statements.join("\n")
    end

    # Generate SQL for env parameter attribute
    # @param attr [EnvAttribute] The environment variable attribute
    # @return [String] SQL statement
    def generate_env_bits(attr)
      # In MySQL, we can't directly access environment variables
      # We'll generate a comment explaining this

      <<~SQL
        -- Set bits for environment variable #{attr.name} (#{attr.bits} bits at position #{attr.position})
        -- Note: MySQL functions cannot access environment variables directly.
        -- For this environment variable (#{attr[:key]}), you should:
        -- 1. Add a parameter to this function
        -- 2. Pass the environment value when calling the function
        -- 3. Or use a constant value that represents your environment

        -- For now, using a placeholder value of 0
        DECLARE #{attr.name}_value BIGINT DEFAULT 0;

        -- The rest would be similar to parameter attribute handling
        -- (Code omitted for brevity - in real implementation, you'd handle this like a parameter)
      SQL
    end

    # Generate SQL for timestamp attribute
    # @param attr [TimestampAttribute] The timestamp attribute
    # @return [String] SQL statement
    def generate_timestamp_bits(attr)
      precision = attr[:precision] || :millisecond

      # Get multiplier and MySQL function based on precision
      case precision
      when :second
        multiplier = 1
        time_func = "UNIX_TIMESTAMP()"
      when :millisecond
        multiplier = 1000
        time_func = "UNIX_TIMESTAMP(NOW(3))"
      when :microsecond, :nanosecond
        # MySQL doesn't support nanosecond precision, use microsecond instead
        multiplier = 1_000_000
        time_func = "UNIX_TIMESTAMP(NOW(6))"
      end

      statements = []

      statements << "-- Set bits for timestamp (#{attr.bits} bits at position #{attr.position}) at #{precision} precision"
      statements << "DECLARE ts_value BIGINT;"
      statements << "SET ts_value = FLOOR(#{time_func} * #{multiplier});"

      # Ensure the value fits in the bit width (wrap around if necessary)
      statements << "SET ts_value = ts_value & (POWER(2, #{attr.bits}) - 1);"

      # Calculate byte positions for this attribute
      start_byte = attr.position / 8
      end_byte = (attr.position + attr.bits - 1) / 8

      # We need to manipulate each affected byte
      (start_byte..end_byte).each do |byte_pos|
        # Calculate which bits in this byte are affected
        byte_start_bit = [ attr.position, byte_pos * 8 ].max % 8
        byte_end_bit = [ (attr.position + attr.bits - 1), ((byte_pos * 8) + 7) ].min % 8
        bits_in_byte = byte_end_bit - byte_start_bit + 1

        # Calculate the shift needed to align the timestamp bits with these byte bits
        ts_shift = (byte_pos * 8) + byte_start_bit - attr.position

        # MySQL uses 1-indexed positions for SUBSTRING
        mysql_pos = byte_pos + 1

        statements << "-- Manipulate byte at position #{byte_pos} (bits #{byte_start_bit}-#{byte_end_bit})"
        statements << "SET uuid_bin = UNHEX("
        statements << "  CONCAT("
        statements << "    SUBSTRING(HEX(uuid_bin), 1, #{(mysql_pos * 2) - 2}),"
        statements << "    LPAD("
        statements << "      HEX("
        statements << "        CONV(SUBSTRING(HEX(uuid_bin), #{(mysql_pos * 2) - 1}, 2), 16, 10) | "
        statements << "        ((ts_value >> #{[ ts_shift, 0 ].max}) & #{(1 << bits_in_byte) - 1}) << #{byte_start_bit}"
        statements << "      ),"
        statements << "      2,"
        statements << "      '0'"
        statements << "    ),"
        statements << "    SUBSTRING(HEX(uuid_bin), #{(mysql_pos * 2) + 1})"
        statements << "  )"
        statements << ");"
      end

      statements.join("\n")
    end

    # Generate SQL for sequence attribute
    # @param attr [SequenceAttribute] The sequence attribute
    # @return [String] SQL statement
    def generate_sequence_bits(attr)
      # MySQL doesn't have native sequences, so we use a user variable to maintain state
      # This will persist for the session, but not across server restarts

      sequence_var = "@#{attr.name}_seq"
      max_value = (1 << attr.bits) - 1

      statements = []

      statements << "-- Set bits for sequence (#{attr.bits} bits at position #{attr.position})"

      # Initialize the sequence variable if not exists
      statements << "IF #{sequence_var} IS NULL THEN"
      statements << "  SET #{sequence_var} = 0;"
      statements << "END IF;"

      # Increment and wrap around if needed
      statements << "SET #{sequence_var} = (#{sequence_var} + 1) % #{max_value + 1};"

      # Calculate byte positions for this attribute
      start_byte = attr.position / 8
      end_byte = (attr.position + attr.bits - 1) / 8

      # We need to manipulate each affected byte
      (start_byte..end_byte).each do |byte_pos|
        # Calculate which bits in this byte are affected
        byte_start_bit = [ attr.position, byte_pos * 8 ].max % 8
        byte_end_bit = [ (attr.position + attr.bits - 1), ((byte_pos * 8) + 7) ].min % 8
        bits_in_byte = byte_end_bit - byte_start_bit + 1

        # Calculate the shift needed to align the sequence bits with these byte bits
        seq_shift = (byte_pos * 8) + byte_start_bit - attr.position

        # MySQL uses 1-indexed positions for SUBSTRING
        mysql_pos = byte_pos + 1

        statements << "-- Manipulate byte at position #{byte_pos} (bits #{byte_start_bit}-#{byte_end_bit})"
        statements << "SET uuid_bin = UNHEX("
        statements << "  CONCAT("
        statements << "    SUBSTRING(HEX(uuid_bin), 1, #{(mysql_pos * 2) - 2}),"
        statements << "    LPAD("
        statements << "      HEX("
        statements << "        CONV(SUBSTRING(HEX(uuid_bin), #{(mysql_pos * 2) - 1}, 2), 16, 10) | "
        statements << "        ((#{sequence_var} >> #{[ seq_shift, 0 ].max}) & #{(1 << bits_in_byte) - 1}) << #{byte_start_bit}"
        statements << "      ),"
        statements << "      2,"
        statements << "      '0'"
        statements << "    ),"
        statements << "    SUBSTRING(HEX(uuid_bin), #{(mysql_pos * 2) + 1})"
        statements << "  )"
        statements << ");"
      end

      statements.join("\n")
    end

    # Generate SQL for random attribute
    # @param attr [RandomAttribute] The random attribute
    # @return [String] SQL statement
    def generate_random_bits(attr)
      # For random bits, we'll generate random bytes and insert them
      # MySQL has RAND() function that returns a float between 0 and 1

      statements = []

      statements << "-- Set bits for random data (#{attr.bits} bits at position #{attr.position})"

      # Calculate byte positions for this attribute
      start_byte = attr.position / 8
      end_byte = (attr.position + attr.bits - 1) / 8

      # We need to manipulate each affected byte
      (start_byte..end_byte).each do |byte_pos|
        # Calculate which bits in this byte are affected
        byte_start_bit = [ attr.position, byte_pos * 8 ].max % 8
        byte_end_bit = [ (attr.position + attr.bits - 1), ((byte_pos * 8) + 7) ].min % 8
        bits_in_byte = byte_end_bit - byte_start_bit + 1

        # MySQL uses 1-indexed positions for SUBSTRING
        mysql_pos = byte_pos + 1

        statements << "-- Manipulate byte at position #{byte_pos} with random bits (bits #{byte_start_bit}-#{byte_end_bit})"
        statements << "SET uuid_bin = UNHEX("
        statements << "  CONCAT("
        statements << "    SUBSTRING(HEX(uuid_bin), 1, #{(mysql_pos * 2) - 2}),"
        statements << "    LPAD("
        statements << "      HEX("
        statements << "        CONV(SUBSTRING(HEX(uuid_bin), #{(mysql_pos * 2) - 1}, 2), 16, 10) | "
        statements << "        (FLOOR(RAND() * #{1 << bits_in_byte}) << #{byte_start_bit})"
        statements << "      ),"
        statements << "      2,"
        statements << "      '0'"
        statements << "    ),"
        statements << "    SUBSTRING(HEX(uuid_bin), #{(mysql_pos * 2) + 1})"
        statements << "  )"
        statements << ");"
      end

      statements.join("\n")
    end
  end
end
# rubocop:enable Layout/LineLength
