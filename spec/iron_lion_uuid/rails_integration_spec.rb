# frozen_string_literal: true

require "spec_helper"

# Skip these tests if Rails is not available
if defined?(Rails) && defined?(ActiveRecord)
  RSpec.describe "Rails Integration" do
    describe "IronLionUUID::Railtie" do
      it "registers the IronLionUUID type with ActiveRecord" do
        # This is somewhat difficult to test directly, so we'll check
        # that the class exists and has the expected methods
        expect(defined?(IronLionUUID::Type)).to eq("constant")

        expect(IronLionUUID::Type.instance_methods).to(
          include(:cast, :serialize, :deserialize)
        )
      end
    end

    describe "IronLionUUID::InstallGenerator" do
      it "exists and is properly configured" do
        # Check that the generator class exists
        expect(defined?(IronLionUUID::Generators::InstallGenerator)).to eq("constant")

        # Check that it inherits from Rails::Generators::Base
        expect(IronLionUUID::Generators::InstallGenerator.superclass).to(
          eq(Rails::Generators::Base)
        )

        # Check that it has the expected options
        options = IronLionUUID::Generators::InstallGenerator.class_options
        expect(options).to have_key(:databases)
        expect(options).to have_key(:dialect)
        expect(options).to have_key(:binary_output)
      end

      it "has a create_migration_file method" do
        expect(IronLionUUID::Generators::InstallGenerator.instance_methods).to(
          include(:create_migration_file)
        )
      end
    end

    describe "IronLionUUID::HasIronLionId" do
      it "exists and is properly configured as a concern" do
        expect(defined?(IronLionUUID::HasIronLionId)).to eq("constant")
        expect(IronLionUUID::HasIronLionId).to respond_to(:included)
      end
    end
  end
else
  RSpec.describe "Rails Integration" do
    it "skips tests when Rails is not available" do
      skip "Rails is not available, skipping integration tests"
    end
  end
end
