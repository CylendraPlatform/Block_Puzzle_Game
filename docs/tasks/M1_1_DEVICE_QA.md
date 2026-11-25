# M1.1 Phase F — Debug APK + Physical Device QA

**Build:** `build/android/BlockPuzzle-M1.1-debug.apk` (63 MB, signed, Godot 4.7.2 export,
exit 0). APK is gitignored and not committed.
**Device:** Samsung Galaxy M31 — `ro.product.model = SM-M315F`, serial `R58R14KC1HZ`,
screen 1080×2340. Physical hardware (not the emulator).
**Date:** 2026-11-25. Tools: adb (install / input / screencap / logcat).

## Steps and results
| # | Check | Result |
|---|-------|--------|
|1|Build debug APK with M1.1 code|PASS (signed, exit 0)|
|2|Install on M31|PASS (after `adb uninstall` — the prior build used a different debug key; `INSTALL_FAILED_UPDATE_INCOMPATIBLE` until the old package was removed)|
|3|Launch, no crash|PASS (Vulkan surface, splash → menu)|
|4|Main menu renders|PASS (`build/qa/m31/menu.png`): "Block Puzzle / Slide & Exit / Level 1", Play/Levels/Editor/v2 Pilot/TD-3.6 QA/Settings|
|5|Open **v2 Pilot** (runs the M1.1 `PuzzleSessionV2` engine)|PASS (`pilot2.png`): Level 1 board, "Drag to the matching exit", footer "Dev v2-001 SOLVED (1)"|
|6|Drag red block → slide → exit through matching gate → win|PASS (`win.png`): board cleared, "Moves 1", **"Level Complete!"** popup (Next / Menu)|
|7|logcat scan for crashes|PASS — no `FATAL`, no `AndroidRuntime`, no `SecurityException` (VIBRATE/haptics fine); only normal SurfaceFlinger/WindowManager/Vulkan lifecycle lines|

Screenshots: `build/qa/m31/menu.png`, `pilot2.png`, `win.png` (gitignored QA scratch).

## Scope and honesty
- This verifies the **app runs correctly on real hardware** with the M1.1 engine changes:
  the v2 drag → slide → exit → win flow works through `PuzzleSessionV2` on the M31, with no
  crash or regression.
- The **new M1.1 mechanics** (locked/conditional gates, counters, blockers, hidden pieces,
  color-switching gates) have **no dedicated UI yet** — they are verified at the
  solver/engine level headlessly (Phases A–E) and by the advanced benchmark fixtures. They
  were **not** visually exercised on device because `board_view_v2` does not yet render
  them. On-device visual QA of advanced mechanics belongs to the later visuals milestone
  (roadmap P3), once those renderers exist.
- No performance/FPS claim is made from this run (per the QA rule: no script-mode FPS; a
  real profiler on a running scene would be needed for a frame-rate figure).

## Reproduce
```sh
GODOT="D:/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe"
"$GODOT" --headless --path . --export-debug "Android" build/android/BlockPuzzle-M1.1-debug.apk
adb -s R58R14KC1HZ uninstall com.blockpuzzle.game
adb -s R58R14KC1HZ install -r build/android/BlockPuzzle-M1.1-debug.apk
adb -s R58R14KC1HZ shell monkey -p com.blockpuzzle.game -c android.intent.category.LAUNCHER 1
```
