# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- Initial gem scaffolding: module structure, gemspec, Minitest integration
  surface, and planning docs under `docs/`.
- **Working choice-sequence engine**, ported from
  [minithesis](https://github.com/DRMacIver/minithesis) (© David R. MacIver,
  MPL-2.0):
  - `TestCase` choice recorder (overrun/invalid/valid/interesting, prefix
    replay).
  - `Gen` combinators (`map`/`bind`/`satisfying`) and primitives (`constant`,
    `integers`, `lists`, `nilable`, `one_of`, `tuples`, `strings`).
  - `TestingState` runner + four-pass shrinker under shortlex order.
  - `TProp.check(gen:)` and Minitest `for_all` / `assert_property` with F-not-E
    reporting, `--seed` reuse, and failures carrying the reproducing choice
    sequence.
  - Shrink-quality regression anchors (`test/tprop/engine_test.rb`).
- Flagship worked example under `examples/roster`; motivating experiment spec
  under `docs/EXPERIMENTS.md`.
- **`Derive` — the `T::Struct` → generator walk**, validated against real
  `sorbet-runtime`. Recurses over `Simple` (primitives, nested structs, enums),
  union nodes (`T::Types::Union` and the `SimplePairUnion` behind
  `T.nilable`/`T::Boolean`), `TypedArray`, `TypedHash`, `TypedSet`,
  `FixedArray`. `assert_property(StructClass)` and `overrides:` now work.
- **Zero-anchored `Gen.integers`** — ranges spanning zero shrink toward `0` and
  reach negatives.
- **`StructuralEquality` mixin** — value `==`/`eql?`/`hash` over `.props`.
- The `examples/roster` property tests now execute (no longer skipped),
  including a test that asserts TProp *falsifies* the tempting "merge preserves
  total hours" property and shrinks to a minimal overlapping roster.

### Still stubbed (raise `NotImplementedError`)

- The `Registry`/`TypeRegistry` tiers (`register_type`, declaration-site hints),
  the example database, recursion cycle detection, and `Gen.floats` (the public
  primitive; `Derive` uses an internal naive float). See `docs/ROADMAP.md`.
