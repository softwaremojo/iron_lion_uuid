# frozen_string_literal: true

module IronLion
  # A minted or parsed id. Each format has its own subclass with a reader
  # per field, so `id.tenant` and `id[:tenant]` both work.
  #
  # Ids compare by their 128-bit value, which is creation order.
  class Id
    include Comparable

    attr_reader :format

    def initialize(format, uuid)
      @format = format
      @uuid = uuid
      @payload = Layout.to_payload(uuid)
      freeze
    end

    def to_i = @uuid

    def to_s = Layout.hyphenate(@uuid)
    alias to_str to_s

    def [](name) = format.read(@payload, name.to_sym)

    def to_h = format.fields.to_h { [_1.name, self[_1.name]] }

    def <=>(other)
      to_i <=> other.to_i if other.is_a?(Id)
    end

    def ==(other)
      other.is_a?(Id) && to_i == other.to_i
    end
    alias eql? ==

    def hash = [Id, @uuid].hash

    def inspect
      shown = format.fields.reject { _1.kind == :random }
      details = shown.map { |field| "#{field.name}=#{show(self[field.name])}" }
      "#<IronLion::Id #{self} #{details.join(' ')}>"
    end

    private

    def show(value)
      case value
      when Time then value.strftime("%Y-%m-%d %H:%M:%S.%L UTC")
      when Module then value.name
      when Location then value.geohash
      else value.inspect
      end
    end
  end
end
