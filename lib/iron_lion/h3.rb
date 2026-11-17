# frozen_string_literal: true

module IronLion
  # Packs an H3 cell (https://h3geo.org) at a fixed resolution into the few
  # bits that actually vary.
  #
  # A 64-bit H3 cell index is mostly constant for a given resolution:
  #
  #   bit  63      reserved (0)
  #   bits 59..62  mode (1 = cell)
  #   bits 56..58  reserved (0)
  #   bits 52..55  resolution
  #   bits 45..51  base cell (0..121)
  #   bits  0..44  15 digits of 3 bits; digits past the resolution are 7
  #
  # So a resolution-r field stores only the base cell and r digits:
  # 7 + 3r bits. Finer cells are trimmed to their parent at r, which is the
  # same operation as H3's cellToParent.
  module H3
    MODE_CELL = 1
    MAX_BASE_CELL = 121
    DIGITS = 15
    RESOLUTIONS = (0..15)
    HEX = /\A(?:0x)?(\h{1,16})\z/

    module_function

    def bits(resolution) = 7 + (3 * resolution)

    def encode(input, resolution)
      index = to_index(input)
      check_cell!(index)

      cell_resolution = (index >> 52) & 0xF
      if cell_resolution < resolution
        raise ArgumentError, "is a resolution #{cell_resolution} cell, coarser than resolution #{resolution}"
      end

      base_cell = (index >> 45) & 0x7F
      digits = (index >> digit_shift(resolution)) & digit_mask(resolution)
      check_digits!(digits, resolution)

      (base_cell << (3 * resolution)) | digits
    end

    # The canonical H3 string for the cell, e.g. "8928308280fffff".
    def decode(raw, resolution)
      base_cell = raw >> (3 * resolution)
      digits = raw & digit_mask(resolution)

      index = (MODE_CELL << 59) |
              (resolution << 52) |
              (base_cell << 45) |
              (digits << digit_shift(resolution)) |
              ((1 << digit_shift(resolution)) - 1)

      index.to_s(16)
    end

    def to_index(input)
      case input
      when Integer then input
      when String
        hex = input.strip.downcase[HEX, 1]
        raise ArgumentError, "is not an H3 index" unless hex

        hex.to_i(16)
      when Array, Hash
        raise ArgumentError,
              "is a coordinate; IronLion takes H3 cells, not coordinates. Convert it to a cell first " \
              "(the h3 gem can), for example in a `from: ->(record) { ... }` resolver"
      else
        raise ArgumentError, "is not an H3 index (pass an integer or a hex string)"
      end
    end

    def check_cell!(index)
      valid = index.between?(0, (1 << 64) - 1) &&
              (index >> 63).zero? &&
              ((index >> 59) & 0xF) == MODE_CELL &&
              (index >> 56).nobits?(0x7) &&
              ((index >> 45) & 0x7F) <= MAX_BASE_CELL

      raise ArgumentError, "is not an H3 cell index" unless valid
    end

    def check_digits!(digits, resolution)
      resolution.times do |i|
        next unless (digits >> (3 * i)).allbits?(0b111)

        raise ArgumentError, "is not a valid H3 cell (digit #{resolution - i} is 7)"
      end
    end

    def digit_shift(resolution) = 3 * (DIGITS - resolution)

    def digit_mask(resolution) = (1 << (3 * resolution)) - 1
  end
end
