---
paths:
  - "scripts/**/*.gd"
  - "scenes/**/*.tscn"
  - "themes/**/*"
  - "project.godot"
---
# Godot game engineering
Read AGENTS.md and docs/tasks/CURRENT_TASK.md. Respect Godot/GDScript syntax, signal lifecycle, scene ownership, and deterministic Rules/Level APIs. Change mechanics only with regression tests. Keep rendering distinct from state transitions. Avoid allocation-heavy redraw loops; profile rather than guessing. Never report on-device behavior based only on headless tests.
