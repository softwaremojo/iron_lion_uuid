# frozen_string_literal: true

module IronLion
  # Packs short alphanumeric strings (subdomains, codes, slugs) into integers
  # and back, losslessly and case-insensitively.
  #
  # It uses bijective base 36: digits run 1..36 instead of 0..35, so there is
  # no zero digit to pad with and every string has exactly one number.
  # "abc" and "0abc" stay distinct, and the empty string is 0. Up to n
  # characters need no more bits than plain base 36 would for exactly n
  # (5 chars fit in 26 bits, 6 in 32).
  module Base36
    DIGITS = [*"0".."9", *"a".."z"].join.freeze
    VALID = /\A[0-9a-z]+\z/

    module_function

    # The largest number a string of up to `chars` characters encodes to.
    def max(chars) = ((36**(chars + 1)) - 36) / 35

    def bits(chars) = max(chars).bit_length

    def encode(string, chars)
      text = string.to_s.downcase
      raise ArgumentError, "is blank" if text.empty?
      raise ArgumentError, "is longer than #{chars} characters" if text.length > chars
      raise ArgumentError, "may only contain letters and digits" unless text.match?(VALID)

      text.each_char.reduce(0) { |number, char| (number * 36) + DIGITS.index(char) + 1 }
    end

    def decode(number)
      text = +""
      while number.positive?
        number -= 1
        text.prepend(DIGITS[number % 36])
        number /= 36
      end
      text
    end
  end
end
