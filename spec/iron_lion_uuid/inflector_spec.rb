# frozen_string_literal: true

require "spec_helper"

RSpec.describe IronLionUUID::Inflector do
  describe ".instance" do
    it "returns a Dry::Inflector instance" do
      expect(described_class.instance).to be_a Dry::Inflector
    end

    it "caches the instance" do
      an_instance_handle = described_class.instance
      another_instance_handle = described_class.instance

      expect(an_instance_handle).to be another_instance_handle
    end

    it "configures acronyms correctly" do
      expect(described_class.camelize("mysql_adapter")).to eq "MySQLAdapter"
      expect(described_class.camelize("sql_query")).to eq "SQLQuery"
      expect(described_class.camelize("uuid_generator")).to eq "UUIDGenerator"
    end
  end

  describe "class method delegation" do
    it "delegates unknown methods to the inflector instance" do
      expect(described_class.underscore("MySQLAdapter")).to eq "mysql_adapter"
      expect(described_class.pluralize("word")).to eq "words"
    end

    it "returns a new inflector instance for methods without arguments" do
      result = described_class.underscore

      expect(result).to be_a described_class
    end

    it "raises NoMethodError for undefined methods" do
      expect { described_class.not_a_real_method }.to raise_error NoMethodError
    end
  end

  describe "instance methods" do
    describe "#[]" do
      it "applies a single transformation" do
        inflector = described_class.new(:underscore)

        expect(inflector["MySQLAdapter"]).to eq "mysql_adapter"
      end

      it "applies multiple transformations in order" do
        inflector = described_class.new(%i[ pluralize underscore ])

        expect(inflector["MySQLAdapter"]).to eq "mysql_adapters"
      end
    end

    describe "#chain" do
      it "creates a new inflector with added transformation" do
        inflector = described_class.new(:underscore)
        chained = inflector.chain(:pluralize)

        expect(chained["SQLQuery"]).to eq "sql_queries"
      end

      it "preserves existing transformations" do
        inflector = described_class.new(:camelize)
        chained = inflector.chain(:pluralize)

        expect(chained["sql_query"]).to eq "SQLQueries"
      end
    end

    describe "method chaining" do
      it "supports method chaining through method_missing" do
        inflector = described_class.new(:camelize)
        result = inflector.pluralize.underscore["SQLQuery"]

        expect(result).to eq "sql_queries"
      end

      it "applies immediate transformation when arguments are provided" do
        inflector = described_class.new(:camelize)

        expect(inflector.pluralize("sql_query")).to eq "SQLQueries"
      end

      it "raises NoMethodError for undefined methods" do
        inflector = described_class.new(:camelize)

        expect { inflector.not_a_real_method }.to raise_error NoMethodError
      end
    end
  end
end
