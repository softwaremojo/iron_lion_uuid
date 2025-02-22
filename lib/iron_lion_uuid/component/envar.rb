# frozen_string_literal: true

class IronLionUUID
  module Component
    # Environment variable component that retrieves values from system
    # environment variables.
    class Envar < Base
      def value
        @value ||= begin
          str = ENV.fetch((options[:key] || name).to_s.upcase, "")
          int = str.to_i
          int.positive? ? int : str.to_i(RADIX)
        end
      end
    end
  end
end
