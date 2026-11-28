# GP-1 step 1: BoardGeometry extraction, verification evidence

Step 1 of `design/gate_proto/GP1_IMPLEMENTATION_PLAN.md`. This is a pure refactor: the board
layout math moved out of `BoardViewV2` into the theme-independent `BoardGeometry`. There are
no visual, rule, save, scoring, level-data or feature-flag changes, and `gameplay/engine`
stays `legacy`.

**Environment:** Windows 10 desktop, Godot 4.7.2 (console build).
**Evidence type:** headless tests and a windowed desktop benchmark. No device, emulator or
playtest was used, and no frame rate is claimed.

## What changed

| File | Change |
|---|---|
| `scripts/presentation/board_geometry.gd` | new `BoardGeometry` (RefCounted, no node, rule, save or theme access). `fit()` and in-place `refit()` compute the layout: cell size, origin, frame band. It also provides board and frame rects, `cell_px`, `cell_center`, `cell_at` and `gate_slot`. The math is moved verbatim |
| `scripts/game/board_view_v2.gd` | `_layout()` calls `geometry.refit(...)` and mirrors `_cell` / `_origin`. `board_rect`, `frame_rect`, `cell_at`, `cell_center`, `_px`, `_cell_at` and `gate_slot` delegate to it. `FRAME_RATIO`, `FRAME_GAP_Y` and `GATE_DEPTH` remain as aliases. The public API is unchanged |
| `test/test_board_geometry_core.gd` | new test (below) |
| `test/bench_board_draw.gd` | opt-in `-- --raw` per-level CSV output. The measurement loop is unchanged |
| `.github/workflows/godot-ci.yml` | adds `test_board_geometry_core` to the headless list |

`BoardGeometry` has no colour or theme references. Every future skin (Carved Pearl, Midnight
Glass) receives this same object.

## Equivalence and reuse test (`test_board_geometry_core.gd`)

The reference is `LegacyLayout`, a frozen verbatim copy of the pre-extraction `BoardViewV2`
code from `main` at `59a07dc` (`_layout`, `board_rect`, `frame_rect`, `_px`, `_cell_at` and
`gate_slot`). The test covers:

- **Equivalence:** all 100 Classic levels × 5 view sizes (360x800, 393x852 and 411x891 board
  areas, the M31 canvas, and a height-limited view) × centred and top-aligned. For each
  case it compares:
  - cell size and origin;
  - board and frame rects;
  - every gate slot, both through `BoardGeometry` and through the view;
  - every cell's position and centre;
  - touch mapping at the centre and both inner corners of every cell;
  - frame-band probes, which must still map off the board.

  This comes to 84,900 checks.
- **Reuse:** one `BoardGeometry` and one `BoardViewV2` are reused through six steps: first
  level, a different level with different board dimensions, a viewport resize, a switch to
  top-aligned, back to the first level, and a switch back to centred. At each step the
  result must equal both the legacy reference and a fresh `fit()`. Then 5 repeated unchanged
  layout calls must give exactly the same values, with no drift. This comes to 459 checks.
- **Touch through the real input path** (`_gui_input`, on the reused view): one in-board
  swipe lands where `PuzzleEngine` says, and one drag-to-exit commits an `EXIT` in the right
  direction. This comes to 6 checks.
- **Result:** exit code 0, 85,379 checks, 0 failures.
- **Can it fail?** I changed one constant in `refit()` (top margin factor 0.16 to 0.17).
  The test then reported 5,345 failures (exit code 225). After restoring the constant it
  passed again with 0 failures.

## Full regression

Sequential (one Godot process at a time, because tests share `user://`); see
`regression.log`. It covers the 26 CI headless scripts, the new `test_board_geometry_core`,
`test_classic_equivalence` (the classic-compat job) and `proto_gates_check`. The totals are
in the last line of the log.

## Redraw performance (`bench/`)

**Method.** `test/bench_board_draw.gd`, unchanged:
- windowed desktop run with the M31 canvas view (688x1380);
- every Classic level, 60 redraws each;
- times the script side of `BoardViewV2._draw()`.

**Runs.** 5 baseline runs and 5 refactored runs, interleaved base, new, base, new on the
same machine in one session. Baseline = this branch with only `board_view_v2.gd` reverted
to `main`. The raw per-level rows are in `bench/*.log`, and `bench/analyse.py` produces
`bench/analysis.txt`.

| | Run medians (µs per redraw) | Mean | SD |
|---|---|---|---|
| Baseline | 1996.5, 2045.2, 1892.2, 1835.4, 1946.3 | 1943.1 | 82.9 |
| Refactor | 2012.0, 1926.0, 2036.2, 1924.7, 2006.6 | 1981.1 | 52.1 |

**Comparisons:**
- Paired by slot, the differences (refactor minus base, µs) are +15.5, −119.2, +144.0, +89.2
  and +60.2, so the sign changes between slots.
- Per level (mean of 5 runs each): the median refactor/base ratio is 1.015. The 10th to 90th
  percentile is 0.943 to 1.094. 57 levels are slower and 43 faster.
- Noise floor, with the same code and no change (baseline runs 1-2 vs 3-5): the median ratio
  is 1.056. The 10th to 90th percentile is 0.949 to 1.197.

**Finding.** The difference is +2.0% on the run means (+38 µs), smaller than the run-to-run
spread of identical code. The paired differences change sign, and the per-level spread is
inside the noise floor. So there is **no measurable systematic redraw regression** at the
resolution of this desktop benchmark. A real effect of about 2% cannot be ruled out with
these runs.

**Allocation fix.** The first version of the extraction allocated a new `BoardGeometry` on
every redraw. It was changed to an in-place `refit()` before these measurements were taken,
so `_draw` allocates no geometry object.

## Not covered

- Device, emulator or human testing. No rendering change was intended; the equivalence test
  proves the geometry, not the pixels.
- Frame rate. Desktop CPU microseconds are not a frame-rate or Android measurement.
