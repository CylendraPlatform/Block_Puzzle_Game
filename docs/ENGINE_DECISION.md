# Phase 2 (preview) — Engine Evaluation & Recommendation

Decision needed from you before Phase 3. Nothing is installed yet.

## Candidates

### Option A — Godot 4 (GDScript), 2D  — recommended if an install is OK
- **Fit:** 2D-first engine; grid puzzles, drag input, tweens/easing, particles, and audio are first-class. Ideal match for this game's feel.
- **Build:** Exports an Android APK/AAB using the **already-installed** SDK (35/36) + NDK 27. No Unity-style licensing.
- **Footprint:** Editor ~120 MB + Android export templates ~1 GB (download). Small final APK (~30-50 MB).
- **Cost:** Free, open source (MIT). No account, no royalties.
- **Blocker:** requires installing the Godot editor + export templates (needs your OK).

### Option B — Native Android (Kotlin + Canvas/Compose)  — recommended if you want zero installs now
- **Fit:** Full control; a grid puzzle renders cleanly on a `SurfaceView`/Canvas or Compose. Slightly more hand-written animation/easing code than Godot.
- **Build:** Buildable **immediately** — toolchain already present (JDK 25, SDK, NDK, Gradle wrapper, adb, Pixel AVD). **No downloads, no blockers.**
- **Footprint:** Tiny APK (~5-10 MB).
- **Cost:** Free. Pure open tooling.

### Option C — Unity  — not recommended here
- Heavy (multi-GB Editor + Hub), requires a Unity account/license tier, and is overkill for a 2D grid puzzle. Longer iteration, larger APK. No advantage over A/B for this scope.

## Recommendation

- **Default pick: Godot 4** — best velocity and game-feel for the sliding-block mechanic, clean Android export on the existing SDK, no licensing. One-time install is the only cost.
- **If you'd rather not install anything: Native Kotlin** — we can start coding immediately; it reaches a buildable APK fastest with zero new downloads.

Unity is ruled out unless you specifically want it.

## What each path unlocks for the rest of the brief
- Level editor + solver (Phase 3 items 9-10): engine-agnostic — the solver/validator is plain code (Python or the engine's language) and portable either way.
- Ads/IAP/analytics interfaces (items 12-14): both paths get clean, testable stub interfaces; no live services until approved.
- Reproducible APK (item 15): both documented in `docs/BUILD.md` once the engine is chosen.
