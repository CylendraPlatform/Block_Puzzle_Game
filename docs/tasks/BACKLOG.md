# Prioritized Backlog

- **TD-3 [implemented, not device-accepted]** Playable v2 pilot, connected pieces, and precise gates. See `docs/tasks/CURRENT_TASK.md`. TD-4 is not started.
- **TD-2 [done]** Complete legal movement and Solver v2. Merged as PR #5.
- **TD-0 / TD-1 [done]** Versioned puzzle-state foundation. Historical evidence stays in `docs/tasks/CURRENT_TASK.md`.
- **BP-101 [P0]** Release-readiness QA and evidence. The previous ledger text is retained below so that history is not dropped.
- **BP-102 [P1]** Evaluate and polish gate-directed block exit animation, after user comparison.
- **BP-103 [P1]** Playtest difficulty and onboarding; revise levels with solver verification.
- **BP-104 [P1]** Safe-area and multi-resolution layout QA.
- **BP-105 [P1]** Reliable mobile FPS and frame-time profiling, including low-end hardware.
- **BP-106 [P1]** Clean-checkout Android export/preset and tracked build automation.
- **BP-107 [P2]** Evaluate optional hints, boosters and daily challenges against playtest results.
- **BP-108 [P3]** Real ads/IAP/analytics, privacy disclosures and store release work; requires explicit authorization.

## BP-101 archival scope

Objective: make the current Godot puzzle game verifiably ready for a limited external Android beta, without speculative features or live monetization. Acceptance still includes a clean debug Android export, device gesture/undo/pause checks, frame-time measurement, exit animation, and level-curve playtests. Those items are not part of TD-0/TD-1. Baseline when that task was written: `main` at `71432387bbca5ed73d234bd0bb621a5812b38c70`.

Items are proposals, not promises or completed work.
