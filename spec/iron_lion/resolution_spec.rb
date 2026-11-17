# frozen_string_literal: true

RSpec.describe "Resolving field values" do
  let(:format) { IronLion.define { tenant bits: 20 } }

  def tenant_for(record = nil, **values) = format.generate(record, **values).tenant

  it "reads the environment as the last resort" do
    with_env("IRON_LION_TENANT" => "12") { expect(tenant_for).to eq(12) }
  end

  it "prefers a configured resolver to the environment" do
    format = IronLion.define { tenant bits: 20, from: -> { 34 } }
    with_env("IRON_LION_TENANT" => "12") { expect(format.generate.tenant).to eq(34) }
  end

  it "passes the record to a resolver that wants it" do
    format = IronLion.define { tenant bits: 20, from: ->(record) { record.fetch(:org) } }
    expect(format.generate({ org: 9 }).tenant).to eq(9)
  end

  it "prefers the record to a resolver" do
    format = IronLion.define { tenant bits: 20, from: -> { 34 } }
    expect(format.generate(Fixtures::Order.new(tenant_id: 56)).tenant).to eq(56)
  end

  it "prefers an explicit value to everything" do
    with_env("IRON_LION_TENANT" => "12") do
      expect(tenant_for(Fixtures::Order.new(tenant_id: 56), tenant: 78)).to eq(78)
    end
  end

  describe "reading the record" do
    it "asks #iron_lion_<field> first, then #<field>_id, then #<field>" do
      everything = Struct.new(:iron_lion_tenant, :tenant_id, :tenant).new(1, 2, 3)
      expect(tenant_for(everything)).to eq(1)
      expect(tenant_for(Struct.new(:tenant_id, :tenant).new(2, 3))).to eq(2)
      expect(tenant_for(Struct.new(:tenant).new(3))).to eq(3)
    end

    it "uses the id of an associated object" do
      tenant = Struct.new(:id).new(77)
      expect(tenant_for(Struct.new(:tenant).new(tenant))).to eq(77)
    end

    it "treats nil as unknown and keeps looking" do
      with_env("IRON_LION_TENANT" => "12") do
        expect(tenant_for(Fixtures::Order.new(tenant_id: nil))).to eq(12)
      end
    end
  end

  describe "failures" do
    it "lists everywhere it looked" do
      expect { tenant_for(Fixtures::Order.new) }.to raise_error(IronLion::MissingValueError) { |error|
        expect(error.message).to eq(<<~MESSAGE.chomp)
          No value for tenant. IronLion looked in:
            1. IronLion.generate(tenant: ...)
            2. the record: Fixtures::Order#iron_lion_tenant, #tenant_id, #tenant
            3. a resolver: `tenant bits: 20, from: -> { ... }` (none configured)
            4. ENV["IRON_LION_TENANT"]
        MESSAGE
      }
    end

    it "rejects an environment value that is not an integer" do
      with_env("IRON_LION_TENANT" => "acme") do
        expect { tenant_for }.to raise_error(IronLion::InvalidValueError, /"acme"; tenant needs an integer/)
      end
    end

    it "rejects values that are not integers" do
      expect { tenant_for(tenant: 1.5) }.to raise_error(IronLion::InvalidValueError, /must be an integer/)
      expect { tenant_for(tenant: -1) }.to raise_error(IronLion::OverflowError)
    end

    it "accepts digit strings" do
      expect(tenant_for(tenant: "42")).to eq(42)
    end
  end
end
