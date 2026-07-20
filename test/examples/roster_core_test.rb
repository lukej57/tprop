# frozen_string_literal: true

require "test_helper"
require_relative "../../examples/roster/interval_ops"

# Executing, example-based tests that prove the functional core actually works.
# These are the conventional tests you'd write anyway; the property tests in
# roster_property_test.rb are what the core *earns* on top of them once the
# engine lands.
#
# We compare intervals via #to_pair (not ==) because value equality comes from
# the still-stubbed TProp::StructuralEquality mixin.
class RosterCoreTest < Minitest::Test
  include Rostering
  Ops = Rostering::IntervalOps

  def pairs(intervals)
    intervals.map(&:to_pair)
  end

  def iv(start_min, end_min)
    Interval.new(start_min: start_min, end_min: end_min)
  end

  def test_duration_of_empty_interval_is_zero
    assert_equal 0, Ops.duration(iv(3, 3))
    assert_equal 0, Ops.duration(iv(10, 4)) # degenerate: end before start
    assert_equal 5, Ops.duration(iv(0, 5))
  end

  def test_touching_intervals_do_not_overlap
    refute Ops.overlap?(iv(0, 5), iv(5, 10)) # half-open: they touch, not overlap
    assert Ops.overlap?(iv(0, 6), iv(5, 10))
  end

  def test_merge_coalesces_overlapping_and_touching_shifts
    merged = Ops.merge([iv(0, 5), iv(5, 10), iv(3, 4), iv(20, 25)])
    assert_equal [[0, 10], [20, 25]], pairs(merged)
  end

  def test_merge_drops_empties_and_sorts
    merged = Ops.merge([iv(20, 25), iv(3, 3), iv(0, 5)])
    assert_equal [[0, 5], [20, 25]], pairs(merged)
  end

  def test_coverage_counts_overlap_once_but_total_duration_double_counts
    shifts = [iv(0, 10), iv(5, 15)]
    assert_equal 15, Ops.coverage(shifts)        # union: [0, 15)
    assert_equal 20, Ops.total_duration(shifts)  # 10 + 10, overlap double-counted
  end

  def test_intersect_is_nil_when_disjoint_or_touching
    assert_nil Ops.intersect(iv(0, 5), iv(5, 10))
    assert_equal [5, 10], Ops.intersect(iv(0, 10), iv(5, 15))&.to_pair
  end
end
