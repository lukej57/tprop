# frozen_string_literal: true

require_relative "interval"

module Rostering
  # The functional core: pure, total functions over Interval / Roster values.
  # No clock, no database, no mutation — decisions only. This is precisely the
  # region where TProp's guarantees hold (see
  # docs/guides/functional-core-imperative-shell.md).
  #
  # Every function here is total: it is defined for *every* Interval a generator
  # can produce, including empty and degenerate ones. Totality is what lets the
  # properties be stated cleanly without a pile of preconditions.
  module IntervalOps
    extend T::Sig
    module_function

    # Duration in minutes. Empty (end <= start) intervals have duration 0 — not
    # a negative number.
    sig { params(i: Interval).returns(Integer) }
    def duration(i)
      [i.end_min - i.start_min, 0].max
    end

    sig { params(i: Interval).returns(T::Boolean) }
    def empty?(i)
      duration(i).zero?
    end

    # Half-open overlap: strict on both sides, so [0, 5) and [5, 10) do NOT
    # overlap (they touch). This single line is where most real boundary bugs
    # live.
    sig { params(a: Interval, b: Interval).returns(T::Boolean) }
    def overlap?(a, b)
      a.start_min < b.end_min && b.start_min < a.end_min
    end

    # Intersection of two intervals, or nil if they don't overlap.
    sig { params(a: Interval, b: Interval).returns(T.nilable(Interval)) }
    def intersect(a, b)
      start = [a.start_min, b.start_min].max
      finish = [a.end_min, b.end_min].min
      return nil if finish <= start

      Interval.new(start_min: start, end_min: finish)
    end

    # The canonical minimal cover of a set of shifts: empties dropped,
    # overlapping *and* touching intervals coalesced, sorted by start. This is
    # "when is someone actually working", deduplicated.
    #
    # Structured as a sort + fold so the result depends only on the *set* of
    # covered minutes, not the input order — which is what makes the
    # order-independence property below true.
    sig { params(intervals: T::Array[Interval]).returns(T::Array[Interval]) }
    def merge(intervals)
      sorted = intervals.reject { |i| empty?(i) }.sort_by(&:start_min)

      sorted.each_with_object([]) do |i, acc|
        last = acc.last
        if last && i.start_min <= last.end_min
          # Overlapping or touching: extend the running interval.
          acc[-1] = Interval.new(start_min: last.start_min, end_min: [last.end_min, i.end_min].max)
        else
          acc.push(i)
        end
      end
    end

    # Total minutes in the union of all shifts (overlaps counted once).
    sig { params(intervals: T::Array[Interval]).returns(Integer) }
    def coverage(intervals)
      merge(intervals).sum { |i| duration(i) }
    end

    # Naive sum of durations (overlaps counted as many times as they appear).
    # Deliberately separate from #coverage — the gap between the two is the
    # teaching moment (see the FALSE property in the tests).
    sig { params(intervals: T::Array[Interval]).returns(Integer) }
    def total_duration(intervals)
      intervals.sum { |i| duration(i) }
    end

    # Is `minute` inside this half-open interval?
    sig { params(i: Interval, minute: Integer).returns(T::Boolean) }
    def covers?(i, minute)
      i.start_min <= minute && minute < i.end_min
    end
  end
end
