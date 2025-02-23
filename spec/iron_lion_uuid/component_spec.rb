# frozen_string_literal: true

require "spec_helper"

RSpec.describe IronLionUUID::Component do
  describe ".create" do
    it "instantiates the correct component type" do
      allow(described_class::Timestamp).to receive(:new)
      described_class.create(:timestamp)

      expect(described_class::Timestamp).to have_received(:new)
    end

    it "passes options to the component constructor" do
      allow(described_class::Random).to receive(:new).with(bits: 32)
      described_class.create(:random, bits: 32)

      expect(described_class::Random).to have_received(:new).with(bits: 32)
    end
  end

  describe ".exists?" do
    it "returns true for defined component types" do
      expect(described_class.exists?(:timestamp)).to be true
      expect(described_class.exists?(:random)).to be true
      expect(described_class.exists?(:sequence)).to be true
    end

    it "returns false for undefined component types" do
      expect(described_class.exists?(:not_real)).to be false
    end
  end

  describe "#initialize" do
    subject(:component) { test_component.new(**options) }

    let(:test_component) do
      Class.new(described_class) do
        def self.name
          "IronLionUUID::Component::TestComponent"
        end
      end
    end

    context "with no options" do
      let(:options) { {} }

      it "sets default values" do
        expect(component.type).to eq :test_component
        expect(component.name).to eq :test_component
        expect(component.bits).to eq 0
        expect(component.options).to be_empty
      end
    end

    context "with custom options" do
      let(:options) do
        {
          name: :custom_name,
          bits: 32,
          extra: "value"
        }
      end

      it "sets attributes from options" do
        expect(component.type).to eq :test_component
        expect(component.name).to eq :custom_name
        expect(component.bits).to eq 32
        expect(component.options).to eq(extra: "value")
      end
    end

    context "with negative bits" do
      let(:options) { { bits: -10 } }

      it "sets bits to 0" do
        expect(component.bits).to eq 0
      end
    end
  end

  describe "#to_s" do
    let(:component) { described_class.new(name: :test) }

    it "returns formatted component name" do
      expect(component.to_s).to eq "Component `test`"
    end
  end

  describe "#bits=" do
    let(:component) { described_class.new(name: :test) }

    it "sets positive bit values" do
      expect { component.bits = 32 }.to output(/Component 'test' was assigned 32 bits/).to_stderr
      expect(component.bits).to eq 32
    end

    it "converts negative values to 0" do
      expect { component.bits = -10 }.to output(/Component 'test' was assigned 0 bits/).to_stderr
      expect(component.bits).to eq 0
    end
  end

  describe "#zero_bits?" do
    it "returns true when bits is 0" do
      component = described_class.new(bits: 0)

      expect(component.zero_bits?).to be true
    end

    it "returns false when bits is positive" do
      component = described_class.new(bits: 32)

      expect(component.zero_bits?).to be false
    end
  end

  describe "#max_value" do
    it "returns correct maximum value for bit size" do
      component = described_class.new(bits: 4)

      expect(component.max_value).to eq 16 # 2^4
    end
  end

  describe "#bit_mask" do
    it "returns correct bit mask for bit size" do
      component = described_class.new(bits: 4)

      expect(component.bit_mask).to eq 15 # 2^4 - 1
    end
  end

  describe "#quarter_bits" do
    it "returns one fourth of total bits" do
      component = described_class.new(bits: 16)

      expect(component.quarter_bits).to eq 4
    end
  end

  describe "#parameter?" do
    it "returns false for base component" do
      component = described_class.new

      expect(component.parameter?).to be false
    end

    it "returns true for parameter components" do
      parameter = described_class::Parameter.new

      expect(parameter.parameter?).to be true
    end
  end
end
