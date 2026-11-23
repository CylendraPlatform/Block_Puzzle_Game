# Development Plan

Milestones, each committed with verification. Status reflects the repository.

## Done
| # | Milestone | Acceptance | Status |
|---|-----------|-----------|--------|
| 0 | Repo + environment audit | Toolchain verified, blockers listed | done (2114daf) |
| 1 | Reference behavior spec | Verified vs assumed, no proprietary assets | done (2114daf) |
| 2 | Engine setup (Godot 4.7.2) | Headless boot + signed debug APK | done (288257a) |
| 3 | Core gameplay | Grid/blocks/gates, drag-slide, matching exits, solver | done (bb8e091) |
| 4 | UX + audio | Menus, settings, pause, original SFX/music, haptics, polish | done (8b36132) |
| 5 | 100 levels + editor | 100 solver-verified levels; editor validate/save/test | done (1473bc4) |
| 6 | Monetization + analytics stubs | Ads/IAP/analytics interfaces, off by default | done (28fc6b8) |
| 7 | Design docs + QA | This doc set; headless + on-device QA pass | this milestone |

## Acceptance criteria met
- Responsive touch-drag with grid movement and solid collision.
- Matching-color exits; win detection.
- Smooth animations/easing + feedback.
- Level progression + local save.
- Undo, restart, pause, settings.
- Main menu, level select, win screen.
- Sound effects + optional music.
- Level editor + automatic solvability validation.
- 100 original verified-solvable levels.
- Configurable difficulty progression (generator tiers).
- Rewarded-ad + IAP + analytics behind testable interfaces (disabled).
- Android build config + reproducible instructions + APK.

## Remaining / future work
- **Difficulty-config knobs** exposed as data (tune generator tiers without code).
- **Narrower, hand-authored gates** for more varied puzzles (editor supports it).
- **Block gimmicks** (ice, locks, keys, multi-color) - optional content.
- **Real providers** behind the stub interfaces (AdMob, Play Billing, remote
  analytics) - each requires SDK integration, consent flow, privacy policy, and
  explicit approval.
- **Broader device matrix** testing (one emulator covered so far; see TEST_PLAN).
- **Release signing** + Play Store listing assets.

## Not production-ready yet - honest gaps
- Tested on a single emulator (Pixel, API ~37, software GPU), not physical hardware
  or multiple screen sizes.
- No automated UI/integration test for the editor's interactive flows (logic is
  covered; UI is manually verified).
- Performance/frame-rate not profiled on low-end hardware.
