# frozen_string_literal: true

RSpec.describe "Alphanumeric text fields" do
  let(:format) { IronLion.define { subdomain chars: 6 } }

  def subdomain_for(record = nil, **values) = format.generate(record, **values).subdomain

  it "sizes the field from the character count" do
    expect(IronLion.define { code chars: 5 }.fields[1].bits).to eq(26)
    expect(format.fields[1].bits).to eq(32)
    expect(format.to_h[:fields][1]).to include(name: :subdomain, kind: :text, bits: 32, chars: 6)
  end

  it "round-trips any alphanumeric string up to the limit, lowercased" do
    %w[a Z 9 acme ACME01 zzzzzz 000000].each do |input|
      expect(IronLion.parse(format.generate(subdomain: input).to_s, format:).subdomain).to eq(input.downcase)
    end
  end

  it "keeps leading zeros and lengths distinct" do
    decoded = %w[abc 0abc 00abc].map { subdomain_for(subdomain: _1) }
    expect(decoded).to eq(%w[abc 0abc 00abc])
  end

  it "accepts symbols" do
    expect(subdomain_for(subdomain: :acme)).to eq("acme")
  end

  it "resolves like any other field" do
    expect(subdomain_for(Struct.new(:subdomain_id).new("shop1"))).to eq("shop1")
    expect(subdomain_for(Struct.new(:subdomain).new(Struct.new(:id).new("shop2")))).to eq("shop2")
    with_env("IRON_LION_SUBDOMAIN" => "devbox") { expect(subdomain_for).to eq("devbox") }
  end

  describe "mistakes" do
    it "rejects strings that are too long, blank or not alphanumeric" do
      { "toolong" => /longer than 6/, "" => /blank/, "my-sh" => /letters and digits/ }.each do |input, message|
        expect { subdomain_for(subdomain: input) }.to raise_error(IronLion::InvalidValueError, message)
      end
    end

    it "rejects widths that cannot fit" do
      expect { IronLion.define { code chars: 24 } }.to raise_error(IronLion::ConfigurationError, /1..23 chars/)
      expect { IronLion.define { code chars: 0 } }.to raise_error(IronLion::ConfigurationError, /1..23 chars/)
    end

    it "describes the field in chars when no value is found" do
      expect { subdomain_for }.to raise_error(IronLion::MissingValueError, /`subdomain chars: 6, from:/)
    end
  end
end
