# frozen_string_literal: true

RSpec.describe IronLion::Id, "#record" do
  let(:format) { IronLion.define { model bits: 8 } }

  it "asks the model class to find the id" do
    model = Class.new { def self.find(id) = [:found, id] }
    stub_const("Fixtures::Ticket", model)
    id = format.generate(model: Fixtures::Ticket)
    expect(id.record).to eq([:found, id.to_s])
  end

  it "explains when the format has no model field" do
    id = IronLion.define { tenant bits: 8 }.generate(tenant: 1)
    expect { id.record }.to raise_error(IronLion::Error, /no model field/)
  end

  it "explains when the model is not a loaded class" do
    id = format.generate(model: "Archived::Thing")
    expect { id.record }.to raise_error(IronLion::Error, /names model "Archived::Thing", which is not a loaded class/)
  end

  it "is available from a bare id through IronLion.find" do
    stub_const("Fixtures::Ticket", Class.new { def self.find(id) = id })
    IronLion.configure { model bits: 8 }
    id = IronLion.generate(model: Fixtures::Ticket)
    expect(IronLion.find(id.to_s.upcase)).to eq(id.to_s)
  end
end
