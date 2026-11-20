# frozen_string_literal: true

module IronLion
  # Finds the value for a field, taking the first source that answers:
  #
  #   1. generate(tenant: 7)                      explicit
  #   2. record.iron_lion_tenant, #tenant_id, #tenant
  #                                               the record being identified
  #   3. tenant bits: 20, from: -> { ... }        a resolver in the format
  #   4. ENV["IRON_LION_TENANT"]                  the environment
  #
  # The `model` field reads the record's class instead of its attributes,
  # and accepts classes or class names as well as integers. A `geohash:`
  # field also accepts a record that has coordinates itself
  # (#latitude/#longitude, #lat/#lng or #lat/#lon).
  # nil never counts as an answer: it means "ask the next source".
  module Resolver
    module_function

    def resolve(field, record, values)
      value = values[field.name]
      value = from_record(field, record) if value.nil?
      value = from_resolver(field, record) if value.nil?
      value = from_env(field) if value.nil?
      raise MissingValueError, missing_message(field, record) if value.nil?

      fit!(field, encode(field, value))
    end

    def encode(field, value)
      if field.model? then model_id(field, value)
      elsif field.kind == :text then text(field, value)
      elsif field.kind == :h3 then spatial(field, value) { H3.encode(value, field.options[:resolution]) }
      elsif field.kind == :geohash then spatial(field, value) { Geohash.encode(value, field.options[:chars]) }
      else integer(field, value)
      end
    end

    def env_key(field) = "IRON_LION_#{field.name.upcase}"

    def record_methods(field)
      return ["iron_lion_#{field.name}"] if field.model?
      return ["iron_lion_#{field.name}", field.name.to_s] if spatial?(field)

      ["iron_lion_#{field.name}", "#{field.name}_id", field.name.to_s]
    end

    def from_record(field, record)
      return if record.nil?

      value = from_attributes(field, record)
      return value unless value.nil?
      return record.class if field.model?

      record if field.kind == :geohash && Geohash.coordinates(record)
    end

    def from_attributes(field, record)
      record_methods(field).each do |method|
        next unless record.respond_to?(method)

        value = record.public_send(method)
        return value unless value.nil?
      end

      nil
    end

    def spatial?(field) = %i[h3 geohash].include?(field.kind)

    def from_resolver(field, record)
      from = field.options[:from] or return
      from.arity.zero? ? from.call : from.call(record)
    end

    def from_env(field)
      raw = ENV.fetch(env_key(field), nil) or return
      field.kind == :value ? Integer(raw, 10) : raw
    rescue ArgumentError
      raise InvalidValueError, "ENV[#{env_key(field).inspect}] is #{raw.inspect}; #{field.name} needs an integer"
    end

    def integer(field, value)
      return value if value.is_a?(Integer)
      return Integer(value, 10) if value.is_a?(String) && value.match?(/\A\d+\z/)
      return integer(field, value.id) if value.respond_to?(:id) && !value.id.nil?

      raise InvalidValueError,
            "#{field.name} must be an integer (or something with an integer #id), not #{value.inspect}"
    end

    def text(field, value)
      return text(field, value.id) if !value.is_a?(String) && !value.is_a?(Symbol) && value.respond_to?(:id)

      Base36.encode(value, field.options[:chars])
    rescue ArgumentError => e
      raise InvalidValueError, "#{field.name} #{value.inspect} #{e.message}"
    end

    def spatial(field, value)
      yield
    rescue ArgumentError => e
      raise InvalidValueError, "#{field.name} #{value.inspect} #{e.message}"
    end

    def model_id(field, value)
      case value
      when Integer then value
      when Module
        return value.iron_lion_model_id if value.respond_to?(:iron_lion_model_id)
        raise InvalidValueError, "#{value.inspect} is anonymous; only named classes get model ids" unless value.name

        field.options[:table].id_for(value.name, capacity: field.max)
      when String, Symbol then field.options[:table].id_for(value.to_s, capacity: field.max)
      else model_id(field, value.class)
      end
    end

    def fit!(field, value)
      return value if value.between?(0, field.max)

      raise OverflowError, "#{field.name} #{value} does not fit in #{field.bits} bits (0..#{field.max})"
    end

    def missing_message(field, record)
      name = field.name
      record_hint =
        if record.nil? then "(no record was passed)"
        else
          hint = "#{record.class}##{record_methods(field).join(', #')}"
          field.kind == :geohash ? "#{hint}, or its own #latitude/#longitude" : hint
        end
      resolver_hint = field.options[:from] ? "(it returned nil)" : "(none configured)"
      <<~MESSAGE.chomp
        No value for #{name}. IronLion looked in:
          1. IronLion.generate(#{name}: ...)
          2. the record: #{record_hint}
          3. a resolver: `#{name} #{field.declared_width}, from: -> { ... }` #{resolver_hint}
          4. ENV[#{env_key(field).inspect}]
      MESSAGE
    end
  end
end
