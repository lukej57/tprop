# frozen_string_literal: true

# This Source Code Form is subject to the terms of the Mozilla Public License,
# v. 2.0. If a copy of the MPL was not distributed with this file, You can
# obtain one at https://mozilla.org/MPL/2.0/ (see LICENSE-MPL.txt).
#
# This file is a Ruby port of parts of minithesis
# (https://github.com/DRMacIver/minithesis), (C) 2020 David R. MacIver, used
# under the MPL-2.0. The rest of TProp is MIT; see README.md "Licensing".

module TProp
  # The runner + shrinker. Runs the property up to `max_examples` times and, on
  # a failing (interesting) case, reduces the choice sequence to a fixed point
  # under a shortlex total order (shorter sequences first; ties broken
  # lexicographically).
  #
  # Ported from minithesis (David R. MacIver, MPL-2.0). Shrink passes, in order:
  #   1. Chunk deletion (with a length-nudge) — collapses list length / size.
  #   2. Block zeroing — collapses values toward their simplest.
  #   3. Per-choice binary search — minimizes each individual integer.
  #   4. Sort / redistribute — lexicographic tidy-ups (sort ranges; swap and
  #      rebalance adjacent pairs).
  #
  # A candidate is accepted only if it is still interesting AND shortlex-smaller.
  #
  # See docs/ARCHITECTURE.md, "TestingState (the runner + shrinker)".
  class TestingState
    # @return [Array<Integer>, nil] the best (smallest) interesting sequence
    attr_reader :result

    # @return [Integer] count of valid (non-rejected) cases seen
    attr_reader :valid_test_cases

    # @param gen [TProp::Gen] the generator under test
    # @param property [Proc] called with each generated value; raises to fail
    # @param max_examples [Integer]
    # @param rng [Random]
    def initialize(gen:, property:, max_examples:, rng:)
      @gen = gen
      @property = property
      @max_examples = max_examples
      @rng = rng

      @valid_test_cases = 0
      @calls = 0
      @result = nil
      @test_is_trivial = false
    end

    def run
      generate
      shrink
    end

    def failed?
      !@result.nil?
    end

    # Total order used for shrink acceptance: shorter first, then lexicographic.
    # Uses `<=>` (not `<`) on the arrays deliberately — see ARCHITECTURE.md.
    def self.shortlex_smaller?(a, b)
      (sort_key(a) <=> sort_key(b)).negative?
    end

    def self.sort_key(choices)
      [choices.length, choices]
    end

    private

    # Run the property against one test case, classify it, and keep it if it is
    # the new smallest interesting example.
    def test_function(test_case)
      begin
        value = test_case.any(@gen)
        @property.call(value)
      rescue StopTest, Frozen
        # control flow: status already set (or being set); fall through
      rescue SystemExit, SignalException, NoMemoryError, SystemStackError
        raise
      rescue Exception # rubocop:disable Lint/RescueException
        # Any error the property raises (including Minitest::Assertion, which is
        # not a StandardError) means "interesting" — unless the case already
        # marked itself (overrun/invalid) on the way out.
        raise if test_case.status

        begin
          test_case.mark_status(TestCase::Status::INTERESTING)
        rescue StopTest
          # expected: mark_status aborts via StopTest
        end
      end

      test_case.finalize!
      status = test_case.status
      @calls += 1
      @test_is_trivial = true if status >= TestCase::Status::INVALID && test_case.choices.empty?
      @valid_test_cases += 1 if status >= TestCase::Status::VALID

      return unless status == TestCase::Status::INTERESTING
      return unless @result.nil? || self.class.shortlex_smaller?(test_case.choices, @result)

      @result = test_case.choices.dup
    end

    def should_keep_generating?
      !@test_is_trivial &&
        @result.nil? &&
        @valid_test_cases < @max_examples &&
        @calls < @max_examples * 10
    end

    def generate
      test_function(TestCase.new(prefix: [], rng: @rng, max_size: TestCase::BUFFER_SIZE)) while should_keep_generating?
    end

    # Re-run a specific choice sequence and return its status. Side effect:
    # updates @result if it turns out to be a smaller interesting example.
    def run_once(choices)
      test_case = TestCase.for_choices(choices)
      test_function(test_case)
      test_case.status
    end

    def shrink
      return unless @result

      consider = lambda do |choices|
        return true if choices == @result

        run_once(choices) == TestCase::Status::INTERESTING
      end

      replace = lambda do |values|
        attempt = @result.dup
        values.each do |i, v|
          return false if i >= attempt.length

          attempt[i] = v
        end
        consider.call(attempt)
      end

      prev = nil
      until prev == @result
        prev = @result.dup

        delete_chunks(consider)
        zero_blocks(replace)
        binary_search_choices(replace)
        sort_ranges(consider)
        redistribute_pairs(replace)
      end
    end

    # Pass 1: delete contiguous runs of choices, with a length-nudge that
    # decrements the preceding choice (unsticks length-dependent generators).
    def delete_chunks(consider)
      k = 8
      while k.positive?
        i = @result.length - k - 1
        while i >= 0
          if i >= @result.length
            i -= 1
            next
          end
          attempt = @result[0...i] + (@result[(i + k)..] || [])
          unless consider.call(attempt)
            if i.positive? && attempt[i - 1] > 0
              attempt[i - 1] -= 1
              i += 1 if consider.call(attempt)
            end
          end
          i -= 1
        end
        k -= 1
      end
    end

    # Pass 2: replace blocks of choices with zeroes (k down to 2; k == 1 is
    # handled by the binary search below).
    def zero_blocks(replace)
      k = 8
      while k > 1
        i = @result.length - k
        while i >= 0
          if replace.call((i...(i + k)).to_h { |j| [j, 0] })
            i -= k
          else
            i -= 1
          end
        end
        k -= 1
      end
    end

    # Pass 3: minimize each individual choice by binary search toward 0.
    def binary_search_choices(replace)
      i = @result.length - 1
      while i >= 0
        idx = i
        self.class.bin_search_down(0, @result[idx]) { |v| replace.call({ idx => v }) }
        i -= 1
      end
    end

    # Pass 4a: sort out-of-order ranges (sort(x) <= x lexicographically).
    def sort_ranges(consider)
      k = 8
      while k > 1
        i = @result.length - k - 1
        while i >= 0
          sorted = @result[i...(i + k)].sort
          consider.call(@result[0...i] + sorted + (@result[(i + k)..] || []))
          i -= 1
        end
        k -= 1
      end
    end

    # Pass 4b: swap out-of-order adjacent pairs, and redistribute value between
    # them (helps properties that depend on a sum).
    def redistribute_pairs(replace)
      [2, 1].each do |k|
        i = @result.length - 1 - k
        while i >= 0
          j = i + k
          if j < @result.length
            replace.call({ j => @result[i], i => @result[j] }) if @result[i] > @result[j]
            if j < @result.length && @result[i].positive?
              prev_i = @result[i]
              prev_j = @result[j]
              self.class.bin_search_down(0, prev_i) { |v| replace.call({ i => v, j => prev_j + (prev_i - v) }) }
            end
          end
          i -= 1
        end
      end
    end

    # Returns n in [lo, hi] with f(n) truthy, assuming (uncheck) f(hi) is true.
    # Finds a locally minimal such n.
    def self.bin_search_down(lo, hi)
      return lo if yield(lo)

      while lo + 1 < hi
        mid = lo + ((hi - lo) / 2)
        if yield(mid)
          hi = mid
        else
          lo = mid
        end
      end
      hi
    end
  end
end
