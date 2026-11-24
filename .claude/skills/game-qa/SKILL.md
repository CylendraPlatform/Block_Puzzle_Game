---
name: game-qa
description: Run and report the Godot puzzle project's existing deterministic and Android QA checks without overstating evidence.
---
# Game QA
1. Read AGENTS.md, docs/runbooks/testing.md and docs/tasks/CURRENT_TASK.md.
2. Inspect source changes and Git status.
3. Run four headless scripts in AGENTS.md using the installed Godot executable; record each exit status and failure log.
4. If Android tools are available, build/install/launch using docs/BUILD.md; exercise actual gestures and navigation.
5. Report tested vs untested behavior, reproducible failures, environment and evidence.
6. Update task evidence only for checks genuinely performed.
