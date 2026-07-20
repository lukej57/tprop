# frozen_string_literal: true

require "sorbet-runtime"
require "tprop"

module Rostering
  # A half-open time interval [start_min, end_min) measured in minutes from a
  # reference instant (e.g. the start of a roster window). Half-open is the
  # load-bearing convention: it makes "touching" intervals — [0, 5) and
  # [5, 10) — unambiguous, and it is exactly the boundary a property tester
  # loves to probe.
  #
  # Degenerate intervals (end_min <= start_min, i.e. empty) are *representable*
  # on purpose. A generator derived from this struct will produce them, and the
  # functional core below is total over them. That is the point: PBT explores
  # the whole representable space, including the shapes a human wouldn't think
  # to write down.
  #
  # NOTE: "minutes since a reference" sidesteps midnight-wraparound (a shift
  # from 22:00 to 02:00 can't be written as start < end on a 0..1440 clock).
  # That wraparound is itself a lovely piece of input-space treachery and a
  # natural next extension — see examples/roster/README.md.
  class Interval < T::Struct
    # Value equality is what equational properties (round-trips, idempotence)
    # assert on. In the finished library this comes from the mixin below; the
    # mixin is currently a stub (see docs/ROADMAP.md), so the *executing*
    # example tests compare via #to_pair meanwhile.
    include TProp::StructuralEquality
    extend T::Sig

    const :start_min, Integer
    const :end_min, Integer

    # A plain, dependency-free serialization boundary, for the round-trip
    # property.
    sig { returns([Integer, Integer]) }
    def to_pair
      [start_min, end_min]
    end

    sig { params(pair: [Integer, Integer]).returns(Interval) }
    def self.from_pair(pair)
      new(start_min: pair[0], end_min: pair[1])
    end
  end

  # A roster is a bag of shifts. This is the struct the property tests point at:
  # `assert_property(Roster) { |r| ... }` derives a generator for the whole
  # thing — including the nested `T::Array[Interval]` — with nothing written by
  # hand. That nested derivation is the entire pitch.
  class Roster < T::Struct
    include TProp::StructuralEquality

    const :shifts, T::Array[Interval]
  end
end
