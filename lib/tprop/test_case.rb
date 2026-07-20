# frozen_string_literal: true

# This Source Code Form is subject to the terms of the Mozilla Public License,
# v. 2.0. If a copy of the MPL was not distributed with this file, You can
# obtain one at https://mozilla.org/MPL/2.0/ (see LICENSE-MPL.txt).
#
# This file is a Ruby port of parts of minithesis
# (https://github.com/DRMacIver/minithesis), (C) 2020 David R. MacIver, used
# under the MPL-2.0. The rest of TProp is MIT; see README.md "Licensing".

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
    # We cap the entropy a single test case may consume, so a test that keeps
    # drawing (e.g. via rejection) can't blow up unboundedly.
    BUFFER_SIZE = 8 * 1024

    # Status a case can end up in. Integer-ordered (OVERRUN < INVALID < VALID <
    # INTERESTING) so the runner can compare with `>=`.
    module Status
      OVERRUN     = 0 # exceeded the size cap
      INVALID     = 1 # a replayed/drawn value exceeded its bound
      VALID       = 2 # ran to completion, property held
      INTERESTING = 3 # ran to completion, property failed
    end

    # Build a test case that replays exactly this sequence of choices and draws
    # nothing fresh (used during shrinking and replay).
    def self.for_choices(choices)
      new(prefix: choices, rng: nil, max_size: choices.length)
    end

    # @return [Array<Integer>] the choices drawn so far
    attr_reader :choices

    # @return [Integer, nil] one of Status::*
    attr_reader :status

    # @param prefix [Array<Integer>] choices to replay before drawing fresh
    # @param rng [Random, nil] source of fresh draws (absent during pure replay)
    # @param max_size [Numeric] cap on the choice-sequence length
    def initialize(prefix: [], rng: nil, max_size: Float::INFINITY)
      @prefix = prefix
      @rng = rng
      @max_size = max_size
      @choices = []
      @status = nil
      @depth = 0
    end

    # Draw an integer in 0..n, recording it into the sequence.
    def choice(n)
      make_choice(n) { @rng.rand(n + 1) }
    end

    # Return true with probability `p`. Shrinks toward false (choice 0).
    def weighted(p)
      if p <= 0
        forced_choice(0) == 1
      elsif p >= 1
        forced_choice(1) == 1
      else
        make_choice(1) { @rng.rand <= p ? 1 : 0 } == 1
      end
    end

    # Insert a fixed choice into the sequence, as if a call to #choice had
    # returned `n`. Occasionally useful as a shrinker hint.
    def forced_choice(n)
      raise ArgumentError, "invalid choice #{n}" if n.negative? || n.bit_length > 64
      raise Frozen if @status

      mark_status(Status::OVERRUN) if @choices.length >= @max_size
      @choices << n
      n
    end

    # Mark this case invalid and abort it.
    def reject
      mark_status(Status::INVALID)
    end

    # Abort as invalid unless `precondition` holds.
    def assume(precondition)
      reject unless precondition
    end

    # Produce a value from a generator, tracking nesting depth.
    def any(gen)
      @depth += 1
      gen.produce(self)
    ensure
      @depth -= 1
    end

    # Set the status and abort the run (raises StopTest).
    def mark_status(status)
      raise Frozen if @status

      @status = status
      raise StopTest
    end

    # Called by the runner once the property has returned: a case that never
    # marked itself completed cleanly and is VALID. An explicit finalizer, so
    # the runner doesn't have to poke at instance state.
    def finalize!
      @status = Status::VALID if @status.nil?
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

    private

    # Make a choice in [0, n], drawing fresh (via the block) only when we've
    # run past the supplied prefix.
    #
    # - If the sequence is at the cap, mark OVERRUN (and abort).
    # - Replay from the prefix while inside it, else draw fresh.
    # - If the resulting value exceeds `n`, mark INVALID (and abort) — this is
    #   what keeps shrunk sequences coherent instead of feeding generators
    #   out-of-range integers.
    def make_choice(n)
      raise ArgumentError, "invalid choice #{n}" if n.negative? || n.bit_length > 64
      raise Frozen if @status

      mark_status(Status::OVERRUN) if @choices.length >= @max_size

      result = if @choices.length < @prefix.length
                 @prefix[@choices.length]
               else
                 yield
               end
      @choices << result
      mark_status(Status::INVALID) if result > n
      result
    end
  end
end
