# TProp

**Property-based testing for Ruby, derived from Sorbet `T::Struct` types.**

TProp turns the type information you already wrote into generators. A
`T::Struct` declaration is a machine-readable schema — every prop carries a
reified runtime type, recursively, including generics, unions, nilability,
enums, and nested structs. `YourStruct.props` *is* the generator, waiting to
be interpreted. TProp interprets it, runs your property hundreds of times,
and when it finds a failure, shrinks it to a minimal counterexample for free.

```ruby
# The entire cost of property-testing a struct's serialization:
assert_property(User) do |user|
  assert_equal user, User.from_hash(user.serialize)
end
```

No hand-written generator. No shadow type system that drifts out of sync with
your real definitions. That elimination of per-property generator boilerplate
is the whole reason TProp can exist where every prior Ruby PBT attempt stalled.

---

## The two-sentence pitch

TProp lives at the intersection of two things a Sorbet codebase already has or
already wants: **runtime-reified types** (so generators can be derived) and a
**functional core / imperative shell** architecture (so there is pure logic
worth generating inputs for). Neither ingredient alone is sufficient; together
they make property testing not just possible in Ruby but nearly free.

## What's in this repository

| Document | What it's for |
|---|---|
| [`docs/RATIONALE.md`](docs/RATIONALE.md) | Why TProp exists, why Ruby PBT failed before, and the deliberate architectural stance it takes. Read this first. |
| [`docs/JOBS_TO_BE_DONE.md`](docs/JOBS_TO_BE_DONE.md) | The jobs users hire TProp for, who the audience is, the fit heuristics, and non-goals. |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | The engine: choice-sequence generation, the shrinker, the `Gen` combinators, the `Derive` walk, and the five-tier generator resolution order. |
| [`docs/ROADMAP.md`](docs/ROADMAP.md) | What ships at 0.1, at 1.0, at 1.x, and the longer platform horizon (fuzzing, mutation testing, and more). |
| [`docs/EXPERIMENTS.md`](docs/EXPERIMENTS.md) | Designed demonstrations to run once the engine works — starting with the slow Rails test vs. property test benchmark (coverage-per-wall-clock, not just speed). |
| [`docs/guides/functional-core-imperative-shell.md`](docs/guides/functional-core-imperative-shell.md) | The educational companion: how to architect for testability so TProp pays off. This is a load-bearing part of the product, not an afterthought. |
| [`examples/roster`](examples/roster) | The flagship worked example: shift/interval algebra — real domain logic plus the property tests that will run against it. |

## Status

**Derivation works — the core pitch runs end to end.** A `T::Struct` becomes a
generator with nothing hand-written:

```ruby
class Interval < T::Struct   # a shift
  const :start_min, Integer
  const :end_min,   Integer
end
class Roster < T::Struct
  const :shifts, T::Array[Interval]
end

assert_property(Roster) do |r|
  once = IntervalOps.merge(r.shifts)
  assert_equal once, IntervalOps.merge(once)   # merge is idempotent
end
```

Under the hood: the choice-sequence core — `TestCase`, the `Gen`
combinators/primitives, and the `TestingState` runner + four-pass shrinker
(ported from [minithesis](https://github.com/DRMacIver/minithesis)); `Derive`,
which walks `.props` and recurses over the reified `T::Types::*` tree
(Simple/Union/TypedArray/TypedHash/Set/FixedArray, nested structs, enums,
`T.nilable`, `T::Boolean`), validated against real `sorbet-runtime`; and
`StructuralEquality` for value-object `==`.

Shrinking is real and reaches struct counterexamples: `x < 100` shrinks to
exactly `100`, an unsorted list to `[1, 0]`, and the tempting-but-false "merging
shifts preserves total hours" is falsified down to a minimal overlapping roster.
See [`examples/roster`](examples/roster).

Runs are reproducible: same `seed:` reproduces a run, a failure carries its
choice sequence, and the **example database** persists a failing example so it
replays first next time — under Minitest, `assert_property` wires this up
automatically (cached in `.tprop-cache/`), so a fixed bug's example is retried
on every run until it passes.

Still stubbed (raise `NotImplementedError`): the `Registry`/`TypeRegistry` tiers
(`register_type`, declaration-site hints), recursion cycle detection for
self-referential structs, and nicer float generation. See
[`docs/ROADMAP.md`](docs/ROADMAP.md).

```bash
bin/setup        # install dependencies
bundle exec rake # run the test suite (green)
```

## Installation — repo only, not on RubyGems

**TProp is deliberately not published to RubyGems and will not be while it is
this early.** It is a long way from being something anyone but the author would
use, and there is no intent to publish a `gem install tprop` version. The only
supported way to use it is directly from this git repository:

```ruby
# Gemfile
gem "tprop", git: "https://github.com/lukej57/tprop.git"
```

This is enforced, not just documented: the gemspec sets `allowed_push_host` to
a non-existent host, so `gem push` refuses to publish (it would only push to a
host that isn't real), guarding against an accidental release to rubygems.org.
Don't remove that guard unless you are deliberately choosing to publish.

## Name

`T` signals Sorbet-ecosystem membership; `prop` double-encodes *property-based
testing* and `T::Struct.props`, the reflection surface the whole library is
built on. Unclaimed on RubyGems and GitHub as of naming.

## Licensing

TProp is MIT-licensed ([`LICENSE.txt`](LICENSE.txt)) **except** the
choice-sequence engine, which is a Ruby port of
[minithesis](https://github.com/DRMacIver/minithesis) (© 2020 David R. MacIver)
and therefore stays under its original **MPL-2.0**
([`LICENSE-MPL.txt`](LICENSE-MPL.txt)). The MPL-covered files are:

- `lib/tprop/test_case.rb`
- `lib/tprop/gen.rb`
- `lib/tprop/testing_state.rb`

MPL-2.0 is file-level (weak) copyleft: those three files must stay MPL and keep
their source available, but they combine freely with the MIT-licensed rest of
the gem. If you modify them, keep the MPL header intact.
