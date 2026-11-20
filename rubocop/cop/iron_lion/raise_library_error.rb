# frozen_string_literal: true

module RuboCop
  module Cop
    module IronLion
      # Every failure from IronLion's public API is an IronLion::Error, so
      # `rescue IronLion::Error` catches all of them. This cop flags raising a
      # core Ruby exception, or a bare string (a RuntimeError), in lib/.
      #
      # @example
      #   # bad
      #   raise ArgumentError, "unknown field :tenat"
      #   raise "unknown field :tenat"
      #
      #   # good
      #   raise UnknownFieldError, "unknown field :tenat"
      #   raise # re-raising the current exception
      class RaiseLibraryError < Base
        MSG = "Raise an IronLion::Error subclass (see lib/iron_lion/errors.rb), not %<raised>s."

        RESTRICT_ON_SEND = %i[raise fail].freeze

        # Ruby's own exception classes. Listed by hand rather than read from
        # Object.constants, where gems add top-level classes such as racc's
        # ParseError that would shadow IronLion's.
        CORE_EXCEPTIONS = %i[
          Exception ScriptError LoadError NotImplementedError SyntaxError
          SecurityError SignalException Interrupt SystemExit SystemStackError NoMemoryError
          StandardError RuntimeError FrozenError ArgumentError UncaughtThrowError
          EncodingError FiberError IOError EOFError IndexError KeyError StopIteration
          ClosedQueueError LocalJumpError NameError NoMethodError RangeError FloatDomainError
          RegexpError SystemCallError ThreadError TypeError ZeroDivisionError
          NoMatchingPatternError NoMatchingPatternKeyError
        ].to_set.freeze

        def on_send(node)
          return unless node.receiver.nil?

          raised = node.first_argument
          return if raised.nil?

          description = core_exception(raised)
          return if description.nil?

          add_offense(node, message: format(MSG, raised: description))
        end

        private

        # A description of the core exception `raised` names, or nil when it
        # names something else.
        def core_exception(raised)
          return "a bare string" if raised.str_type? || raised.dstr_type?

          name = top_level_constant(exception_class(raised))
          name.to_s if CORE_EXCEPTIONS.include?(name)
        end

        # `ArgumentError.new("...")` raises ArgumentError.
        def exception_class(raised)
          if raised.send_type? && raised.method?(:new)
            raised.receiver
          else
            raised
          end
        end

        # The name of `node` when it is a constant such as `KeyError` or
        # `::KeyError`; nil for `IronLion::KeyError` or anything else.
        def top_level_constant(node)
          return unless node&.const_type?
          return unless node.namespace.nil? || node.namespace.cbase_type?

          node.short_name
        end
      end
    end
  end
end
