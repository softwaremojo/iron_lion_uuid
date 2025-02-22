# frozen_string_literal: true

class IronLionUUID
  module Component
    class Timestamp < Base
      UNITS = %i[ millisecond microsecond nanosecond ]

      def value
        Process.clock_gettime Process::CLOCK_REALTIME, unit
      end

      def unit
        @unit ||= begin
          if UNITS.include? options[:unit]
            options[:unit]
          else
            :millisecond
          end
        end
      end

      def multiplier
        @multiplier ||= begin
          case options[:unit]
          when :millisecond then 1_000
          when :nanosecond  then 1_000_000_000
          else                   1_000_000
          end
        end
      end
    end
  end
end

__END__

postgresql:
  value: EXTRACT(EPOCH FROM clock_timestamp() AT TIME ZONE 'utc') * <%= multiplier %>
mysql2:
  value: UNIX_TIMESTAMP() * <%= multiplier %>
sqlite:
  value: (julianday('now') - 2440587.5) * 86400 * <%= multiplier %>
