# frozen_string_literal: true

require "spec_helper"
require "securerandom"

RSpec.describe IronLionUUID::Component::Random do
  describe "#value" do
    let(:component) { described_class.new(bits: 16) }
    let(:max_value) { 2**16 }

    before do
      allow(SecureRandom).to receive(:rand).with(max_value).and_return 12_345
    end

    it "generates random numbers using SecureRandom" do
      component.value

      expect(SecureRandom).to have_received(:rand).with max_value
    end

    it "returns the random value" do
      expect(component.value).to eq 12_345
    end

    it "generates new random values for each call" do
      allow(SecureRandom).to receive(:rand).with(max_value).and_return 1, 2, 3

      expect(component.value).to eq 1
      expect(component.value).to eq 2
      expect(component.value).to eq 3
    end
  end
end
