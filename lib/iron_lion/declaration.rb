# frozen_string_literal: true

module IronLion
  # Turns one line of the format DSL (`tenant bits: 20`) into a validated
  # field prototype. Offsets are assigned later, by Format.
  module Declaration
    Proto = Data.define(:name, :kind, :bits, :options)

    # The keyword names the kind; its value is the width in bits, except for
    # the self-sizing kinds below.
    KIND_KEYWORDS = {
      bits: :value, time: :time, counter: :counter, random: :random,
      chars: :text, h3: :h3, geohash: :geohash
    }.freeze

    # Kinds declared by a precision people think in, which IronLion turns
    # into bits: `subdomain chars: 6`, `cell h3: 9`, `spot geohash: 8`.
    Sized = Data.define(:kind, :option, :unit, :range, :bits)

    SIZED = {
      chars: Sized.new(kind: :text, option: :chars, unit: "chars", range: 1..23, bits: ->(n) { Base36.bits(n) }),
      h3: Sized.new(kind: :h3, option: :resolution, unit: "resolution", range: H3::RESOLUTIONS,
                    bits: ->(n) { H3.bits(n) }),
      geohash: Sized.new(kind: :geohash, option: :chars, unit: "chars", range: Geohash::RESOLUTIONS,
                         bits: ->(n) { Geohash.bits(n) })
    }.freeze

    # Field names that carry built-in behaviour when declared with `bits:`.
    NAMED_KINDS = { created_at: :time, sequence: :counter, random: :random }.freeze

    # Fields that may be declared without a width.
    DEFAULT_BITS = { created_at: 48 }.freeze

    OPTIONS = {
      value: %i[from], text: %i[from], h3: %i[from], geohash: %i[from],
      time: %i[epoch], counter: [], random: []
    }.freeze
    MODEL_OPTIONS = %i[table].freeze

    NAME = /\A[a-z_][a-z0-9_]*\z/

    # A field becomes a reader on its ids, so it may not shadow methods ids
    # rely on. Harmless Object methods (display, format, ...) stay available.
    RESERVED = (
      %i[class hash send public_send object_id freeze frozen? dup clone itself then tap
         is_a? kind_of? instance_of? respond_to? nil? method methods] +
      BasicObject.public_instance_methods + Comparable.public_instance_methods
    ).freeze

    module_function

    def parse(name, options)
      validate_name!(name)
      keyword = kind_keyword(name, options)
      return parse_sized(name, keyword, options) if SIZED.key?(keyword)

      bits = keyword ? options[keyword] : DEFAULT_BITS[name]
      raise ConfigurationError, "#{name} needs a width, e.g. `#{name} bits: 16`" if bits.nil?

      kind = keyword.nil? || keyword == :bits ? NAMED_KINDS.fetch(name, :value) : KIND_KEYWORDS[keyword]
      validate_bits!(name, bits)
      Proto.new(name:, kind:, bits:, options: normalize(name, kind, options.except(*KIND_KEYWORDS.keys)))
    end

    # Self-sizing kinds work out their own bits from the declared precision.
    def parse_sized(name, keyword, options)
      sized = SIZED.fetch(keyword)
      size = options[keyword]

      unless size.is_a?(Integer) && sized.range.cover?(size)
        raise ConfigurationError,
              "#{name} must be #{keyword}: #{sized.range.min}..#{sized.range.max} (#{sized.unit}), not #{size.inspect}"
      end

      options = normalize(name, sized.kind, options.except(keyword)).merge(sized.option => size)
      Proto.new(name:, kind: sized.kind, bits: sized.bits.call(size), options:)
    end

    # Checks a whole format's declarations and settles their order: one
    # leading time field (implied if absent), at most one counter, and spare
    # bits absorbed by a trailing random field.
    def arrange(declarations)
      declarations = declarations.dup
      check_unique!(declarations)
      check_time!(declarations)
      declarations.unshift(implied_time) if declarations.none? { _1.kind == :time }
      counters = declarations.select { _1.kind == :counter }

      if counters.size > 1
        raise ConfigurationError, "a format has at most one counter; found #{counters.map(&:name).join(', ')}"
      end

      fill_remainder(declarations)
    end

    def check_unique!(declarations)
      duplicates = declarations.map(&:name).tally.select { |_, count| count > 1 }.keys
      raise ConfigurationError, "#{duplicates.join(', ')} declared more than once" unless duplicates.empty?
    end

    def check_time!(declarations)
      times = declarations.select { _1.kind == :time }
      raise ConfigurationError, "a format has one time field; found #{times.map(&:name).join(', ')}" if times.size > 1
      return if times.empty? || declarations.first.kind == :time

      raise ConfigurationError, "#{times.first.name} must be declared first: IronLion ids always sort by creation time"
    end

    def fill_remainder(declarations)
      used = declarations.sum(&:bits)
      spare = Layout::PAYLOAD_BITS - used

      if spare.negative?
        breakdown = declarations.map { "#{_1.name} #{_1.bits}" }.join(" + ")
        raise ConfigurationError,
              "#{breakdown} = #{used} bits, but a UUIDv8 holds #{Layout::PAYLOAD_BITS}; trim #{-spare}"
      end

      return declarations if spare.zero?

      if declarations.last.kind == :random
        last = declarations.pop
        declarations << last.with(bits: last.bits + spare)
      elsif declarations.any? { _1.name == :random }
        raise ConfigurationError, "#{spare} bits are spare; declare `random` last so it can absorb them"
      else
        declarations << implied_random(spare)
      end
    end

    def implied_time
      parse(:created_at, {})
    end

    def implied_random(bits)
      Proto.new(name: :random, kind: :random, bits:, options: {})
    end

    def validate_name!(name)
      unless name.to_s.match?(NAME)
        raise ConfigurationError, "#{name.inspect} is not a usable field name (use snake_case)"
      end
      return unless RESERVED.include?(name) || Id.public_method_defined?(name, false)

      raise ConfigurationError, "#{name} is reserved: ids already respond to ##{name}"
    end

    def kind_keyword(name, options)
      keywords = options.keys & KIND_KEYWORDS.keys
      return keywords.first if keywords.size <= 1

      raise ConfigurationError,
            "#{name} declares #{keywords.map { "#{_1}:" }.join(' and ')}; give it exactly one kind"
    end

    def validate_bits!(name, bits)
      return if bits.is_a?(Integer) && bits.between?(1, Layout::PAYLOAD_BITS)

      raise ConfigurationError, "#{name} must be 1..#{Layout::PAYLOAD_BITS} bits, not #{bits.inspect}"
    end

    def normalize(name, kind, options)
      allowed = OPTIONS.fetch(kind)
      allowed += MODEL_OPTIONS if kind == :value && name == :model
      unknown = options.keys - allowed

      unless unknown.empty?
        accepts = allowed.empty? ? "no options" : allowed.map { "#{_1}:" }.join(", ")
        raise ConfigurationError,
              "#{name} (#{kind}) does not understand #{unknown.map { "#{_1}:" }.join(', ')}; it accepts #{accepts}"
      end

      case kind
      when :time then { epoch_ms: epoch_ms(name, options.fetch(:epoch, 0)) }
      when :value, :text, :h3, :geohash then value_options(name, options)
      else {}
      end
    end

    def value_options(name, options)
      normalized = {}

      if options.key?(:from)
        from = options[:from]
        unless from.respond_to?(:call)
          raise ConfigurationError, "#{name} from: must be callable, e.g. -> { Current.#{name}_id }"
        end

        normalized[:from] = from
      end

      normalized[:table] = model_table(options[:table]) if name == :model
      normalized
    end

    def model_table(table)
      case table
      when ModelTable then table
      when nil then ModelTable.new
      when String, Pathname then ModelTable.new(table)
      else raise ConfigurationError, "model table: must be a path or an IronLion::ModelTable"
      end
    end

    def epoch_ms(name, epoch)
      case epoch
      when Integer then epoch
      when String then (Time.parse(epoch).to_r * 1000).floor
      else
        return (epoch.to_time.to_r * 1000).floor if epoch.respond_to?(:to_time)

        raise ConfigurationError, "#{name} epoch: must be a Time, a date string or Unix milliseconds"
      end
    rescue ArgumentError
      raise ConfigurationError, "#{name} epoch: #{epoch.inspect} is not a date"
    end
  end
end
