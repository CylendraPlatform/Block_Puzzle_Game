# TD-3.5 Quality and evidence gates
**This checklist is NOT marked passed.** No TD-3.5 Godot implementation or physical-device QA has yet occurred.

## P0 gameplay
- [ ] Board centered within available safe content; no excessive blank upper/lower half on 1x5/5x1/5x5/9x9.
- [ ] Correct square cells; 1-cell gate is 1-cell wide; colored overlapping gates drawn without suggesting invalid aperture.
- [ ] L/T/S/Z pieces read as one coherent body without self-intersection/artifact.
- [ ] Finger preview consistent with engine grid landing; no ghost or false move.
- [ ] One-swipe EXIT from interior is possible when legal, **and** last-cell stop still possible.
- [ ] Android system edge/nav gestures do not block intended exits.
- [ ] Undo/Restart restore exact authoritative state; exit animations lock input correctly.
- [ ] Moves/win copy accurate, English-only, dev diagnostic hidden in player mode.

## P1 UI
- [ ] Main menu visually aligned with approved Premium Playful 3D direction.
- [ ] Win celebration polished but no fake currency, fabricated scores or unexpected persistence writes.
- [ ] Buttons >=48dp, accessible contrast, responsive safe insets.

## Evidence
| Evidence | Required |
|---|---|
| Source | commit SHA, asset version, Godot version, tested device |
| Screens | 360x800, 412x915, tall/narrow board and cutout |
| Actions | emulator gesture screen recording with entry/drag/exit/undo/restart |
| Real Android | physical device gesture + cutout/nav verification, model/API/build noted |
| Performance | actual scene frame times and memory under chosen test device |
| Human review | user/product-owner signoff on similarity, legibility, game feel |
| Regression | test_v2_pilot, test_v2_session, test_v2_solver, test_v2_foundation, validate_all (100), test_rules, test_drag, test_layout |

## Acceptance statuses
**DESIGN READY** means specs/source art in GitHub. **IMPLEMENTED** means Godot scenes work. **TECH QA PASSED** means automated/emulator proofs. **PRODUCT ACCEPTED** requires owner visual/gesture review and physical-device evidence. Never conflate them.

## Defects from predecessor
Existing PR #6 worked at technical level but screenshots had huge grey background, boards not centrally composed, unstyled debug HUD, ribbons outside rather than cutout gates, very short tutorial puzzles. Preserve these as baseline differences to evaluate, not proof of TD-3.5 completion.
