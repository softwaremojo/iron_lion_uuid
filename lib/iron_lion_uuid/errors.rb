# frozen_string_literal: true

module IronLionUUID
  # Base error class for all IronLionUUID errors
  class Error < StandardError; end

  # Base class for configuration-related errors
  class ConfigurationError < Error
    def initialize(msg = "Invalid IronLionUUID configuration")
      super
    end
  end

  # Raised when attempting to modify a frozen configuration
  class FrozenConfigurationError < ConfigurationError
    def initialize(msg = "Configuration is frozen and cannot be modified")
      super
    end
  end

  # Raised when the total bit width exceeds the available space (122 bits)
  class InvalidBitWidthError < ConfigurationError
    def initialize(msg = "Total bit width exceeds available space (122 bits)", bits: nil)
      msg = "Total bit width (#{bits}) exceeds available space (122 bits)" if bits

      super(msg)
    end
  end

  # Raised when a required environment variable is missing
  class MissingEnvironmentError < ConfigurationError
    def initialize(env_key = nil)
      msg = if env_key
        "Required environment variable '#{env_key}' is not set"
      else
        "Required environment variable is not set"
      end

      super(msg)
    end
  end

  # Raised when a value is too large for the configured bit width
  class ValueTooLargeError < ConfigurationError
    def initialize(value = nil, bits = nil)
      if value && bits
        max_value = (1 << bits) - 1
        msg = "Value #{value} exceeds maximum (#{max_value}) for #{bits} bits"
      else
        msg = "Value exceeds maximum for configured bit width"
      end

      super(msg)
    end
  end

  # Base class for warnings in IronLionUUID
  class Warning < StandardError; end

  # Warning for timestamp precision limitations
  class TimestampPrecisionWarning < Warning
    def initialize(requested_precision = nil, available_precision = nil)
      msg = if requested_precision && available_precision
        "Requested timestamp precision '#{requested_precision}' " \
          "exceeds system capability '#{available_precision}'"
      else
        "Requested timestamp precision exceeds system capability"
      end

      super(msg)
    end
  end
end
