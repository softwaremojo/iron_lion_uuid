# frozen_string_literal: true

require "spec_helper"
require_relative "../../lib/iron_lion_uuid/errors"

RSpec.describe "IronLionUUID Errors" do
  describe IronLionUUID::ConfigurationError do
    it "has a descriptive default message" do
      error = described_class.new
      expect(error.message).to eq("Invalid IronLionUUID configuration")
    end
  end

  describe IronLionUUID::FrozenConfigurationError do
    it "has a descriptive default message" do
      error = described_class.new
      expect(error.message).to eq("Configuration is frozen and cannot be modified")
    end
  end

  describe IronLionUUID::InvalidBitWidthError do
    it "has a descriptive default message" do
      error = described_class.new
      expect(error.message).to eq("Total bit width exceeds available space (122 bits)")
    end
  end

  describe IronLionUUID::MissingEnvironmentError do
    it "has a descriptive default message" do
      error = described_class.new
      expect(error.message).to eq("Required environment variable is not set")
    end

    it "includes the environment key in the message when provided" do
      error = described_class.new("NODE_ID")
      expect(error.message).to eq("Required environment variable 'NODE_ID' is not set")
    end
  end

  describe IronLionUUID::ValueTooLargeError do
    it "has a descriptive default message" do
      error = described_class.new
      expect(error.message).to eq("Value exceeds maximum for configured bit width")
    end

    it "includes the value and bit width in the message when provided" do
      error = described_class.new(300, 8)
      max_value = (1 << 8) - 1
      expect(error.message).to eq("Value 300 exceeds maximum (#{max_value}) for 8 bits")
    end
  end

  describe IronLionUUID::TimestampPrecisionWarning do
    it "has a descriptive default message" do
      warning = described_class.new
      expect(warning.message).to eq(
        "Requested timestamp precision exceeds system capability"
      )
    end

    it "includes the requested and available precision in the message when provided" do
      warning = described_class.new(:nanosecond, :millisecond)
      expect(warning.message).to eq(
        "Requested timestamp precision 'nanosecond' exceeds " \
        "system capability 'millisecond'"
      )
    end
  end
end
