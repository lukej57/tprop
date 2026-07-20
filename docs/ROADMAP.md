# TProp: Roadmap

Tiered by release, and honest about what exists versus what is designed. The
guiding rule: derivation quality and shrink quality come before everything else,
because they are what make the core job (see `JOBS_TO_BE_DONE.md`) free.

## v0.1 — engine core (implemented)

The choice-sequence engine is ported from
[minithesis](https://github.com/DRMacIver/minithesis) (MPL-2.0) and runs for
real over explicit generators. Derivation is the remaining headline work.

- [x] `TestCase` choice-sequence recorder with overrun/invalid status.
- [x] `TestingState` runner + four shrink passes under shortlex order.
- [x] `Gen` combinators (`map`/`bind`/`satisfying`) and core primitives
      (`constant`, `integers`, `lists`, `nilable`, `one_of`, `tuples`, `strings`).
- [x] `TProp.check(gen:)` + Minitest `for_all` / `assert_property` (F-not-E,
      seed reuse, failure carries the reproducing choice sequence).
- [x] Shrink-quality regression anchors passing (`test/tprop/engine_test.rb`):
      `x < 100` shrinks to exactly `100`; an unsorted-list property shrinks to
      exactly `[1, 0]`. Note the shrinker finds a *locally* minimal example
      (minithesis-level), not a guaranteed global minimum.
- [x] **`Derive` — the `T::Struct` → generator walk**, validated against real
      `sorbet-runtime` (`test/tprop/derive_test.rb`). Walks `.props` and
      recurses over the reified tree: `Simple` (primitives, nested structs,
      enums), union nodes (`T::Types::Union` and the `SimplePairUnion` that
      `T.nilable`/`T::Boolean` actually produce), `TypedArray`, `TypedHash`,
      `TypedSet`, `FixedArray`. `assert_property(StructClass)` is live, with
      call-site `overrides:`. Zero-anchored integers (shrink toward 0, reach
      negatives) landed alongside.
- [x] **`StructuralEquality` mixin** — value `==`/`eql?`/`hash` by walking
      `.props`, so equational properties over structs work (the roster
      round-trip / idempotence tests depend on it).

Known v0.1 limitations to carry forward: registries (tiers 2–4) are still stubs;
no recursion cycle detection in nested derivation (self-referential structs
raise a clear error); no example database; no targeted testing; naive float
generation (`Gen.floats` still raises — `Derive` uses an internal naive float).

## v1.0 — the complete, honest core

The five-tier resolution system and derived generators are the headline.

- [ ] **Five-tier generator resolution** end to end (structural < type-keyed <
      built-in hints < user hints < call-site overrides), backed by the
      symbol-keyed `Registry` and type-keyed `TypeRegistry`.
- [ ] **`register_type`** hooked inside `Derive.for_type` (applies at every
      nesting depth).
- [ ] **Declaration-site hints** via `extra: { tprop: ... }`, symbol-preferred.
- [ ] **Recursion cycle detection** in nested-struct derivation (depth bound /
      seen-set), so self-referential structs generate finite values.
- [x] **`StructuralEquality` mixin** shipped (see v0.1). Still to do:
      **`assert_prop_equal`** (with float tolerance) for float-containing
      structs.
- [ ] **Example database** — persist failing choice sequences; replay them
      before random examples on the next run. This is a top adoption lever
      (reproducibility) and a prerequisite for the fuzzing horizon.
- [ ] **Better float generation/shrinking.**
- [ ] **Docs + the FCIS guide** treated as release-blocking, not optional.
      Lead every doc with the flagship high-fit domain — time-interval / shift
      algebra (see `examples/roster`), which is both a textbook fit and
      resonant with the target audience (see `JOBS_TO_BE_DONE.md`). Money and
      parsers are secondary examples.
- [ ] **Motivating experiment: slow Rails test vs. property test** (see
      `EXPERIMENTS.md`). Refactor a database-backed example test to a property
      test over `T::Struct`s and measure coverage-per-wall-clock, not just raw
      speed. A docs/marketing deliverable adjacent to release; the "after" half
      already exists (skipped) in `examples/roster`. The gem's own throughput
      number (examples/sec) rides on the health-checks / `collect` feature
      below — not a bespoke timer.

## v1.x — ergonomic expansions

- [ ] **`assert_stateful`** — sugar for pure state machines: per-state event
      generators, invariant blocks, step bounds. This is state-dependent event
      generation for the `step(state, event) -> [state', effects]` shape, and it
      is explicitly *not* stateful/model-based testing of a mutable system — it
      generates event *traces* and folds them purely. Shrinking still works
      because it is choice-sequence replay underneath. Deferred from 1.0 on
      purpose; the manual `Gen.bind` form works in the meantime.
- [ ] **Targeted property testing** (`target()`-style) — report a fitness score,
      let the engine search toward it. Cheap once the core exists.
- [ ] **`collect` / `label` distribution statistics** and generation health
      checks (too many rejections, too slow, too uniform). High trust-per-effort.
- [ ] **RSpec adapter.**
- [ ] **Ghostwriter-style stub emitter** — since the type info is already
      present, emit starter property tests / generator stubs for a struct.

## Platform horizon — where the choice buffer pays off again

These are not commitments; they are the reason the choice-sequence architecture
is worth its cost. Each reuses the same corpus of choice sequences.

- **Coverage-guided fuzzing** (HypoFuzz-style): a separate, opt-in mode that
  keeps a corpus of coverage-expanding choice sequences, mutates them, and
  shrinks failures back into the same example database. Ruby's stdlib
  `Coverage` module (branch / oneshot) makes this feasible; keep it out of the
  default test path (per Hypothesis's own experience that in-line coverage
  guidance is too slow to bake in).
- **Mutation testing** fed by the choice-buffer corpus for deterministic kills —
  the saved sequences are exactly the inputs most likely to distinguish a mutant.
- **Bounded-exhaustive testing** from the same `.props` derivation walk (small-
  scope exhaustion instead of random sampling).
- **Grammar-based fuzzing**, **effect-fault injection** (fuzzing the responses of
  injected effects), **production-input shrinking** (minimize a captured real
  input against your properties), and **auto-generated contract properties from
  Sorbet `sig` declarations**.

The through-line: one representation (the choice sequence) is simultaneously the
generator input, the shrink target, the replay token, the fuzzing corpus entry,
and the mutation-testing seed. Build it well once.
