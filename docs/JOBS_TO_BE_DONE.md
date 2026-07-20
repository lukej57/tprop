# TProp: Jobs To Be Done

This document frames TProp in terms of the jobs people hire it for, who those
people are, and how to tell — quantitatively — whether a given piece of code is
worth pointing TProp at. It exists to keep scope decisions honest: features earn
their place by serving a named job, not by being interesting.

## Primary jobs

**1. "Let me test the shape of my data, not a handful of examples I thought of."**
The core job. A developer has a `T::Struct` and an invariant (round-trips,
stays non-negative, is idempotent). They want that invariant checked against the
whole representable input space, without writing and maintaining a generator
that duplicates the struct definition. TProp's derivation is the hire.

**2. "When it breaks, hand me the smallest example that breaks it."**
A failing random example is nearly useless; a *minimal* one is a bug report. The
choice-sequence shrinker is the hire — and crucially it shrinks user-written and
derived generators alike, with no per-type shrinker to author.

**3. "Make my failures reproducible and my runs boring."**
Same seed, same run. A persisted failing example replays first on the next run.
A property failure is reported as a test failure (F), not an error (E), so CI
stays legible. This is the job that separates a toy from something a team adopts.

**4. "Reward me for improving my architecture."**
Less obvious, but real: teams hire TProp partly because extracting a value
object from a fat model immediately earns free tests. The tool creates a
gradient toward the functional-core / imperative-shell architecture. See
`RATIONALE.md`.

**5. "Teach me how to write code this works on at all."**
Many prospective users don't have a functional core to point TProp at yet. The
job here is educational — the FCIS guide is what fulfils it. Without it, users
point TProp at entangled code, watch it flail, and conclude "PBT doesn't fit
real apps."

## Who hires it

Sorbet-heavy Ruby codebases with (or moving toward) a typed value-object layer —
Stripe-style domain modeling being the archetype. Concretely: teams with
`T::Struct` value objects, money/quantity types, state machines, parsers,
serialization boundaries, or domain calculations. Teams that are 100%
idiomatic-Rails-over-ActiveRecord with no value layer are explicitly *not* the
initial audience; for them the honest recommendation is to grow a core first.

## When is a piece of code worth it? (fit heuristics)

Two rough predictors, useful for deciding where to spend effort and for teaching
users to aim.

**Property-based-testing fit:**

```
PBT fit  ≈  (property density × input-space treachery)  /  oracle cost
```

- *Property density* — how many real invariants the code obeys (algebraic laws,
  round-trips, conservation, ordering).
- *Input-space treachery* — how much of the bug mass hides in inputs a human
  wouldn't enumerate (boundaries, empties, unicode, overflow, interleavings).
- *Oracle cost* — how hard it is to state "correct" without reimplementing the
  code. Metamorphic and round-trip properties keep this low.

High-fit domains fall out immediately: **geometry, parsers, money, time, CRDTs,
and state machines.** These are the examples the docs and guide should lead with.

**Mutation-testing fit** (relevant because TProp's choice-buffer corpus can feed
a mutation tester later — see `ROADMAP.md`):

```
Mutation fit  ≈  (refactoring frequency × regression cost × oracle uncertainty)
                 / (suite runtime × equivalent-mutant rate)
```

The noteworthy observation: FCIS architecture moves code into the profitable
region of *both* predictors at once — pure, fast, invariant-rich functions are
simultaneously the best PBT subjects and the best mutation-testing subjects.

## Non-goals

- **ActiveRecord generation.** By design. The supported pattern is properties
  over value objects and over the persistence boundary's translation functions,
  not generation of AR instances with live associations.
- **A parallel runner.** pbt's Ractor-based parallelism is genuinely novel, but
  properties over pure value objects are fast enough that parallelism isn't the
  first bottleneck. TProp optimizes derivation and shrink quality first.
- **RSpec-first ergonomics.** Minitest integration ships first (matching the
  Sorbet-heavy demographic). The core `TProp.check` API is framework-agnostic;
  an RSpec adapter is straightforward and can come later.
- **Stateful / model-based testing as a core 1.0 feature.** Valuable, and the
  choice-sequence engine does not preclude it, but out of scope for 1.0. Note
  the one tractable form that *is* consistent with the design: replaying a
  generated operation sequence against an in-memory fake and a real
  implementation and asserting agreement is just a `forall` the user writes
  themselves — no model runner in core required. (See the deferred
  `assert_stateful` in the roadmap for the ergonomic sugar over this.)
