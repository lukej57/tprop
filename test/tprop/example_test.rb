# frozen_string_literal: true

require "test_helper"
require "sorbet-runtime"

# This is the worked example of how you'd use TProp with Minitest. It is the
# north star for the API — a T::Struct is the generator, and the property is
# the whole test.
#
# The engine is currently scaffolding (methods raise NotImplementedError), so
# every property below is `skip`ped and the suite stays green. As the engine
# lands (docs/ROADMAP.md), delete the `skip` lines and these become real,
# executing property tests.
class ExampleTest < Minitest::Test
  # A plain value object: the kind of thing TProp derives a generator for free.
  class User < T::Struct
    include TProp::StructuralEquality

    const :id, Integer
    const :name, String
    prop :nickname, T.nilable(String)

    # A trivial hand-rolled round-trip boundary, standing in for a real
    # serialization / persistence translation.
    def serialize
      { "id" => id, "name" => name, "nickname" => nickname }
    end

    def self.from_hash(h)
      new(id: h["id"], name: h["name"], nickname: h["nickname"])
    end
  end

  # JOB 1 + the headline example from the README: round-trip a struct through
  # serialization with a generator derived entirely from its T::Struct props.
  def test_serialization_round_trips
    skip "engine not implemented yet (docs/ROADMAP.md v0.1)"

    assert_property(User) do |user|
      assert_equal user, User.from_hash(user.serialize)
    end
  end

  # The explicit-generator form, for properties not anchored on a single struct.
  def test_string_length_is_non_negative
    skip "engine not implemented yet (docs/ROADMAP.md v0.1)"

    for_all(TProp::Gen.strings) do |s|
      assert_operator s.length, :>=, 0
    end
  end

  # Call-site overrides (tier 5): constrain one prop for a targeted campaign.
  def test_round_trip_with_override
    skip "engine not implemented yet (docs/ROADMAP.md v0.1)"

    assert_property(User, overrides: { id: TProp::Gen.integers(1..1_000) }) do |user|
      assert_operator user.id, :>=, 1
      assert_equal user, User.from_hash(user.serialize)
    end
  end
end
