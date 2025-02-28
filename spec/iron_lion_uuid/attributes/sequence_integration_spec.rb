# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Sequence Attribute Integration" do
  # Reset configuration before each test
  before do
    if IronLionUUID.instance_variable_defined?(:@configuration)
      IronLionUUID.remove_instance_variable(:@configuration)
    end
    if IronLionUUID.instance_variable_defined?(:@generator)
      IronLionUUID.remove_instance_variable(:@generator)
    end
  end

  describe "UUID generation with sequence" do
    it "configures UUIDs with sequence attributes" do
      IronLionUUID.configure do |uuid|
        uuid.sequence(bits: 16, name: :seq)
      end

      config = IronLionUUID.configuration
      # 1 configured sequence + auto-added random for remaining bits
      expect(config.attributes.size).to eq(2)

      # Check specific attributes
      seq_attr = config.attribute_by_name(:seq)
      expect(seq_attr).to be_a(IronLionUUID::SequenceAttribute)
      expect(seq_attr.bits).to eq(16)
    end

    it "generates UUIDs with sequential values" do
      IronLionUUID.configure do |uuid|
        uuid.sequence(bits: 16, name: :seq)
      end

      # Generate a series of UUIDs
      uuid1 = IronLionUUID.generate
      uuid2 = IronLionUUID.generate
      uuid3 = IronLionUUID.generate

      # Sequence values should be sequential
      expect(uuid1.seq).to eq(1)
      expect(uuid2.seq).to eq(2)
      expect(uuid3.seq).to eq(3)
    end

    it "combines sequence with parameter attributes" do
      IronLionUUID.configure do |uuid|
        uuid.sequence(bits: 16, name: :seq)
        uuid.parameter(bits: 8, name: :model)
      end

      # Generate a UUID with a parameter
      uuid1 = IronLionUUID.generate(1)
      uuid2 = IronLionUUID.generate(2)

      # Check values via accessor methods
      expect(uuid1.seq).to eq(1)
      expect(uuid1.model).to eq(1)

      expect(uuid2.seq).to eq(2)
      expect(uuid2.model).to eq(2)
    end

    it "combines sequence with environment attributes" do
      # Set up environment variable
      ENV["NODE_ID"] = "42"

      IronLionUUID.configure do |uuid|
        uuid.sequence(bits: 16, name: :seq)
        uuid.env(bits: 12, name: :node, key: :NODE_ID)
      end

      # Generate UUIDs
      uuid1 = IronLionUUID.generate
      uuid2 = IronLionUUID.generate

      # Check values via accessor methods
      expect(uuid1.seq).to eq(1)
      expect(uuid1.node).to eq(42)

      expect(uuid2.seq).to eq(2)
      expect(uuid2.node).to eq(42)

      # Clean up environment
      ENV.delete("NODE_ID")
    end

    it "combines sequence with timestamp attributes" do
      IronLionUUID.configure do |uuid|
        uuid.sequence(bits: 16, name: :seq)
        uuid.timestamp(bits: 36, precision: :millisecond, name: :created_at)
      end

      # Generate UUIDs
      uuid1 = IronLionUUID.generate
      uuid2 = IronLionUUID.generate

      # Sequence values should be sequential
      expect(uuid1.seq).to eq(1)
      expect(uuid2.seq).to eq(2)

      # Both should have timestamp values
      expect(uuid1.created_at).to be_a(Integer)
      expect(uuid2.created_at).to be_a(Integer)
    end
  end

  describe "thread safety in integrated environment" do
    it "generates sequential UUIDs in a multi-threaded environment" do
      IronLionUUID.configure do |uuid|
        uuid.sequence(bits: 16, name: :seq)
        uuid.random(bits: 32, name: :random_part)
      end

      # Generate UUIDs in multiple threads
      thread_count = 10
      uuids_per_thread = 10
      all_uuids = Concurrent::Array.new

      threads = Array.new(thread_count) do
        Thread.new do
          uuids_per_thread.times do
            all_uuids << IronLionUUID.generate
          end
        end
      end

      # Wait for all threads to complete
      threads.each(&:join)

      # Extract sequence values
      sequence_values = all_uuids.map(&:seq)

      # Should have unique sequence values
      expect(sequence_values.uniq.size).to eq(thread_count * uuids_per_thread)

      # Values should be between 1 and (thread_count * uuids_per_thread)
      expect(sequence_values.min).to eq(1)
      expect(sequence_values.max).to eq(thread_count * uuids_per_thread)
    end

    it "wraps around correctly in a multi-threaded environment" do
      # Use a small bit width to ensure wrapping
      IronLionUUID.configure do |uuid|
        uuid.sequence(bits: 3, name: :seq) # Max value is 7
      end

      # Access the sequence attribute to set its counter
      seq_attr = IronLionUUID.configuration.attribute_by_name(:seq)
      counter = seq_attr.instance_variable_get(:@counter)
      counter.value = 6 # Start close to the max value

      # Generate UUIDs in multiple threads
      thread_count = 5
      uuids_per_thread = 5
      all_uuids = Concurrent::Array.new

      threads = Array.new(thread_count) do
        Thread.new do
          uuids_per_thread.times do
            all_uuids << IronLionUUID.generate
          end
        end
      end

      # Wait for all threads to complete
      threads.each(&:join)

      # Extract sequence values
      sequence_values = all_uuids.map(&:seq)

      # Should have wrapped around, so all values 0-7 should be present
      expect(sequence_values.uniq.sort).to contain_exactly(0, 1, 2, 3, 4, 5, 6, 7)
    end
  end
end
