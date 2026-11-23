# Test Plan & QA Results

## Strategy
- **Pure core logic** (rules, solver) is unit-tested headless - fast, deterministic.
- **Content** (all 100 levels) is validated for solvability on every run.
- **Services** (ads/IAP/analytics stubs) are tested headless via the autoloads.
- **Presentation** is verified by rendering real scenes and by an on-device
  playthrough (manual, scripted with adb).

## Automated tests (headless)
Run each with:
`godot --headless --path . --script res://test/<file>` (exit code = failures).

| Test | Covers | Result |
|------|--------|--------|
| `test/test_rules.gd` | slide/collision/exit, solvability, min-moves, win | 10/10 pass |
| `test/validate_all.gd` | all 100 shipped levels parse + solvable | 100 levels, 0 failures |
| `test/test_services.gd` | analytics opt-out, IAP purchase to entitlement, ads gating, coins | 7/7 pass |

Tools (not tests): `test/gen_levels.gd` (level generator), `test/shoot.gd`
(scene screenshot helper).

## On-device QA (Pixel AVD, Android ~API 37, software GPU)
Performed via adb install + scripted input on the emulator.

| Check | Result |
|-------|--------|
| Install signed debug APK | Success |
| Launch, engine init, no crash (logcat) | Pass |
| Main Menu renders (title + Play/Levels/Editor/Settings) | Pass |
| Enter Level 1, board + block + gate render | Pass |
| Touch-drag a block (swipe) moves it | Pass |
| Block exits matching gate; board clears | Pass |
| "Level Complete!" win popup appears | Pass |
| Settings screen renders all toggles + Remove Ads | Pass (desktop render) |
| Editor renders with tools | Pass (desktop render) |

### Defects found & status
- **VIBRATE permission missing** - haptics raised a caught `SecurityException` on
  device. **Fixed**: added `permissions/vibrate=true` to the export preset. (Was
  non-fatal; haptics simply did nothing before the fix.)
- **Immersive full-screen hint** - Android shows a one-time system "Viewing full
  screen" prompt on first launch (expected OS behavior, not a bug).

## Manual QA checklist (recommended before release)
- [ ] Undo restores exact prior state across multiple moves.
- [ ] Restart resets the level; Pause overlay buttons all route correctly.
- [ ] Progress persists across app restarts; Level Select locks/unlocks correctly.
- [ ] Settings toggles persist and take effect (SFX/music/haptics/analytics).
- [ ] Editor: place/erase blocks/walls/gates; Validate reports correct solvable/min-moves;
      Save/Load round-trips; Test plays the custom level and returns.
- [ ] Analytics opt-out stops all event recording.
- [ ] Remove-Ads (stub) marks owned and disables the interstitial hook.
- [ ] Multiple screen sizes / aspect ratios render without clipping.
- [ ] Stable frame rate on a representative low-end device.
- [ ] No Arabic or non-English text anywhere in the UI. (Verified: UI strings are
      English-only in source.)
- [ ] No third-party/competitor assets or copied level data. (All assets original;
      levels generator-produced.)

## Coverage note
Core gameplay logic and content have strong automated coverage. Interactive UI and
the editor's tool flows are verified by rendering + manual/on-device checks, not yet
by automated UI tests - see DEVELOPMENT_PLAN "honest gaps".
