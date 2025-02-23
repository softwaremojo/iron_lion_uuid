# frozen_string_literal: true

require "spec_helper"

RSpec.describe IronLionUUID::Component::Envar do
  describe "#value" do
    let(:component) { described_class.new(name: :test_var) }

    before do
      allow(ENV).to receive(:fetch).and_return(env_value)
    end

    context "with numeric environment value" do
      let(:env_value) { "42" }

      it "returns the integer directly" do
        expect(component.value).to eq 42
      end

      it "caches the converted value" do
        first_value = component.value
        allow(ENV).to receive(:fetch).and_return("84")

        expect(component.value).to eq first_value
      end
    end

    context "with base 36 string value" do
      let(:env_value) { "foobar" }

      it "converts to integer using base 36" do
        expect(component.value).to eq 948_437_811
      end
    end

    context "with custom environment key" do
      let(:component) { described_class.new(name: :test_var, key: :custom_key) }
      let(:env_value) { "42" }

      it "uses the specified key" do
        component.value

        expect(ENV).to have_received(:fetch).with("CUSTOM_KEY", "")
      end
    end

    context "with missing environment variable" do
      let(:env_value) { "" }

      it "converts empty string to 0" do
        expect(component.value).to eq 0
      end
    end

    context "with uppercase environment key" do
      let(:component) { described_class.new(name: :test_var) }
      let(:env_value) { "42" }

      it "automatically uppercases the key" do
        component.value

        expect(ENV).to have_received(:fetch).with("TEST_VAR", "")
      end
    end
  end
end
