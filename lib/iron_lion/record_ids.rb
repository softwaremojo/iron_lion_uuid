# frozen_string_literal: true

module IronLion
  # Mints IronLion ids in Ruby, before create, when the database can't.
  #
  # Normally ActiveRecord leaves the id NULL and IronLion's insert trigger
  # fills it from the row's columns and `iron_lion.<field>` settings. A
  # `from:` resolver is a Ruby lambda, so the trigger can't run it. When the
  # format has any field with `from:`, every model on an IronLion table gets
  # its id here instead. The trigger stays installed for raw SQL and bulk
  # inserts, which don't run resolvers.
  #
  # The Railtie includes this into ActiveRecord::Base.
  module RecordIds
    def self.included(base)
      base.extend(ClassMethods)
      base.before_create(:assign_iron_lion_id, if: :mint_iron_lion_id_in_ruby?)
    end

    # Whether a model's ids are minted in Ruby, worked out once per class and
    # format.
    module ClassMethods
      def iron_lion_ids_in_ruby?
        return false unless IronLion.configured?

        format = IronLion.format
        cached = @iron_lion_ids_in_ruby
        return cached.last if cached&.first.equal?(format)

        answer = !abstract_class? && format.from_fields.any? && iron_lion_table?
        @iron_lion_ids_in_ruby = [format, answer]
        answer
      end

      private

      def iron_lion_table?
        table_exists? && with_connection { Installer.iron_lion_table?(_1, table_name) }
      end
    end

    private

    def mint_iron_lion_id_in_ruby? = self.class.iron_lion_ids_in_ruby?

    def assign_iron_lion_id
      self.id ||= IronLion.generate(self).to_s
    end
  end
end
