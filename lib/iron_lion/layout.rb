# frozen_string_literal: true

module IronLion
  # Places a format's 122 payload bits around the 6 bits UUIDv8 reserves:
  #
  #   bits   0..47   payload 0..47
  #   bits  48..51   version (0b1000)
  #   bits  52..63   payload 48..59
  #   bits  64..65   variant (0b10)
  #   bits  66..127  payload 60..121
  #
  # Payload order is preserved, so ids sort by their leading fields.
  module Layout
    PAYLOAD_BITS = 122
    VERSION = 0x8
    VARIANT = 0b10

    LOW_MASK = (1 << 62) - 1
    HEX = /\A\h{32}\z/

    module_function

    def to_uuid(payload)
      high = payload >> 74
      mid  = (payload >> 62) & 0xFFF
      low  = payload & LOW_MASK
      (high << 80) | (VERSION << 76) | (mid << 64) | (VARIANT << 62) | low
    end

    def to_payload(uuid)
      unless uuid.is_a?(Integer) && uuid.between?(0, (1 << 128) - 1)
        raise ParseError, "#{uuid.inspect} is not a 128-bit integer"
      end

      unless (uuid >> 76) & 0xF == VERSION && (uuid >> 62) & 0b11 == VARIANT
        raise ParseError, "#{hyphenate(uuid)} is not a UUIDv8, so it was not minted by IronLion"
      end

      ((uuid >> 80) << 74) | (((uuid >> 64) & 0xFFF) << 62) | (uuid & LOW_MASK)
    end

    def hyphenate(uuid)
      hex = uuid.to_s(16).rjust(32, "0")
      "#{hex[0, 8]}-#{hex[8, 4]}-#{hex[12, 4]}-#{hex[16, 4]}-#{hex[20, 12]}"
    end

    # Accepts the forms people paste: any case, with or without hyphens,
    # braces or a urn:uuid: prefix.
    def from_string(string)
      hex = string.strip.downcase.delete_prefix("urn:uuid:").delete("{}-")
      raise ParseError, "#{string.inspect} is not a UUID" unless hex.match?(HEX)

      hex.to_i(16)
    end
  end
end
