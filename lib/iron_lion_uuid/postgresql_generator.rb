# frozen_string_literal: true

module IronLionUUID
  # PostgreSQL-specific UUID function generator
  class PostgreSQLGenerator < SQLGenerator
    PRECISION_MULTIPLIERS = {
      second: 1,
      millisecond: 1_000,
      microsecond: 1_000_000,
      nanosecond: 1_000_000_000
    }.freeze

    def initialize(configuration = nil)
      super(:postgresql, configuration)
    end

    private

    # Generate PostgreSQL function for UUID generation
    # @param options [Hash] Options for function generation
    # @return [String] The generated SQL function
    def generate_postgresql_function(options)
      function_name = options[:function_name]
      schema = options[:schema]
      qualified_name = "#{schema}.#{function_name}"

      # Get parameter declarations
      params = parameter_declarations
      param_string = params.empty? ? "" : params.join(", ")

      # Build the function
      <<~SQL
        CREATE OR REPLACE FUNCTION #{qualified_name}(#{param_string})
        RETURNS UUID AS $$
        DECLARE
          uuid_value BYTEA;
          result UUID;
        BEGIN
          -- Start with all zeros
          -- Initialize uuid_value with all zeros (16 bytes)
          uuid_value := '\\x00000000000000000000000000000000'::BYTEA;

          -- Set version bits (UUID v8)
          uuid_value := set_bit(uuid_value, 48, 1);
          uuid_value := set_bit(uuid_value, 49, 0);
          uuid_value := set_bit(uuid_value, 50, 0);
          uuid_value := set_bit(uuid_value, 51, 0);

          -- Set variant bits (RFC 4122)
          uuid_value := set_bit(uuid_value, 64, 1);
          uuid_value := set_bit(uuid_value, 65, 0);

          #{generate_attribute_bits}

          -- Convert to UUID
          result := uuid_send(uuid_value);

          RETURN result;
        END;
        $$ LANGUAGE plpgsql;
      SQL
    end

    # Generate SQL for dropping the PostgreSQL function
    # @param options [Hash] Options for function dropping
    # @return [String] The SQL drop statement
    def drop_postgresql_function(options)
      function_name = options[:function_name]
      schema = options[:schema]
      qualified_name = "#{schema}.#{function_name}"

      # Get parameter types
      param_types = parameter_declarations.map { |decl| decl.split.last }
      param_types_string = param_types.empty? ? "" : "(#{param_types.join(', ')})"

      # Build the drop statement
      <<~SQL
        DROP FUNCTION IF EXISTS #{qualified_name}#{param_types_string};
      SQL
    end

    # Generate SQL statements for setting attribute bits
    # @return [String] SQL statements
    def generate_attribute_bits
      statements = []

      ordered_attributes.each do |attr|
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
      end

      statements.join("\n\n")
    end

    # Generate SQL for parameter attribute
    # @param attr [ParameterAttribute] The parameter attribute
    # @return [String] SQL statement
    def generate_parameter_bits(attr)
      <<~SQL
        -- Set bits for parameter #{attr.name} (#{attr.bits} bits at position #{attr.position})
        BEGIN
          DECLARE
            value_to_set BIGINT;
            bit_position INTEGER;
          BEGIN
            -- Use parameter value
            value_to_set := #{attr.name};

            -- Check if value exceeds bit width
            IF value_to_set >= POWER(2, #{attr.bits}) THEN
              RAISE EXCEPTION 'Value % exceeds maximum (%) for % bits',
                              value_to_set, POWER(2, #{attr.bits}) - 1, #{attr.bits};
            END IF;

            -- Set bits
            FOR bit_position IN 0..#{attr.bits - 1} LOOP
              -- Check if bit is set in the value
              IF (value_to_set & (1::BIGINT << bit_position)) != 0 THEN
                uuid_value := set_bit(uuid_value, #{attr.position} + bit_position, 1);
              ELSE
                uuid_value := set_bit(uuid_value, #{attr.position} + bit_position, 0);
              END IF;
            END LOOP;
          END;
        END;
      SQL
    end

    # Generate SQL for env parameter attribute
    # @param attr [EnvAttribute] The environment variable attribute
    # @return [String] SQL statement
    def generate_env_bits(attr)
      # In PostgreSQL, env variables are handled by adding a parameter
      # We add a comment explaining that env values need to be passed to the function

      <<~SQL
        -- Set bits for environment variable #{attr.name} (#{attr.bits} bits at position #{attr.position})
        -- Note: In SQL functions, environment variables must be passed as parameters
        BEGIN
          DECLARE
            value_to_set BIGINT;
            bit_position INTEGER;
          BEGIN
            -- This would normally read from ENV['#{attr[:key]}'], but in SQL we need it as a parameter
            -- For this example, we'll set a placeholder value of 0
            -- In practice, you should add a parameter for this value or use a known constant
            value_to_set := 0; -- PLACEHOLDER: Replace with a parameter value

            -- Check if value exceeds bit width
            IF value_to_set >= POWER(2, #{attr.bits}) THEN
              RAISE EXCEPTION 'Value % exceeds maximum (%) for % bits',
                              value_to_set, POWER(2, #{attr.bits}) - 1, #{attr.bits};
            END IF;

            -- Set bits
            FOR bit_position IN 0..#{attr.bits - 1} LOOP
              -- Check if bit is set in the value
              IF (value_to_set & (1::BIGINT << bit_position)) != 0 THEN
                uuid_value := set_bit(uuid_value, #{attr.position} + bit_position, 1);
              ELSE
                uuid_value := set_bit(uuid_value, #{attr.position} + bit_position, 0);
              END IF;
            END LOOP;
          END;
        END;
      SQL
    end

    # Generate SQL for timestamp attribute
    # @param attr [TimestampAttribute] The timestamp attribute
    # @return [String] SQL statement
    def generate_timestamp_bits(attr)
      precision = attr[:precision] || :millisecond

      # Get multiplier based on precision
      multiplier = PRECISION_MULTIPLIERS[precision]

      <<~SQL
        -- Set bits for timestamp (#{attr.bits} bits at position #{attr.position})
        BEGIN
          DECLARE
            ts_value BIGINT;
            bit_position INTEGER;
          BEGIN
            -- Get current timestamp at #{precision} precision
            ts_value := (EXTRACT(EPOCH FROM CURRENT_TIMESTAMP) * #{multiplier})::BIGINT;

            -- Ensure it fits in the bit width (wrap around if necessary)
            ts_value := ts_value & (POWER(2, #{attr.bits}) - 1);

            -- Set bits
            FOR bit_position IN 0..#{attr.bits - 1} LOOP
              -- Check if bit is set in the timestamp
              IF (ts_value & (1::BIGINT << bit_position)) != 0 THEN
                uuid_value := set_bit(uuid_value, #{attr.position} + bit_position, 1);
              ELSE
                uuid_value := set_bit(uuid_value, #{attr.position} + bit_position, 0);
              END IF;
            END LOOP;
          END;
        END;
      SQL
    end

    # Generate SQL for sequence attribute
    # @param attr [SequenceAttribute] The sequence attribute
    # @return [String] SQL statement
    def generate_sequence_bits(attr)
      function_name = options[:function_name] || "generate_iron_lion_uuid"
      sequence_name = "#{function_name}_seq_#{attr.name}"

      <<~SQL
        -- Set bits for sequence (#{attr.bits} bits at position #{attr.position})
        BEGIN
          DECLARE
            seq_value BIGINT;
            bit_position INTEGER;
          BEGIN
            -- Create sequence if it doesn't exist
            EXECUTE 'CREATE SEQUENCE IF NOT EXISTS #{sequence_name} CYCLE MAXVALUE ' || (POWER(2, #{attr.bits}) - 1);

            -- Get next value from sequence
            EXECUTE 'SELECT nextval(''#{sequence_name}'')' INTO seq_value;

            -- Set bits
            FOR bit_position IN 0..#{attr.bits - 1} LOOP
              -- Check if bit is set in the sequence value
              IF (seq_value & (1::BIGINT << bit_position)) != 0 THEN
                uuid_value := set_bit(uuid_value, #{attr.position} + bit_position, 1);
              ELSE
                uuid_value := set_bit(uuid_value, #{attr.position} + bit_position, 0);
              END IF;
            END LOOP;
          END;
        END;
      SQL
    end

    # Generate SQL for random attribute
    # @param attr [RandomAttribute] The random attribute
    # @return [String] SQL statement
    def generate_random_bits(attr)
      <<~SQL
        -- Set bits for random data (#{attr.bits} bits at position #{attr.position})
        BEGIN
          DECLARE
            bit_position INTEGER;
          BEGIN
            -- Set random bits
            FOR bit_position IN 0..#{attr.bits - 1} LOOP
              -- Generate random bit (0 or 1)
              IF random() > 0.5 THEN
                uuid_value := set_bit(uuid_value, #{attr.position} + bit_position, 1);
              ELSE
                uuid_value := set_bit(uuid_value, #{attr.position} + bit_position, 0);
              END IF;
            END LOOP;
          END;
        END;
      SQL
    end
  end
end
