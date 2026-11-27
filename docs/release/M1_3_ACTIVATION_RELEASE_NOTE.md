# Release note — Classic on the new game screen (M1.3 activation)

Draft for the release that sets `gameplay/engine = v2`. Not published; owner review required.

## Player-facing text (store "What's new", ≤ 500 characters)

> **A fresher look and fairer rules**
> • Classic puzzles now play on the new game screen with a cleaner look, larger buttons and a
>   move counter next to the level name.
> • One rule is now the same everywhere: a block leaves through a gate only when nothing on the
>   board is in its way. In a few Classic levels a block could slip out past another block —
>   that shortcut no longer works.
> • Every level can still be solved within its original move target, and your progress and
>   stars are kept.

## In-game / support wording (longer form)

**Why did a move that used to work stop working?**
Blocks now follow one exit rule: a block exits through a matching gate only when its whole path
to the edge is clear. Before this update, in some Classic levels a block that was stopped by
another block or a wall could still leave if one of its other cells already touched the gate.
That was inconsistent with how every other move works, so it has been corrected. Every Classic
level has been checked to still be solvable within its original move target (par), so star
ratings mean the same as before. Your unlocked levels and earned stars are not changed by the
update.

## Internal reference (not for players)

- Rule: `docs/LEVEL_SYSTEM.md` (exit rule note), decision D1 in
  `docs/architecture/M1_3_UNIFIED_GAMEPLAY_PLAN.md`.
- Levels where the old shortcut is reachable (pinned by `test_classic_equivalence`): 021, 024,
  044, 046, 061, 076, 080, 081, 086, 088, 090. All solvable at their stored `par` under the new
  rule.
- Progress: unlocked levels and stars carry over (ProgressStore migration; verified on a Galaxy
  M31 with existing progress).
- Also in this release (already on the legacy route since M1.3-D): 48 dp touch targets,
  full-screen dimming behind dialogs, Pearl-themed Level Select with drawn stars, clear
  messages when progress cannot be saved.
