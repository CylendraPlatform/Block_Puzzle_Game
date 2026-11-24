# TD-0 test matrix

Schema fixtures in `test/fixtures/v2/` are not playable campaign levels.

| Check | TD-1 evidence | Later |
| --- | --- | --- |
| v1 `Level.from_dict` and 100 files unchanged | `test_v2_foundation.gd` round-trip plus `validate_all.gd` | — |
| Strict v2 diagnostics | schema fixtures for disconnect, overlap, gates, color, trigger, duplicate id, version | — |
| Canonical state hash and deep copy | `test_v2_foundation.gd` | — |
| Rejected transition does not mutate state | `RULES_NOT_IMPLEMENTED` and `UNSUPPORTED_FEATURE` | — |
| `UNKNOWN_CAP_REACHED` is not `UNSOLVABLE` | `PuzzleEngine.search_status` | Real solver in TD-2 |
| Every legal landing and witness replay | Not in TD-1 | TD-2 |
| Event execution, counters, reveal exit ban | Parsed only | TD-4 |
| Timer, gold, undo session | Not in TD-1 | TD-6 |
| Android gestures | Not rerun for this data-only change | TD-7 |

Existing scripts that must stay green: `test_rules.gd`, `validate_all.gd`, `test_services.gd`, `test_drag.gd`, `test_layout.gd`.
