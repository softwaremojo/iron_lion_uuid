# frozen_string_literal: true

module IronLion
  # A decoded position: the centre of a geohash cell, with how far the true
  # point may lie from it.
  Location = Data.define(:geohash, :latitude, :longitude, :latitude_error, :longitude_error) do
    alias_method :lat, :latitude
    alias_method :lng, :longitude
    alias_method :lon, :longitude

    def to_a = [latitude, longitude]

    def to_s = geohash

    def inspect = "#<IronLion::Location #{geohash} #{latitude.round(6)},#{longitude.round(6)}>"
  end

  # Packs a latitude/longitude into a geohash: longitude and latitude bits
  # interleaved, longitude first, 5 bits per character. The stored bits are
  # exactly the geohash, so decoded values paste straight into geohash tools.
  #
  # Coordinates are rounded down to their cell, so decoding returns the
  # cell's centre, not the original point.
  module Geohash
    ALPHABET = "0123456789bcdefghjkmnpqrstuvwxyz"
    VALID = /\A[#{ALPHABET}]+\z/
    MAX_CHARS = 24
    RESOLUTIONS = (1..MAX_CHARS)

    # Methods a record or point may offer, as [latitude, longitude] pairs.
    COORDINATE_METHODS = [%i[latitude longitude], %i[lat lng], %i[lat lon]].freeze

    module_function

    def bits(chars) = 5 * chars

    def encode(input, chars)
      return from_string(input, chars) if input.is_a?(String) || input.is_a?(Symbol)

      position = coordinates(input)
      raise ArgumentError, "is not a position (pass a geohash, [lat, lon], {lat:, lon:} or a point)" unless position

      latitude, longitude = position
      from_coordinates(latitude, longitude, bits(chars))
    end

    def decode(raw, chars)
      total = bits(chars)
      longitude_q, latitude_q = deinterleave(raw, total)
      latitude_bits = total / 2
      longitude_bits = total - latitude_bits

      latitude, latitude_error = centre(latitude_q, latitude_bits, -90, 90)
      longitude, longitude_error = centre(longitude_q, longitude_bits, -180, 180)

      Location.new(geohash: to_string(raw, chars), latitude:, longitude:, latitude_error:, longitude_error:)
    end

    # [latitude, longitude] from the shapes people use for positions, or nil.
    def coordinates(input)
      case input
      when Location then input.to_a
      when Array then input.size == 2 && input.all?(Numeric) ? input : nil
      when Hash then hash_coordinates(input)
      else object_coordinates(input)
      end
    end

    def object_coordinates(object)
      methods = COORDINATE_METHODS.find { |pair| pair.all? { object.respond_to?(_1) } } or return
      position = methods.map { object.public_send(_1) }
      position if position.all?(Numeric)
    end

    def hash_coordinates(hash)
      hash = hash.transform_keys(&:to_sym)
      latitude = hash[:latitude] || hash[:lat]
      longitude = hash[:longitude] || hash[:lng] || hash[:lon]
      [latitude, longitude] if latitude.is_a?(Numeric) && longitude.is_a?(Numeric)
    end

    def from_string(input, chars)
      text = input.to_s.strip.downcase
      raise ArgumentError, "is not a geohash" unless text.match?(VALID)
      raise ArgumentError, "is a #{text.length}-character geohash; #{chars} are needed" if text.length < chars

      text[0, chars].each_char.reduce(0) { |raw, char| (raw << 5) | ALPHABET.index(char) }
    end

    def from_coordinates(latitude, longitude, total)
      raise ArgumentError, "has latitude #{latitude}, outside -90..90" unless latitude.between?(-90, 90)
      raise ArgumentError, "has longitude #{longitude}, outside -180..180" unless longitude.between?(-180, 180)

      latitude_bits = total / 2
      longitude_bits = total - latitude_bits

      interleave(
        quantize(longitude, -180, 180, longitude_bits),
        quantize(latitude, -90, 90, latitude_bits),
        total
      )
    end

    def quantize(value, min, max, bits)
      cells = 1 << bits
      [((value.to_r - min) / (max - min) * cells).floor, cells - 1].min
    end

    def centre(quantized, bits, min, max)
      size = Rational(max - min, 1 << bits)
      [(min + (size * quantized) + (size / 2)).to_f, (size / 2).to_f]
    end

    # Bit i of the geohash (from the most significant) is longitude when i
    # is even and latitude when i is odd.
    def interleave(longitude_q, latitude_q, total)
      longitude_bits = total - (total / 2)
      latitude_bits = total / 2

      total.times.reduce(0) do |raw, i|
        bit =
          if i.even? then (longitude_q >> (longitude_bits - 1 - (i / 2))) & 1
          else (latitude_q >> (latitude_bits - 1 - (i / 2))) & 1
          end

        (raw << 1) | bit
      end
    end

    def deinterleave(raw, total)
      longitude_q = 0
      latitude_q = 0

      total.times do |i|
        bit = (raw >> (total - 1 - i)) & 1
        if i.even? then longitude_q = (longitude_q << 1) | bit
        else latitude_q = (latitude_q << 1) | bit
        end
      end

      [longitude_q, latitude_q]
    end

    def to_string(raw, chars)
      Array.new(chars) { |i| ALPHABET[(raw >> (5 * (chars - 1 - i))) & 0b11111] }.join
    end
  end
end
