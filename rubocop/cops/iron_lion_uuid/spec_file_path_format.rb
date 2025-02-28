# frozen_string_literal: true

require "rubocop"
require_relative "../../../lib/iron_lion_uuid/inflector"

module RuboCop
  module Cop
    module IronLionUUID
      # Checks that the spec file path matches the described class name,
      # using the IronLionUUID::Inflector for conversions.
      #
      # @example
      #   # bad
      #   # spec/fo_obar_spec.rb
      #   RSpec.describe FooBar do
      #   end
      #
      #   # good
      #   # spec/foo_bar_spec.rb
      #   RSpec.describe FooBar do
      #   end
      class SpecFilePathFormat < Base
        MSG = "Spec path should end with %<expected>s."

        def on_rspec_describe(node)
          return unless node.described_class.present?

          underscored_class_name = if node.described_class.const?
            IronLionUUID::Inflector.underscore node.described_class.source
          else
            # Handle cases where the described class is not a constant
            # For example, when using `Class.new`
            return
          end

          expected_path = "#{underscored_class_name}_spec.rb"
          actual_path = processed_source.file_path

          return if actual_path.end_with? expected_path

          add_offense(
            node.loc.expression,
            message: format(MSG, expected: expected_path)
          ) do |corrector|
            correct_file_path corrector, actual_path, expected_path
          end
        end

        private

        def correct_file_path(corrector, actual_path, expected_path)
          expected_full_path = File.join(File.dirname(actual_path), expected_path)

          # Check if the target file already exists before attempting to rename.
          if File.exist? expected_full_path
            # Display a message indicating that the file already exists
            # and skip renaming it.
            puts "Target file already exists: #{expected_full_path}. Skipping rename."
            return
          end

          corrector.replace(
            source_range(
              processed_source.buffer,
              0,
              processed_source.buffer.source.length
            ),
            # Comment out the entire file content to prevent errors during rename
            "##{processed_source.buffer.source}"
          )

          # As Rubocop runs in memory, we can't directly rename the file here.
          # Instead, we pass the rename command back to the user.
          puts "Rename file: #{actual_path} to #{expected_full_path}"
        end

        def source_range(buffer, start_pos, length)
          Parser::Source::Range.new(buffer, start_pos, start_pos + length)
        end
      end
    end
  end
end
