# M1.2 — Advanced Mechanics Visual Integration: QA Evidence

**Build:** `build/android/BlockPuzzle-M1.2-debug.apk` (63 MB, signed). APK gitignored.
**Device:** Samsung Galaxy M31 (SM-M315F, `R58R14KC1HZ`, 1080×2340), physical hardware.
**Install:** `adb install -r` only — **non-destructive**, kept prior progress (menu showed
"Level 36"). No `pm clear`, no `uninstall`. Date: 2026-11-26.

## On-device (physical M31)
| Check | Result |
|-------|--------|
|Install `-r`, launch, no crash|PASS (`m2_menu.png`); logcat: no FATAL/AndroidRuntime/SecurityException|
|**Advanced QA** menu entry (dev-gated, campaign-separate)|PASS — loads the advanced levels (`m2_menu.png` shows the button)|
|**Locked gate** renders + opens|PASS — adv-001 blue gate is locked, then opens once its counter reaches 0 (`m2_adv001.png` → `m2_adv001_unlocked.png`)|
|**Counter** badge + decrement|PASS — badge shows "2", then "1" after a red key exits, then disappears on unlock (`m2_adv001.png`/`_mid`/`_unlocked.png`)|
|Interaction (drag → slide → exit)|PASS — red and blue pieces drag and exit on device|
|Input lock during animation (no duplicate action)|PASS — a second swipe sent during an exit animation was correctly ignored (Moves stayed 1)|

## Mechanic rendering (BoardViewV2 — same renderer on device and desktop)
On-device automated play could not reliably drive adv-001 to its win to *navigate* to
adv-002/adv-003 (the adb swipe-to-exit timing is flaky against the input lock), so the hidden
piece, blocker and color-switching **resting visuals** were captured with a deterministic
desktop render through the same `BoardViewV2` (`test/shot_advanced.gd`). The code path is
identical to the device; the adv-001 device captures confirm the renderer matches on hardware.
| Mechanic | Evidence | Visual |
|----------|----------|--------|
|**Hidden piece**|`desktop_adv-002.png`|obscured "?" tile (no colour), non-grabbable (headless `test_m1_2_view`)|
|**Blocker**|`desktop_adv-002.png`|hatched "X" obstacle tile|
|**Color-switching gate**|`desktop_adv-003.png`|gate drawn in the phase-0 scheduled colour (red) of schedule [red, blue, green]|
|**Counter + locked gate**|`desktop_adv-001.png` + on-device|counter badge + locked/open styling|

All mechanics are distinguished by **shape/symbol, not colour alone** (lock glyph, "X" hatch,
"?" tile, counter badge) — R3 accessibility.

## Honest status
- Fully verified **on the physical M31**: locked gate, counter (badge + decrement + unlock),
  interaction, input-lock, non-destructive install, Advanced QA entry.
- Verified by **render + headless logic** (same renderer; not yet played through on device):
  hidden piece, blocker, color-switching gate visuals, and the no-grab-hidden interaction.
- Not claimed: a full human playthrough of adv-002/adv-003 on device, or FPS (no script-mode
  FPS; a real on-device profiler would be needed).
- M1.1 engine untouched; full M1.1 headless regression stays green; no PRs merged.

## Reproduce (non-destructive)
```sh
GODOT="D:/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe"
"$GODOT" --headless --path . --export-debug "Android" build/android/BlockPuzzle-M1.2-debug.apk
adb -s R58R14KC1HZ install -r build/android/BlockPuzzle-M1.2-debug.apk   # in-place; STOP on signature mismatch
adb -s R58R14KC1HZ shell am start -n com.blockpuzzle.game/com.godot.game.GodotAppLauncher
# Menu -> Advanced QA -> play the counter / hidden+blocker / color-switching levels
"$GODOT" --path . --script res://test/shot_advanced.gd   # desktop renders of each mechanic
```
