# frozen_string_literal: true

RSpec.describe IronLion::ModelTable, ".default" do
  after do
    described_class.default_path = nil
    described_class.default_assign = nil
  end

  it "keeps tables in memory and assigning unless told otherwise" do
    table = IronLion.define { model bits: 8 }.fields[1].options[:table]
    expect(table.path).to be_nil
    expect(table).to be_assign
  end

  it "uses the configured default path and assignment, as the Railtie sets them" do
    described_class.default_path = "config/iron_lion.yml"
    described_class.default_assign = false

    implied = IronLion.define { model bits: 8 }.fields[1].options[:table]
    named = IronLion.define { model bits: 8, table: "elsewhere.yml" }.fields[1].options[:table]

    expect([implied.path, implied.assign?]).to eq(["config/iron_lion.yml", false])
    expect([named.path, named.assign?]).to eq(["elsewhere.yml", false])
  end
end
