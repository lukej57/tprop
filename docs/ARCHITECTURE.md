# TProp: Architecture

This is the technical design of the engine. It is the reference for anyone
working on the library internals. The one decision everything else hangs off is
the **choice-sequence representation**, so it comes first.

> **Implementation status.** The engine (`TestCase`/`Gen`/`TestingState`),
> `Derive`, `StructuralEquality`, and the example database are implemented. The
> five-tier resolution's middle tiers (the registries) are not yet — see the
> notes inline and `ROADMAP.md` for the authoritative status.

## The foundational decision: a choice sequence, not values

Every source of randomness in a TProp run flows through a single method that
records an integer into a growing sequence:

```
TestCase#choice(n) -> Integer in 0..n   # records the drawn integer
```

Generators never see a raw RNG. They see a `TestCase` and pull integers from it
via `choice`. A generator is therefore a pure function from a choice sequence to
a value. This is the minithesis / Hypothesis "Conjecture" architecture, and it
buys three properties *for every generator at once*, including user-written and
type-derived ones:

1. **Shrinking is free and universal.** The shrinker minimizes the integer
   sequence, not the values. Because all generators read the same sequence, one
   shrinker shrinks everything — no per-type shrink function, ever.
2. **Replay is trivial.** A failing example is just its integer sequence.
   Serialize it, store it, replay it later, embed it for reproduction.
3. **Invariants are preserved under shrinking.** A generator constrained to (say)
   even integers still produces even integers when re-run against a smaller
   sequence, because the *generator* runs again — the constraint is never
   bypassed the way an external, value-level shrinker would bypass it.

> Design heuristic to preserve everywhere: structure generators so that
> **all-zeros is the simplest value.** The shrinker drives choices toward 0 and
> sequences toward shorter, so "0 / empty / nil / \"\"" should fall out of a
> zeroed choice sequence. Lists especially: draw a continue-flag then an element
> (`[flag, elem, flag, elem, …, stop]`) rather than drawing a length up front,
> so that deleting a span of the sequence deletes list elements and shrinking
> composes with structure.

### `TestCase`

Holds the choice sequence, an optional prefix (for replay/shrinking), an
optional RNG (absent during pure replay), and a status. `choice(n)`:

- If we're still inside a supplied prefix, replay that value; otherwise draw
  fresh from the RNG.
- If the sequence exceeds the size cap, mark the case **overrun**.
- If a replayed/drawn value exceeds the requested bound `n`, mark the case
  **invalid** — this is what keeps shrunk sequences coherent instead of feeding
  generators out-of-range integers and crashing them.

A `TestCase` can also be marked interesting after the fact (e.g. when the
property raised), via an explicit finalizer rather than an `instance_variable`
hack.

### `TestingState` (the runner + shrinker)

Runs the property up to `max_examples` times and, on a failing (interesting)
case, runs shrink passes to a fixed point under a **shortlex total order**
(shorter sequences first; ties broken lexicographically). The shrink passes, in
order:

1. **Chunk deletion** with a length-nudge — delete contiguous runs of choices
   (this is what collapses list length and structural size).
2. **Block zeroing** — set spans of choices to zero (collapses values toward
   their simplest).
3. **Per-choice binary search** — minimize each individual integer.
4. **Sort / redistribute** — sort out-of-order ranges of choices, and swap and
   rebalance adjacent pairs (helps properties that depend on a sum). These are
   lexicographic tidy-ups.

Each candidate is accepted only if it is still interesting *and* strictly
smaller under shortlex. The acceptance test (`TestingState.shortlex_smaller?`)
compares `[length, choices]` with `<=>`, **not** `<` — an `Array` comparison
with `<` was a historical bug here, so keep those tests sharp.

The shrink-time cache (minithesis's `CachedTestFunction`, which memoizes
choice-sequence → status) is a deferred optimization; the current shrinker
re-runs the property directly. Correct, just not maximally fast.

## The generator layer: `Gen`

A `Gen` (a "Possibility" in minithesis terms) is a named recipe that turns a
`TestCase` into a value. Composition:

- `map { |v| ... }` — transform the produced value.
- `bind { |v| other_gen }` — sequence a dependent generator. Works across the
  choice sequence, so shrinking still composes (this is the case that defeats
  Hedgehog-style integrated shrinking; here it is a non-issue because both
  generators read the same underlying sequence).
- `satisfying(max_tries:) { |v| pred }` — filter; rejects the case (not crash)
  if no candidate passes within the try budget.

Primitives (all shrinking toward the simplest value):

- `constant(v)`
- `integers(range | min:/max:)` — anchored at the in-range point nearest zero so
  shrinking lands there. Ranges spanning zero draw a magnitude then a sign, so
  both signs are reachable while all-zeros still decodes to `0`.
- `strings`, `lists`, `nilable`, `one_of`, `tuples`, and the rest of the usual kit.

`Gen.floats` is **not yet implemented** as a public primitive (it raises):
predictable float shrinking wants care — toward simple values like 0.0 and small
integers-as-floats, not toward bit-pattern neighbors. `Derive` generates floats
from an internal naive combinator (integer part + hundredths, shrinking to 0.0)
in the meantime.

## The derivation layer: `Derive`

`Derive.for_struct(StructClass, overrides:)` walks `StructClass.props` (reading
each prop's `:type_object`), and for each prop calls `Derive.for_type(type)`,
which does structural recursion over the reified type tree: `Simple` (dispatched
on `.raw_type` to a primitive, a nested `T::Struct` (recurse), or a `T::Enum`
subclass (choose among its values)), `TypedArray`, `TypedHash`, `TypedSet`,
`FixedArray`, and union nodes. The composed `Gen` produces a fully populated
struct instance via keyword args.

A validation note worth recording (this is why the roadmap insisted on grounding
against real `sorbet-runtime`): `T.nilable(X)` and `T::Boolean` do **not** reify
as `T::Types::Union` — they are `T::Private::Types::SimplePairUnion`. So unions
are matched by duck-typing `.types` rather than a class name, which covers both.
Union members are ordered so `NilClass` comes first, so nilables shrink to `nil`.

Known gaps to close (see roadmap): **recursion cycle detection** for self- or
mutually-referential structs — currently `Derive` tracks the build stack and
raises a clear error on a cycle rather than recursing unboundedly, but does not
yet *generate* finite values for them. `sorbet-schema`'s type walk is useful
*reference* code for the edge cases — not a dependency, since TProp owns this
traversal, but a good check against a second implementation.

## Generator resolution: the five tiers

> **Status:** tiers 1 (structural) and 5 (call-site overrides) are implemented.
> Tiers 2–4 depend on the registries, which are still stubs (`register`,
> `register_type`, `reset_registry!` raise `NotImplementedError`). The design
> below is the plan for the middle tiers.

When `Derive` needs a generator for a type or prop, it resolves in this order,
each tier overriding the ones above it:

1. **Structural derivation** — the default, from the reified type alone.
2. **Type-keyed registration** — `TProp.register_type(Money) { ... }`. Hooked
   *inside* `Derive.for_type`, not the prop loop, so it applies at every nesting
   depth: any `Money` prop, even three structs deep, picks it up. This tier is
   what promotes whole domains (and, later, whole *interfaces* — generatable
   fakes for injected dependencies) to first-class subjects.
3. **Built-in hints** — TProp's own sensible refinements (e.g. a well-known
   symbol vocabulary).
4. **User hints** — declaration-site metadata via Sorbet's `extra:` slot, e.g.
   `const :age, Integer, extra: { tprop: :adult_age }` or a range. Symbol-preferred
   form keeps production code free of literal TProp references; the symbol is
   resolved through the registry.
5. **Call-site overrides** — the `overrides:` kwarg on `assert_property` /
   `TProp.check`, for one-off targeted campaigns ("only dunning-phase traces").

Two registries back this: a **symbol-keyed `Registry`** (hints) and a
**type-keyed `TypeRegistry`** (registrations, matched by walking the class's
ancestors). Both are layered: user entries shadow built-ins, and
`reset_registry!` drops user state without disturbing built-ins — important for
test isolation of TProp itself and of suites that register generators.

## Public API surface (current)

```ruby
# Framework-agnostic:
TProp.check(StructClass, overrides:, max_examples:, seed:, database:, key:) { |value| ... }
TProp.check(gen: some_gen, ...) { |value| ... }

# Minitest integration (mixed into your test class):
assert_property(StructClass, overrides:, max_examples:, seed:) { |value| ... }
for_all(gen_a, gen_b, ...) { |a, b, ...| ... }
```

Minitest integration reuses Minitest's `--seed` so `-s 12345` reproduces a
property run, and converts a `TProp::PropertyFailure` into a
`Minitest::Assertion` (reported as F, not E) while preserving the shrunk
counterexample's backtrace.

## The example database

Persists the shrunk failing choice sequence per property, so the next run
replays it first — the reproducibility job, and the corpus substrate the
fuzzing horizon reuses. A database is any object exposing `db[key]` (→
`Array<Integer>` or nil), `db[key] = choices`, and `db.delete(key)`. Two ship:
`TProp::MemoryDatabase` and `TProp::FileDatabase` (one JSON file per key under
`.tprop-cache/`; corrupt entries are treated as absent, never fatal).

`TProp.check` persists only when given both `database:` and `key:` — no
surprise file-writes from the low-level API. The Minitest integration opts in
automatically, keyed by `"Class#method"`, using the configurable
`TProp.default_database`. The flow: a stored example replays first (via
`TestingState#replay`); if it still fails it seeds the result and is then
*re-shrunk* (so a stale-but-failing example adapts to code changes); a passing
run clears the entry.

## Companion value-object support

`T::Struct` lacks structural equality, which does not affect the engine (the
choice-sequence machinery never compares struct instances) but does bite the
*equational properties users write* — round-trips, algebraic laws, any
`f(x) == y`. TProp therefore ships:

- **`TProp::StructuralEquality`** — a mixin implementing `==`, `eql?`, and
  `hash` by walking `.props` in declaration order. Deliberate decisions: the
  comparison helper is `protected` (so `==` can call it on `other`), matching is
  exact-class (not `is_a?`, to keep `==` symmetric), and nested-struct recursion
  is delegated to Ruby's built-in container equality rather than hand-rolled.
- **`TProp.assert_prop_equal`** (planned) — an equality assertion with float
  tolerance, for properties over structs containing floats.
