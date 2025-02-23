# frozen_string_literal: true

require "bigdecimal"
require "forwardable"
require "pry"
require_relative "iron_lion_uuid/version"

# IronLionUUID provides functionality for generating unique identifiers using
# native database functions. It supports multiple database adapters including
# PostgreSQL, MySQL, and SQLite, falling back to a Ruby-based implementation
# when the database adapter is not supported.
class IronLionUUID
  extend Forwardable

  autoload :Component,  "iron_lion_uuid/component"
  autoload :Definition, "iron_lion_uuid/definition"
  autoload :Generator,  "iron_lion_uuid/generator"
  autoload :Index,      "iron_lion_uuid/index"
  autoload :Inflector,  "iron_lion_uuid/inflector"

  class Error < StandardError; end

  class << self
    attr_reader :index

    def install
      raise NotImplementedError, "Unsupported database adapter" unless adapter_supported?

      sql_path = "sql/#{adapter}_function.sql"
      ActiveRecord::Base.connection.execute File.read(sql_path)
    end

    def generate(*args)
      if adapter_supported?
        ActiveRecord::Base.connection.select(
          index.iron_lion_uuid(*args, sql: true)
        )
      else
        index.iron_lion_uuid(*args)
      end
    end

    def definition(&)
      return @definition unless block_given?

      @index = Index.new
      @definition = Definition.new(index, &)
    end

    def define_getter(name, index, bits)
      define_method name do
        data index, bits
      end
    end

    private

    def adapter
      @adapter ||= begin
        ActiveRecord::Base.connection.adapter_name.downcase.to_sym
      rescue NameError
        :no_active_record
      end
    end

    def adapter_supported?
      @adapter_supported ||= %i[postgresql mysql2 sqlite].include?(adapter)
    end
  end

  attr_reader :uuid, :int

  def_delegators :@uuid, :to_s, :inspect

  def initialize(uuid)
    @uuid = uuid.frozen? ? uuid : uuid.dup.freeze

    bytes = [ @uuid.delete("-") ].pack("H*")
    @int = (bytes.unpack1("Q>") << 64) | bytes.unpack1("Q<")
    @int &= ~(0xf << 76)
    @int &= ~(0x3 << 62)
  end

  def data(index, bits)
    shifted = @int >> (Index::MAX_BITS - (index + bits))
    mask = (1 << bits) - 1
    shifted & mask
  end

  def definition
    self.class.definition
  end

  def index
    self.class.index
  end
end
