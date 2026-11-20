# frozen_string_literal: true

RSpec.describe IronLion::Installer, :active_record do
  # Defined lazily: ActiveRecord is only loaded when a database is reachable.
  let(:models) do
    stub_const("Shop", Module.new)
    stub_const("Shop::Record", Class.new(ActiveRecord::Base) { self.abstract_class = true })
    stub_const("Shop::Order", Class.new(Shop::Record) { self.table_name = "orders" })
    stub_const("Shop::Payment", Class.new(Shop::Record) { self.table_name = "payments" })
    stub_const("Shop::Widget", Class.new(Shop::Record) { self.table_name = "widgets" })
    stub_const("Shop::Vehicle", Class.new(Shop::Record) { self.table_name = "vehicles" })
    stub_const("Shop::Car", Class.new(Shop::Vehicle))
    [Shop::Record, Shop::Order, Shop::Payment, Shop::Widget, Shop::Vehicle, Shop::Car]
  end

  let(:table) { IronLion::ModelTable.new }

  let(:format) do
    models_table = table
    IronLion.define do
      tenant   bits: 16
      model    bits: 8, table: models_table
      sequence bits: 12
    end
  end

  let(:installer) { described_class.new(connection, format:, models:) }

  before do
    connection.create_table(:orders, id: :uuid, default: nil) { |t| t.bigint :tenant_id }
    connection.create_table(:payments, id: :uuid) { |t| t.bigint :tenant_id }
    connection.create_table(:widgets) { |t| t.bigint :tenant_id }
    connection.create_table(:vehicles, id: :uuid, default: nil) do |t|
      t.string :type
      t.bigint :tenant_id
    end
    reset_schema_cache(*models.reject(&:abstract_class?))
  end

  def parse(uuid) = IronLion.parse(uuid, format:)

  it "installs on uuid tables without a default, once per table" do
    report = installer.call
    expect(report.installed).to eq([%w[orders Shop::Order], %w[vehicles Shop::Vehicle]])
  end

  it "explains why it left a uuid table with a default alone, and ignores other keys" do
    report = installer.call
    expect(report.skipped).to eq([["payments", "its id defaults to gen_random_uuid() " \
                                               "(create it with `id: :uuid, default: nil` for IronLion ids)"]])
    expect(report.to_s).to include("orders: IronLion ids (Shop::Order)", "payments: skipped")
  end

  describe "once installed" do
    before { installer.call }

    it "gives ActiveRecord creates IronLion ids from the database" do
      order = Shop::Order.create!(tenant_id: 7)
      id = parse(order.id)
      expect(id.to_h).to include(tenant: 7, model: Shop::Order)
    end

    it "names the base class for single-table inheritance" do
      expect(parse(Shop::Car.create!(tenant_id: 1).id).model).to eq(Shop::Vehicle)
    end

    it "fills ids for bulk inserts too" do
      rows = Shop::Order.insert_all([{ tenant_id: 1 }, { tenant_id: 2 }], returning: :id).rows.flatten
      expect(rows.map { parse(_1).tenant }).to eq([1, 2])
    end

    it "finds the record from a bare id" do
      order = Shop::Order.create!(tenant_id: 7)
      expect(parse(order.id).record).to eq(order)
      expect(IronLion.find(order.id.upcase, format:)).to eq(order)
    end

    it "numbers models in the format's model table" do
      expect(table.to_h).to eq("Shop::Order" => 1, "Shop::Vehicle" => 2)
    end

    it "can run again" do
      expect { installer.call }.not_to raise_error
      expect(parse(Shop::Order.create!(tenant_id: 3).id).tenant).to eq(3)
    end

    it "uninstalls" do
      installer.uninstall
      reset_schema_cache(Shop::Order)
      expect { Shop::Order.create!(tenant_id: 1) }.to raise_error(ActiveRecord::NotNullViolation)
    end
  end

  it "leaves the model out of triggers when the format has no model field" do
    plain = IronLion.define { tenant bits: 16 }
    described_class.new(connection, format: plain, models:).call
    expect(IronLion.parse(Shop::Order.create!(tenant_id: 4).id, format: plain).tenant).to eq(4)
  end

  it "does nothing on databases other than Postgres" do
    sqlite = instance_double(ActiveRecord::ConnectionAdapters::AbstractAdapter, adapter_name: "SQLite")
    allow(sqlite).to receive(:execute)

    report = described_class.new(sqlite, format:, models:).call
    expect(report.installed).to be_empty
    expect(sqlite).not_to have_received(:execute)
  end
end
