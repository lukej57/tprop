# TProp: Rationale

## The puzzle this library answers

Property-based testing is thirty years old, has an unambiguous track record of
finding bugs that example tests miss, and has essentially zero adoption in
Ruby. That is not because Ruby programmers don't know about it — Rantly,
PropCheck, theft, and pbt all exist. It is because in every prior Ruby PBT
library, the price of admission for each property is hand-writing a generator
that restates the shape of your data. The generator is a shadow type system: it
re-encodes facts about your domain in a parallel notation, it drifts silently
when the real definition changes, and writing it is often more work than the
example-based test it was meant to replace. Rational engineers decline, and
have declined for a decade.

TProp's founding observation is that in a Sorbet codebase, that price has
already been paid. A `T::Struct` declaration is a machine-readable schema:
every prop carries a reified runtime type object, recursively, including
generics (`T::Array[Symbol]`), unions (`T.any`), nilability (`T.nilable`),
enums (`T::Enum`), and nested structs. `User.props` is the generator, waiting
to be interpreted.

```ruby
assert_property(User) do |user|
  assert_equal user, User.from_hash(user.serialize)
end
```

## The governing principle

> **Custom-generator effort is proportional to the semantic distance between
> your types and your invariants.**

In untyped Ruby that distance is total: every generator is written by hand
(this is pbt's world). In a refinement-typed language it approaches zero.
Sorbet sits in between: `Integer` derives a working generator but
over-approximates a field that means "age." TProp's job is to make the common
case (the distance is small) free, and the uncommon case (the distance is real
— "age is 2..120", "this string is an ISO country code") cheap and local, via
hints and registries rather than wholesale generator rewrites.

## Why property testing failed in Rails specifically

The failure of PBT in Rails was never just a tooling gap. A better generator
library pointed at `app/models` would still have nothing good to aim at,
because idiomatic Rails couples domain logic directly to ActiveRecord models,
and AR models are close to the worst possible property subjects:

- **No purity.** Attribute access can trigger queries; callbacks fire mail and
  enqueue jobs; `==` is identity/primary-key based, not structural. The
  "describable input space" a generator needs doesn't exist independently — it
  is entangled with world-state.
- **Evaluation has side effects.** Shrinking re-executes the property hundreds
  of times against mutated inputs. If evaluation touches the database, that
  becomes both slow and non-deterministic — DB sequences and leftover rows leak
  between executions, so the same input stops reproducing the same result, and
  shrinking (and replay) quietly break.
- **The types are schema types, not domain types.** `varchar` and `int4` sit at
  maximal semantic distance from the invariants you actually want to assert.

The subjects PBT wants — pure functions over immutable values — are exactly
what idiomatic Rails declines to separate out.

## The stance TProp takes, deliberately

TProp targets the **functional-core / imperative-shell** architecture that
Sorbet-heavy codebases already trend toward: `T::Struct` value objects carrying
domain data and invariants, with ActiveRecord demoted to a persistence
boundary. In that architecture:

- Value objects are pure, cheap, immutable, and (with a structural-equality
  mixin) structurally equal — ideal property subjects — and TProp derives their
  generators for free.
- The AR↔struct boundary itself becomes a property:
  `assert_property(PaymentIntent) { |p| PaymentIntent.from_row(p.to_row) == p }`.
- Domain logic (money arithmetic, state-machine transitions, fee calculation)
  is tested exhaustively without a database in the loop.

TProp does **not** try to make ActiveRecord property-testable, and treating that
as a non-goal is a feature. It keeps the library honest and small, and it turns
the library into an *incentive*: every struct you extract from a fat model
immediately earns free generative tests. The testing tool pays you to improve
the architecture. This also bounds the addressable audience honestly — TProp is
for codebases that have, or want, a typed value-object layer. That is the
positioning, not a limitation to apologize for.

## The unifying criterion

A single line ties together every architectural pattern TProp rewards —
value objects, effects-as-values, injected clocks, the repository pattern:

> **A dependency is well-factored exactly when its test double can be
> generated.**

This is sharper than "prefer dependency injection" because it is mechanical: if
you cannot write a TProp generator for the fake, the seam is in the wrong place.
The property that makes an object a safe argument to a pure function —
*closure under its own data*, meaning it holds no hidden pointers into
world-state — is the exact property that makes it generable. So converting an
entity into a value object simultaneously shrinks the shell, grows the core, and
earns free tests. Three-way alignment on one refactor.

Two honesty checks worth keeping in the framing:

1. **Value objects are necessary but not sufficient.** They purify the *data
   plane* — the nouns the core reasons about. The *effect plane* — the verbs —
   needs the other half: effects-as-values, so the core can *decide* an I/O
   without *performing* it. Nouns and verbs both have to be reified as values
   before the shell can stay thin.
2. **The enabling is conditional on the logic actually migrating.** You can have
   anemic value objects — data bags with the behavior still stranded in the
   shell — and get none of the benefit. The value object is the substrate that
   *permits* the core; it does not constitute it. (Note: "anemic" here names the
   failure of logic to migrate, not the mere fact of passive data carriers,
   which are idiomatic and fine in a functional-leaning design.)

## Much of the wedge is pedagogy, not API

The trace-fold pattern, the effect recorder, and the invariant ladder
(example → trace property → inductive invariant → guided stateful runs) are all
expressible with 1.0 primitives. What is missing in the ecosystem is anyone
showing Ruby programmers the pattern end to end. A worked guide — see
[`guides/functional-core-imperative-shell.md`](guides/functional-core-imperative-shell.md)
— is a deliverable on equal footing with the library, and likely the sharpest
adoption wedge: "property-test your state machines" is a concrete, felt pain,
where "do PBT" is an abstraction.
