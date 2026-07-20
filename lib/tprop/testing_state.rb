# frozen_string_literal: true

module TProp
  # The runner + shrinker. Runs the property up to `max_examples` times,
  # caches results keyed by the choice sequence, and on a failing (interesting)
  # case runs shrink passes to a fixed point under a shortlex total order
  # (shorter sequences first; ties broken lexicographically).
  #
  # Shrink passes, in order:
  #   1. Chunk deletion (with a length-nudge) — collapses list length / size.
  #   2. Block zeroing — collapses values toward their simplest.
  #   3. Per-choice binary search — minimizes each individual integer.
  #   4. Local reorder — swap adjacent elements to expose smaller equivalents.
  #
  # Each candidate is accepted only if it is still interesting AND strictly
  # smaller under shortlex. The engine has historically been bitten right here
  # (a `better?` that silently returned nil; an Array compared with `<` instead
  # of `<=>`), so these are the places to keep tests sharp.
  #
  # See docs/ARCHITECTURE.md, "TestingState (the runner + shrinker)".
  class TestingState
    # @param gen [TProp::Gen] the generator under test
    # @param max_examples [Integer]
    # @param seed [Integer, nil]
    # @yield [Object] the property; should raise to signal failure
    def initialize(gen:, max_examples: TProp::DEFAULT_MAX_EXAMPLES, seed: nil, &property)
      @gen = gen
      @max_examples = max_examples
      @seed = seed
      @property = property
      @result = nil # the best (smallest) interesting choice sequence found
    end

    # Generate and test up to `max_examples` cases. Populates the best
    # interesting result, if any.
    def run
      # TODO: draw fresh TestCases, run the property, record interesting ones.
      raise NotImplementedError, "TestingState#run is not implemented yet"
    end

    # Shrink the recorded interesting result to a fixed point.
    def shrink
      # TODO: apply the four passes above under shortlex acceptance.
      raise NotImplementedError, "TestingState#shrink is not implemented yet"
    end

    # @return [Boolean] whether a failing case was found
    def failed?
      !@result.nil?
    end

    # Total order used for shrink acceptance: shorter first, then lexicographic.
    #
    # @param a [Array<Integer>]
    # @param b [Array<Integer>]
    # @return [Boolean] true iff `a` is strictly smaller than `b`
    def self.shortlex_smaller?(a, b)
      # TODO: [a.length, a] <=> [b.length, b] == -1. Guard against the historic
      # `<` vs `<=>` bug on the Array tiebreak.
      raise NotImplementedError, "TestingState.shortlex_smaller? is not implemented yet"
    end
  end
end
