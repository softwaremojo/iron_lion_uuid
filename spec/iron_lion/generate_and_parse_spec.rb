# frozen_string_literal: true

RSpec.describe "Generating and parsing" do
  before do
    IronLion.configure do
      tenant   bits: 20
      model    bits: 10
      node     bits: 10
      sequence bits: 12
    end
  end

  let(:id) { IronLion.generate(Fixtures::Order.new(tenant_id: 4211), node: 53) }

  it "round-trips every field through the string form" do
    parsed = IronLion.parse(id.to_s)
    expect(parsed).to eq(id)
    expect(parsed.to_h).to eq(id.to_h)
    expect(parsed.tenant).to eq(4211)
    expect(parsed.node).to eq(53)
    expect(parsed.model).to eq(Fixtures::Order)
  end

  it "records creation time to the millisecond, in UTC" do
    before = Time.now
    created = IronLion.generate(tenant: 1, model: "X", node: 1).created_at
    expect(created).to be_utc
    expect(created).to be_between(Time.at(before.to_i), Time.now)
  end

  it "sorts in creation order" do
    ids = Array.new(2000) { IronLion.generate(tenant: 1, model: "X", node: 1) }
    expect(ids.sort).to eq(ids)
    expect(ids.map(&:to_s).sort).to eq(ids.map(&:to_s))
  end

  it "backdates with an explicit created_at" do
    past = Time.utc(2020, 2, 29, 12, 0, 0.25r)
    expect(IronLion.generate(tenant: 1, model: "X", node: 1, created_at: past).created_at).to eq(past)
  end

  it "parses ids, integers and pasted strings alike" do
    expect(IronLion.parse(id)).to eq(id)
    expect(IronLion.parse(id.to_i)).to eq(id)
    expect(IronLion.parse(" #{id.to_s.upcase} ")).to eq(id)
  end

  it "decodes with another format when told to" do
    other = IronLion.define { shard bits: 74 }
    reread = IronLion.parse(id.to_s, format: other)
    expect(reread.created_at).to eq(id.created_at)
    expect(reread).to respond_to(:shard)
    expect(reread).not_to respond_to(:tenant)
  end

  describe "the id" do
    it "reads fields by method or by name" do
      expect(id[:tenant]).to eq(id.tenant)
      expect(id["node"]).to eq(53)
      expect { id[:nope] }.to raise_error(IronLion::UnknownFieldError, /no nope field/)
    end

    it "is a string where a string is expected" do
      expect("id: " + id).to eq("id: #{id}") # rubocop:disable Style/StringConcatenation
      expect(id.to_s).to match(/\A\h{8}-\h{4}-8\h{3}-[89ab]\h{3}-\h{12}\z/)
    end

    it "inspects as the facts a developer wants" do
      timestamp = /\d{4}-\d\d-\d\d \d\d:\d\d:\d\d\.\d{3} UTC/
      expect(id.inspect).to match(
        /\A#<IronLion::Id #{id} created_at=#{timestamp} tenant=4211 model=Fixtures::Order node=53 sequence=\d+>\z/
      )
    end

    it "is a frozen value object" do
      expect(id).to be_frozen
      expect({ id => 1 }[IronLion.parse(id.to_s)]).to eq(1)
    end
  end

  describe "mistakes" do
    it "rejects unknown fields, catching typos" do
      expect { IronLion.generate(tenat: 1) }.to raise_error(IronLion::UnknownFieldError, /unknown field :tenat/)
    end

    it "rejects values for generated fields" do
      expect { IronLion.generate(tenant: 1, model: "X", node: 1, sequence: 3) }
        .to raise_error(IronLion::InvalidValueError, /sequence is generated/)
    end

    it "raises errors that rescue IronLion::Error catches" do
      expect(IronLion::UnknownFieldError).to be < IronLion::Error
      expect(IronLion::InvalidValueError).to be < IronLion::Error
    end

    it "rejects values too wide for their field" do
      expect { IronLion.generate(tenant: 1 << 20, model: "X", node: 1) }
        .to raise_error(IronLion::OverflowError, /tenant 1048576 does not fit in 20 bits/)
    end

    it "rejects times before the epoch" do
      IronLion.configure { created_at time: 40, epoch: "2026-01-01" }
      expect { IronLion.generate(created_at: Time.utc(2025)) }.to raise_error(IronLion::OverflowError)
    end
  end

  it "explains when it has not been configured" do
    IronLion.reset!
    expect { IronLion.generate }.to raise_error(IronLion::NotConfiguredError, /IronLion.configure/)
  end
end
