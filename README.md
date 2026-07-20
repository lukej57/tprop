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

**Early scaffolding.** This repository currently contains the gem structure,
the full module surface as documented stubs (choice-sequence `TestCase`,
`TestingState` shrinker, `Gen` combinators, `Derive` walk, registries,
`StructuralEquality`, Minitest integration), and the planning docs. The engine
methods raise `NotImplementedError` — the design is settled (see
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)); the implementation is not
written yet.

The intended usage already lives in the flagship worked example,
[`examples/roster`](examples/roster) (shift/interval algebra) — real,
executing domain logic plus the property tests that will run against it. The
property tests are the API north star; they are `skip`ped until the engine
lands. **The first development task is implementing and validating `Derive`
against real `sorbet-runtime`** — see [`docs/ROADMAP.md`](docs/ROADMAP.md).

```bash
bin/setup        # install dependencies
bundle exec rake # run the test suite (green: stubs + skipped example properties)
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
