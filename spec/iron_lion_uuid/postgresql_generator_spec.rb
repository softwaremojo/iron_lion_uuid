# frozen_string_literal: true

require "spec_helper"

RSpec.describe IronLionUUID::PostgreSQLGenerator do
  before do
    # Set up a test configuration with all attribute types
    IronLionUUID.configure do |uuid|
      uuid.parameter(bits: 16, name: :model)
      uuid.env(bits: 8, name: :node, key: :NODE_ID)
      uuid.timestamp(bits: 36, precision: :millisecond, name: :created_at)
      uuid.sequence(bits: 16, name: :seq)
      uuid.random(bits: 32, name: :random_part)
    end
  end

  after do
    # Clean up
    if IronLionUUID.instance_variable_defined?(:@configuration)
      IronLionUUID.remove_instance_variable(:@configuration)
    end
  end

  describe "#generate_postgresql_function" do
    it "generates a valid PostgreSQL function" do
      generator = described_class.new

      sql = generator.generate_function

      # Check for function declaration
      expect(sql).to include("CREATE OR REPLACE FUNCTION public.generate_iron_lion_uuid")
      expect(sql).to include("RETURNS UUID")
      expect(sql).to include("LANGUAGE plpgsql")

      # Check for parameter declaration
      expect(sql).to include("model INTEGER")

      # Check for version and variant bits
      expect(sql).to include("-- Set version bits (UUID v8)")
      expect(sql).to include("-- Set variant bits (RFC 4122)")

      # Check for attribute handling
      expect(sql).to include("-- Set bits for parameter model")
      expect(sql).to include("-- Set bits for environment variable node")
      expect(sql).to include("-- Set bits for timestamp")
      expect(sql).to include("-- Set bits for sequence")
      expect(sql).to include("-- Set bits for random data")
    end

    it "allows customizing the function name and schema" do
      generator = described_class.new

      sql = generator.generate_function(function_name: "custom_uuid_generator",
                                        schema: "my_schema")

      expect(sql).to include("CREATE OR REPLACE FUNCTION my_schema.custom_uuid_generator")
    end

    it "includes sequence creation when sequence attributes are used" do
      generator = described_class.new

      sql = generator.generate_function

      expect(sql).to include("CREATE SEQUENCE IF NOT EXISTS")
      expect(sql).to include("SELECT nextval")
      expect(sql).to include("CYCLE MAXVALUE")
    end
  end

  describe "#generate_drop_function" do
    it "generates a valid DROP FUNCTION statement" do
      generator = described_class.new

      sql = generator.generate_drop_function

      expect(sql).to include("DROP FUNCTION IF EXISTS public.generate_iron_lion_uuid")
    end

    it "allows customizing the function name and schema" do
      generator = described_class.new

      sql = generator.generate_drop_function(function_name: "custom_uuid_generator",
                                             schema: "my_schema")

      expect(sql).to include("DROP FUNCTION IF EXISTS my_schema.custom_uuid_generator")
    end
  end

  describe "attribute bit generation" do
    it "generates parameter attribute bits correctly" do
      generator = described_class.new

      # Get private method access
      parameter_attr = IronLionUUID.configuration.attribute_by_name(:model)
      sql = generator.send(:generate_parameter_bits, parameter_attr)

      expect(sql).to include("value_to_set := model")
      expect(sql).to include("Check if value exceeds bit width")
      expect(sql).to include("IF value_to_set >= POWER(2, #{parameter_attr.bits})")
      expect(sql).to include("FOR bit_position IN 0..#{parameter_attr.bits - 1}")
    end

    it "generates timestamp attribute bits correctly" do
      generator = described_class.new

      # Get private method access
      timestamp_attr = IronLionUUID.configuration.attribute_by_name(:created_at)
      sql = generator.send(:generate_timestamp_bits, timestamp_attr)

      expect(sql).to include("-- Get current timestamp at millisecond precision")
      expect(sql).to include("ts_value := (EXTRACT(EPOCH FROM CURRENT_TIMESTAMP) * 1000)")
      expect(sql).to include("-- Ensure it fits in the bit width")
      expect(sql).to include("FOR bit_position IN 0..#{timestamp_attr.bits - 1}")
    end

    it "generates sequence attribute bits correctly" do
      generator = described_class.new

      # Get private method access
      sequence_attr = IronLionUUID.configuration.attribute_by_name(:seq)
      sql = generator.send(:generate_sequence_bits, sequence_attr)

      expect(sql).to include("CREATE SEQUENCE IF NOT EXISTS")
      expect(sql).to include("SELECT nextval")
      expect(sql).to include("MAXVALUE ' || (POWER(2, #{sequence_attr.bits}) - 1)")
      expect(sql).to include("FOR bit_position IN 0..#{sequence_attr.bits - 1}")
    end

    it "generates environment variable attribute bits correctly" do
      generator = described_class.new

      # Get private method access
      env_attr = IronLionUUID.configuration.attribute_by_name(:node)
      sql = generator.send(:generate_env_bits, env_attr)

      expect(sql).to include("-- Set bits for environment variable #{env_attr.name}")
      expect(sql).to include("-- This would normally read from ENV['#{env_attr[:key]}']")
      expect(sql).to include("value_to_set := 0; -- PLACEHOLDER")
      expect(sql).to include("FOR bit_position IN 0..#{env_attr.bits - 1}")
    end

    it "generates random attribute bits correctly" do
      generator = described_class.new

      # Get private method access
      random_attr = IronLionUUID.configuration.attribute_by_name(:random_part)
      sql = generator.send(:generate_random_bits, random_attr)

      expect(sql).to include("-- Set bits for random data")
      expect(sql).to include("FOR bit_position IN 0..#{random_attr.bits - 1}")
      expect(sql).to include("IF random() > 0.5 THEN")
    end
  end
end
