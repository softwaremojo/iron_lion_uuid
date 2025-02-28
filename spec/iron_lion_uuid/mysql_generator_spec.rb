# frozen_string_literal: true

require "spec_helper"

RSpec.describe IronLionUUID::MySQLGenerator do
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

  describe "#generate_mysql_function" do
    it "generates a valid MySQL function" do
      generator = described_class.new

      sql = generator.generate_function

      # Check for function declaration
      expect(sql).to include("CREATE FUNCTION generate_iron_lion_uuid")
      expect(sql).to include("RETURNS CHAR(36)")
      expect(sql).to include("DELIMITER //")

      # Check for parameter declaration
      expect(sql).to include("model BIGINT UNSIGNED")

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

    it "allows customizing the function name" do
      generator = described_class.new

      sql = generator.generate_function(function_name: "custom_uuid_generator")

      expect(sql).to include("CREATE FUNCTION custom_uuid_generator")
    end

    it "can generate binary output instead of string" do
      generator = described_class.new

      sql = generator.generate_function(binary_output: true)

      expect(sql).to include("RETURNS BINARY(16)")
      expect(sql).to include("RETURN uuid_bin")
      expect(sql).not_to include("RETURN uuid_str")
    end

    it "includes session variable for sequence when sequence attributes are used" do
      generator = described_class.new

      sql = generator.generate_function

      expect(sql).to include("@seq_seq")
      expect(sql).to include("IF @seq_seq IS NULL")
      expect(sql).to include("SET @seq_seq = (")
    end
  end

  describe "#generate_drop_function" do
    it "generates a valid DROP FUNCTION statement" do
      generator = described_class.new

      sql = generator.generate_drop_function

      expect(sql).to include("DROP FUNCTION IF EXISTS generate_iron_lion_uuid")
    end

    it "allows customizing the function name" do
      generator = described_class.new

      sql = generator.generate_drop_function(function_name: "custom_uuid_generator")

      expect(sql).to include("DROP FUNCTION IF EXISTS custom_uuid_generator")
    end
  end

  describe "attribute bit generation" do
    it "generates parameter attribute bits correctly" do
      generator = described_class.new

      # Get private method access
      parameter_attr = IronLionUUID.configuration.attribute_by_name(:model)
      sql = generator.send(:generate_parameter_bits, parameter_attr)

      expect(sql).to include("-- Set bits for parameter #{parameter_attr.name}")

      expect(sql).to include(
        "IF #{parameter_attr.name} >= POWER(2, #{parameter_attr.bits})"
      )

      expect(sql).to include("SET MESSAGE_TEXT")
      expect(sql).to include("UNHEX(")
    end

    it "generates timestamp attribute bits correctly" do
      generator = described_class.new

      # Get private method access
      timestamp_attr = IronLionUUID.configuration.attribute_by_name(:created_at)
      sql = generator.send(:generate_timestamp_bits, timestamp_attr)

      expect(sql).to include("-- Set bits for timestamp")
      expect(sql).to include("DECLARE ts_value BIGINT")
      expect(sql).to include("NOW(3)") # Millisecond precision
      expect(sql).to include("SET ts_value")
    end

    it "generates sequence attribute bits correctly" do
      generator = described_class.new

      # Get private method access
      sequence_attr = IronLionUUID.configuration.attribute_by_name(:seq)
      sql = generator.send(:generate_sequence_bits, sequence_attr)

      expect(sql).to include("-- Set bits for sequence")
      expect(sql).to include("@#{sequence_attr.name}_seq")
      expect(sql).to include("IF @#{sequence_attr.name}_seq IS NULL")
      expect(sql).to include("SET @#{sequence_attr.name}_seq = (")
      expect(sql).to include("% #{1 << sequence_attr.bits}")
    end

    it "generates environment variable attribute bits correctly" do
      generator = described_class.new

      # Get private method access
      env_attr = IronLionUUID.configuration.attribute_by_name(:node)
      sql = generator.send(:generate_env_bits, env_attr)

      expect(sql).to include("-- Set bits for environment variable #{env_attr.name}")

      expect(sql).to include(
        "-- Note: MySQL functions cannot access environment variables directly"
      )

      expect(sql).to include(env_attr[:key].to_s)
    end

    it "generates random attribute bits correctly" do
      generator = described_class.new

      # Get private method access
      random_attr = IronLionUUID.configuration.attribute_by_name(:random_part)
      sql = generator.send(:generate_random_bits, random_attr)

      expect(sql).to include("-- Set bits for random data")
      expect(sql).to include("RAND()")
    end
  end
end
