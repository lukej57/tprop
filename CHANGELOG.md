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

### Still stubbed (raise `NotImplementedError`)

- `Derive` (the `T::Struct` → generator walk — next task), the
  `Registry`/`TypeRegistry` tiers, `StructuralEquality`, `Gen.floats`, and the
  example database. See `docs/ROADMAP.md`.
