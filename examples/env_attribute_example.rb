# frozen_string_literal: true

require "iron_lion_uuid"

# First, set some environment variables for demonstration purposes
ENV["NODE_ID"] = "42"       # A numeric ID for the current node/server
ENV["ENV_TYPE"] = "prod"    # A string indicator for the environment (dev/test/prod)
ENV["DATACENTER"] = "east1" # A string identifier for the datacenter

# Configure UUID structure with environment variable attributes
IronLionUUID.configure do |config|
  # Allocate 12 bits for node ID (numerical)
  config.env(bits: 12, name: :node, key: :NODE_ID)

  # Allocate 8 bits for environment type (converted from string)
  config.env(bits: 8, name: :env_type, key: :ENV_TYPE)

  # Allocate 16 bits for datacenter (converted from string)
  config.env(bits: 16, name: :datacenter, key: :DATACENTER)

  # The remaining bits will be auto-filled with random data
end

# Generate a UUID using the environment variables
uuid = IronLionUUID.generate
puts "Generated UUID with environment variables: #{uuid}"
puts "  Node ID (from ENV['NODE_ID']): #{uuid.node}"
puts "  Environment Type (from ENV['ENV_TYPE']): #{uuid.env_type}"
puts "  Datacenter (from ENV['DATACENTER']): #{uuid.datacenter}"
puts "  As converted values:"
puts "    'prod' in base36 = #{ENV['ENV_TYPE'].to_i(36)}"
puts "    'east1' in base36 = #{ENV['DATACENTER'].to_i(36)}"

# Demonstrating multiple UUIDs with the same environment
puts "\nGenerating multiple UUIDs with the same environment:"
3.times do |i|
  uuid = IronLionUUID.generate
  puts "  UUID #{i + 1}: #{uuid}"
end
puts "Note: The environment components remain the same, but the random parts differ"

# Changing an environment variable and generating a new UUID
puts "\nChanging NODE_ID environment variable:"
puts "  Original NODE_ID: #{ENV.fetch('NODE_ID', nil)}"
ENV["NODE_ID"] = "99"
puts "  New NODE_ID: #{ENV.fetch('NODE_ID', nil)}"

uuid = IronLionUUID.generate
puts "  New UUID: #{uuid}"
puts "  New Node ID component: #{uuid.node}"

# Demonstrating error for missing environment variable
puts "\nDemonstrating error for missing environment variable:"
begin
  ENV.delete("NODE_ID")
  puts "  Deleted NODE_ID environment variable"
  puts "  Attempting to generate UUID..."
  uuid = IronLionUUID.generate
  puts "  This should not be reached"
rescue IronLionUUID::MissingEnvironmentError => e
  puts "  #{e.class}: #{e.message}"
end

# Restore the environment variable
ENV["NODE_ID"] = "42"

# Demonstrating error for value too large for bit width
puts "\nDemonstrating error for value too large for bit width:"
begin
  ENV["NODE_ID"] = "4096" # Too large for 12 bits (max 4095)
  puts "  Set NODE_ID to 4096 (too large for 12 bits)"
  puts "  Attempting to generate UUID..."
  uuid = IronLionUUID.generate
  puts "  This should not be reached"
rescue IronLionUUID::ValueTooLargeError => e
  puts "  #{e.class}: #{e.message}"
end

# Show combining environment variables with parameters
puts "\nCombining environment variables with parameters:"
ENV["NODE_ID"] = "42" # Reset to valid value

# Reconfigure with both environment and parameter attributes
IronLionUUID.configure do |config|
  config.env(bits: 12, name: :node, key: :NODE_ID)
  config.parameter(bits: 16, name: :model)
end

# Generate UUIDs with parameter values
models = [ 101, 202, 303 ]
models.each do |model_id|
  uuid = IronLionUUID.generate(model_id)
  puts "  Model #{model_id} on Node #{ENV.fetch('NODE_ID', nil)}: #{uuid}"
  puts "    Extracted node ID: #{uuid.node}"
  puts "    Extracted model ID: #{uuid.model}"
end
