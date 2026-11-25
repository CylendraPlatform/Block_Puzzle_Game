# TD-3.6 — QA, timed-mode policy and acceptance
## Timer — separate policy from game engine
- Normal puzzles: real elapsed time count-up, no loss on timer.
- Optional Timed Challenge: level-specific countdown, paused during OS app background/incoming interruption and pause overlay; defined pause budget must be documented. Timer starts at first meaningful interaction or explicit Start, not during loading.
- Clarify Undo use before implementing ranking: recommended initial QA policy is Undo allowed, but tracked, and no timed leaderboard/rewards in this stage.
- Pause, restart, app background, low FPS and soft keyboard/Android system events must not tick a hidden time debt or cause negative displayed time.
- On expiry show Retry / Continue in normal (untimed) mode; don't corrupt progress or history. Timer cannot call an illegal move.
- Stars: do not expose until thresholds are defined, tied to real scoring, and tested. No coins, commerce or ads in TD-3.6.

## Evidence matrix
| Group | Required |
|---|---|
| Geometry and solver | strict schema, 30/30 SOLVED + witness replay; no UNKNOWN disguised |
| Content | 30 level cards, dependency audit and distribution, 8 P1 hand-authored gold standards |
| Regression | original 15 v2 pilot, legacy 100 schema/rules, undo/restart and no progress overwrite |
| UX | show screenshot + gesture video for at least easy/medium/hard puzzle; accurate move/timer |
| Android | APK, hash/signature, emulator test, physical-device safe area, touch gesture, background timer |
| Performance | real frame times from engine instrumentation on device; solver batch profile |
| Playtest | 5+ players preferred, independently observe: completion, time, hints, mis-taps, exit confusion, enjoyment and quit points; report actual N and bias |

## Difficulty study
Collect `level_id`, `tester_anonymous_id`, `attempt`, `start/end`, `complete`, `duration`, `moves`, `undo_count`, `hint_count`, `rage_quit_or_skip` (voluntary), optional comprehension rating. Respect privacy; no PII in repo. Measure median times where sample adequate and note uncertainty.

## Acceptance gates
**P0 instrumentation accepted** -> **P1 eight benchmarks + human/design review** -> **P2 generator reviewed** -> **P3 30 puzzles solver-verified** -> **P4 QA interface/timer** -> **P5 product-owner review**. Neither test exit 0 nor flashy screenshots alone is product acceptance.

## Existing PR dependency
TD-3.6 is stacked onto TD-3.5 PR #7, stacked onto TD-3 PR #6. Do not merge any independently until reviewed and approved in order.
