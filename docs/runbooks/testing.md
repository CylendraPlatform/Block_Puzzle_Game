# Test and QA Runbook

From repository root run with the exact Godot executable installed locally:
```sh
godot --headless --path . --script res://test/test_rules.gd
godot --headless --path . --script res://test/validate_all.gd
godot --headless --path . --script res://test/test_services.gd
godot --headless --path . --script res://test/test_drag.gd
godot --headless --path . --script res://test/test_v2_foundation.gd
godot --headless --path . --script res://test/test_v2_solver.gd
godot --headless --path . --script res://test/test_v2_session.gd
godot --headless --path . --script res://test/test_v2_pilot.gd
godot --path . --script res://test/test_v2_pilot_shots.gd
godot --headless --path . --script res://test/test_v2_campaign.gd
godot --headless --path . --script res://test/profile_v2_search.gd
godot --path . --script res://test/test_layout.gd
```
Document version, command, exit code, and relevant output. No passing result may be inferred from code inspection. `test_v2_campaign.gd` replays adapted levels with a 2500 expansion cap. A CAP line is a budget limit, not an unsolvable level. That script can take several minutes.

For presentation/UI changes, launch the actual game and check Main Menu, Level Select, gameplay, pause, settings, editor and win screen. On Android, test touch gestures, exit, undo, restart and persistence. Include at least two screen sizes when possible; record unavailable tests as NOT RUN.

For frame rate, use an actual running scene on emulator/hardware and a valid profiler, not `--script` FPS. A solver pass means reachable completion under its search rules; it does not prove game design quality.

Do not claim CI, build, emulator, device or Play Store verification unless executed.

## Run tests one at a time (shared `user://`)

Every Godot process for this project, headless or windowed, test or game, shares one
`user://` folder (`%APPDATA%\Godot\app_userdata\<project name>` on Windows). Several tests
guard the player's real saves by hashing them at the start and checking the hash at the end:
`test_m1_2_sequencing` (`progress.save`, `pilot_v2.save`), `test_progress_store`,
`test_game_screen`, `test_classic_score` and `test_td36_benchmarks`. If another process for
this project (the editor, a running build, a windowed QA script, another test) writes one of
those files while such a test runs, the test fails with "saves untouched" although the code
under test wrote nothing.

Seen on 2026-11-27: `test_m1_2_sequencing` exited 1 ("campaign and pilot saves untouched") in a
local headless batch while windowed render scripts ran at the same time; the same commit passed
alone twice and in CI, which runs tests one after another. Which concurrent process wrote the
file was not identified. The guard is right to fail when the real saves change; it is the
runner that must not overlap.

So: run the test scripts sequentially, and do not run windowed QA scripts, the editor's Play
button or a desktop build of this project during a test run. Re-run a "saves untouched" failure
on its own before treating it as a defect. Gameplay code and save formats are not changed to
work around this.
