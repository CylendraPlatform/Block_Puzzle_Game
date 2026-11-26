# M1.2 — Advanced Mechanics Visual Integration: QA Evidence

Two QA rounds. Round 2 (PR #12 review fixes) supersedes round 1's render-only evidence.

## Round 2 — review fixes, full physical-device playthrough (2026-11-26)

**Code under test:** commit `6b8bd9f` (clean tree), exported as
`build/android/BlockPuzzle-M1.2r-debug.apk` (63.7 MB, debug, signed; APK gitignored).
**Device:** Samsung Galaxy M31 (SM-M315F, `R58R14KC1HZ`, 1080×2340), physical hardware.
**Install:** `adb install -r` only — in-place update: `firstInstallTime` unchanged
(2026-11-25 18:09:18), `lastUpdateTime` 2026-11-26 08:10:10. No `pm clear`, no uninstall,
no `logcat -c`. The main menu showed **"Level 36"** before and after all QA play, so
campaign progress was neither written nor cleared.
**Method:** `adb shell input swipe/tap` + `adb exec-out screencap`; burst captures (~0.7 s
apart) right after a commit to catch queued presentation steps. Evidence PNGs are in
`build/qa/m12r/` (gitignored, local).

### adv-001 — counter + locked gate (played to completion)
| Check | Result | Evidence |
|-------|--------|----------|
|Rejected: blue into the locked gate (counter 2, then 1)|PASS — no move, Moves unchanged|`a1_01_*`, `a1_04_*`|
|r1 exits; badge 2→1|PASS|`a1_03_after_r1`|
|**Intermediate state**: engine committed (Moves 1) while badge still shows 2|PASS|`a1_02_r1_exit_b1`|
|**Intermediate state**: r2 sliding out (Moves 2) while gate still locked / badge 1|PASS|`a1_05_r2_exit_b1`|
|Gate shown unlocked once its steps play|PASS|`a1_05_r2_exit_b2`|
|Undo after green's exit (Moves 3→2, green restored)|PASS|`a1_08_undo_green`|
|Level complete at the minimum 4 moves (rejections not counted)|PASS|`a1_10_win`|

### adv-002 — hidden piece + blocker (played to completion)
| Check | Result | Evidence |
|-------|--------|----------|
|Rejected: dragging the hidden "?" tile|PASS — nothing moves, Moves 0|`a2_01_reject_hidden_drag`|
|**Intermediate state**: blue exit committed (Moves 1) while the tile still shows "?"|PASS|`a2_02_blue_exit_b1`|
|Rejected: revealed green into the blocker|PASS — Moves stays 1|`a2_04_reject_green_blocked`|
|**Intermediate state**: red exit committed (Moves 2) while the "X" blocker is still drawn|PASS|`a2_05_red_exit_b1`|
|Restart mid-level restores "?", blocker and pieces (Moves 0)|PASS|`a2_07_restart`|
|Level complete at the minimum 3 moves|PASS|`a2_09_win`|

### adv-003 — colour-switching gate (opened directly via the selector, played to completion)
| Check | Result | Evidence |
|-------|--------|----------|
|Dev selector opens adv-003 directly from a fresh Advanced QA screen|PASS|`a3_01_selected`|
|One-cell move rotates the gate red→blue after the piece lands|PASS|`a3_02_red_one_cell_gate_blue`|
|Rejected: red into the blue gate (colour mismatch)|PASS — Moves stays 1|`a3_03_reject_red_into_blue`|
|Undo restores red and the red gate (Moves 0)|PASS|`a3_04_undo_gate_red`|
|**Intermediate state**: red exit committed (Moves 1, phase blue) while the gate is still red|PASS|`a3_05_red_exit_b1`|
|After blue exits the gate shows green (Moves 2)|PASS|`a3_07_after_blue_gate_green`|
|Restart restores pieces and the red gate|PASS|`a3_08_restart_gate_red`|
|Level complete at the minimum 3 moves; gate back to red (phase 0)|PASS|`a3_09_win`|

### Runtime log (logcat window 11-26 08:10:18 onward, 56,074 lines)
- No `FATAL`, `AndroidRuntime` exception, `SIGSEGV`, ANR or process death for the app; the
  app kept PID 7843 for the whole session.
- No Godot `SCRIPT ERROR` / `ERROR:` / `WARNING:` lines.
- One error-level line from the app process: Samsung system `USNET` network notice (not app code).

### Measured performance (on the M31, dev build)
The removed hot-path call (`SolverV2.solve` from the start state) now runs once per level on
a worker thread and is cached; its on-device cost is exactly what the previous build paid on
**every** load, commit, undo and restart:

| Level | Solve on device (worker) | Before: main-thread stall per interaction |
|-------|--------------------------|-------------------------------------------|
|adv-001|26,938 ms|≈27 s|
|adv-002|525 ms|≈0.5 s|
|adv-003|80 ms|≈0.08 s|

After the fix, per-commit handling (`[perf] commit_ms`, engine transition + presentation
setup + status) measured **3.1–5.4 ms** over 17 commits. The board stayed interactive while
adv-001's 27 s solve ran (moves were made before the readout changed from "solving…").
The adv-001 stall explains the "flaky" automated swipes in round 1. Not claimed: FPS
(no frame profiler was run).

## Round 1 — initial M1.2 (superseded)
Locked gate + counter, interaction and input lock were checked on the M31; hidden piece,
blocker and colour switching were only checked by desktop render (`test/shot_advanced.gd`).
Round 2 replaces that render evidence with the device playthrough above.

## Reproduce (non-destructive)
```sh
GODOT="D:/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe"
"$GODOT" --headless --path . --export-debug "Android" build/android/BlockPuzzle-M1.2r-debug.apk
adb -s R58R14KC1HZ install -r build/android/BlockPuzzle-M1.2r-debug.apk   # STOP on signature mismatch
adb -s R58R14KC1HZ shell am start -n com.blockpuzzle.game/com.godot.game.GodotAppLauncher
# Menu -> Advanced QA -> adv-001 / adv-002 / adv-003 selector
adb -s R58R14KC1HZ logcat -d -v time -T "<start time>" | grep -F "[perf]"
```
