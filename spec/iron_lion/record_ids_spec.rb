# frozen_string_literal: true

# The suite doesn't boot Rails, so these models include IronLion::RecordIds
# directly, as the Railtie does for ActiveRecord::Base.
RSpec.describe IronLion::RecordIds, :active_record do
  let(:table) { IronLion::ModelTable.new }

  let(:models) do
    stub_const("Shop", Module.new)
    stub_const("Shop::Record", Class.new(ActiveRecord::Base) do
      self.abstract_class = true
      include IronLion::RecordIds
    end)
    stub_const("Shop::Order", Class.new(Shop::Record) { self.table_name = "orders" })
    stub_const("Shop::Payment", Class.new(Shop::Record) { self.table_name = "payments" })
    [Shop::Order, Shop::Payment]
  end

  before do
    connection.create_table(:orders, id: :uuid, default: nil) { |t| t.bigint :tenant_id }
    connection.create_table(:payments, id: :uuid) { |t| t.bigint :tenant_id }
    reset_schema_cache(*models)
  end

  def configure(tenant_from: nil)
    models_table = table
    IronLion.configure do
      if tenant_from
        tenant bits: 16, from: tenant_from
      else
        tenant bits: 16
      end
      model    bits: 8, table: models_table
      sequence bits: 12
    end
    IronLion::Installer.new(connection, models:).call
  end

  describe "when the format has a from: field" do
    let!(:report) { configure(tenant_from: -> { 7 }) }

    it "mints ids in Ruby, so the resolver runs" do
      order = Shop::Order.create!
      expect(IronLion.parse(order.id).to_h).to include(tenant: 7, model: Shop::Order)
    end

    it "keeps an id that was supplied" do
      id = IronLion.generate(Shop::Order, tenant: 3).to_s
      expect(Shop::Order.create!(id:).id).to eq(id)
    end

    it "still lets the trigger fill ids for raw SQL inserts" do
      id = connection.select_value("INSERT INTO orders (tenant_id) VALUES (5) RETURNING id")
      expect(IronLion.parse(id).to_h).to include(tenant: 5, model: Shop::Order)
    end

    it "leaves tables that aren't IronLion tables to their default" do
      allow(IronLion).to receive(:generate).and_call_original
      Shop::Payment.create!(tenant_id: 1)
      expect(IronLion).not_to have_received(:generate)
    end

    it "says so in the install report" do
      expect(report.to_s).to include("orders: IronLion ids (Shop::Order), minted in Ruby because tenant uses from:")
    end
  end

  describe "when the format has no from: fields" do
    before do
      configure
      allow(IronLion).to receive(:generate).and_call_original
    end

    it "leaves the id to the database" do
      order = Shop::Order.create!(tenant_id: 4)
      expect(IronLion).not_to have_received(:generate)
      expect(IronLion.parse(order.id).tenant).to eq(4)
    end
  end

  it "does nothing until IronLion is configured" do
    expect(Shop::Order.iron_lion_ids_in_ruby?).to be(false)
  end

  it "notices when the format changes" do
    configure
    expect(Shop::Order.iron_lion_ids_in_ruby?).to be(false)
    configure(tenant_from: -> { 1 })
    expect(Shop::Order.iron_lion_ids_in_ruby?).to be(true)
  end
end
