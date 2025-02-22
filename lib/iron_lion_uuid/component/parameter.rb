# frozen_string_literal: true

class IronLionUUID
  module Component
    class Parameter < Base
      def value
        lambda do |param|
          case param
          when Integer           then param
          when Float, BigDecimal then param.to_i
          else                        param.to_s.to_i(RADIX)
          end
        end
      end
    end
  end
end
