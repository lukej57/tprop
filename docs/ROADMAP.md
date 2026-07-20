# TProp: Roadmap

Tiered by release, and honest about what exists versus what is designed. The
guiding rule: derivation quality and shrink quality come before everything else,
because they are what make the core job (see `JOBS_TO_BE_DONE.md`) free.

## v0.1 — engine skeleton (exists, needs grounding)

Scaffolded and smoke-tested against a **hand-written `T::Types` stub**, so the
first work is grounding it in reality, not adding features.

- [x] `TestCase` choice-sequence recorder with overrun/invalid status.
- [x] `TestingState` runner + four shrink passes under shortlex order.
- [x] `Gen` combinators (`map`/`bind`/`satisfying`) and core primitives.
- [x] `Derive` structural walk over `T::Types::*`.
- [x] Minitest integration (F-not-E, seed reuse).
- **[ ] FIRST TASK: validate `Derive` against real `sorbet-runtime`.** Replace
  the stub, confirm the type-tree node classes and `.props` shape match, and fix
  what differs. Nothing else is trustworthy until this is done.
- Smoke tests already assert concrete shrink quality and should be kept as
  regression anchors: `x < 100` shrinks to exactly `100`; an unsorted-list
  property shrinks to exactly `[1, 0]`; a derived-struct counterexample shrinks
  to the minimal field assignment (e.g. `nickname: "aaaaa"`, everything else at
  its minimum).

Known v0.1 limitations to carry forward: no recursion cycle detection in nested
derivation, no example database, no targeted testing, naive float encoding.

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
- [ ] **`StructuralEquality` mixin** and **`assert_prop_equal`** (with float
      tolerance) shipped and documented — the equational-property job depends on
      these.
- [ ] **Example database** — persist failing choice sequences; replay them
      before random examples on the next run. This is a top adoption lever
      (reproducibility) and a prerequisite for the fuzzing horizon.
- [ ] **Better float generation/shrinking.**
- [ ] **Docs + the FCIS guide** treated as release-blocking, not optional.
      Lead every doc with the flagship high-fit domain — time-interval / shift
      algebra (see `examples/roster`), which is both a textbook fit and
      resonant with the target audience (see `JOBS_TO_BE_DONE.md`). Money and
      parsers are secondary examples.

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
