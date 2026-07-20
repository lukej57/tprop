# frozen_string_literal: true

require "test_helper"

# Exercises the choice-sequence engine end to end over explicit generators
# (no derivation). The shrink-quality assertions are the regression anchors
# named in docs/ARCHITECTURE.md and docs/ROADMAP.md — keep them sharp.
class EngineTest < Minitest::Test
  Gen = TProp::Gen

  def test_passing_property_does_not_raise
    result = TProp.check(gen: Gen.integers(0..1000), max_examples: 200, seed: 1) do |n|
      raise "out of range" unless n >= 0 && n <= 1000
    end
    assert_nil result
  end

  def test_generated_integers_stay_in_range
    seen = []
    TProp.check(gen: Gen.integers(5..9), max_examples: 200, seed: 7) { |n| seen << n }
    assert_operator seen.min, :>=, 5
    assert_operator seen.max, :<=, 9
  end

  # Regression anchor: `x < 100` shrinks to exactly 100.
  def test_shrinks_integer_to_the_boundary
    error = assert_raises(TProp::PropertyFailure) do
      TProp.check(gen: Gen.integers(0..1_000), max_examples: 200, seed: 3) do |n|
        raise "too big" unless n < 100
      end
    end
    assert_equal 100, error.counterexample
  end

  # Regression anchor: an unsorted-list property shrinks to exactly [1, 0].
  def test_shrinks_unsorted_list_to_one_zero
    error = assert_raises(TProp::PropertyFailure) do
      TProp.check(gen: Gen.lists(Gen.integers(0..100)), max_examples: 300, seed: 5) do |list|
        raise "unsorted" unless list == list.sort
      end
    end
    assert_equal [1, 0], error.counterexample
  end

  def test_same_seed_reproduces_the_same_counterexample
    run = lambda do
      TProp.check(gen: Gen.integers(0..1_000), max_examples: 200, seed: 42) do |n|
        raise "too big" unless n < 500
      end
    rescue TProp::PropertyFailure => e
      e.choices
    end
    assert_equal run.call, run.call
  end

  def test_failure_carries_the_reproducing_choice_sequence
    error = assert_raises(TProp::PropertyFailure) do
      TProp.check(gen: Gen.integers(0..1_000), max_examples: 200, seed: 9) do |n|
        raise "too big" unless n < 100
      end
    end
    refute_nil error.choices
    # Replaying the recorded sequence reproduces the same counterexample.
    replay = TProp::TestCase.for_choices(error.choices)
    assert_equal error.counterexample, replay.any(Gen.integers(0..1_000))
  end

  def test_map_and_bind_compose
    error = assert_raises(TProp::PropertyFailure) do
      evens = Gen.integers(0..500).map { |n| n * 2 }
      TProp.check(gen: evens, max_examples: 200, seed: 2) do |n|
        assert_equal 0, n % 2 # holds
        raise "too big" unless n < 10
      end
    end
    assert_equal 10, error.counterexample # smallest even >= 10
  end

  def test_shortlex_ordering
    assert TProp::TestingState.shortlex_smaller?([0], [0, 0])      # shorter wins
    assert TProp::TestingState.shortlex_smaller?([1, 0], [1, 1])   # tie -> lexicographic
    refute TProp::TestingState.shortlex_smaller?([2], [1])
  end
end
