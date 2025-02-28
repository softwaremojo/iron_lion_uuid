# frozen_string_literal: true

module IronLionUUID
  # Rails integration via Railtie
  # Only loaded if Rails is present
  class Railtie < Rails::Railtie
    initializer "iron_lion_uuid.configure_rails" do
      ActiveSupport.on_load(:active_record) do
        # Register UUID type with ActiveRecord
        ActiveRecord::Type.register(:iron_lion_uuid, IronLionUUID::Type)

        # Include HasIronLionId if configured
        if IronLionUUID.configuration && defined?(IronLionUUID::HasIronLionId)
          ActiveRecord::Base.include(IronLionUUID::HasIronLionId)
        end
      end
    end

    # Register generators
    generators do
      require_relative "generators/install_generator" if defined?(Rails::Generators)
    end

    # Log information about the integration
    config.after_initialize do
      if Rails.logger && IronLionUUID.configuration
        Rails.logger.info(
          "IronLionUUID: Rails integration initialized with " \
          "#{IronLionUUID.configuration.attributes.size} attributes"
        )
      end
    end
  end
end
