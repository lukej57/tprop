# Architecting for Testability: Functional Core, Imperative Shell

*A companion guide to TProp.*

This guide is not really about TProp's API. It is about the code you point TProp
*at*. TProp's value scales almost linearly with how much of your logic lives in
pure functions over immutable values — so learning this architecture is learning
how to make the tool pay off. Skip it, and the likely outcome is: you install
TProp, point it at code entangled with the database and the clock, watch it
produce flaky or un-shrinkable failures, and conclude that "property testing
doesn't fit real apps." This guide exists to prevent that specific
disappointment.

## 1. Why purity is what PBT *needs*, not just what it prefers

Every capability TProp offers depends on the property being a pure, fast,
deterministic function of its input:

- **Shrinking** re-runs the property hundreds of times against progressively
  smaller inputs and assumes each run reproduces the same result for the same
  input. A function that reads the wall clock, hits the network, or mutates
  shared state violates that assumption — a shrink step can change behavior for
  reasons unrelated to the input, and the shrinker either stalls or "minimizes"
  to nonsense.
- **Replay from the example database** assumes the same input reproduces the
  same failure tomorrow. Impurity breaks it the same way.
- **Running thousands of examples** assumes each run is cheap and free of side
  effects. A database round-trip per example is both slow and, because state
  leaks between runs, non-deterministic.

So the functional core is not merely "easier to test." It is *the only region
where TProp's guarantees hold cleanly.* The imperative shell is precisely the
set of things that would sabotage them. That reframing matters: moving logic
across the boundary is not a matter of taste, it is what makes the guarantees
true.

## 2. The boundary is decisions vs. effects, not computation vs. I/O

The most common way this architecture is taught wrong is as "computation vs.
I/O," which invites you to pull only trivial helpers into the core and leave the
interesting branching logic in the shell — inside the ActiveRecord callback,
tangled with the save. Then TProp can't reach anything that matters.

The real split is **decisions vs. effects:**

- The **core decides.** It takes data in, and returns a *description of what
  should happen* — as data. It performs nothing.
- The **shell performs.** It is dumb. It takes the description the core returned
  and carries it out against the real world.

Concretely, a core function does not send the email; it returns a value that
*says* "an email should be sent, to here, with this body." The shell receives
that value and sends it.

```ruby
# CORE — pure. Decides. Returns effects as values.
sig { params(state: SubState, event: SubEvent).returns([SubState, T::Array[Effect]]) }
def step(state, event)
  # ...pure branching on state and event...
  [new_state, [Effect::SendReceipt.new(to: state.email, amount: charge.amount)]]
end

# SHELL — impure. Performs. Contains no decisions.
def handle(event)
  new_state, effects = Domain.step(@state, event)   # decide
  @state = new_state
  effects.each { |e| perform(e) }                   # perform
end
```

This "return effects as values" move is the verb-side counterpart to value
objects. Value objects reify the *nouns* the core reasons about; effects-as-
values reify the *verbs* it would otherwise perform. Both have to be values
before the shell can go thin.

### The quiet bonus: this dissolves most "stateful testing" needs

A lot of logic that *feels* like it needs a stateful test harness is really a
pure state transition wearing a mutable costume. If `step` returns the next
state as a value, you can property-test the transition — and whole *traces* of
transitions, by folding a generated `T::Array[SubEvent]` through `step` — without
ever building a model of a mutable system. You generate the event list, fold it,
and assert an invariant on the result. That is why a design built this way gets
the coverage people reach for model-based testing to get, while staying pure.

## 3. Model your domain as `T::Struct`s so the core is TProp-shaped

FCIS pushes you toward modeling the domain as plain data flowing through
transformations. In Ruby + Sorbet, that data is `T::Struct`s. This is the
happy coincidence that makes TProp nearly free: **the shape FCIS wants you to
produce is exactly the shape TProp generates for free.** Design your core as
`T::Struct -> T::Struct` (or `[state, event] -> [state, effects]`) and the
generators are already written — they're your type declarations.

The load-bearing properties of a good value object (all three, not just
immutability):

1. **Value equality** — equal by contents, not identity. (`T::Struct` lacks
   this by default; use `TProp::StructuralEquality`.)
2. **No external identity** — it isn't a row with a primary key.
3. **Closure under its own data** — it holds no hidden pointers into world-state
   (no live association, no injected service, no lazy DB handle). It means what
   it says entirely in its own fields.

That third property is the one that does double duty. It is what makes the
object a *safe argument to a pure function*, and it is the exact same property
that makes it *generatable*. Which gives the whole architecture a mechanical
test:

> **A dependency is well-factored exactly when its test double can be
> generated.** If you can't write a TProp generator for the fake, the seam is in
> the wrong place.

## 4. The property vocabulary a pure core unlocks

Most developers can install a PBT library and then stall at "what property do I
even assert?" A pure core makes a small, reusable vocabulary available. Each is
awkward-to-impossible against impure code:

- **Round-trip:** `decode(encode(x)) == x`. Serialization, parsing, the
  AR↔struct boundary. The highest-value starting property because the oracle is
  free.
- **Invariant preservation:** some predicate is true of the output whenever it's
  true of the input (a fold over a trace keeps `balance >= 0`).
- **Idempotence:** `f(f(x)) == f(x)`. Normalizers, dedup, redelivery of an event.
- **Commutativity / order-independence:** `f(a, b) == f(b, a)`, or applying
  operations in any order lands in the same place (CRDTs, merges).
- **Metamorphic / differential:** you can't state "correct" directly, but you
  can relate two runs — an old and a refactored `step` must agree on every
  generated trace; a slow reference and a fast implementation must match.

Teach each one with a small, real example over a `T::Struct`. The example is
what unblocks people, far more than the API reference.

## 5. What to do with the shell, and where PBT stops

The shell still needs tests — just not property tests. It gets a small number of
integration/contract tests verifying that it wires the core to the real world
correctly: that the effect the core described actually gets performed, that the
row actually persists, that the boundary translation is hooked up. These are
few, because the shell contains no decisions to explore.

And it is worth saying plainly where PBT stops being the right tool: the shell's
job — actual I/O, actual persistence, actual delivery — is not a property
subject, and no amount of generator cleverness changes that. The honest pitch is
not "property-test everything." It is "grow a core worth property-testing, test
*that* exhaustively, and test the thin shell conventionally."

## 6. The Ruby-specific friction (and a suggested worked refactor)

The ambient Rails culture fights this architecture at every turn: ActiveRecord
everywhere, callbacks that fire effects on save, `Time.now` sprinkled through
domain logic, "service objects" that both decide and persist in the same method.
A guide that stays abstract will read as academic. The persuasive version shows
a *before/after* on idiomatic, Rails-ish code:

- **Before:** a service object that loads records, branches on their state, does
  arithmetic, writes back, and enqueues a mailer — all in one method. Show a test
  for it that is slow, hits the DB, and is flaky under a frozen-clock edge case.
- **After:** extract the state and inputs into `T::Struct`s; move the branching
  and arithmetic into a pure `step`/`decide` that returns `[new_state, effects]`;
  leave a shell that loads, calls the core, persists, and performs. Now show the
  property tests appearing *as the core emerges* — round-trip on the structs,
  an invariant over a generated trace, no-double-charge over the effect list —
  none of which were expressible before.

Injected collaborators the core needs (clock, repository) follow the same rule
as everything else: they are well-factored when their test double is a value you
can generate. An injected clock becomes a generated time-advance event; a
repository behind an `interface!` with an in-memory, struct-backed implementation
becomes a generated *world*.

---

### Suggested form for this resource

Two credible shapes, and they're worth building differently:

1. **A written guide / tutorial series** shipped with the docs — the structure
   above, each section standing alone as a post, collected with connective
   tissue. Cheaper to produce; good reference.
2. **A companion example repository** — one small Ruby/Sorbet app refactored
   from entangled to FCIS in commits, with the property tests appearing as the
   core emerges. More work, but the more persuasive teaching tool for *this*
   idea specifically, because the payoff (tests you couldn't write before) is
   shown rather than asserted.

A natural full-length treatment is a short book built around one evolving state
machine — Part I "the shape of the thing" (the `step` pattern, first property,
effects-as-values), Part II "the invariant ladder" (generating reachable and
unreachable states, guided traces), Part III "the machine meets the world"
(time, the persistence boundary, semantic generation, and a taste of the
fuzzing future). Each chapter earns one new idea against the same running
example.
