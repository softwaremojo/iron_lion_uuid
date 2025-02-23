# frozen_string_literal: true

require "yaml"
require_relative "inflector"

class IronLionUUID
  # Component module provides the building blocks for constructing UUIDs.
  # It contains various component types (Time, Sequence, etc.) that can be
  # combined to create custom UUID formats. Each component represents a
  # specific part of the UUID and handles its own data conversion and validation.
  class Component
    RADIX = 36

    autoload :Envar,     "iron_lion_uuid/component/envar"
    autoload :Parameter, "iron_lion_uuid/component/parameter"
    autoload :Random,    "iron_lion_uuid/component/random"
    autoload :Sequence,  "iron_lion_uuid/component/sequence"
    autoload :Timestamp, "iron_lion_uuid/component/timestamp"

    class << self
      def create(type, options = {})
        const_get(Inflector.classify(type)).then do |klass|
          klass.new(**options)
        end
      end

      def exists?(type)
        const_defined? Inflector.classify(type)
      end
    end

    attr_reader :type, :name, :bits, :encoded, :options

    def initialize(**options)
      @type = Inflector.demodulize.underscore(self.class.name).to_sym
      @name = options[:name] || @type
      @bits = [ 0, options[:bits].to_i ].max
      @encoded = options.key?(:encoded) ? options[:encoded] : false
      @options = options.except(:name, :bits, :encoded)
    end

    def to_s
      "Component `#{name}`"
    end

    def call(arg = nil)
      result = value
      result = result.call(arg) if result.is_a? Proc

      puts "#{self}: #{result.to_s(16)} of #{max_value.to_s(16)}"
      result % max_value
    end

    def sql_value(adapter)
      template = end_block[adapter]

      if template[:value]
        "#{template[:value]} % #{max_value}"
      else
        template.fetch(:raw_sql, value)
      end
    end

    def sql_dependency(adapter)
      end_block[adapter][:dependency]
    end

    def parameter?
      is_a? Parameter
    end

    def bits=(num)
      num = [ 0, num.to_i ].max
      warn "Component '#{name}' was assigned #{num} bits"
      @bits = num
    end

    def zero_bits?
      bits.zero?
    end

    def max_value
      (1 << bits)
    end

    def bit_mask
      max_value - 1
    end

    def quarter_bits
      bits / 4
    end

    private

      def end_block(matcher = 1)
        file = matcher.respond_to?(:to_path) ? match.to_path : caller_file(matcher)

        Marshal.load(
          Marshal.dump(
            YAML.safe_load(
              File.read(file).split(/^__END__$/, 2)[1] || "{}",
              permitted_classes: [ Regexp, Symbol ],
              symbolize_names: true
            )
          )
        )
      end

      def caller_file(index)
        if index.is_a? Integer
          caller_locations[index]
        else
          caller_locations.find do |location|
            index.match location.absolute_path
          end
        end.absolute_path
      end
  end
end
