# frozen_string_literal: true

module IronLionUUID
  # Generates SQL functions for database-side UUID generation
  # that match the Ruby-side configuration
  class SQLGenerator
    ADAPTERS = %i[ postgresql mysql sqlite ].freeze

    # Create a generator for the specified adapter
    # @param adapter [Symbol] The database adapter
    #   (:postgresql, :mysql, :sqlite)
    # @param configuration [Configuration] The UUID configuration
    # @return [SQLGenerator] The appropriate generator
    def self.for_adapter(adapter, configuration = nil)
      case adapter.to_sym
      when :postgresql
        PostgreSQLGenerator.new(configuration)
      when :mysql
        MySQLGenerator.new(configuration)
      when :sqlite
        SQLiteGenerator.new(configuration)
      else
        raise ArgumentError, <<~MESSAGE.tr("\n", " ")
          Unsupported database adapter: #{adapter}.
          Supported adapters: #{ADAPTERS.join(', ')}
        MESSAGE
      end
    end

    # Initialize a new SQLGenerator
    # @param adapter [Symbol] The database adapter
    #   (:postgresql, :mysql, :sqlite)
    # @param configuration [Configuration] The UUID configuration
    # @raise [ArgumentError] If the adapter is not supported
    def initialize(adapter, configuration = nil)
      unless ADAPTERS.include?(adapter)
        raise ArgumentError, <<~MESSAGE.tr("\n", " ")
          Unsupported database adapter: #{adapter}.
          Supported adapters: #{ADAPTERS.join(', ')}
        MESSAGE
      end

      @adapter = adapter
      @configuration = configuration || IronLionUUID.configuration

      # Ensure configuration exists
      raise ConfigurationError, "UUID structure not configured" unless @configuration

      # Options for function generation
      @options = {}
    end

    # Generate SQL function for the configured UUID structure
    # @param options [Hash] Options for function generation
    # @option options [String] :function_name Name of the function
    #   (default: 'generate_iron_lion_uuid')
    # @option options [String] :schema Schema name for PostgreSQL
    #   (default: 'public')
    # @option options [Boolean] :binary_output Generate binary UUIDs for MySQL
    #   (default: false)
    # @return [String] The generated SQL function
    def generate_function(**options)
      @options = {
        function_name: "generate_iron_lion_uuid",
        schema: "public",
        binary_output: false
      }.merge(options)

      # Delegate to database-specific implementation
      method_name = :"generate_#{@adapter}_function"

      unless respond_to? method_name
        raise ArgumentError, "Unsupported database adapter: #{@adapter}"
      end

      __send__ method_name, @options
    end

    # Generate drop statement for the function
    # @param options [Hash] Options for function dropping
    # @option options [String] :function_name Name of the function
    #   (default: 'generate_iron_lion_uuid')
    # @option options [String] :schema Schema name for PostgreSQL
    #   (default: 'public')
    # @return [String] The SQL drop statement
    def generate_drop_function(**options)
      @options = {
        function_name: "generate_iron_lion_uuid",
        schema: "public"
      }.merge(options)

      # Delegate to database-specific implementation
      method_name = :"drop_#{@adapter}_function"

      unless respond_to? method_name
        raise ArgumentError, "Unsupported database adapter: #{@adapter}"
      end

      __send__ method_name, @options
    end

    protected

    # Access options within the class
    attr_reader :options

    private

    # Generate parameter list for function declaration
    # @return [Array<String>] Array of parameter declarations
    def parameter_declarations
      # Extract parameter attributes
      param_attributes = @configuration.attributes_of_type(:parameter)

      # Generate parameter declarations
      param_attributes.map do |attr|
        # Parameter name and type
        case @adapter
        when :postgresql, :sqlite
          "#{attr.name} INTEGER"
        when :mysql
          "#{attr.name} BIGINT UNSIGNED"
        end
      end
    end

    # Generate parameter list for function call
    # @return [String] Comma-separated parameter names
    def parameter_names
      # Extract parameter attributes
      param_attributes = @configuration.attributes_of_type(:parameter)

      # Generate parameter names
      param_attributes.map(&:name).join(", ")
    end

    # Get all attributes in correct order
    # @return [Array<Attribute>] Ordered attributes
    def ordered_attributes
      # Sort attributes by position
      @configuration.attributes.sort_by(&:position)
    end

    # PostgreSQL function generation (placeholder)
    def generate_postgresql_function(options)
      raise NotImplementedError, "PostgreSQL function generation not implemented"
    end

    # MySQL function generation (placeholder)
    def generate_mysql_function(options)
      raise NotImplementedError, "MySQL function generation not implemented"
    end

    # SQLite function generation (placeholder)
    def generate_sqlite_function(options)
      raise NotImplementedError, "SQLite function generation not implemented"
    end

    # Drop PostgreSQL function (placeholder)
    def drop_postgresql_function(options)
      raise NotImplementedError, "PostgreSQL function dropping not implemented"
    end

    # Drop MySQL function (placeholder)
    def drop_mysql_function(options)
      raise NotImplementedError, "MySQL function dropping not implemented"
    end

    # Drop SQLite function (placeholder)
    def drop_sqlite_function(options)
      raise NotImplementedError, "SQLite function dropping not implemented"
    end
  end
end
