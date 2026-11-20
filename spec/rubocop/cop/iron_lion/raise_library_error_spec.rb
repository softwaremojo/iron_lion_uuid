# frozen_string_literal: true

require "rubocop"
require "rubocop/rspec/support"
require_relative "../../../../rubocop/cop/iron_lion/raise_library_error"

RSpec.describe RuboCop::Cop::IronLion::RaiseLibraryError, :config do
  include RuboCop::RSpec::ExpectOffense

  it "flags raising a core exception" do
    expect_offense(<<~RUBY)
      raise ArgumentError, "unknown field"
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Raise an IronLion::Error subclass (see lib/iron_lion/errors.rb), not ArgumentError.
    RUBY
  end

  it "flags fail, top-level constants and .new" do
    expect_offense(<<~RUBY)
      fail ::KeyError, "no field"
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^ Raise an IronLion::Error subclass (see lib/iron_lion/errors.rb), not KeyError.
      raise TypeError.new("not an integer")
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Raise an IronLion::Error subclass (see lib/iron_lion/errors.rb), not TypeError.
    RUBY
  end

  it "flags a bare string, which raises RuntimeError" do
    expect_offense(<<~'RUBY')
      raise "no #{name} field"
      ^^^^^^^^^^^^^^^^^^^^^^^^ Raise an IronLion::Error subclass (see lib/iron_lion/errors.rb), not a bare string.
    RUBY
  end

  it "accepts IronLion errors and re-raising" do
    expect_no_offenses(<<~RUBY)
      raise InvalidValueError, "too wide"
      raise IronLion::UnknownFieldError, "no field"
      raise error
      raise
    RUBY
  end
end
