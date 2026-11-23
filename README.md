# Block Puzzle Game

An **original** mobile sliding-block puzzle for Android, inspired by the gameplay *feel* of the color-matched-exit genre (e.g. Color Block Jam). Slide colored polyomino blocks around a grid and push each out through the matching-color gate. Original code, art, branding, and levels. English-only UI.

> Status: **Phase 0-1 complete** (audit + reference spec). Awaiting engine decision before Phase 3 coding.

## Documentation

- [`docs/AUDIT.md`](docs/AUDIT.md) — Phase 0 environment & repo audit, toolchain inventory, blockers.
- [`docs/REFERENCE_SPEC.md`](docs/REFERENCE_SPEC.md) — Phase 1 reference behavior spec (verified vs assumed).
- [`docs/ENGINE_DECISION.md`](docs/ENGINE_DECISION.md) — Godot vs Native Kotlin vs Unity, with recommendation.
- [`docs/BUILD.md`](docs/BUILD.md) — reproducible Android build steps.
- [`docs/MONETIZATION.md`](docs/MONETIZATION.md) — ads / IAP / analytics stub architecture + privacy stance.

## Design & process docs

- [`docs/GDD.md`](docs/GDD.md) — game design.
- [`docs/TECHNICAL_DESIGN.md`](docs/TECHNICAL_DESIGN.md) — architecture & implementation.
- [`docs/LEVEL_SYSTEM.md`](docs/LEVEL_SYSTEM.md) — level format, solver, generator, editor.
- [`docs/DEVELOPMENT_PLAN.md`](docs/DEVELOPMENT_PLAN.md) — milestones & acceptance.
- [`docs/TEST_PLAN.md`](docs/TEST_PLAN.md) — test strategy & QA results.
- [`CLAUDE.md`](CLAUDE.md) — repo development guide.

## Environment (verified 2026-11-23)

JDK 25, Android SDK (`D:\Android\Sdk`: platforms 35/36, build-tools up to 37, NDK 27), adb + `Pixel_10_Pro_XL` AVD, Node 22, Python 3.14. No game engine installed yet.

## Legal

No proprietary assets, source, audio, or level data from any third-party game are used. All content is original.
