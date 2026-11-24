---
name: level-validation
description: Validate the existing 100 Godot JSON puzzle levels and review difficulty metrics before content changes.
---
# Level validation
1. Read AGENTS.md, docs/LEVEL_SYSTEM.md and docs/tasks/CURRENT_TASK.md.
2. Run `godot --headless --path . --script res://test/validate_all.gd`.
3. Run `godot --headless --path . --script res://test/audit_levels.gd`.
4. Review flagged levels and minimum-solution distribution.
5. Remember solving a level does not prove it is enjoyable or safe from all undesirable states.
6. Record actual results and update docs/LEVEL_QUALITY_REPORT.md only if measurements changed.
