# frozen_string_literal: true

module IronLion
  # The receiver of a format block. Every method call is a field declaration,
  # name first: `tenant bits: 20`. It inherits from BasicObject so that
  # ordinary names (hash, format, display, ...) are free to be fields.
  class Builder < BasicObject
    def self.build(&block)
      ::Kernel.raise ::IronLion::ConfigurationError, "a format needs a block of field declarations" unless block

      builder = new
      block.arity == 1 ? yield(builder) : builder.instance_eval(&block)
      ::IronLion::Format.new(builder.__declarations__)
    end

    def initialize
      @declarations = []
    end

    def __declarations__
      @declarations
    end

    def method_missing(name, *args, **options, &block)
      unless args.empty? && block.nil?
        ::Kernel.raise ::IronLion::ConfigurationError,
                       "declare fields as `#{name} bits: 16`; positional arguments and blocks are not accepted"
      end

      @declarations << ::IronLion::Declaration.parse(name, options)
      nil
    end

    def respond_to_missing?(*)
      true
    end
  end
end
