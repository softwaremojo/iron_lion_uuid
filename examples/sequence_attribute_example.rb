# frozen_string_literal: true

require "iron_lion_uuid"

puts <<~TEXT
  IRON LION UUID EXAMPLE: SEQUENCE ATTRIBUTES
  ===========================================
TEXT

# Configure UUID structure with a sequence attribute
IronLionUUID.configure do |uuid|
  # Allocate 16 bits for sequence number (provides up to 65,536 sequential values)
  uuid.sequence(bits: 16, name: :seq)

  # Allocate 16 bits for model ID parameter
  uuid.parameter(bits: 16, name: :model)

  # The remaining 90 bits will be auto-filled with random data
end

puts <<~TEXT
  UUID Configuration:
    - 16-bit sequence (up to 65,536 sequential values)
    - 16-bit model ID parameter
    - Remaining bits are random

  Generating sequential UUIDs:
TEXT

# Generate 5 UUIDs in sequence
5.times do |i|
  uuid = IronLionUUID.generate(101) # model ID = 101
  puts "  #{i + 1}. UUID: #{uuid}"
  puts "     Sequence number: #{uuid.seq}"
  puts "     Model ID: #{uuid.model}"
end

# Demonstrate how sequence works with different models
puts "\nGenerating UUIDs for different models:"

models = [
  { id: 1, name: "User" },
  { id: 2, name: "Product" },
  { id: 3, name: "Order" }
]

models.each do |model|
  uuid = IronLionUUID.generate(model[:id])

  puts "  Model: #{model[:name]} (ID: #{model[:id]})"
  puts "    UUID: #{uuid}"
  puts "    Sequence number: #{uuid.seq}"
  puts "    Model ID: #{uuid.model}"
end

# Demonstrate sequence wrapping
puts "\nDemonstrating sequence wrapping:"

# Configure with a small bit width for demonstration purposes
IronLionUUID.instance_variable_set(:@configuration, nil)
IronLionUUID.instance_variable_set(:@generator, nil)

IronLionUUID.configure do |uuid|
  # Allocate just 3 bits for sequence (max value is 7)
  uuid.sequence(bits: 3, name: :seq)
end

puts "  Configured with 3-bit sequence (values 0-7)"
puts "  Generating 10 UUIDs to demonstrate wrapping:"

10.times do |i|
  uuid = IronLionUUID.generate
  puts "    #{i + 1}. Sequence number: #{uuid.seq}"
end

# Demonstrate thread safety
puts "\nDemonstrating thread safety:"

# Configure with larger bit width again
IronLionUUID.instance_variable_set(:@configuration, nil)
IronLionUUID.instance_variable_set(:@generator, nil)

IronLionUUID.configure do |uuid|
  uuid.sequence(bits: 16, name: :seq)
end

# Generate UUIDs in multiple threads
thread_count = 5
uuids_per_thread = 3

puts "  Generating UUIDs in #{thread_count} parallel threads " \
     "(#{uuids_per_thread} UUIDs per thread):"

threads = []
thread_uuids = {}

thread_count.times do |t|
  threads << Thread.new do
    thread_uuids[t] = []
    uuids_per_thread.times do
      uuid = IronLionUUID.generate
      thread_uuids[t] << uuid
    end
  end
end

# Wait for all threads to complete
threads.each(&:join)

# Display the results
thread_count.times do |t|
  puts "\n  Thread #{t + 1} generated:"
  thread_uuids[t].each do |uuid|
    puts "    UUID: #{uuid}"
    puts "    Sequence: #{uuid.seq}"
  end
end

# Check uniqueness
all_sequences = thread_uuids.values.flatten.map(&:seq)
puts <<~TEXT

    All sequence numbers generated: #{all_sequences.join(', ')}
    Unique sequence numbers: #{all_sequences.uniq.size} (expected: #{thread_count * uuids_per_thread})
    All sequence numbers unique: #{all_sequences.uniq.size == all_sequences.size ? 'YES' : 'NO'}

  Use cases for sequence attributes:
    1. High-volume ID generation - ensures uniqueness even when many IDs are created in a short time
    2. Ordered IDs - allows for chronological ordering of IDs created within the same time period
    3. Sharded databases - can help ensure uniqueness across distributed systems
    4. Batch processing - can identify records created in the same operation
    5. Debugging - sequential numbers make it easier to trace ID generation

  Benefits of thread-safe sequence generation:
    - Safe for multi-threaded applications like web servers
    - No lock contention when generating UUIDs in parallel
    - Consistent, predictable behavior even under load
    - Scalable to high-concurrency environments
TEXT
