# frozen_string_literal: true

module TProp
  # A Gen (a "Possibility" in minithesis terms) is a named recipe that turns a
  # TestCase into a value. Composition and primitives live here.
  #
  # Design heuristic to preserve everywhere: structure generators so that
  # all-zeros is the simplest value. The shrinker drives choices toward 0 and
  # sequences toward shorter, so "0 / empty / nil / \"\"" should fall out of a
  # zeroed choice sequence.
  #
  # See docs/ARCHITECTURE.md, "The generator layer".
  class Gen
    # @return [String, nil] a human-readable name, for diagnostics
    attr_reader :name

    # @param name [String, nil]
    # @yield [TestCase] the block that produces a value from a test case
    def initialize(name: nil, &produce)
      @name = name
      @produce = produce
    end

    # Produce a value from a TestCase.
    # @param test_case [TProp::TestCase]
    def call(test_case)
      # TODO: invoke @produce; this is the interpreter entry point.
      raise NotImplementedError, "Gen#call is not implemented yet"
    end

    # --- Composition -------------------------------------------------------

    # Transform the produced value.
    def map(&block)
      # TODO
      raise NotImplementedError, "Gen#map is not implemented yet"
    end

    # Sequence a dependent generator. Works across the choice sequence, so
    # shrinking still composes (the case that defeats Hedgehog-style integrated
    # shrinking is a non-issue here — both generators read the same sequence).
    def bind(&block)
      # TODO
      raise NotImplementedError, "Gen#bind is not implemented yet"
    end

    # Filter: reject the case (not crash) if no candidate passes within the
    # try budget.
    def satisfying(max_tries: 100, &predicate)
      # TODO
      raise NotImplementedError, "Gen#satisfying is not implemented yet"
    end

    class << self
      # --- Primitives (all shrinking toward the simplest value) ------------

      def constant(value)
        raise NotImplementedError, "Gen.constant is not implemented yet"
      end

      # Anchored at the in-range point nearest zero so shrinking lands there.
      def integers(range = nil, min: nil, max: nil)
        raise NotImplementedError, "Gen.integers is not implemented yet"
      end

      def strings(min_length: 0, max_length: nil, alphabet: nil)
        raise NotImplementedError, "Gen.strings is not implemented yet"
      end

      # Draw a continue-flag then an element (flag, elem, flag, elem, …, stop)
      # rather than drawing a length up front, so deleting a span of the
      # sequence deletes list elements and shrinking composes with structure.
      def lists(element_gen, min_length: 0, max_length: nil)
        raise NotImplementedError, "Gen.lists is not implemented yet"
      end

      # T.nilable(X) — biased so nil falls out of a zeroed sequence.
      def nilable(inner_gen)
        raise NotImplementedError, "Gen.nilable is not implemented yet"
      end

      def one_of(*gens)
        raise NotImplementedError, "Gen.one_of is not implemented yet"
      end

      # Float encoding is a known area to improve: shrink toward simple values
      # (0.0, small integers-as-floats), not bit-pattern neighbors.
      def floats(min: nil, max: nil)
        raise NotImplementedError, "Gen.floats is not implemented yet"
      end
    end
  end
end
