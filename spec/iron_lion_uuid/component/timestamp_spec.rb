# frozen_string_literal: true

require "spec_helper"

RSpec.describe IronLionUUID::Component::Timestamp do
  describe "#unit" do
    it "defaults to millisecond" do
      component = described_class.new

      expect(component.unit).to eq :millisecond
    end

    it "accepts valid time units" do
      %i[ millisecond microsecond nanosecond ].each do |unit|
        component = described_class.new(unit: unit)

        expect(component.unit).to eq unit
      end
    end

    it "defaults to millisecond for invalid units" do
      component = described_class.new(unit: :invalid)

      expect(component.unit).to eq :millisecond
    end
  end

  describe "#multiplier" do
    {
      millisecond: 1_000,
      microsecond: 1_000_000,
      nanosecond: 1_000_000_000
    }.each do |unit, expected|
      context "with #{unit} unit" do
        it "returns correct multiplier" do
          component = described_class.new(unit: unit)

          expect(component.multiplier).to eq expected
        end
      end
    end
  end

  describe "#value" do
    let(:now) { 1_234_567_890.123456 }

    before do
      allow(Process).to receive(:clock_gettime)
        .with(Process::CLOCK_REALTIME, anything)
        .and_return now
    end

    it "gets current time in milliseconds by default" do
      component = described_class.new
      component.value

      expect(Process).to have_received(:clock_gettime)
        .with Process::CLOCK_REALTIME, :millisecond
    end

    it "gets current time in specified unit" do
      component = described_class.new(unit: :microsecond)
      component.value

      expect(Process).to have_received(:clock_gettime)
        .with Process::CLOCK_REALTIME, :microsecond
    end
  end
end
