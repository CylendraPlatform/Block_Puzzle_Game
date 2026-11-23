# Phase 1 — Reference Behavior Specification

_Subject: Color Block Jam (Rollic Games), analyzed as a genre reference for an original clone._

**Method & scope.** This spec is built from **publicly observable gameplay** (store listings, gameplay footage, the visible rules of the genre) and general puzzle-game knowledge. It is a *behavioral* description for building an **original** game — not an extraction of proprietary code, art, audio, or level data. Each claim is tagged:

- **[V]** Verified — directly observable in normal play / public material.
- **[A]** Assumption — inferred; must be validated during tuning, not treated as fact.

> REA note: if a legally obtained build is later made available on the AVD/device, `rea` can confirm **[A]** items (grid size, timing curves, spawn rules) via UI-scenario capture and feature tracing. Until then, treat **[A]** as design hypotheses.

---

## 1. Core fantasy & loop

- **[V]** Single-screen spatial puzzle. A bounded board holds several colored blocks of various shapes. The board edges have colored **exit gates**. The player slides blocks around and pushes each block out through the gate of its matching color. Clear all blocks to win the level.
- **[V]** One hand, one finger: drag a block; it slides along grid lanes until it hits something or exits.
- **[V]** Short levels (tens of seconds to a couple of minutes), high level count, immediate restart — classic hyper/hybrid-casual cadence.

## 2. Board & grid

- **[V]** Rectangular grid of square cells. Blocks occupy whole cells (polyomino shapes).
- **[A]** Typical playable area ~**6x6 to 8x8** cells; grows/irregular on later levels. (Our design default: configurable, start 6x6.)
- **[V]** Gates sit on the board perimeter, each spanning one or more edge cells, each colored. A block may leave only through a same-color gate wide enough for it.
- **[A]** Some levels add **walls / blocked cells** and fixed obstacles inside the board. (Our design: support interior walls from day one.)

## 3. Blocks

- **[V]** Blocks are solid colored polyominoes (1x1, 1x2, 1x3, L, T, square, etc.).
- **[V]** Each block has exactly one color = its target gate color.
- **[V]** Blocks are rigid — no rotation during play; they only translate.
- **[V]** Movement is axis-aligned translation (up/down/left/right); no diagonal moves observed.
- **[A]** Some variants add gimmicks (ice that slides full-length, chained/locked blocks, multi-color blocks, keys). Treat as **optional later content**, not core.

## 4. Input, movement & collision

- **[V]** Drag gesture: finger down on a block, drag in a direction, block follows along the dragged axis.
- **[A]** Movement model: block moves cell-by-cell in the drag direction until the next cell is blocked by another block, a wall, or the board edge (non-matching). It stops flush against the obstacle. (Our implementation choice: grid-snapped, obstacle-stopped translation with a short easing settle.)
- **[V]** Collision is solid: blocks cannot overlap. No observed "pushing" of other blocks — each block moves into empty space only.
- **[V]** A block aligned with its matching gate slides **off the board** through the gate and is removed.
- **[A]** Partial exit: a long block may need multiple drags or must fully clear the gate to count. (Our rule: a block exits only when it can fully pass the gate; gate must be >= block's crossing width.)

## 5. Win / lose / softlock

- **[V]** **Win:** all blocks removed through their gates.
- **[A]** **Lose:** either a **move limit** or a **timer** on some levels; many levels are untimed/unlimited and purely spatial. (Our design: per-level optional move-cap and optional timer, both off by default.)
- **[A]** **Softlock:** a state where no block can reach its gate. Good level design (and our solver) must guarantee every shipped level is solvable; Undo/Restart cover the rest.

## 6. Feedback & animation (game feel)

- **[V]** Blocks slide smoothly with the finger and settle with a slight ease when released.
- **[V]** Exiting a gate plays a satisfying pop/slide-out with color-matched particles/flash.
- **[A]** Haptic tick on collision and on exit; sound cues for grab, bump, exit, win. (Our design: all of these, toggleable.)
- **[V]** Win screen with stars/score and next-level flow; restart button always reachable.

## 7. Progression & difficulty

- **[V]** Linear level map; difficulty rises via more blocks, more colors, tighter space, interior walls, and later gimmicks.
- **[A]** Difficulty knobs: board size, block count, color count, free-space ratio, min-moves-to-solve, obstacle density. (Our `LEVEL_SYSTEM.md` will formalize these.)

## 8. Menus / UX

- **[V]** Main menu, level select, in-level HUD (restart, undo, pause/settings, hint/boosters), win popup.
- **[V]** Local progress persistence (unlocked levels, stars).

## 9. Monetization (general genre patterns, observational)

- **[V]** Free-to-play. Common genre patterns: interstitials between levels, **rewarded** ads for hints/undo/extra moves, a remove-ads IAP, optional cosmetic/booster purchases.
- Our build: **testable interface only**, no live ads/IAP until configured and approved (brief Phase 3 items 12-13).

---

## 10. Original-design deltas (how ours will intentionally differ)

To stay clearly original: our own color palette, block art style, branding/name, gate visuals, sound design, and **100% original levels** generated and validated by our own solver. Core *mechanic* (slide colored blocks to matching gates) is a genre convention, not protectable; our *expression* of it is original.

## 11. Open questions to validate in tuning

1. Exact feel of the settle easing (duration/curve).
2. Whether blocks ever push others (we chose **no**; revisit if it hurts feel).
3. Gate-width vs block-width exit rule edge cases.
4. Default board size and color count for the first 10 "tutorial" levels.
