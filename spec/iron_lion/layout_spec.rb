# frozen_string_literal: true

RSpec.describe IronLion::Layout do
  let(:all_ones) { (1 << 122) - 1 }

  it "sets version 8 and the RFC variant whatever the payload" do
    [0, all_ones, SecureRandom.random_number(1 << 122)].each do |payload|
      uuid = described_class.to_uuid(payload)
      expect((uuid >> 76) & 0xF).to eq(8)
      expect((uuid >> 62) & 0b11).to eq(0b10)
    end
  end

  it "round-trips every payload bit" do
    100.times do
      payload = SecureRandom.random_number(1 << 122)
      expect(described_class.to_payload(described_class.to_uuid(payload))).to eq(payload)
    end
    expect(described_class.to_payload(described_class.to_uuid(all_ones))).to eq(all_ones)
  end

  it "keeps the payload order, so ids sort like their payloads" do
    payloads = Array.new(200) { SecureRandom.random_number(1 << 122) }
    expect(payloads.sort.map { described_class.to_uuid(_1) }).to eq(payloads.map { described_class.to_uuid(_1) }.sort)
  end

  it "puts the leading 48 payload bits in the first 12 hex digits" do
    uuid = described_class.to_uuid(0xABCDEF012345 << 74)
    expect(described_class.hyphenate(uuid)).to start_with("abcdef01-2345-8")
  end

  it "rejects UUIDs that are not version 8" do
    v4 = "9b2e7c1a-3f4d-4e5a-8b6c-7d8e9f0a1b2c"
    expect { described_class.to_payload(described_class.from_string(v4)) }
      .to raise_error(IronLion::ParseError, /not a UUIDv8/)
  end

  describe ".from_string" do
    let(:canonical) { "01a1e923-e9f8-8010-9cc0-10d400348597" }
    let(:value) { 0x01a1e923e9f880109cc010d400348597 }

    it "accepts the forms people paste" do
      [canonical, canonical.upcase, canonical.delete("-"), "{#{canonical}}", "urn:uuid:#{canonical}", " #{canonical}\n"]
        .each { expect(described_class.from_string(_1)).to eq(value) }
    end

    it "rejects anything else" do
      ["", "nope", canonical[0..-2], "#{canonical}0"].each do |input|
        expect { described_class.from_string(input) }.to raise_error(IronLion::ParseError)
      end
    end
  end
end
