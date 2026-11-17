# frozen_string_literal: true

require "iron_lion"
require "tmpdir"

# Classes the model field can resolve back to by name.
module Fixtures
  Order = Struct.new(:tenant_id, keyword_init: true)
  User = Struct.new(:tenant_id, keyword_init: true)
  Car = Struct.new(:model)

  class Invoice
    def self.iron_lion_model_id = 7
  end
end

module EnvHelpers
  def with_env(vars)
    saved = vars.keys.to_h { [_1, ENV.fetch(_1, nil)] }
    vars.each { |key, value| ENV[key] = value }
    yield
  ensure
    saved.each { |key, value| ENV[key] = value }
  end
end

RSpec.configure do |config|
  config.include EnvHelpers
  config.disable_monkey_patching!
  config.order = :random
  config.after { IronLion.reset! }
  config.around do |example|
    # Keep the developer's real environment from leaking into resolution.
    with_env(ENV.keys.grep(/\AIRON_LION_/).to_h { [_1, nil] }) { example.run }
  end
end
