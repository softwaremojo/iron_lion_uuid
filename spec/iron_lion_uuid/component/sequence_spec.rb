# frozen_string_literal: true

require "spec_helper"

RSpec.describe IronLionUUID::Component::Sequence do
  describe "#value" do
    it "returns incrementing values starting from 1" do
      component = described_class.new

      expect(component.value).to eq 1
      expect(component.value).to eq 2
      expect(component.value).to eq 3
    end

    it "creates a new sequence for each instance" do
      component1 = described_class.new
      component2 = described_class.new

      expect(component1.value).to eq 1
      expect(component2.value).to eq 1
      expect(component1.value).to eq 2
      expect(component2.value).to eq 2
    end
  end
end
