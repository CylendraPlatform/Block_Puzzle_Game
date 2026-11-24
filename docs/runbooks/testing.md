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
