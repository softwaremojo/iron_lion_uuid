# frozen_string_literal: true

require "spec_helper"

RSpec.describe IronLionUUID::Index do
  let(:index) { described_class.new }

  # Mock component class for testing
  let(:mock_component) do
    Class.new do
      attr_accessor :bits, :name

      def initialize(name, bits)
        @name = name
        @bits = bits
      end

      def parameter?
        false
      end

      def call(_arg)
        0
      end

      def to_s
        name
      end
    end
  end

  describe "#initialize" do
    it "creates an empty components hash" do
      expect(index.components).to be_empty
    end
  end

  describe "#<<" do
    let(:component) { mock_component.new("test", 10) }

    it "adds a component to the index" do
      index << component
      expect(index.components).to include component
    end

    context "when component already exists" do
      it "warns about redefinition" do
        index << component
        expect { index << component }.to output(/Redefining test/).to_stderr
      end
    end

    context "when component would exceed bit limit" do
      let(:large_component) { mock_component.new("large", 123) }

      it "warns about exceeding bit limit" do
        expect { index << large_component }.to output(/large over bit limit/).to_stderr
      end
    end
  end

  describe "#validate!" do
    context "when total bits are within limit" do
      before do
        index << mock_component.new("comp1", 61)
        index << mock_component.new("comp2", 61)
      end

      it "does not raise error" do
        expect { index.validate! }.not_to raise_error
      end
    end

    context "when total bits exceed limit" do
      before do
        index << mock_component.new("comp1", 62)
        index << mock_component.new("comp2", 61)
      end

      it "raises ArgumentError" do
        expect { index.validate! }.to raise_error(
          ArgumentError, "Total bits (123) exceeds maximum allowed bits (122)"
        )
      end
    end
  end

  describe "#size" do
    before do
      index << mock_component.new("comp1", 30)
      index << mock_component.new("comp2", 40)
    end

    it "returns sum of component bits" do
      expect(index.size).to eq 70
    end
  end

  describe "#params" do
    let(:param_component) do
      Class.new(mock_component) do
        def parameter?
          true
        end
      end
    end

    before do
      index << mock_component.new("regular", 30)
      index << param_component.new("param", 40)
    end

    it "returns only parameter components" do
      expect(index.params.count).to eq 1
      expect(index.params.first.name).to eq "param"
    end
  end

  describe "#iron_lion_uuid" do
    let(:param_component) do
      Class.new(mock_component) do
        def parameter?
          true
        end

        def call(arg)
          arg || 0
        end
      end
    end

    before do
      index << param_component.new("param1", 61)
      index << param_component.new("param2", 61)
    end

    context "with regular call" do
      it "generates a valid UUID" do
        uuid = index.iron_lion_uuid(1, 2)

        expect(uuid).to be_a IronLionUUID
        expect(uuid.to_s).to match(
          /\A[0-9a-f]{8}-[0-9a-f]{4}-8[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/
        )
      end
    end

    context "with SQL generation" do
      it "generates SQL select statement" do
        sql = index.iron_lion_uuid(1, 2, sql: true)

        expect(sql).to eq "SELECT iron_lion_uuid(1, 2);"
      end

      it "raises ArgumentError with wrong number of arguments" do
        expect { index.iron_lion_uuid(1, sql: true) }.to raise_error ArgumentError
      end
    end
  end
end
