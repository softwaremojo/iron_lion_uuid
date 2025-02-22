# frozen_string_literal: true

require_relative "inflector"

class IronLionUUID
  # Component module provides the building blocks for constructing UUIDs.
  # It contains various component types (Time, Sequence, etc.) that can be
  # combined to create custom UUID formats. Each component represents a
  # specific part of the UUID and handles its own data conversion and validation.
  module Component
    autoload :Base,      "iron_lion_uuid/component/base"
    autoload :Envar,     "iron_lion_uuid/component/envar"
    autoload :Parameter, "iron_lion_uuid/component/parameter"
    autoload :Random,    "iron_lion_uuid/component/random"
    autoload :Sequence,  "iron_lion_uuid/component/sequence"
    autoload :Timestamp, "iron_lion_uuid/component/timestamp"

    def self.create(type, options = {})
      const_get(Inflector.classify(type)).then do |klass|
        klass.new(**options)
      end
    end

    def self.exists?(type)
      const_defined? Inflector.classify(type)
    end
  end
end
