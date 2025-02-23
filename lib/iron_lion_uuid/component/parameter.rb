# frozen_string_literal: true

class IronLionUUID
  class Component
    # Parameter component for IronLionUUID
    class Parameter < Component
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
