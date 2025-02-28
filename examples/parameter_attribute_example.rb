# frozen_string_literal: true

require "iron_lion_uuid"

# Configure UUID structure with parameter attributes
IronLionUUID.configure do |uuid|
  # Allocate 16 bits for model ID (numerical)
  uuid.parameter(bits: 16, name: :model)

  # Allocate 8 bits for status code (numerical)
  uuid.parameter(bits: 8, name: :status)

  # The remaining bits will be auto-filled with random data
end

# Generate UUIDs with different parameter values
puts "Generating UUIDs with different model IDs:"
models = [ 101, 202, 303 ]
models.each do |model_id|
  uuid = IronLionUUID.generate(model_id, 1) # status = 1 (active)
  puts "  Model #{model_id}: #{uuid}"
  puts "    Extracted model ID: #{uuid.model}"
  puts "    Extracted status: #{uuid.status}"
end

# Generate UUIDs with different status values
puts "\nGenerating UUIDs with different status codes:"
statuses = [ 1, 2, 3, 4 ] # 1=active, 2=pending, 3=archived, 4=deleted
statuses.each do |status|
  uuid = IronLionUUID.generate(101, status) # model = 101
  puts "  Status #{status}: #{uuid}"
  puts "    Extracted model ID: #{uuid.model}"
  puts "    Extracted status: #{uuid.status}"
end

# Using string parameters (converted from base36)
puts "\nGenerating UUIDs with string parameters:"
string_params = %w[a z 10 user123]
string_params.each do |param|
  uuid = IronLionUUID.generate(param, 1)
  puts "  String '#{param}': #{uuid}"
  puts "    Converted to model ID: #{uuid.model}"
  # Base36 values:
  # 'a' -> 10
  # 'z' -> 35
  # '10' -> 36
  # 'user123' -> complex calculation
end

# Validating parameter values
puts "\nValidation example:"
begin
  # Trying to generate a UUID with a value that's too large for the bit width
  # 8 bits can only hold values 0-255
  puts "  Attempting to generate UUID with status=500 (too large for 8 bits)..."
  uuid = IronLionUUID.generate(101, 500)
  puts "  This should not be reached"
rescue IronLionUUID::ValueTooLargeError => e
  puts "  #{e.class}: #{e.message}"
end
