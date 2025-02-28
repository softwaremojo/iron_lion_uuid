# frozen_string_literal: true

require "iron_lion_uuid"
require "time"

puts "IRON LION UUID EXAMPLE: TIMESTAMP ATTRIBUTES"
puts "==========================================="

# Configure UUID structure with timestamp attributes at different precisions
IronLionUUID.configure do |uuid|
  # Allocate 36 bits for timestamp at millisecond precision
  uuid.timestamp(bits: 36, precision: :millisecond, name: :created_at)

  # Allocate 16 bits for model ID parameter
  uuid.parameter(bits: 16, name: :model)

  # The remaining 70 bits will be auto-filled with random data
end

puts "UUID Configuration:"
puts "  - 36-bit timestamp (millisecond precision)"
puts "  - 16-bit model ID parameter"
puts "  - Remaining bits are random"
puts

# Generate UUIDs with timestamps
puts "Generating UUIDs with timestamps:"

# Generate UUIDs for different models
models = [
  { id: 1, name: "User" },
  { id: 2, name: "Product" },
  { id: 3, name: "Order" }
]

models.each do |model|
  # Generate a UUID for this model
  uuid = IronLionUUID.generate(model[:id])

  # Extract the timestamp and convert to Time
  timestamp_ms = uuid.created_at
  timestamp_time = Time.at(timestamp_ms / 1000.0)

  puts "\nModel: #{model[:name]} (ID: #{model[:id]})"
  puts "  UUID: #{uuid}"
  puts "  Created at: #{timestamp_time.strftime('%Y-%m-%d %H:%M:%S.%L')}"
  puts "  Timestamp value: #{timestamp_ms}"
  puts "  Model ID: #{uuid.model}"
end

# Demonstrate time sorting
puts "\nGenerating UUIDs at different times and sorting them:"

# Create an array to store our time-spaced UUIDs
uuids = []

# Generate UUIDs spaced 1 second apart
puts "  Generating 5 UUIDs at 1-second intervals..."
5.times do |i|
  # Sleep for 1 second to ensure different timestamps
  sleep 1
  uuid = IronLionUUID.generate(1)
  timestamp = Time.at(uuid.created_at / 1000.0)

  uuids << { uuid: uuid, time: timestamp }
  puts "    #{i + 1}. #{timestamp.strftime('%H:%M:%S.%L')} -> #{uuid}"
end

# Shuffle the UUIDs
shuffled = uuids.shuffle
puts "\n  Shuffled UUIDs:"
shuffled.each_with_index do |item, i|
  puts "    #{i + 1}. #{item[:time].strftime('%H:%M:%S.%L')} -> #{item[:uuid]}"
end

# Sort by UUID value, which should match chronological order due to timestamp bits
sorted = shuffled.sort_by { |item| item[:uuid].value }
puts "\n  Sorted by UUID value (chronological due to timestamp):"
sorted.each_with_index do |item, i|
  puts "    #{i + 1}. #{item[:time].strftime('%H:%M:%S.%L')} -> #{item[:uuid]}"
end

# Demonstrate different precision levels
puts "\nDifferent timestamp precision levels:"

# Reset configuration to demonstrate different precisions
IronLionUUID.instance_variable_set(:@configuration, nil)
IronLionUUID.instance_variable_set(:@generator, nil)

precisions = {
  second: 32,      # ~136 years with 32 bits
  millisecond: 42, # ~136 years with 42 bits
  microsecond: 52, # ~136 years with 52 bits
  nanosecond: 62   # ~136 years with 62 bits
}

precisions.each do |precision, bits|
    IronLionUUID.configure do |uuid|
      uuid.timestamp(bits: bits, precision: precision)
    end

    uuid = IronLionUUID.generate
    timestamp_value = uuid.timestamp

    # Convert to appropriate display based on precision
    case precision
    when :second
      display_time = Time.at(timestamp_value).strftime("%Y-%m-%d %H:%M:%S")
    when :millisecond
      display_time = Time.at(timestamp_value / 1000.0).strftime("%Y-%m-%d %H:%M:%S.%L")
    when :microsecond
      seconds = timestamp_value / 1_000_000.0
      display_time = Time.at(seconds).strftime("%Y-%m-%d %H:%M:%S.%L") +
                     format("%03d", (seconds * 1_000_000).to_i % 1000)
    when :nanosecond
      seconds = timestamp_value / 1_000_000_000.0
      display_time = Time.at(seconds).strftime("%Y-%m-%d %H:%M:%S.%L") +
                     format("%06d", (seconds * 1_000_000_000).to_i % 1_000_000)
    end

    puts "\n  #{precision.to_s.capitalize} precision (#{bits} bits):"
    puts "    UUID: #{uuid}"
    puts "    Timestamp: #{display_time}"
    puts "    Raw value: #{timestamp_value}"
rescue StandardError => e
    puts "\n  #{precision.to_s.capitalize} precision (#{bits} bits):"
    puts "    Error: #{e.message}"
end

# Demonstrate practical use with time boundaries
puts "\nTimestamp boundaries use case:"

# Reset configuration
IronLionUUID.instance_variable_set(:@configuration, nil)
IronLionUUID.instance_variable_set(:@generator, nil)

# Configure for time range use case
IronLionUUID.configure do |uuid|
  uuid.timestamp(bits: 42, precision: :millisecond, name: :created_at)
  uuid.parameter(bits: 8, name: :event_type)
end

# Scenario: Generating UUIDs for events with different types
event_types = [
  { id: 1, name: "Login" },
  { id: 2, name: "Logout" },
  { id: 3, name: "Purchase" },
  { id: 4, name: "Page View" }
]

# Generate some events
puts "  Generating events:"
events = []

event_types.each do |event|
  # Create event UUID
  uuid = IronLionUUID.generate(event[:id])
  timestamp = Time.at(uuid.created_at / 1000.0)

  events << { uuid: uuid, type: event, time: timestamp }

  puts "    #{event[:name]} at #{timestamp.strftime('%H:%M:%S.%L')} -> #{uuid}"
end

# Simulate finding events in a time range
now = Time.now
one_minute_ago = now - 60

puts "\n  Finding events between #{one_minute_ago.strftime('%H:%M:%S')} " \
     "and #{now.strftime('%H:%M:%S')}:"

  # Convert time boundaries to millisecond timestamps
  min_timestamp = (one_minute_ago.to_f * 1000).to_i
  max_timestamp = (now.to_f * 1000).to_i

  # Filter events in the time range
  events_in_range = events.select do |event|
    event[:uuid].created_at >= min_timestamp && event[:uuid].created_at <= max_timestamp
  end

  if events_in_range.empty?
    puts "    No events found in the given time range."
  else
    events_in_range.each do |event|
      time_str = event[:time].strftime("%H:%M:%S.%L")
      puts "    #{event[:type][:name]} at #{time_str} -> #{event[:uuid]}"
    end
  end

  puts "\nTimestamp UUIDs can help:"
  puts "  - Track when records were created without extra database fields"
  puts "  - Generate naturally time-sortable identifiers"
  puts "  - Create time-bound query ranges directly from UUIDs"
  puts "  - Balance between precision and bit usage based on your needs"
