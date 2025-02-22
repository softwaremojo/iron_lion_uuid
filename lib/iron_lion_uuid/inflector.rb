# frozen_string_literal: true

require "dry/inflector"

class IronLionUUID
  class Inflector
    class << self
      def instance
        @instance ||= Dry::Inflector.new do |inflections|
          inflections.acronym "MySQL", "SQL", "UUID"
        end
      end

      private

      def method_missing(inflection, *args, &)
        return super unless instance.respond_to? inflection
        return new inflection if args.empty?

        instance.public_send inflection, *args, &
      end

      def respond_to_missing?(inflection, include_private = false)
        instance.respond_to? inflection, include_private or super
      end
    end

    def initialize(*args)
      @chain = args.flatten
    end

    def call(obj)
      @chain.reduce obj do |str, inflection|
        Inflector.public_send inflection, str
      end
    end

    alias [] call

    def chain(inflection)
      self.class.new @chain, inflection
    end

    private

    def method_missing(inflection, *args, &)
      return super unless Inflector.respond_to? inflection

      inflector = chain(inflection)
      return inflector if args.empty?

      inflector.call args.first
    end

    def respond_to_missing?(inflection, include_private = false)
      Inflector.respond_to?(inflection, include_private) or super
    end
  end
end
