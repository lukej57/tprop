# frozen_string_literal: true

module TProp
  # The foundational representation: a single test case as a growing sequence
  # of drawn integers (the "choice sequence"). Generators never see a raw RNG —
  # they pull integers from a TestCase via #choice, which makes every generator
  # a pure function from a choice sequence to a value.
  #
  # This is the minithesis / Hypothesis "Conjecture" architecture. Because all
  # generators read the same sequence, one shrinker shrinks everything, replay
  # is just re-running against a saved sequence, and generator invariants are
  # preserved under shrinking.
  #
  # See docs/ARCHITECTURE.md, "The foundational decision".
  class TestCase
    # Status a case can end up in.
    module Status
      OVERRUN     = :overrun     # exceeded the size cap
      INVALID     = :invalid     # a replayed/drawn value exceeded its bound
      VALID       = :valid       # ran to completion, property held
      INTERESTING = :interesting # ran to completion, property failed
    end

    # @return [Array<Integer>] the choices drawn so far
    attr_reader :choices

    # @return [Symbol, nil] one of Status::*
    attr_reader :status

    # @param prefix [Array<Integer>] choices to replay before drawing fresh
    # @param rng [Random, nil] source of fresh draws (absent during pure replay)
    # @param max_size [Integer] cap on the choice-sequence length
    def initialize(prefix: [], rng: nil, max_size: 8 * 1024)
      @prefix = prefix
      @rng = rng
      @max_size = max_size
      @choices = []
      @status = nil
    end

    # Draw an integer in 0..n, recording it into the sequence.
    #
    # - If still inside the supplied prefix, replay that value.
    # - Otherwise draw fresh from the RNG (or fail if none).
    # - If the sequence exceeds the cap, mark OVERRUN.
    # - If a replayed/drawn value exceeds `n`, mark INVALID.
    #
    # @param n [Integer] inclusive upper bound
    # @return [Integer]
    def choice(n)
      # TODO: implement per docs/ARCHITECTURE.md (prefix replay, overrun/invalid).
      raise NotImplementedError, "TestCase#choice is not implemented yet"
    end

    # Mark this case as interesting (the property failed) after the fact.
    def mark_interesting!
      @status = Status::INTERESTING
    end

    def overrun?
      @status == Status::OVERRUN
    end

    def invalid?
      @status == Status::INVALID
    end

    def interesting?
      @status == Status::INTERESTING
    end
  end
end
