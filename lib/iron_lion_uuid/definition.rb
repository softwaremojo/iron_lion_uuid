# frozen_string_literal: true

# IronLionUUID is a flexible UUID generation system that allows
# for custom UUID formats through component-based composition.
# It provides a DSL for defining UUID structures and handles
# the complex logic of UUID generation and parsing.
class IronLionUUID
  # Definition class provides a DSL for defining custom UUID formats.
  # It allows users to specify the components and their order within
  # the UUID, managing the allocation of bits and ensuring the
  # resulting UUID structure is valid.
  class Definition
    attr_reader :index

    def initialize(index, &)
      @index = index
      instance_exec(&)
      @index.rationalize!
    end

    private

      def method_missing(type, *args, &)
        if respond_to? type
          @index << Component.create(type, *args)
        else
          super
        end
      end

      def respond_to_missing?(type, include_private = true)
        return true if Component.exists? type

        super
      end
  end
end
