# frozen_string_literal: true

RSpec.describe IronLion::Clock do
  let(:now) { [1000] }
  let(:clock) { described_class.new(3, source: -> { now.first }) }

  it "counts up within a millisecond and resets in the next" do
    expect(Array.new(3) { clock.tick }).to eq([[1000, 0], [1000, 1], [1000, 2]])
    now[0] = 1001
    expect(clock.tick).to eq([1001, 0])
  end

  it "borrows the next millisecond rather than blocking when the sequence runs out" do
    ticks = Array.new(6) { clock.tick }
    expect(ticks).to eq([[1000, 0], [1000, 1], [1000, 2], [1000, 3], [1001, 0], [1001, 1]])
  end

  it "stays monotonic when the system clock steps backwards" do
    clock.tick
    now[0] = 900
    expect(clock.tick).to eq([1000, 1])
  end

  it "returns the time alone when the format has no counter" do
    expect(described_class.new(source: -> { 5 }).tick).to eq([5, nil])
  end

  it "never repeats under contention" do
    format = IronLion.define { sequence bits: 4 }
    ids = Array.new(8) { Thread.new { Array.new(2000) { format.generate } } }.flat_map(&:value)
    pairs = ids.map { [_1.created_at, _1.sequence] }
    expect(pairs.uniq.size).to eq(ids.size)
  end
end
