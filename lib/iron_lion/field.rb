# frozen_string_literal: true

module IronLion
  # One named run of bits in a format's payload. Offsets count from the most
  # significant payload bit, so the first field is the primary sort key.
  Field = Data.define(:name, :kind, :bits, :offset, :options) do
    def max = (1 << bits) - 1

    def shift = Layout::PAYLOAD_BITS - offset - bits

    def extract(payload) = (payload >> shift) & max

    def place(raw) = raw << shift

    def model? = kind == :value && name == :model

    def to_h
      spec = { name:, kind:, bits:, offset: }
      spec[:epoch_ms] = options[:epoch_ms] if kind == :time
      spec[:chars] = options[:chars] if kind == :text
      spec
    end
  end
end
