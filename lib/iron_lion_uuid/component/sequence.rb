# frozen_string_literal: true

class IronLionUUID
  module Component
    # Sequence component for IronLionUUID
    class Sequence < Base
      SEQUENCE_NAME = :iron_lion_uuid_seq

      def value
        sequence.next
      end

      private

      def sequence
        @sequence ||= (1..Float::INFINITY).lazy
      end
    end
  end
end

__END__

postgresql:
  value: SELECT NEXTVAL('<%= SEQUENCE_NAME %>')
  dependency: |
    CREATE SEQUENCE <%= SEQUENCE_NAME %>
      START WITH 1
      INCREMENT BY 1
      NO MINVALUE
      NO MAXVALUE
      CACHE 1;
mysql2:
  value: AUTO_INCREMENT
sqlite:
  raw_sql: |
    SELECT seq % <%= max_value %>
    FROM sqlite_sequence
    WHERE name = '<%= SEQUENCE_NAME %>'
