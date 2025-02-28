# frozen_string_literal: true

module IronLionUUID
  # Rails integration module
  # Requires ActiveRecord and Rails
  module RailsIntegration
    # Only load the Rails-specific files if Rails is present
    def self.load
      # Check if we're in a Rails environment
      if defined?(Rails) && defined?(ActiveRecord)
        # Load core Rails integration components
        require_relative "type"
        require_relative "has_iron_lion_id"

        # Load generator support
        require_relative "sql_generator"
        require_relative "postgresql_generator"
        require_relative "mysql_generator"
        require_relative "sqlite_generator"

        # Load railtie last
        require_relative "railtie"

        true
      else
        false
      end
    end
  end
end
