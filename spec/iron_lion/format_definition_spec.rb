# frozen_string_literal: true

RSpec.describe "Defining a format" do
  def layout(format) = format.fields.map { [_1.name, _1.kind, _1.bits] }

  it "implies a leading 48-bit created_at and fills the rest with random" do
    format = IronLion.define { tenant bits: 20 }
    expect(layout(format)).to eq([[:created_at, :time, 48], [:tenant, :value, 20], [:random, :random, 54]])
  end

  it "lays fields out in declaration order" do
    format = IronLion.define do
      tenant   bits: 20
      model    bits: 10
      node     bits: 10
      sequence bits: 12
    end
    expect(format.fields.map(&:offset)).to eq([0, 48, 68, 78, 88, 100])
    expect(format.inspect).to eq("#<IronLion::Format created_at:48 tenant:20 model:10 node:10 sequence:12 random:22>")
  end

  it "gives some field names built-in behaviour" do
    format = IronLion.define do
      created_at bits: 44
      sequence   bits: 12
      random     bits: 8
    end
    expect(layout(format)).to eq([[:created_at, :time, 44], [:sequence, :counter, 12], [:random, :random, 66]])
  end

  it "lets the kind keyword name any field" do
    format = IronLion.define do
      minted_at time: 46
      serial    counter: 10
      salt      random: 4
      shard     bits: 6
    end
    expect(layout(format)).to eq(
      [[:minted_at, :time, 46], [:serial, :counter, 10], [:salt, :random, 4], [:shard, :value, 6],
       [:random, :random, 56]]
    )
  end

  it "accepts a block parameter instead of instance_eval" do
    format = IronLion.define { |f| f.tenant bits: 8 }
    expect(format.field_names).to eq(%i[created_at tenant random])
  end

  it "lets names that Object already uses be fields" do
    format = IronLion.define { display bits: 4 }
    expect(format.field_names).to include(:display)
  end

  it "accepts an epoch as a date string, Time or milliseconds" do
    ["2026-01-01T00:00:00Z", Time.utc(2026), 1_767_225_600_000].each do |epoch|
      format = IronLion.define { created_at time: 44, epoch: epoch }
      expect(format.fields.first.options[:epoch_ms]).to eq(1_767_225_600_000)
    end
  end

  it "describes itself as data for other back ends" do
    spec = IronLion.define { node bits: 10 }.to_h
    expect(spec).to include(version: 8, payload_bits: 122)
    expect(spec[:fields].first).to eq(name: :created_at, kind: :time, bits: 48, offset: 0, epoch_ms: 0)
  end

  describe "mistakes" do
    def rejects(message, &)
      expect { IronLion.define(&) }.to raise_error(IronLion::ConfigurationError, message)
    end

    it { rejects(/tenant needs a width/) { tenant } }
    it { rejects(/give it exactly one kind/) { tenant bits: 4, counter: 4 } }
    it { rejects(/does not understand epoc:; it accepts epoch:/) { created_at bits: 40, epoc: 0 } }
    it { rejects(/node \(value\) does not understand table:/) { node bits: 4, table: "x.yml" } }
    it { rejects(/must be 1..122 bits/) { tenant bits: 0 } }
    it { rejects(/positional arguments/) { tenant 20 } }
    it { rejects(/tenant declared more than once/) { tenant bits: 4; tenant bits: 4 } }
    it { rejects(/one time field/) { created_at bits: 40; minted_at time: 40 } }
    it { rejects(/created_at must be declared first/) { tenant bits: 4; created_at bits: 40 } }
    it { rejects(/at most one counter/) { sequence bits: 4; serial counter: 4 } }
    it { rejects(/= 126 bits.*trim 4/) { tenant bits: 78 } }
    it { rejects(/declare `random` last/) { random bits: 4; node bits: 4 } }
    it { rejects(/reserved/) { to_s bits: 4 } }
    it { rejects(/from: must be callable/) { tenant bits: 4, from: 3 } }
    it { rejects(/not a date/) { created_at time: 44, epoch: "someday" } }
    it { rejects(/needs a block/) }
  end
end
