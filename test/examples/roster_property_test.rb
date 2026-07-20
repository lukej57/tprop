# frozen_string_literal: true

require "test_helper"
require_relative "../../examples/roster/interval_ops"

# The API north star for the flagship example. Every test here derives its
# generator from a T::Struct — no hand-written generator anywhere — and asserts
# a property across the whole representable roster space.
#
# The engine is still scaffolding, so each property is `skip`ped and the suite
# stays green. When Derive + TestingState land (docs/ROADMAP.md), delete the
# `skip` lines and these execute for real. The comments spell out the minimal
# counterexample the shrinker should hand back for the falsifiable ones.
class RosterPropertyTest < Minitest::Test
  include Rostering
  Ops = Rostering::IntervalOps

  # --- Properties that should HOLD ---------------------------------------

  # Idempotence: merging an already-merged roster changes nothing. Normalizers
  # and dedup love this property.
  def test_merge_is_idempotent
    skip "engine not implemented yet (docs/ROADMAP.md v0.1)"

    assert_property(Roster) do |r|
      once = Ops.merge(r.shifts)
      assert_equal once, Ops.merge(once)
    end
  end

  # Invariant: the merged cover is sorted and pairwise non-overlapping.
  def test_merge_output_is_sorted_and_disjoint
    skip "engine not implemented yet (docs/ROADMAP.md v0.1)"

    assert_property(Roster) do |r|
      merged = Ops.merge(r.shifts)
      merged.each_cons(2) do |a, b|
        assert_operator a.end_min, :<, b.start_min # strictly disjoint (touching was coalesced)
      end
    end
  end

  # Order-independence: coverage depends only on the set of shifts, not the
  # order they arrive in. (Uses a second generated roster as a permutation
  # source — a taste of composing generators.)
  def test_coverage_is_order_independent
    skip "engine not implemented yet (docs/ROADMAP.md v0.1)"

    assert_property(Roster) do |r|
      assert_equal Ops.coverage(r.shifts), Ops.coverage(r.shifts.shuffle)
    end
  end

  # Coverage never exceeds naive total, with equality exactly when nothing
  # overlaps. A clean metamorphic relation — the oracle is free.
  def test_coverage_is_bounded_by_total_duration
    skip "engine not implemented yet (docs/ROADMAP.md v0.1)"

    assert_property(Roster) do |r|
      assert_operator Ops.coverage(r.shifts), :<=, Ops.total_duration(r.shifts)
    end
  end

  # Round-trip: an interval survives serialization unchanged. The highest-value
  # starting property because the oracle costs nothing.
  def test_interval_round_trips_through_pair
    skip "engine not implemented yet (docs/ROADMAP.md v0.1)"

    assert_property(gen: TProp::Derive.for_struct(Interval)) do |i|
      assert_equal i, Interval.from_pair(i.to_pair)
    end
  end

  # --- A property that is TEMPTING but FALSE -----------------------------

  # It is very natural to assume merging shifts preserves the total hours. It
  # does not: overlaps get counted once after merging. This test exists to be
  # *falsified* — when the engine lands, it should fail and the shrinker should
  # hand back the minimal counterexample: two shifts that overlap by one
  # minute, e.g. shifts = [[0, 2), [1, 3)] (total 4, coverage 3). That minimal
  # example is the whole value proposition in one line.
  def test_merge_does_NOT_preserve_total_duration
    skip "DEMO of a false property — unskip once the engine lands to watch it fail & shrink"

    assert_property(Roster) do |r|
      # Intentionally wrong: merging collapses overlaps, so the total shrinks.
      assert_equal Ops.total_duration(r.shifts), Ops.total_duration(Ops.merge(r.shifts))
    end
  end
end
