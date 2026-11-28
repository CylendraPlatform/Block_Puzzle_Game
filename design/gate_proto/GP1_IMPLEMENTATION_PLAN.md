# GP-1 implementation plan: positioned-gate prototype in Carved Pearl, theme-ready

**Status: plan for owner review. No code written yet.**

## Owner decisions this plan follows

- Two selectable themes, **Carved Pearl** (default, built first) and **Midnight Glass**
  (second, after the Pearl prototype passes acceptance).
- One shared engine, state, GameScreen, level catalog and save system. Themes change pixels
  only.
- GP-1 = prototype levels A, B and C in Pearl, isolated from Classic and from player progress.
- `gameplay/engine` stays `legacy`. No v2 activation, release signing or merge of PR #30.

This plan replaces the open "decided in the implementation plan" points of
`MILESTONE_GP1.md`. Its scope, out-of-scope list and risks still apply.

## 1. Theme architecture and asset boundaries

Three layers. Only the bottom one knows about themes.

| Layer | Owns | Theme-aware? |
|---|---|---|
| Rules | `PuzzleEngine`, `PuzzleState`, `PuzzleSessionV2`, `SolverV2`, level JSON | no |
| Presentation logic | `BoardViewV2`: input, drag, preview, move / exit / event animation timing, undo and transition playback; new `BoardGeometry` (layout, cell to pixel, opening rectangles) | no |
| Skin | new `BoardSkin`: draws the static board layers, the pieces and the effects from a `ThemeTokens` set | yes |

**Boundaries:**
- **Geometry lives in one place, `BoardGeometry`.** It is pure and testable. It covers cell
  size, origin, frame band, recess, and each gate's opening (exactly `lo..hi`, posts on the
  cell lines). Input and every skin call it; no skin computes its own layout.
- **Skins never see `PuzzleState` or actions.** They get a definition, the geometry and a
  per-frame draw list: piece id, shape, colour, pixel position, alpha, and an exit clip
  rectangle. So a skin cannot change rules, moves or saves.
- **Tokens are data.** A `ThemeTokens` resource holds colours, material parameters (bevel,
  gloss, shadow offsets and blur, translucency, glow) and the shared geometry ratios from
  `art_selection/README.md`. Its first fields mirror `TOKENS` in `render_art_selection.py`.
  - `themes/carved_pearl.tres`: complete.
  - `themes/midnight_glass.tres`: palette only, `available = false`.
- **Assets:** no hand-drawn bitmaps in GP-1. The skin draws every layer procedurally once and
  bakes it into textures (section 3). Glass glow sprites come later, through the same baking
  step.
- **Classic is untouched.** Setting `BoardViewV2.skin` is optional. With no skin set, the
  existing drawing code runs unchanged, so Classic (on v2), the Pilot, TD-3.6 QA and Advanced
  QA all render as today. Only the prototype route sets a skin in GP-1. Moving Classic onto
  skins is a separate, later decision.

### Appearance setting

- `Settings.appearance`, default `"carved_pearl"`, stored in `user://settings.save` next to
  sfx and music. It is not stored in the progress files.
- An unknown or unavailable value, such as `"midnight_glass"` before it ships, falls back to
  Pearl.
- Older builds ignore the extra key, so downgrading is safe.
- A new `ThemeRegistry` maps ids to token resources and to availability.
- Changing the setting emits `Settings.changed`. GameScreen hands the new tokens to the
  board, which bakes again. Session, undo history, move count and the current level stay as
  they are.
- **GP-1 UI:** an "Appearance" row in Settings, shown only when `DevAccess.enabled()`. It
  lists Carved Pearl and greys out "Midnight Glass (coming later)". It becomes visible to
  players in the milestone that ships the second theme, because until then the setting only
  affects the prototype route.

## 2. Files

**New:**

| Path | Purpose |
|---|---|
| `scripts/presentation/board_geometry.gd` | `BoardGeometry`: pure layout and opening rectangles, used by input, skins and tests |
| `scripts/presentation/theme_tokens.gd` | `ThemeTokens` resource (colours, materials, ratios, `available`) |
| `scripts/presentation/theme_registry.gd` | id to tokens; `resolve(id)` falls back to Pearl |
| `scripts/presentation/board_skin.gd` | `BoardSkin`: bakes the static layers and piece sprites, draws a frame from the draw list |
| `themes/carved_pearl.tres`, `themes/midnight_glass.tres` | token sets (Glass palette only) |
| `levels_v2/gate_proto/proto_a.json`, `proto_b.json`, `proto_c.json` | importable copies of the design levels (ids `proto-a`, `proto-b`, `proto-c`) |
| `test/test_gp1_geometry.gd` | openings exactly `lo..hi`, frame solid elsewhere, touch mapping, exit clip |
| `test/test_gp1_isolation.gd` | route and appearance never touch the real saves (byte-identical) |
| `test/test_appearance.gd` | setting persistence, fallback, switching mid-level keeps state |
| `test/shot_gp1.gd` | desktop renders for evidence (output to `build/`, never into `res://`) |

**Modified:**

| Path | Change |
|---|---|
| `scripts/game/board_view_v2.gd` | uses `BoardGeometry`; optional `skin`; with a skin set, `_draw` sends the static layers and the piece draw list to it. Input and animation code unchanged |
| `scripts/game/game_screen.gd` | reads a launch context: campaign (default Classic) and progress store (default the real one). Listens for appearance changes. No rule changes |
| `scripts/core/campaign_catalog.gd` | new campaign `GATE_PROTO` built from `levels_v2/gate_proto/`; not part of Classic or Chapter 1 |
| `scripts/core/settings.gd` | `appearance` field, setter, load and save |
| `scripts/ui/settings_ui.gd` | dev-only Appearance row |
| `scripts/ui/main_menu.gd` | dev-only "Gate Prototype" button, next to the existing QA entries |
| `test/proto_gates_check.gd` | also checks that the `levels_v2` copies equal the design files |
| `.github/workflows/*.yml` | add the three new tests to the headless list |

Not touched: the engine, state, solver, validator, `ProgressStore` code, the Classic levels,
`Game.tscn` / `BoardView` (legacy route), the editor and `project.godot` (engine stays
`legacy`).

## 3. Rendering and animation

- **Bake once, draw cheaply.** On level load, on resize and on theme change, `BoardSkin`
  renders into a `SubViewport` set to update once, then keeps the result as textures:
  - **base:** page shadow, slab side, recessed floor, cell dimples, channel floors with
    threshold strip, chevron and glyph;
  - **lip:** the frame top face with the openings cut out, plus its bevels and the shadow it
    casts into the recess, on a transparent background;
  - **piece sprites:** one per piece (shape, colour, cell size) with contact and ambient
    shadow, side face, top face, bevel, sheen and embossed glyph.
- **Per frame**, `_draw` does three things:
  1. draws the base texture;
  2. draws each piece sprite at its animated position;
  3. draws the lip texture on top.
  Drawing the lip after the pieces gives the "under the frame" exit without any mask shader.
  An exiting piece's sprite is cropped (`draw_texture_rect_region`) at the frame's outer
  edge along the exit axis. Exits are axis-aligned, so the crop is one rectangle.
- **Animation is shared, not per theme.** Move, exit, bump, event flashes and the door pulse
  keep the existing `BoardViewV2` timings and step queue. Ease, `STEP_MOVE` and `STEP_EXIT`
  are unchanged unless the owner asks.
  - The skin only supplies the look: the pulse sprite and the threshold brightness while a
    dragged piece lines up with its door.
  - The reduced-motion option from `ART_SPEC.md` stays planned for later.
- **No rendering in rules code.** Animation reads `PuzzleEvent`s exactly as today.
- **Glass later.** It uses the same three layers plus pre-baked glow sprites, drawn
  additively. No real-time blur and no screen-texture reads. This keeps it within the budget
  below.

## 4. Performance budgets

These are targets. Each is proven by measurement before it is claimed.

| Item | Budget | How it is checked |
|---|---|---|
| Per-frame board drawing | 2 + N textured draws (N = pieces on the board, at most 4 here) plus effects; no polygon building and no allocation in `_draw` | code review and `test/bench_board_draw.gd`, extended to the skinned path |
| Per-frame board CPU, desktop | not above today's unskinned board on the same machine | `bench_board_draw.gd`, before and after |
| Bake time, desktop | ≤ 50 ms per level | timing logged by `shot_gp1.gd` |
| Bake time, Galaxy M31 | ≤ 250 ms, hidden behind the level transition | device profiler run, only with exclusive access |
| Frame rate, Galaxy M31 | holds 60 fps while dragging and during exits | Godot profiler on the device; never inferred from desktop or headless runs |
| Texture memory | ≤ 12 MB for base + lip + piece sprites at device resolution | computed from the texture sizes and logged |

If a device budget is missed, the plan is to lower the bake resolution, then merge the
piece side and top faces into fewer draws. Effects are not moved to shaders.

## 5. Isolation of the prototype levels and their progress

- **Levels:** `levels_v2/gate_proto/` is its own campaign, `GATE_PROTO`. It is not listed by
  Classic, Chapter 1, the level select or any player route.
- **Route:** the "Gate Prototype" button exists only when `DevAccess.enabled()` (editor, debug
  export or `--dev`). It opens the shared `GameScreen.tscn` with the launch context
  `{campaign: GATE_PROTO, store: isolated}`. The engine flag stays `legacy`. The flag still
  decides how Classic opens, and this route does not change it.
- **Progress:** same `ProgressStore` code, separate directory.
  `ProgressStore.open("user://gate_proto/", 0)` writes only `user://gate_proto/*.save`.
  Stars, unlocks and moves for A, B and C never mix with Classic.
- **Tests guard it:** `test_gp1_isolation.gd` plays A, B and C to a win, switches appearance
  mid-level and restarts. Then it checks that `progress.save`, `progress_v2.save`,
  `pilot_v2.save` and the Classic part of the store are byte-identical to before. The only
  new files allowed are `settings.save` (the appearance key) and the `gate_proto/` files.

## 6. Validation and acceptance

**Automated (must pass):**
- All 27 existing CI scripts plus the 3 new ones exit 0, and both CI jobs (`headless`,
  `classic-compat`) are green on the final SHA.
- `proto_gates_check.gd`: the copies equal the design levels, are solver-verified and pass
  the quality bar (72+ checks).
- Geometry:
  - every opening covers exactly `lo..hi`, with posts on the cell lines;
  - the frame is solid everywhere else;
  - no full-edge opening;
  - `cell_at` matches the current mapping;
  - an exit ends with the sprite fully cropped.
- Appearance:
  - the default is Pearl;
  - an unknown id falls back to Pearl;
  - the value persists across a reload;
  - switching mid-level leaves the state, move count, undo depth and level index unchanged.
- Isolation: as in section 5.

**Evidence and human checks:**
- Desktop renders at 360x800, 393x852, 411x891 and the M31 canvas, compared with
  `art_selection/renders/pearl_*`. The look must match the approved concept within reason.
- Galaxy M31 install, captures and profiler run, only with exclusive device access. The
  install uses `adb install -r` with no data reset; a signing mismatch stops the run and is
  reported.
- Owner playtest of A, B and C, and owner sign-off on the in-game look.

**Done means:** all of the above, and a draft PR that the owner reviews and merges.

## 7. Rollback

- **One PR, no data migration.** Reverting the merge commit removes the route, the skin and
  the setting.
- **Saved data:**
  - `settings.save` may keep an `appearance` key, which older builds ignore;
  - `user://gate_proto/` may remain, which nothing else reads.
  - Classic progress files are never written by this work, so no rollback is needed for them.
- **No runtime kill switch is needed.** Players cannot reach the route (dev-only), and with
  no skin set the board draws exactly as before.
- **The PR is staged so each step can be reverted on its own:**
  1. `BoardGeometry` extraction with no visual change, proven by the existing geometry and
     drag tests;
  2. tokens, registry and setting;
  3. skin and baking;
  4. campaign, route and isolation tests.

## 8. Order of work and rough size

| Step | Scope | Size |
|---|---|---|
| 1 | `BoardGeometry` extraction (pure refactor, tests unchanged and green) | 1 day |
| 2 | `ThemeTokens`, `ThemeRegistry`, `Settings.appearance`, dev Appearance row, `test_appearance` | 1 day |
| 3 | `BoardSkin` Pearl: bake base, lip and pieces; three-layer draw; exit crop; pulse | 2-3 days |
| 4 | `GATE_PROTO` campaign, launch context, dev route, isolated store, `test_gp1_isolation` | 1 day |
| 5 | Evidence renders, benchmark, docs; device run when access allows | 1 day + device time |

That is about 6-7 developer days in total. These are estimates. Midnight Glass is a later
milestone of about 3-4 days on top, because it reuses all of the above.

## 9. Not in GP-1

- Midnight Glass rendering;
- skins for Classic or the other dev routes;
- Chapter 1 content;
- editor support for positioned gates;
- player-visible Appearance setting;
- any change to rules, saves, store, analytics or monetisation;
- release signing;
- `gameplay/engine` change.
