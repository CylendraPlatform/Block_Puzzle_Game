# Game Design Document — Block Puzzle Game

## 1. Concept
A single-screen spatial puzzle for Android. The board holds colored polyomino
blocks; the board edges have colored exit gates. The player slides blocks around
the grid and pushes each one out through the gate matching its color. Clearing all
blocks wins the level. Original code, art, branding, and levels; English-only UI.
Inspired by the *feel* of the color-matched-exit genre (e.g. Color Block Jam) — see
[REFERENCE_SPEC.md](REFERENCE_SPEC.md) — not a copy of any specific title.

## 2. Core loop
Enter level → read the board → drag blocks to their matching gates → clear all
blocks → win popup → next level. Short sessions, instant restart, high level count.

## 3. Rules (implemented)
- **Grid:** rectangular, square cells. Origin top-left; +x right, +y down.
- **Blocks:** rigid colored polyominoes (1×1, 1×2/2×1, 1×3/3×1, L, 2×2). One color
  each = its target gate color. Translate only (no rotation).
- **Movement:** drag a block; it slides along the dragged axis, cell-by-cell, until
  blocked by a wall, another block, or the board edge. Collision is solid (no
  overlap, no pushing other blocks).
- **Exit:** a block flush against the matching-color gate, with the gate spanning its
  crossing cells, slides off the board and is removed.
- **Win:** all blocks removed. **No timer / move cap** in the current build (optional
  per the reference spec; off by default).
- **Softlock safety:** every shipped level is verified solvable by the BFS solver;
  Undo and Restart are always available.

## 4. Controls
One finger. Touch a block and drag up/down/left/right. Axis locks on first motion.
Release settles with a short ease. Mouse drag works on desktop for testing.

## 5. Content & progression
- **100 levels**, generator-produced and solver-verified, difficulty rising across
  tiers (board 5×5→7×7, 1→5 blocks, more colors and interior walls; shortest-solution
  length ranges ~1→9 moves). See [LEVEL_SYSTEM.md](LEVEL_SYSTEM.md).
- Linear unlock: finishing level N unlocks N+1; progress saved locally.
- **Level editor** lets players build, validate (real solver), save, and test custom
  levels.

## 6. UX / screens
- **Main Menu:** Play (resume at progress), Levels, Editor, Settings.
- **Level Select:** grid of levels; locked past current progress.
- **Game HUD:** Menu, Pause, Undo, Restart, level label; Pause overlay
  (Resume/Restart/Levels/Menu); win popup (Next).
- **Settings:** Sound Effects, Music, Haptics, Share Analytics toggles; Remove Ads.
- **Editor:** tools for walls/blocks/gates, color/shape/size, Validate/Save/Load/Test.

## 7. Audio & feel
Original procedurally-generated SFX (tap, slide, bump, exit chime, win arpeggio) and
an optional ambient music loop. Haptic ticks on move/exit/bump. Smooth block
settle-easing and selected-block highlight. All toggleable.

## 8. Visual design
Dark board (#242838) on a near-black app background (#1b1e2b). Six distinct block
colors with darker outlines. Colored gate bars outside the matching edge. Clean,
high-contrast, readable at phone sizes. Portrait 720×1280 reference, stretch-expand.

## 9. Monetization (stubbed, off by default)
Rewarded/interstitial ad interface, IAP architecture (Remove Ads + coin packs), and
privacy-first analytics — all disabled with no SDKs/billing/network until configured
and approved. See [MONETIZATION.md](MONETIZATION.md).

## 10. Non-goals (current build)
Timers/move-caps, block gimmicks (ice, locks, keys, multi-color), online features,
and real ads/IAP. All are possible future extensions behind the existing modular
boundaries.
