# frozen_string_literal: true

require "rails/generators"

module IronLion
  module Generators
    # bin/rails generate iron_lion:install
    class InstallGenerator < ::Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Configures IronLion ids: an initializer with your format and config/iron_lion.yml for model numbers."

      def create_initializer
        template "initializer.rb", "config/initializers/iron_lion.rb"
      end

      def create_model_table
        template "iron_lion.yml", "config/iron_lion.yml"
      end

      def explain
        say <<~TEXT

          IronLion is set up. Next:

            1. Adjust the format in config/initializers/iron_lion.rb.
            2. Give new tables IronLion ids:

                 create_table :orders, id: :uuid, default: nil do |t|

               Postgres fills the id on insert. Triggers are installed after every
               migration and schema load (or run bin/rails iron_lion:install).
            3. Commit config/iron_lion.yml. Models are numbered in development and
               test; production reads the file and never numbers a model itself.

          Then, in a console: IronLion.find("<any id>")

        TEXT
      end
    end
  end
end
