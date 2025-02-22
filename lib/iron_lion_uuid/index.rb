# frozen_string_literal: true

class IronLionUUID
  # Index class manages the registry of components that make up a UUID
  # definition. It tracks the bit allocation of each component and
  # ensures the total bits don't exceed the maximum allowed (122 bits).
  # It also provides validation for component uniqueness and space constraints.
  class Index
    MAX_BITS        = 122
    VERSION_VARIANT = (8 << 76) | (2 << 62)
    HIGH_MASK       = 0xffffffff_ffff
    MID_MASK        = 0xfff
    LOW_MASK        = 0x3fff_ffffffffffff

    def initialize
      @components = {}
    end

    def iron_lion_uuid(*args, sql: false)
      return select_function_sql(*args) if sql

      args = args.dup

      big_int, pool = components.inject([ 0, MAX_BITS ]) do |(id, pool), component|
        pool -= component.bits
        arg = args.shift if component.parameter?
        id |= component.call(arg) << pool
        [ id, pool ]
      end

      warn "pool should be 0, is #{pool}" unless pool.zero?

      # Get first 48 bits of big_int and shift left in front of the VERSION
      high = (big_int & (HIGH_MASK << 74)) << 6
      # Get the next 12 bits and shift left in front of the VARIANT
      mid  = (big_int & (MID_MASK << 62)) << 2
      # Get the last 62 bits
      low  = big_int & LOW_MASK

      IronLionUUID.new(int_to_uuid(VERSION_VARIANT | high | mid | low))
    end

    def components
      @components.values
    end

    def params
      @params ||= components.select(&:parameter?)
    end

    def <<(component)
      warn "Redefining #{component}"     if exists?     component
      warn "#{component} over bit limit" if over_limit? component

      @components[component.name] = component
    end

    def rationalize!
      remainder = MAX_BITS - size

      if remainder.positive?
        zero_bit_components = components.select(&:zero_bits?)

        if zero_bit_components.any?
          slice = remainder / zero_bit_components.count
          extra = remainder % zero_bit_components.count

          zero_bit_components.each_with_index do |component, index|
            component.bits += slice + (index < extra ? 1 : 0)
          end
        else
          components.last.bits += remainder
        end
      elsif remainder.negative?
        components.reverse_each do |component|
          next if component.zero_bits?

          if component.bits < remainder.abs
            # We still have too many bits assigned
            remainder += component.bits
            component.bits = 0
          else
            component.bits += remainder
            break
          end
        end
      end

      @components.reject! do |_, component|
        if component.zero_bits?
          warn "#{component} with 0 bits was removed"
          true
        end
      end

      @components.inject(0) do |index, (key, component)|
        IronLionUUID.define_getter key, index, component.bits
        index += component.bits
      end
    end

    def size
      components.sum(&:bits)
    end

    def sql_dependencies(adapter)
      components.map do |component|
        component.sql_dependency adapter
      end.join("\n")
    end

    def sql_values(adapter)
      components.map do |component|
        component.sql_value adapter
      end
    end

    private

      def select_function_sql(*args)
        raise ArgumentError if args.count != params.count

        args = args.dup

        <<~SQL.tr("\n", "")
          SELECT iron_lion_uuid(
          #{params.map { |component| component.call args.shift }.join(', ')}
          );
        SQL
      end

      def exists?(component)
        @components.key? component.name
      end

      def over_limit?(component)
        size + component.bits > MAX_BITS
      end

      def int_to_uuid(id)
        raw_uuid = id.to_s(16).downcase.rjust(32, "0")
        raw_uuid.scan(/(.{8})(.{4})(.{4})(.{4})(.{12})/).join("-")
      end

      def debug(value)
        format("%2d: #{value.to_s(16)}", value.to_s(2).length)
        # pp((value.to_s(2).length - 1) => value.to_s(16))
      end
  end
end
