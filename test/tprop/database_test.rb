# frozen_string_literal: true

require "test_helper"
require "tmpdir"

# The example database: storage implementations plus the end-to-end
# replay/persist/delete behavior through TProp.check.
class DatabaseTest < Minitest::Test
  Gen = TProp::Gen

  # --- storage implementations ------------------------------------------

  def test_memory_database_round_trip
    db = TProp::MemoryDatabase.new
    assert_nil db["k"]
    db["k"] = [1, 2, 3]
    assert_equal [1, 2, 3], db["k"]
    db.delete("k")
    assert_nil db["k"]
  end

  def test_memory_database_copies_on_read_and_write
    db = TProp::MemoryDatabase.new
    stored = [1, 2]
    db["k"] = stored
    stored << 3 # mutating the caller's array must not affect the store
    assert_equal [1, 2], db["k"]
    db["k"] << 99 # mutating a read value must not affect the store
    assert_equal [1, 2], db["k"]
  end

  def test_file_database_round_trip
    Dir.mktmpdir do |dir|
      db = TProp::FileDatabase.new(File.join(dir, "cache"))
      assert_nil db["Foo#bar"]
      db["Foo#bar"] = [100]
      assert_equal [100], db["Foo#bar"]
      db.delete("Foo#bar")
      assert_nil db["Foo#bar"]
    end
  end

  def test_file_database_treats_corrupt_entries_as_absent
    Dir.mktmpdir do |dir|
      db = TProp::FileDatabase.new(dir)
      db["k"] = [1]
      # Corrupt the underlying file.
      file = Dir.children(dir).map { |f| File.join(dir, f) }.first
      File.write(file, "not json{")
      assert_nil db["k"] # never raises; just misses
    end
  end

  def test_file_database_delete_is_a_no_op_when_absent
    Dir.mktmpdir do |dir|
      db = TProp::FileDatabase.new(dir)
      assert_nil db.delete("missing")
    end
  end

  # --- end-to-end behavior through check --------------------------------

  def failing_check(db, seed: 1)
    TProp.check(gen: Gen.integers(0..1_000), max_examples: 200, seed: seed, database: db, key: "k") do |n|
      raise "too big" unless n < 100
    end
  end

  def test_a_failure_is_persisted_and_a_pass_clears_it
    db = TProp::MemoryDatabase.new

    assert_raises(TProp::PropertyFailure) { failing_check(db) }
    refute_nil db["k"], "a failing example should be stored"

    # Now a property that always holds: the stale entry is dropped.
    TProp.check(gen: Gen.integers(0..1_000), max_examples: 50, seed: 1, database: db, key: "k") do |n|
      assert_operator n, :>=, 0
    end
    assert_nil db["k"], "a passing run should clear the stored example"
  end

  def test_stored_example_replays_first_and_reproduces_without_searching
    db = TProp::MemoryDatabase.new
    # Seed the minimal failing sequence for `n < 5` directly.
    db["k"] = [5]

    error = assert_raises(TProp::PropertyFailure) do
      # A generously wide range + tiny example budget: random generation is very
      # unlikely to hit the boundary. Replay does, deterministically.
      TProp.check(gen: Gen.integers(0..1_000_000), max_examples: 1, seed: 999, database: db, key: "k") do |n|
        raise "too big" unless n < 5
      end
    end
    assert_equal 5, error.counterexample
  end

  def test_no_persistence_without_a_key
    db = TProp::MemoryDatabase.new
    assert_raises(TProp::PropertyFailure) do
      TProp.check(gen: Gen.integers(0..1_000), max_examples: 200, seed: 1, database: db) do |n|
        raise "too big" unless n < 100
      end
    end
    assert_nil db["k"], "without a key, nothing is persisted"
  end

  def test_reproduces_the_same_counterexample_across_runs
    db = TProp::MemoryDatabase.new
    first = (failing_check(db, seed: 7) rescue $!).counterexample
    # Different seed, but the stored example replays first, so same result.
    second = (failing_check(db, seed: 12_345) rescue $!).counterexample
    assert_equal first, second
  end
end
