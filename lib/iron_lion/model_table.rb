# frozen_string_literal: true

module IronLion
  # Gives each model a small, permanent integer that fits the format's model
  # field. Ids are issued in order and never reused or renumbered.
  #
  # With a path, the table lives in a checked-in YAML file:
  #
  #   models:
  #     "User": 1
  #     "Order": 2
  #
  # Assigning is safe across processes (the file is locked while it is
  # rewritten). Turn assignment off where the table must be read-only, such
  # as production, and unknown models raise instead of being numbered.
  class ModelTable
    HEADER = <<~YAML
      # IronLion model ids. Append-only: once issued, an id belongs to that
      # model forever. Rename a model by changing its key, never its number.
    YAML

    class << self
      # Where a format's model table lives when it does not say, and whether
      # it may number new models. In Rails: config/iron_lion.yml, assigning
      # only in development and test.
      attr_accessor :default_path
      attr_writer :default_assign

      def default_assign = @default_assign.nil? || @default_assign

      def default = new(default_path, assign: default_assign)
    end

    attr_reader :path
    attr_writer :assign

    def initialize(path = nil, assign: true)
      @path = path&.to_s
      @assign = assign
      @mutex = Mutex.new
      @ids = nil
    end

    def assign? = @assign

    def id_for(name, capacity: nil)
      name = name.to_s
      @mutex.synchronize do
        known = ids[name]
        next known if known

        unless @assign
          raise UnknownModelError,
                "#{name} has no IronLion model id#{" in #{path}" if path}, and new ids are not issued here. " \
                "Create a #{name} where they are (in Rails: development or test) and commit the table."
        end

        path ? assign_in_file(name, capacity) : assign_in_memory(name, capacity)
      end
    end

    def name_for(id)
      @mutex.synchronize do
        found = ids.key(id)
        next found if found || path.nil?

        @ids = nil # another process may have assigned it since we loaded
        ids.key(id)
      end
    end

    # The class for an id when it is loaded, else its name, else the bare id.
    def model_for(id)
      name = name_for(id) or return id
      Object.const_get(name)
    rescue NameError
      name
    end

    def to_h
      @mutex.synchronize { ids.dup }
    end

    private

    def ids
      @ids ||= path && File.exist?(path) ? read(File.read(path)) : {}.freeze
    end

    def assign_in_memory(name, capacity)
      id = next_id(ids, capacity)
      @ids = ids.merge(name => id).freeze
      id
    end

    def assign_in_file(name, capacity)
      FileUtils.mkdir_p(File.dirname(path))

      File.open(path, File::RDWR | File::CREAT, 0o644) do |file|
        file.flock(File::LOCK_EX)
        current = read(file.read)
        current = current.merge(name => next_id(current, capacity)) unless current.key?(name)
        file.rewind
        file.write(dump(current))
        file.flush
        file.truncate(file.pos)
        @ids = current.freeze
      end

      @ids.fetch(name)
    end

    def next_id(current, capacity)
      id = (current.values.max || 0) + 1
      return id if capacity.nil? || id <= capacity

      raise OverflowError, "the model table is full: #{capacity} models fit in the model field; widen it"
    end

    def read(text)
      models = (YAML.safe_load(text) || {}).fetch("models", nil) || {}
      validate!(models)
      models.freeze
    end

    def validate!(models)
      unless models.is_a?(Hash) && models.all? { |name, id| entry?(name, id) }
        raise ConfigurationError, "#{path} must map model names to positive integers under `models:`"
      end

      reused = models.values.tally.select { |_, count| count > 1 }.keys
      raise ConfigurationError, "#{path} gives id #{reused.join(', ')} to more than one model" unless reused.empty?
    end

    def entry?(name, id) = name.is_a?(String) && id.is_a?(Integer) && id.positive?

    def dump(models)
      return "#{HEADER}models: {}\n" if models.empty?

      lines = models.sort_by(&:last).map { |name, id| "  #{name.dump}: #{id}\n" }
      "#{HEADER}models:\n#{lines.join}"
    end
  end
end
