# Production Upgrade Audit

_Baseline commit: `76820a1`. Godot 4.7.2.stable. Date: 2026-11-23._
_Baseline tests (all green): rules 10/10, validate_all 100/100 solvable, services 7/7._

This audit assesses the existing functional game against a commercial "premium casual
puzzle" bar (Color Block Jam as a feel benchmark, not an asset source) and defines the
upgrade plan. It is an **upgrade, not a rewrite** - the core rules, solver, 100 levels,
and Android pipeline are sound and will be preserved.

## Doc/reality reconciliation
The README was updated in the prior milestone and now reflects the full implementation
(engine, gameplay, 100 levels, editor, stubs, docs). No contradictory docs remain; this
audit adds the upgrade layer.

## 1. Existing working systems (preserve)
- **Core rules** (`rules.gd`): grid slide, solid collision, matching-color exit, win -
  deterministic, unit-tested.
- **Solver** (`rules.gd`): BFS `solve` + `solve_min_moves` (difficulty signal, cost-capped).
- **Content**: 100 JSON levels, every one solver-verified (`validate_all` 0 failures).
- **Input**: touch/mouse drag with axis-lock, undo snapshots, restart (on-device verified).
- **Screens**: Main Menu, Level Select (lock/unlock), Settings (persisted), Pause overlay,
  win popup.
- **Editor**: place walls/blocks/gates, Validate (real solver), Save/Load, Test-play.
- **Audio**: 6 original generated WAVs + music loop; haptics (VIBRATE now granted).
- **Services**: Ads/IAP/Analytics stub autoloads (off by default, no SDK/network).
- **Build**: reproducible headless APK export; local JSON persistence.

## 2. Incomplete / shallow systems
- **Visual presentation**: flat dark rectangles; no depth, rounded premium styling,
  gradients, or shadows. Biggest gap vs the benchmark.
- **Exit / win feedback**: a scale-pop on exit and a plain "Level Complete!" panel; no
  particles, no celebratory motion, no juice.
- **Gates**: plain colored bars - no frame, glow, idle animation, or departure effect.
- **Level Select**: a plain number grid; no completed/star indicators, no level-map feel.
- **Progression depth**: linear unlock only - no stars/scoring, daily challenges,
  achievements, boosters, or hints.
- **Onboarding**: no explicit tutorial framing beyond easy early levels.
- **Shop**: only a stub "Remove Ads" row; no coin/booster store UI.

## 3. Bugs & technical risks
- **FIXED this milestone**: VIBRATE permission (haptics threw a caught SecurityException).
- **Drag model**: moves from the grab anchor recomputed each event - correct and
  deterministic, but not true finger-follow with continuous visual drag + squash/stretch.
  Upgrade target, not a bug.
- **Safe areas / display cutouts**: not handled; HUD could collide with notches.
- **Build hygiene**: QA screenshots were written under `build/` (inside the project), so
  Godot imported them into the APK (minor bloat). Add a `.gdignore` in `build/`.
- **Line endings**: LF->CRLF warnings on Windows (cosmetic; consider `.gitattributes`).
- **Single-slot editor save** (`custom_level.json`) - fine for now, not multi-level.

## 4. Visual & UX deficiencies
- Palette is functional but not "bright and welcoming"; board sits small and centered with
  large empty vertical space on tall screens (poor use of aspect ratio).
- No visual hierarchy/depth; blocks read as flat tiles, not physical objects.
- Default engine font/typography; no spacing/sizing design system.
- Selected-state is a slight lighten only; no illumination/lift.
- Win/pause panels are minimal engine `Panel`s, not styled components.

## 5. Level-design deficiencies
- Difficulty is graded only by **minimum solution length (1-9 moves)** - shallow. Three
  levels solve in 1 move (too trivial outside the very first tutorial slots).
- Generator uses **full-side gates per color** -> reliable but less interesting than
  narrow, placed gates; limited layout variety.
- No stored per-level **difficulty metrics** (branching factor, reachable-state count,
  solution diversity) - only implied by tier.
- No curated **tutorial arc**; onboarding relies on low block counts.
- Potential repetition/trivial layouts not yet audited per-level (Phase E).

## 6. Performance concerns
- **Not profiled.** `board_view` redraws per frame while blocks ease (acceptable), but FPS
  on real/low-end hardware is unmeasured. Only a software-GPU emulator has been used.
- Particle/shader budgets will need limits once juice is added.
- No allocation profiling during drag.

## 7. Recommended upgrade architecture
- **Design system**: centralize palette/typography/spacing/dimensions/timing in a `Theme`
  + a `Style` constants script; keep styling separate from rules (`VISUAL_DESIGN_SYSTEM.md`).
- **Blocks**: a reusable 2D shader (rounded corners, bevel/highlight, contact shadow) or
  a styled draw; selected-state illumination. Stay 2D/2.5D - no 3D migration unless measured.
- **Gates**: framed, glowing, idle-animated; satisfying departure effect + particles.
- **Board**: defined play area with soft depth; responsive sizing that fills tall screens
  (reduce dead space); safe-area aware.
- **Drag**: evolve to continuous finger-follow with grid snap on release, subtle
  squash/stretch and collision resistance, preserving deterministic logic + undo.
- **Levels**: richer difficulty model (metrics beyond min-moves), curated progression,
  narrow-gate variety; store metrics per level (`LEVEL_QUALITY_REPORT.md`).
- **Progression**: stars/ratings + level-map select; evaluate dailies/achievements by
  value, not count.
- **Analytics schema**: formalize the event set (`ANALYTICS_EVENT_SCHEMA.md`).

## 8. Prioritized implementation plan (maps to mission phases)
1. **Phase B - Premium visuals** (highest leverage): design tokens/theme; redesign blocks,
   gates, board, backgrounds, panels; responsive layout; baseline vs after screenshots.
2. **Phase C - Interaction feel**: continuous drag, collision feedback, exit/settle
   animation, squash/stretch; movement correctness + interruption tests.
3. **Phase D - UX & progression**: polished menu/HUD, win flow with juice, level-map select
   with stars; persisted progress.
4. **Phase E - Level quality**: per-level audit + metrics, replace weak/trivial levels,
   narrow-gate variety, keep 100 solver-verified; `LEVEL_QUALITY_REPORT.md`.
5. **Phase F - Audio/effects/perf**: refine SFX/haptics sync, controlled particles, profile
   FPS before/after, Android optimization, safe-area handling.
6. **Phase G - Final QA & delivery**: full test suite, on-device per-screen capture at
   multiple resolutions, fix blockers, `PRODUCTION_UPGRADE_REPORT.md`, final APK.

### Quality gates (each phase)
Automated tests stay green; `validate_all` stays 0 failures; at least one real build-render
(desktop + on-device where feasible) with screenshots; no claim of "done/performant" without
measurement.

### Context note
This is a large multi-phase effort. Work proceeds incrementally with a committed, verified
milestone per phase; visuals and interaction (B, C) are the highest-value first steps.
