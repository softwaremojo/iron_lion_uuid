# frozen_string_literal: true

require "spec_helper"

RSpec.describe IronLionUUID::Component::Parameter do
  describe "#value" do
    let(:component) { described_class.new(bits: 16) }
    let(:value_proc) { component.value }

    context "with Integer input" do
      it "returns the integer directly" do
        expect(value_proc.call(42)).to eq 42
      end
    end

    context "with Float input" do
      it "converts to integer" do
        expect(value_proc.call(42.9)).to eq 42
      end

      it "handles negative numbers" do
        expect(value_proc.call(-42.9)).to eq(-42)
      end
    end

    context "with BigDecimal input" do
      it "converts to integer" do
        decimal = BigDecimal("42.9")
        expect(value_proc.call(decimal)).to eq 42
      end
    end

    context "with String input" do
      it "converts base 36 strings to integers" do
        expect(value_proc.call("2n")).to eq 95
        expect(value_proc.call("zz")).to eq 1295
      end

      it "handles uppercase strings" do
        expect(value_proc.call("2N")).to eq 95
        expect(value_proc.call("ZZ")).to eq 1295
      end

      it "handles longer strings" do
        expect(value_proc.call("foobar")).to eq 948_437_811
      end
    end
  end

  describe "#parameter?" do
    it "identifies as a parameter component" do
      component = described_class.new

      expect(component.parameter?).to be true
    end
  end
end
