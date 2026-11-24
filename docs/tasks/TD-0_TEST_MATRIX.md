# TD-0 test matrix

Schema fixtures in `test/fixtures/v2/` are not playable campaign levels.

| Check | TD-1 evidence | Later |
| --- | --- | --- |
| v1 `Level.from_dict` and 100 files unchanged | `test_v2_foundation.gd` round-trip plus `validate_all.gd` | — |
| Strict v2 diagnostics | schema fixtures plus negative cases for fractional and string numbers, unknown fields, id references, compound conditions, and counters | Cycle detection in TD-4; metric-key allowlist deferred |
| Canonical state hash and deep copy | `test_v2_foundation.gd` | — |
| Rejected transition does not mutate state | `ILLEGAL_ACTION` and `UNSUPPORTED_FEATURE` in `test_v2_solver.gd` | — |
| `UNKNOWN_CAP_REACHED` is not `UNSOLVABLE` | `SolverV2` zero-cap and tight-cap cases | — |
| Every legal landing and witness replay | `test_v2_solver.gd` plus `docs/v2/SOLVER_V2.md` | Full 100-level replay only when `test_v2_campaign.gd` prints SOLVED |
| Event execution, counters, reveal exit ban | Parsed only | TD-4 |
| Timer, gold, undo session | Not in TD-1 | TD-6 |
| Android gestures | Not rerun for this data-only change | TD-7 |

Existing scripts that must stay green: `test_rules.gd`, `validate_all.gd`, `test_services.gd`, `test_drag.gd`, `test_layout.gd`.
