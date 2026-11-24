# Cursor / Claude Code execution task — TD-3.5
**Status: NOT STARTED — design pack delivered only.**
**Working branch:** `feat/td35-premium-playful-visuals` (derived from PR #6). 
**Stacked PR base:** `feat/td3-geometry-gates-pilot` until parent PR #6 merges.
**Purpose:** implement visually coherent premium mobile game gameplay, menu and level-complete UI from the design system, with no new rules/monetization.

## Before code
Read `AGENTS.md`, `CLAUDE.md` (if present), `.cursor` instructions, runbooks, `docs/tasks/CURRENT_TASK.md`, `docs/tasks/TD-3_IMPLEMENTATION.md`, docs/design/TD35_*, and all v2 schema/solver contracts. Inspect current branch, working tree, stashes and parent PR; preserve work. Reconcile current task ledger before coding, without deleting historical TD-3 evidence. No direct commits to main or to PR #6.

## Execution
**Checkpoint 1:** Implement theme tokens, responsive SafeArea composition and centered board. Screenshot 1x5, 5x1, 5x5, 9x9 on 360x800 and 412x915. Share links/screens for review.
**Checkpoint 2:** Dynamic connected 2.5D polyomino renderer, correct physically open gate apertures, drag/hover/exit feedback. Verify L/T/S/Z silhouettes and gate spans. Test no change to PuzzleEngine.
**Checkpoint 3:** Fix one-swipe EXIT UX with an intentional preview threshold, retaining the ability to stop at last cell. Reproduce from interior, blocked exit, all directions, emulator near-system-edge touches. Automated tests and recordings.
**Checkpoint 4:** Menu and Level Complete native UI, original icon/vector sources, appropriate animations, no fake gold/stars. Reuse actual current state and dev-only pilot route.
**Checkpoint 5:** Automated + emulator + physical-device QA, evidence matrix, asset import check, performance measurement; polished debug APK for product-owner feedback.

## Scope fence
- Do not modify v1 100 level JSON or legacy progress.save, rules engine, solver legal semantics, TD-4 triggers, timers, purchases/ads integration or remote analytics.
- `build/android` debug QA APK, if published, must use test signing only and should not activate production features.
- New UI components must be genuine Godot scene/native vector/shader functionality, not screenshots with clickable hotspots.
- In-game user-facing strings English-only. Do not claim concept SVGs are complete high-fidelity render assets.
- Provide code changes, commit SHA, screenshots and recorded gesture evidence, test commands/exits, Godot import errors, and remaining differences from concept.

## Done gate
Do not mark complete until gameplay P0, menu/win P1, true source/asset QA, all baseline tests, AND owner visual sign-off. Android physical-device evidence is explicitly required for full product acceptance. Prepare PR against parent branch only; do not merge without owner approval.
