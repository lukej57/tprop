# frozen_string_literal: true

require "test_helper"
require "sorbet-runtime"

# Exercises the T::Struct -> generator walk against real sorbet-runtime across
# the type-node kinds Derive claims to support.
class DeriveTest < Minitest::Test
  class Priority < T::Enum
    enums do
      Low = new
      High = new
    end
  end

  class Point < T::Struct
    include TProp::StructuralEquality
    const :x, Integer
    const :y, Integer
  end

  class Everything < T::Struct
    const :n, Integer
    const :s, String
    const :maybe, T.nilable(String)
    const :flag, T::Boolean
    const :priority, Priority
    const :point, Point
    const :points, T::Array[Point]
    const :counts, T::Hash[Symbol, Integer]
  end

  # Collect one sample per generated value, so we can assert over the sample.
  def sample(struct_class, count: 200, seed: 1, **check_kwargs, &block)
    values = []
    TProp.check(struct_class, max_examples: count, seed: seed, **check_kwargs) { |v| values << v; block&.call(v) }
    values
  end

  def test_derives_a_populated_struct
    values = sample(Everything)
    refute_empty values
    v = values.first
    assert_kind_of Integer, v.n
    assert_kind_of String, v.s
    assert_includes [true, false], v.flag
    assert_kind_of Priority, v.priority
    assert_kind_of Point, v.point
    assert_kind_of Array, v.points
    assert(v.points.all? { |p| p.is_a?(Point) })
    assert_kind_of Hash, v.counts
  end

  def test_nilable_reaches_both_nil_and_present
    maybes = sample(Everything, count: 300).map(&:maybe)
    assert_includes maybes, nil
    assert(maybes.any? { |m| m.is_a?(String) })
  end

  def test_enum_only_yields_declared_values
    priorities = sample(Everything, count: 300).map(&:priority).uniq
    assert(priorities.all? { |p| Priority.values.include?(p) })
    assert_operator priorities.length, :>=, 1
  end

  def test_integers_reach_negatives_and_shrink_toward_zero
    ns = sample(Everything, count: 300, seed: 3).map(&:n)
    assert(ns.any?(&:negative?), "expected some negative integers")
    assert(ns.any? { |x| x.abs < 5 }, "expected small integers")

    # A failing property over a nested int shrinks that int toward 0.
    error = assert_raises(TProp::PropertyFailure) do
      TProp.check(Point, max_examples: 200, seed: 7) do |p|
        raise "too big" unless p.x < 10
      end
    end
    assert_equal 10, error.counterexample.x
  end

  def test_call_site_override_constrains_a_prop
    xs = []
    TProp.check(Point, overrides: { x: TProp::Gen.constant(42) }, max_examples: 100, seed: 1) { |p| xs << p.x }
    assert_equal [42], xs.uniq
  end

  def test_non_struct_raises_argument_error
    assert_raises(ArgumentError) { TProp::Derive.for_struct(Integer) }
  end

  # A self-referential struct (defined here by reopening after the class exists,
  # since the body can't reference itself).
  class SelfRef < T::Struct
  end
  SelfRef.prop :nested, T.nilable(SelfRef)

  def test_recursive_struct_raises_clear_error
    assert_raises(NotImplementedError) { TProp::Derive.for_struct(SelfRef) }
  end
end
