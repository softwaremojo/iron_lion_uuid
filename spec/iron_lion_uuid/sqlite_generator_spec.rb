# frozen_string_literal: true

require "spec_helper"

RSpec.describe IronLionUUID::SQLiteGenerator do
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

  describe "#generate_sqlite_function" do
    it "generates a valid SQLite function" do
      generator = described_class.new

      sql = generator.generate_function

      # Check for function declaration
      expect(sql).to include("CREATE OR REPLACE FUNCTION generate_iron_lion_uuid")
      expect(sql).to include("RETURNS TEXT")

      # Check for helper functions
      expect(sql).to include("CREATE OR REPLACE FUNCTION format_uuid")
      expect(sql).to include("CREATE OR REPLACE FUNCTION set_uuid_bits")

      # Check for parameter declaration
      expect(sql).to include("model INTEGER")

      # Check for version and variant bits
      expect(sql).to include("-- Set version bits (v8)")
      expect(sql).to include("-- Set variant bits (RFC 4122)")

      # Check for attribute handling via CTEs
      expect(sql).to include("-- Set bits for parameter attribute model")
      expect(sql).to include("-- Set bits for environment variable attribute node")
      expect(sql).to include("-- Set bits for timestamp attribute")
      expect(sql).to include("-- Set bits for sequence attribute")
      expect(sql).to include("-- Set bits for random attribute")
    end

    it "allows customizing the function name" do
      generator = described_class.new

      sql = generator.generate_function(function_name: "custom_uuid_generator")

      expect(sql).to include("CREATE OR REPLACE FUNCTION custom_uuid_generator")
    end

    it "includes sequence table creation for sequence attributes" do
      generator = described_class.new

      sql = generator.generate_function

      expect(sql).to include("create_seq_table")
      expect(sql).to include("CREATE TABLE seq_sequence")
      expect(sql).to include("INSERT INTO seq_sequence")
      expect(sql).to include("UPDATE seq_sequence SET value")
    end
  end

  describe "#generate_drop_function" do
    it "generates valid DROP FUNCTION statements" do
      generator = described_class.new

      sql = generator.generate_drop_function

      expect(sql).to include("DROP FUNCTION IF EXISTS generate_iron_lion_uuid")
      expect(sql).to include("DROP FUNCTION IF EXISTS set_uuid_bits")
      expect(sql).to include("DROP FUNCTION IF EXISTS format_uuid")
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
      sql = generator.send(:generate_parameter_bits, parameter_attr, 0)

      expect(sql).to include(
        "-- Set bits for parameter attribute #{parameter_attr.name}"
      )

      expect(sql).to include(
        "WHEN #{parameter_attr.name} >= POWER(2, #{parameter_attr.bits}) THEN"
      )

      expect(sql).to include("RAISE(FAIL, 'Value exceeds maximum")

      expect(sql).to include(<<~SQL.tr("\n", " "))
        set_uuid_bits(hex,
        #{parameter_attr.position},
        #{parameter_attr.bits},
        #{parameter_attr.name})
      SQL
    end

    it "generates timestamp attribute bits correctly" do
      generator = described_class.new

      # Get private method access
      timestamp_attr = IronLionUUID.configuration.attribute_by_name(:created_at)
      sql = generator.send(:generate_timestamp_bits, timestamp_attr, 0)

      expect(sql).to include("-- Set bits for timestamp attribute")
      expect(sql).to include("unixepoch('now') * 1000") # Millisecond precision
      expect(sql).to include(
        "set_uuid_bits(hex, #{timestamp_attr.position}, #{timestamp_attr.bits}"
      )
    end

    it "generates sequence attribute bits correctly" do
      generator = described_class.new

      # Get private method access
      sequence_attr = IronLionUUID.configuration.attribute_by_name(:seq)
      sql = generator.send(:generate_sequence_bits, sequence_attr, 0)

      expect(sql).to include("-- Set bits for sequence attribute")
      expect(sql).to include("#{sequence_attr.name}_sequence")
      expect(sql).to include("CREATE TABLE #{sequence_attr.name}_sequence")
      expect(sql).to include("UPDATE #{sequence_attr.name}_sequence SET value")
      expect(sql).to include("INSERT INTO #{sequence_attr.name}_sequence")
    end

    it "generates environment variable attribute bits correctly" do
      generator = described_class.new

      # Get private method access
      env_attr = IronLionUUID.configuration.attribute_by_name(:node)
      sql = generator.send(:generate_env_bits, env_attr, 0)

      expect(sql).to include(
        "-- Set bits for environment variable attribute #{env_attr.name}"
      )

      expect(sql).to include(
        "-- Note: SQLite doesn't support environment variables directly"
      )

      expect(sql).to include("'#{env_attr[:key]}'")

      expect(sql).to include(
        "set_uuid_bits(hex, #{env_attr.position}, #{env_attr.bits}, 0)"
      )
    end

    it "generates random attribute bits correctly" do
      generator = described_class.new

      # Get private method access
      random_attr = IronLionUUID.configuration.attribute_by_name(:random_part)
      sql = generator.send(:generate_random_bits, random_attr, 0)

      expect(sql).to include("-- Set bits for random attribute")
      expect(sql).to include("random() * POWER(2, #{random_attr.bits})")

      expect(sql).to include(
        "set_uuid_bits(hex, #{random_attr.position}, #{random_attr.bits}"
      )
    end

    it "generates sequence table creation SQL correctly" do
      generator = described_class.new

      # Get private method access
      sequence_attr = IronLionUUID.configuration.attribute_by_name(:seq)
      sql = generator.send(:create_sequence_table, sequence_attr)

      expect(sql).to include("-- Create sequence table if it doesn't exist")
      expect(sql).to include("CREATE TABLE #{sequence_attr.name}_sequence")
      expect(sql).to include("sqlite_master")
      expect(sql).to include("type='table' AND name='#{sequence_attr.name}_sequence'")
    end
  end
end
