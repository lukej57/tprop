# Worked example: roster / shift interval algebra

This is TProp's flagship example — the one the docs and guide lead with. It was
chosen deliberately, and the reasoning is worth stating because it is the same
reasoning a user should apply when deciding where to point TProp.

## Why this example

`docs/JOBS_TO_BE_DONE.md` gives a quantitative fit heuristic:

```
PBT fit ≈ (property density × input-space treachery) / oracle cost
```

Geometry is the textbook high-fit domain — but it doesn't *resonate* with a
workforce/rostering audience, and resonance and fit are different axes. Time
intervals resolve the tension: **a time interval is one-dimensional geometry**,
so it scores just as high on the heuristic, while being a shift on a roster —
something you actually build.

- **Property density (high).** Merging shifts is idempotent; the merged cover is
  sorted and disjoint; coverage is order-independent and bounded by the naive
  total; intersection is commutative; serialization round-trips. Real algebra,
  not contrived.
- **Input-space treachery (high).** The bugs hide exactly where humans don't
  look: shifts that *touch* but don't overlap (`[0, 5)` vs `[5, 10)`), zero-length
  shifts (`[3, 3)`), one shift fully containing another, and — once you model a
  wall clock — the midnight/DST wraparound. A generator walks straight into all
  of them.
- **Oracle cost (low).** Every property here is metamorphic or a round-trip, so
  "what's the correct answer?" never requires reimplementing the code.

## The files

| File | What it is |
|---|---|
| `interval.rb` | The domain as `T::Struct`s: `Interval` (a half-open shift) and `Roster` (a bag of shifts). `Roster.props` **is** the generator. |
| `interval_ops.rb` | The functional core: pure, total functions (`merge`, `coverage`, `intersect`, …). No clock, no DB — the region where TProp's guarantees hold. |
| `../../test/examples/roster_core_test.rb` | Executing, example-based tests that prove the core actually works today. |
| `../../test/examples/roster_property_test.rb` | The property tests — the API north star. `skip`ped until the engine lands; unskip to run. |

## The one line that sells it

The property test names only the struct. The nested `T::Array[Interval]`
generator is derived — nothing is written by hand:

```ruby
assert_property(Roster) do |r|
  once = IntervalOps.merge(r.shifts)
  assert_equal once, IntervalOps.merge(once)   # merge is idempotent
end
```

## The teaching centerpiece: a tempting property that's false

It is very natural to assume that merging shifts preserves total hours. It does
not — overlaps get counted once after merging. `roster_property_test.rb`
includes that false property on purpose. When the engine lands, it fails, and
the shrinker hands back the *minimal* counterexample:

```
shifts = [ [0, 2), [1, 3) ]   # total 4 minutes, but coverage is only 3
```

Two shifts overlapping by a single minute. That minimal example — not a random
100-shift roster — is the entire value proposition in one line: a failing
random example is noise; a shrunk one is a bug report.

## What to model next (the treachery you'd add)

`start_min`/`end_min` are "minutes from a reference", which sidesteps
midnight wraparound. Modelling a real wall clock — where a shift can run
22:00→02:00 and `start > end` is legal — is the natural next chapter, and a
perfect showcase of input-space treachery: the generator produces the wrapping
shifts a human reviewer forgets, and the properties (does coverage still add
up across midnight?) immediately put pressure on the logic.
