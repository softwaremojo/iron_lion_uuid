# frozen_string_literal: true

require "spec_helper"

RSpec.describe IronLionUUID::Definition do
  let(:index) { IronLionUUID::Index.new }
  let(:mock_component) { instance_double(IronLionUUID::Component, bits: 61, name: :test) }

  before { allow(IronLionUUID).to receive(:define_getter) }

  describe "#initialize" do
    it "executes the provided block in instance context" do
      allow(IronLionUUID::Component).to receive(:exists?).with(:timestamp).and_return(true)
      allow(IronLionUUID::Component).to receive(:create).with(:timestamp).and_return(mock_component)
      definition = described_class.new(index, &:timestamp)

      expect(definition.index.components).to include(mock_component)
    end

    it "validates the index after components are added" do
      allow(index).to receive(:validate!)

      described_class.new(index) do
        # empty
      end

      expect(index).to have_received(:validate!)
    end

    it "defines getters for components" do
      allow(IronLionUUID::Component).to(
        receive(:exists?).with(:timestamp).and_return(true)
      )

      allow(IronLionUUID::Component).to(
        receive(:create).with(:timestamp).and_return(mock_component)
      )

      described_class.new(index, &:timestamp)

      expect(IronLionUUID).to have_received(:define_getter).with(:test, 0, 61)
    end
  end

  describe "method_missing" do
    context "when component type exists" do
      before do
        allow(IronLionUUID::Component).to(
          receive(:exists?).with(:timestamp).and_return(true)
        )

        allow(IronLionUUID::Component).to(
          receive(:create).with(:timestamp, bits: 61).and_return(mock_component)
        )
      end

      it "creates and adds component to index" do
        definition = described_class.new(index) do |uuid|
          uuid.timestamp bits: 61
        end

        expect(definition.index.components).to include mock_component
      end
    end

    context "when component type does not exist" do
      it "raises NoMethodError" do
        expect do
          described_class.new(index, &:not_a_real_component)
        end.to raise_error(NoMethodError)
      end
    end
  end

  describe "component ordering" do
    let(:a_component) { instance_double(IronLionUUID::Component, bits: 61, name: :first) }
    let(:another_component) { instance_double(IronLionUUID::Component, bits: 61, name: :second) }

    before do
      allow(IronLionUUID::Component).to receive(:exists?).with(:first).and_return true
      allow(IronLionUUID::Component).to receive(:exists?).with(:second).and_return true
      allow(IronLionUUID::Component).to receive(:create).with(:first).and_return a_component
      allow(IronLionUUID::Component).to receive(:create).with(:second).and_return another_component
    end

    it "maintains component order as defined" do
      definition = described_class.new(index) do |uuid|
        uuid.first
        uuid.second
      end

      expect(definition.index.components).to eq [ a_component, another_component ]
    end

    it "defines getters with correct bit offsets" do
      described_class.new(index) do |uuid|
        uuid.first
        uuid.second
      end

      expect(IronLionUUID).to have_received(:define_getter).with(:first, 0, 61)
      expect(IronLionUUID).to have_received(:define_getter).with(:second, 61, 61)
    end
  end
end
