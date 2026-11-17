# frozen_string_literal: true

module IronLion
  # Hands out (millisecond, sequence) pairs that strictly increase within a
  # process, Snowflake style.
  #
  # When a millisecond's sequence space runs out, or the system clock steps
  # backwards, the clock borrows the next millisecond instead of blocking.
  # Ids stay unique and ordered; created_at may run a few ms ahead of the
  # wall clock until real time catches up.
  class Clock
    attr_writer :source

    def initialize(sequence_max = nil, source: nil)
      @sequence_max = sequence_max
      @source = source || -> { Process.clock_gettime(Process::CLOCK_REALTIME, :millisecond) }
      @mutex = Mutex.new
      @last = -1
      @sequence = 0
    end

    def now
      @source.call
    end

    def tick
      return [now, nil] unless @sequence_max

      @mutex.synchronize do
        current = now
        if current > @last
          @last = current
          @sequence = 0
        elsif @sequence < @sequence_max
          @sequence += 1
        else
          @last += 1
          @sequence = 0
        end
        [@last, @sequence]
      end
    end
  end
end
