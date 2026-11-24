# Production Upgrade Report

_Commercial-grade upgrade of the existing Block Puzzle Game. Godot 4.7.2.
Baseline `76820a1` -> upgrade phases A-G._

## Milestones (committed)
| Phase | Commit | Summary |
|-------|--------|---------|
| A Audit | `100cdd3` | Baseline + `docs/PRODUCTION_UPGRADE_AUDIT.md` |
| B Visuals | `58f6715` | Design tokens, theme, rounded/beveled blocks, glowing gates, board tray, gradient bg |
| C Interaction | `74d8158` | Continuous finger-follow drag, collision feedback, settle easing |
| D Progression | `9e7b710` | Par + star ratings, level-select stars/current, menu indicator |
| E Level quality | `c466d70` | Audit tool + report; replaced trivial L6/L7; 0 flags |
| F FX/Perf | `9619e75` | Pooled styleboxes (alloc fix), win particles |
| G QA/Delivery | _this_ | On-device QA, this report, final APK |

## Implemented features
- Premium visuals: centralized design tokens (`style.gd`) + project theme
  (`main_theme.tres`); rounded/beveled blocks with highlight + contact shadow;
  rounded board tray with depth; framed gates with pulsing color glow; gradient bg.
- Continuous finger-follow dragging with grid-snap on release, axis lock, collision
  bump feedback, gate-pull vs resistance overshoot; deterministic logic preserved.
- Progression: per-level `par`, 1-3 star ratings (moves vs par), persisted; level
  select shows current + completed stars; menu current-level indicator.
- 100 original solver-verified levels; par on every level; weak levels replaced.
- Level editor (place/validate/save/test) and BFS solver retained + extended
  (`solve_min_moves`, difficulty grading).
- Audio: original generated SFX + music loop; haptics (VIBRATE granted); win particles.
- Monetization/analytics stubs (ads/IAP/analytics), disabled by default, no network.
- Reproducible Android build; local JSON persistence (progress incl. stars, settings,
  entitlements, custom level).

## Successfully tested (evidence)
- **Automated (headless, deterministic):** `test_rules` 10/10, `validate_all`
  **100/100 levels solvable**, `test_services` 7/7, `test_drag` 6/6 (continuous drag
  end-to-end incl. exit->win and undo-restore). All green on the final build.
- **Level audit:** `audit_levels.gd` -> 0 quality flags; par distribution 2-9 (intro L1=1).
- **On-device (Pixel AVD, Android ~API 37, software GPU):** see On-Device QA below.
- **Desktop renders:** menu, game, settings, level-select, editor all render correctly
  with the premium theme.

## On-Device QA (Phase G)
_Filled from the Phase G emulator run (screenshots under `build/android/qa_*.png`)._
- Install signed APK: PASS.
- Launch + engine init, no crash (logcat): PASS.
- Main menu -> Play -> Level 1 renders (premium board): PASS.
- Touch-drag solves the level; win popup + stars shown; no VIBRATE errors (fixed in QA): PASS.

## Partially implemented
- **Visual pass**: board/blocks/gates/menu fully restyled; level-select/settings/editor
  received the themed widgets but not bespoke art. Background gradient reads subtly.
- **Progression depth**: stars + unlock implemented; daily challenges, achievements,
  boosters, hints intentionally not added (evaluated as lower value for now).
- **Win celebration**: particles + star reveal present; no elaborate sequence.

## Known defects / limitations
- **FPS not reliably measured.** The `--script` FPS probe is invalid (returns ~1, a
  script-mode artifact). Allocation reduction is code-verified, but a true frame-rate
  profile requires a normal on-device run - not yet done. No performance target is
  claimed as met.
- **Safe-area / display-cutout** handling not implemented; HUD could overlap a notch
  on some devices.
- **Single emulator only** (software GPU); no physical hardware or multi-resolution
  matrix tested.
- **Editor interactive flows** lack automated UI tests (logic covered; UI manual).
- Level JSON serializes numbers as floats (`5.0`) after the par tool; harmless
  (loader int-casts), cosmetic cleanup pending.
- Build screenshots written under `build/` get imported into the APK (minor bloat);
  add a `build/.gdignore`.

## Deferred (future work)
- Real device-matrix QA + frame-rate profiling + safe-area insets.
- Bespoke art/font, block-face shader, richer background.
- Daily challenges / achievements / boosters if product wants them.
- Deeper difficulty model (branching factor, state-count metrics).

## Requires external credentials / approval (not enabled)
- Real ads (ad SDK + consent), real IAP (Play Billing + product IDs + store config),
  remote analytics (consent + privacy policy). All stubbed and OFF until configured
  and explicitly approved.
- Release keystore + Play Store listing for a production build.

## Definition-of-done status
Met: runs on Android; professional visual consistency; responsive dragging; satisfying
feedback; functioning menus/controls; saves/restores progress (incl. stars); coherent
difficulty curve; 100 solver-verified levels; automated suite passes; reproducible build;
English-only UI; original/open assets. **Not claimed:** full device compatibility,
measured performance targets, or store readiness - see Known defects / Deferred.
