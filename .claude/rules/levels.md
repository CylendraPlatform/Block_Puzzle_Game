---
paths:
  - "levels/**/*"
  - "test/gen_levels.gd"
  - "test/audit_levels.gd"
  - "scripts/core/rules.gd"
  - "scripts/core/level.gd"
---
# Level integrity
Validate all shipped levels with test/validate_all.gd after any content or solver change. Re-run audit_levels.gd when modifying progression. BFS minimum moves is not a sufficient difficulty/fun metric; include branching, trial play and observable feedback. Do not copy competitor layouts.
