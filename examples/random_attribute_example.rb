# frozen_string_literal: true

require "iron_lion_uuid"

# Configure UUID structure with random attributes
IronLionUUID.configure do |uuid|
  # Allocate 36 bits for first random section
  uuid.random(bits: 36, name: :section1)

  # Allocate 48 bits for second random section
  uuid.random(bits: 48, name: :section2)

  # The remaining 38 bits will be auto-filled with random data
end

# Generate some UUIDs
puts "Generating 5 random UUIDs:"
5.times do |i|
  uuid = IronLionUUID.generate
  puts "  #{i + 1}. #{uuid}"
end

# Different random UUIDs should never collide
# Let's generate a bunch and check for uniqueness
puts "\nChecking uniqueness of 1000 UUIDs..."
uuids = Array.new(1000) { IronLionUUID.generate }
unique_count = uuids.map(&:to_s).uniq.size

puts "  Generated #{uuids.size} UUIDs"
puts "  Unique UUIDs: #{unique_count}"
puts "  All UUIDs unique: #{unique_count == uuids.size ? 'YES' : 'NO'}"

# We can parse UUIDs from strings
uuid_str = uuids.first.to_s
puts "\nParsing UUID from string: #{uuid_str}"
parsed_uuid = IronLionUUID.from_string(uuid_str)
puts "  Parsed: #{parsed_uuid}"
puts "  Original and parsed equal? #{uuids.first == parsed_uuid ? 'YES' : 'NO'}"

# Validate UUIDs
puts "\nValidating UUIDs:"
valid_str = "f47ac10b-58cc-4372-a567-0e02b2c3d479"
invalid_str = "not-a-valid-uuid"

puts "  '#{valid_str}' is valid? #{IronLionUUID.valid?(valid_str) ? 'YES' : 'NO'}"
puts "  '#{invalid_str}' is valid? #{IronLionUUID.valid?(invalid_str) ? 'YES' : 'NO'}"
