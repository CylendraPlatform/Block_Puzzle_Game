# Milestone GP-1: positioned-gate prototype route (proposal)

**Status: proposal for owner approval. Not started.** The implementation plan, which follows
the owner's theme decision (Carved Pearl default, Midnight Glass second), is
`GP1_IMPLEMENTATION_PLAN.md`.

## Goal

Play the three prototype levels A, B, C in the real game, drawn in the approved art direction,
in a route that cannot affect Classic, player progress or the default experience. Nothing else.

## In scope

1. **Content**: copy `proto_a/b/c.json` into a new, importable folder `levels_v2/gate_proto/`
   (the `design/` copies stay as the design reference); ids `proto-a`, `proto-b`, `proto-c`.
2. **Route**: a developer-only entry "Gate Prototype" next to the existing developer routes,
   shown only when `DevAccess` allows it (never in player builds). It lists the three levels
   and opens them in the v2 GameScreen in a prototype mode.
3. **No persistence**: the prototype mode writes nothing (no progress, stars or settings);
   completion shows the win card with "Prototype" instead of stars.
4. **Renderer**: a board drawing path used only by the prototype route (a `BoardViewV2`
   subclass or a style flag, decided in the implementation plan): solid frame with real
   openings over `lo..hi`, blocks, exit pass-through and door pulse, per `ART_SPEC.md`; frame
   and openings pre-baked per level. Classic keeps its current renderer.
5. **Tests**:
   - `proto_gates_check.gd` against the copied levels, plus a check that the copies equal the
     design files;
   - a geometry test: each opening covers exactly `lo..hi`, the frame is uncut elsewhere, touch
     mapping unchanged, an exit animation ends with the block fully clipped;
   - a route test: the prototype mode never opens `ProgressStore` for writing and leaves the
     real `user://` save files byte-identical;
   - the full existing suite and both CI jobs green.
6. **Evidence**: desktop renders at 360x800, 393x852, 411x891 and the M31 canvas; Galaxy M31
   captures and a profiler run only with exclusive access; owner playtest of A, B, C.

## Out of scope

Chapter 1 levels beyond A, B, C; Classic levels or their renderer; the editor's gate tool;
colour glyphs on Classic; the authoring lint as a production tool (it stays in the test
script); store, save-format, analytics or monetisation changes; release signing; changing
`gameplay/engine` (stays `legacy`); any default activation.

## Acceptance

- A, B, C playable end to end in the prototype route on desktop, with exits only through the
  correct openings (engine rules unchanged).
- All tests above green; both CI jobs green on the final SHA.
- `user://progress.save`, `progress_v2.save` and `pilot_v2.save` byte-identical before and
  after playing the route.
- Owner approves the in-game look against `ART_SPEC.md`.

## Risks

- Renderer cost on device is unmeasured (the current board redraws every frame); pre-baking
  addresses it, the M31 profiler run confirms it.
- The prototype mode must not share code paths that save; the route test guards it.
