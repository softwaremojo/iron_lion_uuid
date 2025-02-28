# frozen_string_literal: true

module IronLionUUID
  # Enhanced UUID with attribute value extraction
  class CustomUUID < UUID
    # Initialize a new CustomUUID
    # @param value [Integer] The 128-bit value
    # @param attributes [Array<Attribute>] The attributes to extract values from
    def initialize(value, attributes = [])
      super(value)
      @attributes = attributes

      # Define accessor methods for named attributes
      define_attribute_accessors
    end

    private

    # Define accessor methods for named attributes
    def define_attribute_accessors
      @attributes.each do |attr|
        next unless attr.name

        # Define a method named after the attribute
        self.class.class_eval do
          define_method(attr.name) do
            attr.extract_from(@value)
          end
        end
      end
    end
  end
end
