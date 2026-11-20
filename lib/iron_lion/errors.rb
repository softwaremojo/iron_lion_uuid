# frozen_string_literal: true

module IronLion
  class Error < StandardError; end

  # The format declaration is invalid.
  class ConfigurationError < Error; end

  # IronLion.configure has not been called.
  class NotConfiguredError < ConfigurationError; end

  # A field name is not one of the format's fields.
  class UnknownFieldError < Error; end

  # No source could supply a value for a field.
  class MissingValueError < Error; end

  # A value was supplied but is not something the field can hold.
  class InvalidValueError < Error; end

  # A value does not fit in its field's bits.
  class OverflowError < InvalidValueError; end

  # The input is not an IronLion (UUIDv8) id.
  class ParseError < Error; end

  # A model has no id and the model table is not allowed to assign one.
  class UnknownModelError < Error; end
end
