# frozen_string_literal: true

require "spec_helper"

RSpec.describe IronLionUUID::Index do
  let(:index) { described_class.new }

  describe "#rationalize!" do
    it "handles negative remainder by removing bits from last component" do
      IronLionUUID::Definition.new(index) do
        timestamp bits: 48
        sequence  bits: 48
        random    bits: 48 # This adds up to 144 bits, too many
      end

      # After rationalization, components should fit within 122 bits
      expect(index.size).to eq(122)
    end

    it "removes components that end up with 0 bits" do
      IronLionUUID::Definition.new(index) do
        timestamp bits: 48
        sequence  bits: 48
        random    bits: 48 # Will get reduced to 26
        parameter bits: 48 # Will get reduced to 0
      end

      expect(index.components.count).to be 3

      index.components.each do |component|
        expect(component.bits).to be > 0
      end
    end
  end
end
