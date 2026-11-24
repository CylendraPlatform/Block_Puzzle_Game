# Visual Design System

Premium-casual puzzle styling. All tokens live in `scripts/core/style.gd` (the
`Style` class) and the project-wide theme `themes/main_theme.tres` (set as
`gui/theme/custom`). Styling is kept separate from puzzle rules.

## Palette
**Blocks** (vivid, logical name -> color): red `#ff5a6e`, blue `#4d7cff`,
green `#2fd6a6`, yellow `#ffc442`, orange `#ff8f3c`, purple `#b36bff`.

**Surfaces**: app background vertical gradient `#2b3150` -> `#171a28`; board tray
`#30354f`; empty cell `#272b40`; wall `#12141d`; panel `#242a44`; panel border
`#4a5280`. **Text**: `#f4f6ff` (primary), `#aab0cc` (dim), `#ffffff` (title).

## Typography (px)
Title 64, Heading 30, Body 24, Button 26. Engine default font (swap a brand font by
adding it to the theme later).

## Spacing & dimensions
Corner radius: block 14-20% of cell, panel 20, button 16. Button min height 76,
min width 300. Cell padding 10% of cell. Board tray padding ~12% of a cell.

## Components & states
- **Buttons** (theme): rounded, soft border + drop shadow; hover brightens + grows
  shadow; pressed darkens; disabled dims. Focus outline removed.
- **Panels** (theme): rounded 20, border, soft shadow - used for win/pause popups.
- **Blocks** (drawn): rounded body + dark bevel border + contact shadow + upper
  directional highlight. Selected = brighter body/highlight + larger shadow (lift).
- **Cells**: inset rounded wells inside the board tray.
- **Gates**: rounded colored bar set just outside the matching edge, with a light
  border and a color-matched **idle glow that pulses** (period `GATE_PULSE`).
- **Board**: rounded tray with soft drop shadow; sits on the gradient background.

## Motion / timing (seconds)
Block settle lerp speed `EASE_SPEED` 22; exit pop `EXIT_DUR` 0.22; gate pulse period
`GATE_PULSE` 1.6; squash/stretch amount `SQUASH` 0.06 (reserved for Phase C).

## Responsive layout
Board sizes to fill the available width and is pinned under the HUD, with gate
clearance, so leftover portrait space sits below the puzzle.
Interactive controls use `SafeArea` (`scripts/ui/safe_area.gd`) and platform display
insets. The premium art pass is still open; this is not final visual design.

## Rendering approach
Pure 2D. Rounded/beveled/shadowed shapes are drawn with `StyleBoxFlat` via
`draw_style_box` - no 3D, no custom shader yet (a block shader is an optional future
refinement). Per-frame StyleBox allocation is acceptable for a small board now;
caching static cell/tray boxes is a Phase F optimization.

## Known tuning items
- Background gradient reads subtly in current renders; richer stops/vignette to come.
- Add a branded font and a block-face shader for extra depth if measured worthwhile.
