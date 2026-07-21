# frozen_string_literal: true

require "json"
require "digest"
require "fileutils"

module TProp
  # The example database persists the shrunk failing choice sequence for a
  # property so the next run can replay it first — reproducibility, and a
  # prerequisite for the fuzzing horizon (docs/ROADMAP.md).
  #
  # A database is any object with this interface, all keyed by an opaque String
  # and dealing in choice sequences (Array<Integer>):
  #
  #   db[key]            -> Array<Integer> or nil
  #   db[key] = choices  -> store
  #   db.delete(key)     -> remove (no-op if absent)
  #
  # Two implementations ship: MemoryDatabase (tests, hermetic default) and
  # FileDatabase (one small JSON file per key).

  # In-memory, non-persistent. Handy for tests and for a hermetic default.
  class MemoryDatabase
    def initialize
      @store = {}
    end

    def [](key)
      value = @store[key]
      value&.dup
    end

    def []=(key, choices)
      @store[key] = choices.dup
    end

    def delete(key)
      @store.delete(key)
    end
  end

  # Directory-backed: one JSON file per key (filename = a hash of the key, so
  # arbitrary key strings are safe). Corrupt or unreadable files are treated as
  # absent, never as an error — a bad cache entry must not break a test run.
  class FileDatabase
    FORMAT_VERSION = 1

    def initialize(directory)
      @directory = directory
    end

    def [](key)
      path = path_for(key)
      return nil unless File.exist?(path)

      data = JSON.parse(File.read(path))
      choices = data["choices"]
      return nil unless choices.is_a?(Array) && choices.all?(Integer)

      choices
    rescue JSON::ParserError, SystemCallError
      nil
    end

    def []=(key, choices)
      FileUtils.mkdir_p(@directory)
      payload = { "v" => FORMAT_VERSION, "key" => key, "choices" => choices }
      File.write(path_for(key), JSON.generate(payload))
    end

    def delete(key)
      path = path_for(key)
      File.delete(path) if File.exist?(path)
    rescue SystemCallError
      nil
    end

    private

    def path_for(key)
      File.join(@directory, "#{Digest::SHA1.hexdigest(key)[0, 16]}.json")
    end
  end
end
