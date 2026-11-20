# frozen_string_literal: true

require "fileutils"
require "pathname"
require "securerandom"
require "time"
require "yaml"

require_relative "iron_lion/version"
require_relative "iron_lion/errors"
require_relative "iron_lion/layout"
require_relative "iron_lion/base36"
require_relative "iron_lion/h3"
require_relative "iron_lion/geohash"
require_relative "iron_lion/field"
require_relative "iron_lion/declaration"
require_relative "iron_lion/builder"
require_relative "iron_lion/clock"
require_relative "iron_lion/model_table"
require_relative "iron_lion/resolver"
require_relative "iron_lion/id"
require_relative "iron_lion/format"
require_relative "iron_lion/postgres"
require_relative "iron_lion/installer"

# IronLion mints time-sortable UUIDv8s that carry the facts you need to debug
# them: when, which model, which node, which tenant.
#
#   IronLion.configure do
#     tenant   bits: 20
#     model    bits: 10
#     node     bits: 10
#     sequence bits: 12
#   end
#
#   id = IronLion.generate(order)
#   IronLion.parse(id.to_s).model # => Order
module IronLion
  class << self
    # Sets the organisation's one format. Call once, at boot.
    def configure(&)
      @format = define(&)
    end

    # Builds a format without installing it. Useful for decoding ids from
    # another system: IronLion.parse(id, format: IronLion.define { ... }).
    def define(&)
      Builder.build(&)
    end

    def format
      @format or raise NotConfiguredError,
                       "IronLion has no format yet. Call IronLion.configure { ... } at boot " \
                       "(in Rails: config/initializers/iron_lion.rb)."
    end

    def configured?
      !@format.nil?
    end

    # Mints a new id. Pass the record it is for, and any values IronLion
    # cannot work out for itself.
    def generate(record = nil, **values)
      format.generate(record, **values)
    end

    # Decodes an id. IronLion never guesses the format: it uses the
    # configured one unless you hand it another.
    def parse(input, format: self.format)
      format.parse(input)
    end

    # Finds the record an id belongs to: paste a UUID, get the row.
    def find(input, format: self.format)
      parse(input, format:).record
    end

    # Forgets the configured format. Intended for test suites.
    def reset!
      @format = nil
    end
  end
end

require_relative "iron_lion/railtie" if defined?(Rails::Railtie)
