# M1.3 — Unified Gameplay Experience: Architecture and Migration Plan

**Status:** Phase 1 (audit and design) — for review. No gameplay route, save file or level
was changed to produce this plan. **Baseline:** `main` at `dc95d45` (PR #6–#14 merged).
**Decision under review:** move the main player experience (Play / Levels / Next / Undo /
Restart) onto the v2 engine (`PuzzleEngine`, `PuzzleSessionV2`, `BoardViewV2`). Sticky
pieces and joined locks/keys are out of scope.

## 0. Summary

| Question | Answer (evidence in §2–§3) |
|---|---|
|Can the shipped 100 levels run on v2 unchanged?|**97 of 100** have identical legal moves on every compared state. The other 3 (021, 080, 090) differ only by a legacy pass-through-exit defect (§3.2); all 3 stay solvable under v2 at exactly their stored `par`.|
|Can existing progress be preserved?|Yes. `progress.save` is `{unlocked, stars{index}}`; every file's `id` equals its sorted position + 1, so index → `legacy-<id>` is deterministic.|
|Rollback?|A local engine flag plus a non-destructive save design (v1 file never deleted; dual-written while the rollback window is open).|
|New content?|A 20-level original v2 chapter with solver metrics per level and a human playtest gate; the existing 15 pilot levels are tutorial-length and are not shipped as-is.|
|Latest `main` CI|Run `45813224305` on `dc95d45`: **success** (2026-11-26 11:44→11:53 UTC).|

Recommended path (§4): **Stage A** — run the existing 100 levels ("Classic") on the v2
engine behind a flag, with progress mapped 1:1; **Stage B** — add an original v2 chapter
after Classic is accepted. Legacy code stays in the tree until the rollback window closes.

## 1. Scope

In scope (this phase): audit, compatibility evidence, architecture, migration and rollback
design, pilot campaign design, acceptance criteria, PR breakdown.
Out of scope: any implementation, save migration, route change, store release, live ads or
billing, timer/gold/hints, sticky pieces, joined locks/keys.

## 2. Audit — two runtimes side by side

| Concern | Live Play today (legacy) | v2 path today (dev-only) | Migration impact |
|---|---|---|---|
|Rules authority|`Rules.slide_result` (`scripts/core/rules.gd`)|`PuzzleEngine.transition` (deterministic, events)|Classic must keep identical legal moves (§3).|
|Legal moves|Any landing 1..max slide; exit from the max slide when a matching gate spans every cell|Every free landing + one straight exit per open matching gate|Equivalent except the exit edge case in §3.2.|
|Exit gesture|Exit when finger passes max slide **+0.4 cell**|**+0.34 cell**, **+0.12** inside the screen-edge zone (device-tested)|Feel change, not a rule change; decision D4.|
|Move count|`_moves` counts every committed move; **Undo does not decrement** (Undo costs stars)|`move_count()` = `state.move_number`; Undo rewinds it|Stars change unless Classic keeps legacy counting; decision D2.|
|Par / stars|`par` from JSON, computed with **full slides only**; `Catalog.star_rating(moves, par)` 3/2/1|No stars|Keep the legacy `par` and formula for Classic.|
|Win|All blocks gone|All `required` pieces exited (adapter marks all required)|Same.|
|Undo / Restart|Snapshot stack; Restart reloads the level|Snapshot history; presentation queue reconciles mid-animation|v2 is stricter (input lock, no duplicate commits).|
|Persistence|`user://progress.save` `{"unlocked": int, "stars": {"<index>": 1..3}}`, written in place (not atomic)|`pilot_v2.save` / `td36_qa.save` index only; Advanced QA writes nothing|New versioned store (§5).|
|Identity|Sorted file position|Stable string ids (`legacy-<n>`, `v2-001`, `adv-001`)|Explicit mapping; ADR-002 forbids index-only identity for new content.|
|Navigation|Main Menu → Play (resume at `unlocked`) / Levels (grid gated by `unlocked`) → `Game.tscn`; win card Next / Menu; Pause: Resume / Restart / Levels / Main Menu|Pilot / Advanced QA screens: Menu / Restart / Undo; win card Next / Menu|One unified game screen (§6).|
|Editor|**Test** plays a v1 custom level through `Game.tscn` (`Settings.custom_level`)|—|Unified screen must accept a custom v1 level via `V1Adapter`.|
|Analytics / ads|`level_start`, `level_complete` (moves, stars, undos), `undo_used`, `level_restart`; no-op interstitial every 3 levels|None|Keep the same hooks (still stub/no-op providers).|
|Visuals|Dark `Style` palette, rounded blocks|`TD35Theme` (pearl canvas, connected silhouettes, mechanic glyphs)|Player-visible change; decision D3.|
|Solver|`Rules` BFS (full slides), validator for 100 levels|`SolverV2` (all landings, witness replay, metrics)|Classic keeps `validate_all`; v2 solver for new content.|

Other facts: Settings persist `sfx`, `music`, `haptics`, `analytics_opt_out` in
`user://settings.save`; `Settings.selected_level` is runtime-only. Debug builds expose dev
routes via `DevAccess`; release builds hide them (verified in M1.2).

### 2.1 Content inventory
- `levels/` — 100 legacy levels, `par` 1–9, ids 1..100 in file order.
- `levels_v2/pilot` 15 (lengths 1–5, onboarding-grade), `levels_v2/td36` 16 (8 fixtures,
  8 polyomino candidates, lengths 4–6), `levels_v2/benchmark` 3, `levels_v2/benchmark_advanced` 3.

## 3. Legacy level compatibility (measured)

**Method** (read-only script, not committed): for each of the 100 levels, compare the set of
successor states produced by legacy `Rules` — every landing plus the exit, i.e. what Play
allows — with the successor set produced by `PuzzleEngine` on `V1Adapter.to_v2()` output.
Compared (a) the first 120 states in breadth-first order from the start and (b) every state
along a shortest legacy solution (full slides + exits, the move set `par` was computed with),
which exercises every exit; then checked v2 reaches a win at the end of that solution.

### 3.1 Results (Godot 4.7.2, `main` at `dc95d45`, 206 s)

| Result | Levels |
|---|---|
|**Equivalent** — identical successor sets on 21–129 compared states each, including every state of a shortest solution; v2 reaches a win at its end|**97**|
|**Different** — legacy offers an exit v2 refuses (§3.2); no state where v2 offers something legacy does not|**3**: 021, 080, 090|

Sanity check: the script's full-slide shortest solution equals the stored `par` for all 100
levels. The comparison is bounded (not an exhaustive proof of equivalence); M1.3-B turns it
into a committed test.

| Level | Board | `par` | Where it differs | v2 optimum (`SolverV2`, cap 200,000, witness-replayed) |
|---|---|---|---|---|
|021|6×5, 2 pieces|3|4th compared state|SOLVED, 3 moves (26 states)|
|080|6×6, 5 pieces, 2 walls|7|within the first 120 states|SOLVED, 7 moves (64,494 states)|
|090|7×6, 5 pieces, 3 walls|5|start state|SOLVED, 5 moves (7,117 states)|

### 3.2 The exit difference

`Rules._can_exit` asks only whether *some* block cell touches the edge and every cell lies in
a matching gate's span. When an L-shaped block slides toward an edge and is stopped by
another block or wall while one of its cells already touches the edge, legacy lets it exit
**through the obstruction**. v2 (`PuzzleEngine._exit_slide`) treats the step as blocked.
Example, level 021 from state `b1@(5,0), b2@(1,1)`: the orange L stops with cell (4,1)
against blue at (5,1) while cell (5,2) touches the right edge; legacy removes it.

This is a legacy rule defect, not intended design. Running these levels on v2 removes that
shortcut. All three levels stay solvable under v2 at exactly their stored `par` (021: 3,
080: 7, 090: 5), so the shortcut is never needed for an optimal solution and star
thresholds keep their meaning; only the extra pass-through option disappears (decision D1).

### 3.3 Par note
`par` was computed with full slides only, while players may stop part-way. Classic keeps the
stored `par` and the legacy star formula so existing star ratings keep their meaning.

## 4. Campaign structure — options and recommendation

| Option | What players see | Progress | Risk |
|---|---|---|---|
|**A. Engine swap first (recommended)**|Same 100 levels, same numbering, on the v2 engine and screen|1:1 mapping; stars kept|Low: rules proven equivalent except the documented defect|
|B. New v2 campaign replaces Play; legacy becomes "Practice"|New levels first; old progress in a side list|Kept but demoted|Medium: no proven content yet; TDD §14 advises against until the new campaign proves itself|
|C. Big bang (A + B together)|New engine, screen and content at once|Mapped|High: two variables in one release|

Recommendation: **A then B.** Stage A ships the engine and screen with "Classic" (the 100
levels) as the main campaign. Stage B adds "Chapter 1" — the original pilot chapter (§7) —
as a second campaign after Classic passes device acceptance. Classic and Chapter 1 are
separately labelled campaigns with independent progress (ADR-002, TDD §9/§14).

## 5. Save migration and rollback

### 5.1 New store
`user://progress_v2.save` (new file; `progress.save` is never deleted or rewritten into a new
format). Example with synthetic values:
```json
{
  "save_version": 2,
  "campaigns": {
    "classic": {"unlocked": 36, "stars": {"legacy-1": 3, "legacy-2": 2}},
    "chapter1": {"unlocked": 0, "stars": {}}
  },
  "migration": {"from": "progress.save", "source_version": 1, "source_sha256": "<hash>", "at_unix": 1795000000}
}
```
- Keys are stable level ids; Classic ids are `legacy-<n>` = `V1Adapter` ids.
- Mapping: v1 `stars["<i>"]` → `legacy-<i+1>`; `unlocked` copied as-is (both mean "number
  of Classic levels completed in order").
- Writes are atomic: write `progress_v2.save.tmp`, flush, rename over the target; keep
  `progress_v2.save.bak` of the previous good copy. A corrupt or unreadable file falls back
  to `.bak`, then to a fresh migration from `progress.save` — never to an empty save while
  v1 data exists.

### 5.2 Migration rules
- Runs once at startup when `progress_v2.save` is missing; idempotent (same input → same
  output; re-running is harmless; `source_sha256` records what was migrated).
- Malformed v1 values (non-int, out-of-range stars, unknown index) are clamped/ignored and
  logged, never crash. Missing v1 file → fresh v2 store.
- Best stars only ever increase.
- **Dual-write while the rollback window is open:** every Classic completion also updates
  `progress.save` in its existing v1 format (atomically), so an older build or the legacy
  engine sees the same progress. Turned off only by a later, separately approved release.

### 5.3 Rollback
- Engine flag `gameplay.engine` = `legacy` | `v2` (project setting + debug-only override in
  Settings). Stage A ships with `v2`; rolling back is one flag change and a rebuild — the
  legacy `Game.tscn`, `Rules`, `BoardView` and `Catalog` stay unchanged in the tree.
- Because of dual-write, rolling back loses no Classic progress. Chapter 1 progress lives
  only in `progress_v2.save`; the legacy build ignores it, and a later re-upgrade finds it
  intact.
- Downgrade of `save_version` is never written; a newer unknown version is read-only.

## 6. Unified gameplay architecture

```
MainMenu ── Play ──────────────► GameScreen(campaign, level_id = resume point)
         └─ Levels ─► LevelSelect(campaign tabs: Classic | Chapter 1)
                              └─ tap ──► GameScreen(campaign, level_id)
Editor ── Test ────────────────► GameScreen(custom v1 level, no progress)

GameScreen (one scene; replaces Game.tscn when gameplay.engine = v2)
  ├─ PuzzleSessionV2          authoritative state, history, undo, restart, win
  ├─ BoardViewV2              input + presentation queue (M1.2), never writes state
  ├─ HUD: Pause · title · Undo
  ├─ Pause: Resume · Restart · Levels · Main Menu
  └─ Win card: stars · Next · Menu

CampaignCatalog   ordered list of {id, path, campaign, par}; stable ids; no index identity
ProgressStore     §5 (atomic, versioned, migration, dual-write)
StarPolicy        per campaign: Classic = legacy formula + legacy move counting (D2)
```

Rules for the controller (lessons from M1.2):
- Input stays locked until the presentation queue drains; Undo / Restart / level switch /
  scene exit reconcile immediately; no duplicate commits.
- The controller never derives rules; it only calls `PuzzleSessionV2` and reads events.
- No solver on the interaction path; dev diagnostics stay `DevAccess`-gated with cancellation.
- Analytics and ad hooks keep their current names and payloads (`level_start`,
  `level_complete{moves, stars, undos}`, `undo_used`, `level_restart`, interstitial
  opportunity every 3 levels) — providers stay no-op.
- English-only text; safe-area layout via `SafeArea`; haptics/audio through existing autoloads.

## 7. Chapter 1 — original v2 pilot campaign

**Size:** 20 original levels (not generated in bulk, not adapted from legacy, no competitor
layouts). Mechanics: connected multi-cell pieces and precise (narrow / uneven) gates only;
advanced mechanics (M1.1) are a later chapter.

**Progression bands** (targets, tuned after playtest):

| Levels | Focus | Optimal moves | Explored states (SolverV2) | Distinct pieces |
|---|---|---|---|---|
|1–4|Drag, exit, one multi-cell piece|1–3|< 50|1–2|
|5–9|Ordering two pieces, narrow gate alignment|3–5|50–500|2–3|
|10–15|Dependencies, temporary repositioning|5–8|500–5,000|3–4|
|16–20|Mastery: dependencies + precise gates|7–11|2,000–30,000|4–5|

**Measured difficulty** — recorded per level with `PuzzleMetrics` and committed with the level:
optimal length, explored states, mean/max branching on the reference solution,
shortest-path count, dependency count (forced order), delayed exits / temporary moves,
structural fingerprint. Acceptance: every level `SOLVED` with witness replay; pairwise
structural similarity < 0.80; band targets met or the deviation justified in the level card.

**Human difficulty** (`human_difficulty` is currently "unmeasured"): playtest with at least
5 people on device, recording solve time, restarts and undo use per level. Gate: median
solve time rises by band; no level with > 40% abandonment; findings fed back before Stage B
ships. Solver metrics alone are not accepted as a difficulty sign-off.

## 8. Acceptance criteria

### 8.1 Automated (local and CI)
- All existing suites stay green (CI: headless suite; locally: plus `test_layout` and shot tests).
- New: `test_progress_migration` (v1 fixtures → v2: stars/unlocked mapping, malformed input,
  idempotency, atomic write + `.bak` recovery, dual-write round-trip, newer-version read-only).
- New: `test_classic_equivalence` — the §3 comparison as a committed test for all 100 levels
  (bounded per level), with the documented defect levels as explicit expectations.
- New: `test_game_screen` — Play resume point, Levels gating, Next, Undo, Restart, win →
  stars → unlock, Pause routes, editor Test path, no save writes for custom levels.
- `validate_all` (legacy) and `SolverV2` witness replay for every Classic and Chapter 1 level.
- Benchmarks and witness replay unchanged against the baseline.

### 8.2 Physical Galaxy M31 (non-destructive)
- `adb install -r` over the current install; `firstInstallTime` unchanged; **no** `pm clear`
  or uninstall. Record the menu's level label before and after.
- Existing progress visible unchanged in Classic (unlocked count and stars match the v1 file).
- Play resumes at the right level; Levels gating and stars match; Next / Undo / Restart /
  Pause routes work; complete at least 3 Classic levels including one level from §3.2.
- Rollback rehearsal: install the flag-`legacy` build with `install -r`, confirm progress is
  intact (dual-write), reinstall the `v2` build, confirm again.
- Logcat: no crash, ANR or Godot script error; commit handling time recorded.
- Not claimed without a profiler: FPS.

## 9. Delivery plan (one PR per step, each reviewed)

| PR | Scope | Gate |
|---|---|---|
|M1.3-A|`ProgressStore` + migration + dual-write + tests (not wired to UI)|Migration tests green; no route change|
|M1.3-B|`CampaignCatalog` + `test_classic_equivalence`; apply decision D1 for §3.2 levels|100-level evidence committed|
|M1.3-C|`GameScreen` behind `gameplay.engine` (default `legacy`), LevelSelect campaign support, editor Test path|`test_game_screen` green; legacy route untouched|
|M1.3-D|Flip default to `v2` for Classic; device acceptance §8.2 incl. rollback rehearsal|Owner sign-off|
|M1.3-E|Chapter 1 content (20 levels) + metrics + playtest|Playtest gate §7|

## 10. Risks
- Rule defect removal (§3.2) changes a few levels' available moves — mitigated by measured
  solvability and an explicit decision (D1).
- Star inflation/deflation if move counting changes — mitigated by D2.
- Visual identity change for existing players — D3; TD-3.5 visuals are not yet owner-approved.
- Save corruption on non-atomic legacy writes — the new store is atomic; v1 dual-write also atomic.
- Two engines in the tree during the rollback window — time-boxed; removal is a separate
  approved PR.

## 11. Decisions requested from the owner
- **D1** — Accept the v2 exit rule for levels with the §3.2 pattern (remove the pass-through
  exit; recommended — all three keep their optimal length), or keep those levels on the
  legacy route until re-authored.
- **D2** — Classic move counting: keep legacy (Undo does not refund moves) for star stability
  (recommended), or adopt v2 counting.
- **D3** — Visual identity for the unified screen: TD-3.5 pearl theme (needs visual sign-off)
  or the legacy dark palette on `BoardViewV2`.
- **D4** — Exit gesture thresholds: v2 (0.34 / 0.12 edge, device-tested) or legacy 0.4.
- **D5** — Chapter 1 size, and whether Chapter 1 unlocks after Classic level N or is open.
