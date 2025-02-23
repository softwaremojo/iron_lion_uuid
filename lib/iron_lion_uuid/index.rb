# frozen_string_literal: true

require "forwardable"

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

    extend Forwardable

    attr_reader :component_map

    def_delegators :@component_map, :[], :[]=, :values, :key?

    def initialize
      @component_map = {}
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
      values # delegated to @component_map.values
    end

    def params
      @params ||= components.select(&:parameter?)
    end

    def <<(component)
      warn "Redefining #{component}"     if exists?     component
      warn "#{component} over bit limit" if over_limit? component

      self[component.name] = component # delegated to @component_map.[]=
    end

    def validate!
      return unless (size - MAX_BITS).positive?

        raise ArgumentError,
              "Total bits (#{size}) exceeds maximum allowed bits (#{MAX_BITS})"
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
        key? component.name # delegated to @component_map.key?
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
