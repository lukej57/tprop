# frozen_string_literal: true

require "test_helper"
require_relative "../../examples/roster/interval_ops"

# The API north star for the flagship example, now executing for real. Every
# test here derives its generator from a T::Struct — no hand-written generator
# anywhere — and asserts a property across the whole representable roster space.
class RosterPropertyTest < Minitest::Test
  include Rostering
  Ops = Rostering::IntervalOps

  # --- Properties that should HOLD ---------------------------------------

  # Idempotence: merging an already-merged roster changes nothing. (Relies on
  # TProp::StructuralEquality for interval value equality.)
  def test_merge_is_idempotent
    assert_property(Roster) do |r|
      once = Ops.merge(r.shifts)
      assert_equal once, Ops.merge(once)
    end
  end

  # Invariant: the merged cover is sorted and pairwise non-overlapping.
  def test_merge_output_is_sorted_and_disjoint
    assert_property(Roster) do |r|
      merged = Ops.merge(r.shifts)
      merged.each_cons(2) do |a, b|
        assert_operator a.end_min, :<, b.start_min # strictly disjoint (touching was coalesced)
      end
    end
  end

  # Order-independence: coverage depends only on the set of shifts, not the
  # order they arrive in.
  def test_coverage_is_order_independent
    assert_property(Roster) do |r|
      assert_equal Ops.coverage(r.shifts), Ops.coverage(r.shifts.shuffle)
    end
  end

  # Coverage never exceeds naive total, with equality exactly when nothing
  # overlaps. A clean metamorphic relation — the oracle is free.
  def test_coverage_is_bounded_by_total_duration
    assert_property(Roster) do |r|
      assert_operator Ops.coverage(r.shifts), :<=, Ops.total_duration(r.shifts)
    end
  end

  # Round-trip: an interval survives serialization unchanged. The highest-value
  # starting property because the oracle costs nothing.
  def test_interval_round_trips_through_pair
    assert_property(gen: TProp::Derive.for_struct(Interval)) do |i|
      assert_equal i, Interval.from_pair(i.to_pair)
    end
  end

  # --- The tempting-but-FALSE property, now demonstrably falsified --------

  # It is very natural to assume merging shifts preserves total hours. It does
  # not: overlaps get counted once after merging. So TProp *finds* a
  # counterexample and TProp.check raises — which is exactly what this test
  # asserts. The shrunk counterexample is a roster whose shifts actually
  # overlap (total > coverage): the whole value proposition, discovered
  # automatically.
  def test_pbt_falsifies_the_tempting_total_duration_property
    error = assert_raises(TProp::PropertyFailure) do
      TProp.check(Roster, max_examples: 500, seed: 20_260_721) do |r|
        # Intentionally wrong: merging collapses overlaps, so the total shrinks.
        unless Ops.total_duration(r.shifts) == Ops.total_duration(Ops.merge(r.shifts))
          raise "expected merge to preserve total duration"
        end
      end
    end

    counterexample = error.counterexample
    assert_kind_of Roster, counterexample
    # The counterexample genuinely contains overlapping shifts.
    assert_operator Ops.total_duration(counterexample.shifts), :>, Ops.coverage(counterexample.shifts)
  end
end
