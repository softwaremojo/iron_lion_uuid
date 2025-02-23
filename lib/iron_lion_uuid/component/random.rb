# frozen_string_literal: true

class IronLionUUID
  class Component
    # Represents a key component of a UUID. This class handles the generation
    # and SQL representation of random numerical key values.
    class Random < Component
      def value
        SecureRandom.rand max_value
      end

      def to_sql
        <<~SQL
          #{name} := (RANDOM() * #{limit})::BIGINT;
        SQL
      end
    end
  end
end
