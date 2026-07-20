# frozen_string_literal: true

# This Source Code Form is subject to the terms of the Mozilla Public License,
# v. 2.0. If a copy of the MPL was not distributed with this file, You can
# obtain one at https://mozilla.org/MPL/2.0/ (see LICENSE-MPL.txt).
#
# This file is a Ruby port of parts of minithesis
# (https://github.com/DRMacIver/minithesis), (C) 2020 David R. MacIver, used
# under the MPL-2.0. The rest of TProp is MIT; see README.md "Licensing".

module TProp
  # A Gen (a "Possibility" in minithesis terms) is a named recipe that turns a
  # TestCase into a value. Composition and primitives live here.
  #
  # Design heuristic preserved everywhere: structure generators so that
  # all-zeros is the simplest value. The shrinker drives choices toward 0 and
  # sequences toward shorter, so "0 / empty / nil / \"\"" falls out of a zeroed
  # choice sequence.
  #
  # See docs/ARCHITECTURE.md, "The generator layer".
  class Gen
    # @return [String] a human-readable name, for diagnostics
    attr_reader :name

    # @param name [String]
    # @yield [TestCase] the block that produces a value from a test case
    def initialize(name: "gen", &produce)
      @name = name
      @produce = produce
    end

    # Produce a value from a TestCase. Combinators call `test_case.any(sub_gen)`
    # (not this directly) so that nesting depth is tracked.
    def produce(test_case)
      @produce.call(test_case)
    end

    # --- Composition -------------------------------------------------------

    # Transform the produced value.
    def map(&block)
      Gen.new(name: "#{@name}.map") { |tc| block.call(tc.any(self)) }
    end

    # Sequence a dependent generator. Works across the choice sequence, so
    # shrinking still composes.
    def bind(&block)
      Gen.new(name: "#{@name}.bind") { |tc| tc.any(block.call(tc.any(self))) }
    end

    # Filter: reject the case (not crash) if no candidate passes within the try
    # budget.
    def satisfying(max_tries: 3, &predicate)
      Gen.new(name: "#{@name}.satisfying") do |tc|
        value = nil
        found = false
        max_tries.times do
          value = tc.any(self)
          if predicate.call(value)
            found = true
            break
          end
        end
        tc.reject unless found
        value
      end
    end

    class << self
      # --- Primitives (all shrinking toward the simplest value) ------------

      # Only `value` is possible. Draws nothing.
      def constant(value)
        new(name: "constant(#{value.inspect})") { |_tc| value }
      end

      # Any integer in an inclusive range, anchored so it shrinks toward the
      # in-range value nearest zero (0 if the range spans it, else the closest
      # endpoint). Ranges that span zero also draw a sign, so both signs are
      # reachable while all-zeros still decodes to 0.
      #
      #   Gen.integers(0..100)      # shrinks toward 0
      #   Gen.integers(-50..50)     # shrinks toward 0, reaches negatives
      #   Gen.integers(min: 1, max: 6)
      def integers(range = nil, min: nil, max: nil)
        lo, hi = bounds_from(range, min, max)
        raise ArgumentError, "empty integer range #{lo}..#{hi}" if hi < lo

        name = "integers(#{lo}..#{hi})"
        if lo >= 0
          new(name: name) { |tc| lo + tc.choice(hi - lo) }         # nearest-zero is lo
        elsif hi <= 0
          new(name: name) { |tc| hi - tc.choice(hi - lo) }         # nearest-zero is hi
        else
          magnitude = [lo.abs, hi].max
          new(name: name) { |tc| signed_choice(tc, magnitude, lo, hi) }
        end
      end

      # A list of elements. Drawn as a repeated (continue-flag, element) so that
      # deleting a span of the choice sequence deletes list elements, and
      # shrinking composes with structure. Shrinks toward the empty list.
      def lists(element_gen, min_length: 0, max_length: nil)
        new(name: "lists(#{element_gen.name})") do |tc|
          result = []
          loop do
            if result.length < min_length
              tc.forced_choice(1)
            elsif max_length && result.length + 1 >= max_length
              tc.forced_choice(0)
              break
            elsif !tc.weighted(0.9)
              break
            end
            result << tc.any(element_gen)
          end
          result
        end
      end

      # T.nilable(X): nil or an inner value, biased so nil falls out of a zeroed
      # sequence.
      def nilable(inner_gen)
        new(name: "nilable(#{inner_gen.name})") do |tc|
          tc.weighted(0.7) ? tc.any(inner_gen) : nil
        end
      end

      # A value from one of the given generators. Shrinks toward the first.
      def one_of(*gens)
        raise ArgumentError, "one_of needs at least one generator" if gens.empty?
        return gens.first if gens.length == 1

        new(name: "one_of") { |tc| tc.any(gens[tc.choice(gens.length - 1)]) }
      end

      # A fixed-length tuple (array) of values, one per generator.
      def tuples(*gens)
        new(name: "tuples") { |tc| gens.map { |g| tc.any(g) } }
      end

      # A string over `alphabet` (default: letters + digits + space, so shrinks
      # toward "" and repeated "a"). Fuller unicode/byte coverage is a
      # documented refinement (docs/ROADMAP.md).
      def strings(min_length: 0, max_length: nil, alphabet: nil)
        alpha = alphabet || (("a".."z").to_a + ("A".."Z").to_a + ("0".."9").to_a + [" "])
        char_gen = integers(0..(alpha.length - 1)).map { |i| alpha[i] }
        lists(char_gen, min_length: min_length, max_length: max_length).map(&:join)
      end

      # Float generation is deliberately not implemented yet: predictable
      # shrinking of floats wants care (toward 0.0 and small integers-as-floats,
      # not bit-pattern neighbours). See docs/ROADMAP.md.
      def floats(*)
        raise NotImplementedError, "Gen.floats is not implemented yet (docs/ROADMAP.md)"
      end

      private

      # Draw a magnitude (shrinking to 0), then a sign, clamped to [lo, hi].
      # magnitude == 0 draws no sign, so all-zeros decodes to 0.
      def signed_choice(test_case, magnitude, lo, hi)
        mag = test_case.choice(magnitude)
        return 0 if mag.zero?

        pos_ok = mag <= hi
        neg_ok = mag <= lo.abs
        if pos_ok && neg_ok
          test_case.choice(1).zero? ? mag : -mag
        elsif pos_ok
          mag
        else
          -mag
        end
      end

      def bounds_from(range, min, max)
        if range
          lo = range.begin
          hi = range.end
          hi -= 1 if range.exclude_end?
          [lo, hi]
        else
          raise ArgumentError, "provide a range or both min: and max:" if min.nil? || max.nil?

          [min, max]
        end
      end
    end
  end
end
