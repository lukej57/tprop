# TProp: Motivating Experiments

Designed demonstrations that turn TProp's arguments into measurements. These are
*specs to run once the engine works* (see `ROADMAP.md`), not results — the
numbers below are stated expectations, flagged as such, not data. The point of
writing them now is to fix the experiment design and, crucially, the *metric*,
before there's any temptation to cherry-pick.

## Experiment 1: the slow Rails test vs. the property test

### The claim

A slow, database-backed example test refactored to run as a property test over
`T::Struct` value objects is not merely faster — it explores far more of the
input space in far less time, and finds boundary bugs the original never could.
This is the empirical demonstration of the argument in
[`RATIONALE.md`](RATIONALE.md), "Why property testing failed in Rails
specifically."

### Why "it's faster" is the wrong headline

Raw speed invites an unfair comparison and undersells the result. The honest
metric is **coverage per unit wall-clock**: distinct input shapes exercised per
second. The example test and the property test are not the same test run at two
speeds — they explore fundamentally different amounts of the space:

| | Example test over ActiveRecord | Property test over `T::Struct`s |
|---|---|---|
| Cost per case | a DB transaction: insert rows via factory, fire callbacks, roll back (~ms–tens of ms) | a pure function call (~µs) |
| Number of cases | a handful a human wrote | hundreds to hundreds of thousands, generated |
| Which cases | shapes a human thought of | boundaries, empties, degenerate shapes, plus shrinking |
| Determinism | leaks state between runs (DB sequences, leftover rows) | pure; same seed → same run |

Speed and coverage **compound**: each case being ~1000× cheaper is *why* you can
afford ~1000× more of them. That product is the number to report.

### Design

Reuse the flagship domain ([`examples/roster`](../examples/roster)) so the
before/after is directly comparable and the reader already knows the code.

**Before (the slow test).** A Rails-flavoured test of shift merging that:

- defines an ActiveRecord `Shift` model backed by a real (SQLite/Postgres) table;
- uses a factory/fixture helper to create a handful of hand-picked rosters
  (the 5–15 cases a developer would actually write);
- reconstructs intervals from rows and asserts the merge is correct.

It is slow (a transaction per case), few-cased, non-deterministic under leftover
state, and — the crux — its hand-picked fixtures do **not** include the
treacherous shapes.

**After (the property test).** Already half-written and living (skipped) in
[`test/examples/roster_property_test.rb`](../test/examples/roster_property_test.rb):

```ruby
assert_property(Roster) do |r|
  once = IntervalOps.merge(r.shifts)
  assert_equal once, IntervalOps.merge(once)   # + the other invariants
end
```

No DB, no factory, no fixtures — `Roster.props` is the generator.

**The planted bug.** Introduce one realistic boundary bug into `merge`/`overlap?`
— e.g. use `<=` where `<` belongs, so touching shifts `[0, 5)` and `[5, 10)` are
treated as overlapping. The example test's fixtures sail past it; the property
test finds it and the shrinker reports the minimal counterexample.

### What to measure

Run both under a **fixed wall-clock budget** (say 1 second each) and report:

1. **Cases checked in the budget** — the headline. Expect ~10¹ for the DB test
   vs. ~10⁴–10⁵ for the property test.
2. **Latency per case** — DB transaction vs. pure call. Expect a 10²–10³× gap.
3. **Boundary bug found? (y/n)** — the categorical result that matters most:
   *no amount of extra speed helps a test that never generates the failing
   shape.* Expect the example test to miss it and the property test to catch it,
   with a one-line shrunk counterexample.

### Expected result (illustrative — not measured)

> In the ~300 ms the database-backed test spends verifying 10 hand-built
> rosters, TProp verifies on the order of 10,000 generated ones and reports the
> touching-boundary bug as `shifts = [[0, 5), [5, 10)]`. The example suite, run
> to completion, never exercises that shape and passes.

Report it as two bars (cases/second, log scale) with the bug-found result
annotated on each — the annotation is the part that lands.

### Honesty rules for a fair comparison

- **Assert the same thing on both sides.** The property is identical; only the
  input source and the subject's purity differ.
- **Don't count one-time setup as per-case cost** on either side; measure steady
  state.
- **Concede what the shell test still earns.** The integration test that proves
  the AR↔struct boundary actually persists and reloads correctly is not replaced
  by this — see the FCIS guide, "What to do with the shell." The claim is
  "property-test the core," not "delete your integration tests."
- **Use existing tooling** (`benchmark`/`benchmark-ips`) for timing. TProp ships
  no bespoke benchmarking; its own throughput number (examples/sec) comes from
  the planned health-checks / `collect` feature (`ROADMAP.md`, v1.x), not a
  separate timer.

### Status

Runnable once `Derive` + `TestingState` land. The "after" half already exists as
skipped tests in `examples/roster`; the "before" half and the measurement
harness are the work. This is a docs/marketing deliverable, adjacent to the
release, not a library feature.
