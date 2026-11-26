# M1.3 — Unified Gameplay Experience: Architecture and Migration Plan

**Status:** Phase 1 plan, revision 2 — direction approved by the owner on 2026-11-26 with
decisions D1–D5 (§0.1) and five required refinements (folded in below). No gameplay route,
save file or level was changed to produce this plan. **Baseline:** `main` at `dc95d45`.
**Goal:** move the main player experience (Play / Levels / Next / Undo / Restart) onto the v2
engine (`PuzzleEngine`, `PuzzleSessionV2`, `BoardViewV2`). Sticky pieces and joined
locks/keys are out of scope.

## 0. Summary

| Question | Answer (evidence in §2–§3) |
|---|---|
|Can the shipped 100 levels run on v2 unchanged?|**97 of 100** showed identical legal moves on every compared state. This is **bounded differential evidence, not an exhaustive proof** (§3.1). The other 3 (021, 080, 090) differ only by a legacy pass-through-exit defect (§3.2); all 3 stay solvable under v2 at exactly their stored `par`.|
|Is existing progress preserved?|Yes. `progress.save` maps deterministically to stable ids (every file's `id` = sorted position + 1). It is never deleted, and is merged into the new store on every load (§5).|
|Rollback?|An engine flag plus a non-destructive save design: the v1 file is kept and dual-written for Classic while the rollback window is open; the new store max-merges it back on every load (§5.5).|
|New content?|Chapter 1: 20 original levels, independently accessible, separate progress and stars; becomes the default Play campaign only after its acceptance (§4.2, §7).|
|Latest `main` CI|Run `45813224305` on `dc95d45`: **success** (2026-11-26 11:44→11:53 UTC).|

### 0.1 Owner decisions (2026-11-26)

| | Decision | Where applied |
|---|---|---|
|**D1**|Adopt v2's strict exit rule for 021, 080, 090. Keep the original level files unchanged, document the intentional behavioural difference, and keep solvability/`par` regression tests.|§3.2, §8.1|
|**D2**|Preserve Classic scoring. Undo never refunds scoring moves or changes earned stars. The scoring counter is independent of `PuzzleState.move_number`.|§6.1, §8.1|
|**D3**|TD-3.5 Pearl is the unified visual identity, **default only after physical-device visual sign-off**.|§6.3, §8.2|
|**D4**|Exit gesture thresholds 0.34 cell, 0.12 cell near the screen edge; configurable and regression-tested.|§6.3, §8.1|
|**D5**|Chapter 1 = 20 original levels, independent of Classic completion, separate progress and stars. After it passes acceptance it becomes the default Play campaign; Classic stays available as "Classic".|§4.2, §7|

## 1. Scope

In scope: audit, compatibility evidence, architecture, migration and rollback design, pilot
campaign design, acceptance criteria, PR breakdown. Implementation proceeds one reviewed PR
at a time (§9); M1.3-A is the first.
Out of scope: store release, live ads or billing, timer/gold/hints, sticky pieces, joined
locks/keys.

## 2. Audit — two runtimes side by side

| Concern | Live Play today (legacy) | v2 path today (dev-only) | Migration impact |
|---|---|---|---|
|Rules authority|`Rules.slide_result` (`scripts/core/rules.gd`)|`PuzzleEngine.transition` (deterministic, events)|Classic must keep identical legal moves (§3).|
|Legal moves|Any landing 1..max slide; exit from the max slide when a matching gate spans every cell|Every free landing + one straight exit per open matching gate|Equivalent except the exit defect in §3.2.|
|Exit gesture|Exit when the finger passes max slide **+0.4 cell**|**+0.34 cell**, **+0.12** inside the screen-edge zone (device-tested)|D4: adopt v2 thresholds.|
|Move count|`_moves` += 1 per committed move or exit; **Undo does not decrement**; Restart resets to 0|`move_count()` = `state.move_number`; Undo rewinds it|D2: separate Classic scoring counter (§6.1).|
|Par / stars|`par` from JSON (full-slide optimum); `Catalog.star_rating(moves, par)` 3/2/1; best kept|No stars|Keep the legacy `par` and formula for Classic.|
|Win|All blocks gone|All `required` pieces exited (adapter marks all required)|Same.|
|Undo / Restart|Snapshot stack; Restart reloads the level|Snapshot history; presentation queue reconciles mid-animation|v2 is stricter (input lock, no duplicate commits).|
|Persistence|`user://progress.save` `{"unlocked": int, "stars": {"<index>": 1..3}}`, written in place (not atomic)|`pilot_v2.save` / `td36_qa.save` index only; Advanced QA writes nothing|New versioned, crash-safe store (§5).|
|Identity|Sorted file position|Stable string ids (`legacy-<n>`, `v2-001`, `adv-001`)|Explicit mapping; ADR-002 forbids index-only identity for new content.|
|Navigation|Main Menu → Play (resume at `unlocked`) / Levels (grid gated by `unlocked`) → `Game.tscn`; win card Next / Menu; Pause: Resume / Restart / Levels / Main Menu|Pilot / Advanced QA screens: Menu / Restart / Undo; win card Next / Menu|One unified game screen (§6).|
|Editor|**Test** plays a v1 custom level through `Game.tscn` (`Settings.custom_level`)|—|Must keep working (§6.2).|
|Analytics / ads|`level_start`, `level_complete` (moves, stars, undos), `undo_used`, `level_restart`; no-op interstitial every 3 levels|None|Keep the same hooks (still stub/no-op providers).|
|Visuals|Dark `Style` palette, rounded blocks|`TD35Theme` (pearl canvas, connected silhouettes, mechanic glyphs)|D3.|
|Solver|`Rules` BFS (full slides), validator for 100 levels|`SolverV2` (all landings, witness replay, metrics)|Classic keeps `validate_all`; v2 solver for new content.|

Other facts: Settings persist `sfx`, `music`, `haptics`, `analytics_opt_out` in
`user://settings.save`; `Settings.selected_level` is runtime-only. Debug builds expose dev
routes via `DevAccess`; release builds hide them (verified in M1.2).

### 2.1 Content inventory
- `levels/` — 100 legacy levels, `par` 1–9, ids 1..100 in file order.
- `levels_v2/pilot` 15 (lengths 1–5, onboarding-grade), `levels_v2/td36` 16 (8 fixtures,
  8 polyomino candidates, lengths 4–6), `levels_v2/benchmark` 3, `levels_v2/benchmark_advanced` 3.

## 3. Legacy level compatibility (measured)

**Method** (read-only script; M1.3-B commits it as a test): for each of the 100 levels,
compare the set of successor states produced by legacy `Rules` — every landing plus the
exit, i.e. what Play allows — with the successor set produced by `PuzzleEngine` on
`V1Adapter.to_v2()` output. Compared (a) the first 120 states in breadth-first order from the
start and (b) every state along a shortest legacy solution (full slides + exits, the move set
`par` was computed with), which exercises every exit; then checked v2 reaches a win at the
end of that solution.

### 3.1 Results (Godot 4.7.2, `main` at `dc95d45`, 206 s)

| Result | Levels |
|---|---|
|**Equivalent on all compared states** — identical successor sets on 21–129 compared states each, including every state of a shortest solution; v2 reaches a win at its end|**97**|
|**Different** — legacy offers an exit v2 refuses (§3.2); no state where v2 offers something legacy does not|**3**: 021, 080, 090|

Sanity check: the script's full-slide shortest solution equals the stored `par` for all 100
levels.

**This is bounded evidence, not a formal proof.** Each level's reachable state space is far
larger than the 21–129 states compared, so a difference could exist in an unexplored state.
It shows the rules agree near the start and along an optimal solution, where play
concentrates. M1.3-B keeps it as a regression test and widens coverage (deeper BFS for small
levels and a seeded random walk for large ones); a later full-proof check is optional.

| Level | Board | `par` | Where it differs | v2 optimum (`SolverV2`, cap 200,000, witness-replayed) |
|---|---|---|---|---|
|021|6×5, 2 pieces|3|4th compared state|SOLVED, 3 moves (26 states)|
|080|6×6, 5 pieces, 2 walls|7|within the first 120 states|SOLVED, 7 moves (64,494 states)|
|090|7×6, 5 pieces, 3 walls|5|start state|SOLVED, 5 moves (7,117 states)|

### 3.2 The exit difference (D1: adopt v2's strict rule)

`Rules._can_exit` asks only whether *some* block cell touches the edge and every cell lies in
a matching gate's span. When an L-shaped block slides toward an edge and is stopped by
another block or wall while one of its cells already touches the edge, legacy lets it exit
**through the obstruction**. v2 (`PuzzleEngine._exit_slide`) treats the step as blocked.
Example, level 021 from state `b1@(5,0), b2@(1,1)`: the orange L stops with cell (4,1)
against blue at (5,1) while cell (5,2) touches the right edge; legacy removes it.

All three levels stay solvable under v2 at exactly their stored `par` (021: 3, 080: 7,
090: 5), so the shortcut is never needed for an optimal solution and star thresholds keep
their meaning.

Per D1:
- `levels/level_021.json`, `level_080.json`, `level_090.json` are **not edited**.
- The difference is documented in `docs/LEVEL_SYSTEM.md` (exit rule note) and in the Classic
  release notes as an intentional rule correction.
- Regression tests (M1.3-B): v2 solves each of the three at exactly its `par` with witness
  replay; the equivalence test expects these three — and only these — to differ, and only
  through the pass-through pattern (legacy-only successors, none v2-only).

### 3.3 Par note
`par` was computed with full slides only, while players may stop part-way. Classic keeps the
stored `par` and the legacy star formula so existing star ratings keep their meaning.

## 4. Campaign structure

| Option | What players see | Progress | Risk |
|---|---|---|---|
|**A. Engine swap first (chosen)**|Same 100 levels, same numbering, on the v2 engine and screen|1:1 mapping; stars kept|Low: rules matched on all compared states except the documented defect|
|B. New v2 campaign replaces Play; legacy becomes "Practice"|New levels first; old progress in a side list|Kept but demoted|Medium: no proven content yet|
|C. Big bang (A + B together)|New engine, screen and content at once|Mapped|High: two variables in one release|

### 4.1 Campaigns
- **Classic** — the 100 existing levels, ids `legacy-1`…`legacy-100`, Classic scoring (§6.1).
- **Chapter 1** — 20 original v2 levels, ids `ch1-01`…`ch1-20`, independent of Classic
  completion, separate progress and stars (D5).

### 4.2 Launch sequence (explicit)

| Phase | When | Play button opens | Levels screen | Chapter 1 |
|---|---|---|---|---|
|**0 — today**|now|legacy `Game.tscn` (legacy engine)|legacy grid|not shipped|
|**1 — Classic-first (temporary)**|after M1.3-D sign-off|Classic on the v2 `GameScreen`, resume point = Classic `unlocked`|Classic tab|not shipped|
|**2 — Chapter 1 available**|after M1.3-E content passes the solver gate|still Classic|tabs: Classic · Chapter 1 (Chapter 1 open from level 1, no Classic prerequisite)|playable, own progress|
|**3 — Chapter 1 default**|after Chapter 1 passes the playtest gate (§7) and owner sign-off|Chapter 1 resume point|tabs: Chapter 1 · Classic|default|

The Play target is a single build-time setting, `gameplay/default_campaign` (`classic` →
`chapter1`), changed in its own reviewed PR at the phase 2 → 3 step. It is not stored in the
player's save, so rolling the build back restores the previous default. Classic progress is
unaffected by every phase change.

## 5. Save migration, crash safety and rollback

### 5.1 Files (all in `user://`)

| File | Role |
|---|---|
|`progress_v2.save`|Authoritative store (new).|
|`progress_v2.save.tmp`|Next version being written; may survive a crash.|
|`progress_v2.save.bak`|Previous good version.|
|`progress.save`|Legacy v1 file. Never deleted. Read on every load; dual-written for Classic (§5.4).|
|`progress.save.tmp` / `.bak`|Same crash-safe protocol for the dual-write (ignored by old builds).|

### 5.2 v2 format
Example with synthetic values:
```json
{
  "save_version": 2,
  "seq": 41,
  "campaigns": {
    "classic": {"unlocked": 36, "stars": {"legacy-1": 3, "legacy-2": 2}},
    "chapter1": {"unlocked": 0, "stars": {}}
  },
  "migration": {"from": "progress.save", "source_version": 1, "source_sha256": "<hash>", "at_unix": 1795000000},
  "checksum": "<sha256 of the canonical save_version + seq + campaigns>"
}
```
- `seq` increases by one on every write; recovery picks the highest valid `seq`.
- `checksum` is SHA-256 of a canonical, key-sorted, integer-normalised serialisation of
  `save_version`, `seq` and `campaigns`. A file is **valid** only if it parses, has the
  expected shape (unlocked ≥ 0; stars 1–3) and the checksum matches. A truncated or torn file
  is therefore rejected rather than half-read.
- Mapping from v1: `stars["<i>"]` → `legacy-<i+1>`; `unlocked` → Classic `unlocked`.

### 5.3 Write protocol (same for v2 and the v1 dual-write)
1. Serialise; write `X.tmp`; flush; close; check the file error.
2. Read `X.tmp` back; it must equal the written bytes exactly. Abort on failure.
3. If `X` exists and is valid (checksum for v2, parse/shape for v1): delete `X.bak`, then
   rename `X` → `X.bak`. If `X` exists but is invalid, delete it instead, so a corrupt file
   never replaces a good backup.
4. Rename `X.tmp` → `X`.

No step overwrites a file by rename. Windows refuses rename onto an existing file, so the
protocol never relies on it; on Android (app-internal ext4/f2fs storage) a rename inside one
directory is atomic, and the same protocol is used for both.

**Recovery on load** — candidates `X`, `X.tmp`, `X.bak`; the valid one with the highest `seq`
wins; if it was not `X`, the store immediately rewrites `X` from it (self-heal):

| Interrupted at | Files left | Loaded |
|---|---|---|
|during step 1|`X` valid, `X.tmp` torn|`X` (torn tmp fails validation)|
|after 1, before 3|`X` valid, `X.tmp` valid (newer)|`X.tmp`|
|inside step 3 (after delete, before rename)|`X` valid, `X.tmp` valid|`X.tmp`|
|after step 3, before 4|`X.bak` (old), `X.tmp` (new), no `X`|`X.tmp`|
|after step 4|`X` (new), `X.bak` (old)|`X`|
|`X` corrupted later (disk error)|`X` invalid, `X.bak` valid|`X.bak`|
|all v2 files invalid or missing|—|fresh migration from `progress.save`; never an empty store while v1 data exists|

**Durability limit:** GDScript has no `fsync`. A power loss right after a write can lose that
write (the OS may not have flushed it), but it can never produce a store that loads corrupt
data, because every candidate is checksum-validated and the previous good copy is kept.

### 5.4 Merge, migration and dual-write rules
- **Every load max-merges `progress.save` into Classic:** `unlocked = max(v2, v1)`, each
  star = max(v2, v1). Progress only grows. This one rule covers first migration, a rollback
  to the legacy build followed by a re-upgrade, and a failed dual-write.
- First run (no valid v2 file): build the store from `progress.save` (or empty), record
  `migration`, write `progress_v2.save` immediately. `progress.save` is **not** rewritten.
- Re-running is idempotent: the same inputs give the same campaigns; nothing is written when
  nothing changed.
- Malformed v1 values are ignored with a warning, never a crash: non-integer or out-of-range
  `unlocked` → 0 (and clamped to the Classic level count); non-integer, negative or unknown
  level indexes are skipped; stars ≤ 0 or fractional are skipped; stars > 3 are clamped to 3.
- **Dual-write (Classic only, while the rollback window is open):** each save writes v2
  first, then `progress.save` in the exact legacy format (`{"unlocked", "stars"}` with
  0-based string indexes, no extra keys), using the §5.3 protocol.
- **Dual-write failure handling:** the two writes are independent.
  - v1 fails → v2 is still saved; the store flags `pending_v1`, logs a warning, and retries on
    the next save. Gameplay is never blocked.
  - v2 fails → the in-memory state is kept, v1 is still attempted, and the next save
    retries. If v1 succeeded, the next load's merge recovers Classic progress from it.
  - Both fail → in-memory progress continues; the next save retries both; a warning is logged.
- A newer `save_version` (> 2) puts the store in **read-only** mode: nothing is written, and
  older files are left untouched.

### 5.5 Rollback
- Engine flag `gameplay/engine` = `legacy` | `v2`. Rolling back is one flag change and a
  rebuild; legacy `Game.tscn`, `Rules`, `BoardView` and `Catalog` stay unchanged in the tree
  until the rollback window is closed by a separate approved PR.
- A rolled-back build reads `progress.save`, which dual-write kept current, so it shows the
  player's Classic progress. When the player re-upgrades, the load merge brings any progress
  made on the legacy build back into v2.
- Chapter 1 progress lives only in `progress_v2.save`; a legacy build ignores it and a later
  re-upgrade finds it intact.

## 6. Unified gameplay architecture

```
MainMenu ── Play ──────────────► GameScreen(default_campaign, resume point)
         └─ Levels ─► LevelSelect(campaign tabs)
                              └─ tap ──► GameScreen(campaign, level_id)
Editor ── Test ────────────────► GameScreen(custom v1 level via V1Adapter, no progress)

GameScreen (one scene; replaces Game.tscn when gameplay/engine = v2)
  ├─ PuzzleSessionV2   authoritative state, history, undo, restart, win
  ├─ BoardViewV2       input + presentation queue (M1.2), never writes state
  ├─ ClassicScore      scoring counter (§6.1), independent of PuzzleState
  ├─ HUD: Pause · title · Undo
  ├─ Pause: Resume · Restart · Levels · Main Menu
  └─ Win card: stars · Next · Menu

CampaignCatalog   ordered {id, path, campaign, par}; stable ids; no index identity
ProgressStore     §5 (M1.3-A)
```

### 6.1 Classic scoring counter (D2)
`ClassicScore` is a small object owned by `GameScreen`, separate from `PuzzleState`:
- `on_commit()` — +1 for every action `PuzzleSessionV2.commit` accepts (move or exit);
  rejected actions do not count.
- `on_undo()` — **no change** (Undo never refunds scoring moves). The engine's
  `move_number` still rewinds, so mechanics that depend on it (colour schedules) stay correct.
- `on_restart()` — reset to 0 (legacy Restart reloads the level and zeroes the count).
- On win: `stars = Catalog.star_rating(score, par)`; `ProgressStore.record_completion`
  stores only an improvement. Earned stars never decrease: replaying worse, Undo, Restart or
  quitting mid-level cannot lower them.
- Analytics keep `level_complete{moves = score, stars, undos}`.

### 6.2 Progress and editor preservation
- Existing Classic `unlocked` and stars are visible unchanged on first launch of the new
  build (verified by tests and on device, §8).
- The editor's **Test** button keeps working: `GameScreen` accepts `Settings.custom_level`,
  adapts it with `V1Adapter`, never writes progress, and Next returns to the editor. Until
  M1.3-C lands, the editor continues to use the legacy route unchanged.

### 6.3 Presentation (D3, D4)
- TD-3.5 Pearl is the target theme; `GameScreen` is activated by default only after a
  physical-device visual sign-off (§8.2).
- Exit thresholds `EXIT_PAST = 0.34` and `EXIT_PAST_AT_EDGE = 0.12` become project settings
  (`gameplay/exit_past`, `gameplay/exit_past_edge`) read by `BoardViewV2`, defaulting to these
  values; the existing drag tests assert the defaults and the threshold behaviour.

Controller rules (from M1.2): input stays locked until the presentation queue drains; Undo /
Restart / level switch / scene exit reconcile immediately; no duplicate commits; the
controller never derives rules; no solver on the interaction path; analytics and ad hooks keep
their names and payloads, providers stay no-op; English-only text; `SafeArea` layout.

## 7. Chapter 1 — original v2 pilot campaign (D5)

**Size:** 20 original levels (not bulk-generated, not adapted from legacy, no competitor
layouts). Mechanics: connected multi-cell pieces and precise (narrow / uneven) gates;
advanced mechanics (M1.1) come in a later chapter. Accessible from level 1 without any
Classic prerequisite; separate progress and stars.

**Progression bands** (targets, tuned after playtest):

| Levels | Focus | Optimal moves | Explored states (SolverV2) | Distinct pieces |
|---|---|---|---|---|
|1–4|Drag, exit, one multi-cell piece|1–3|< 50|1–2|
|5–9|Ordering two pieces, narrow gate alignment|3–5|50–500|2–3|
|10–15|Dependencies, temporary repositioning|5–8|500–5,000|3–4|
|16–20|Mastery: dependencies + precise gates|7–11|2,000–30,000|4–5|

**Measured difficulty** — recorded per level with `PuzzleMetrics` and committed with the
level: optimal length, explored states, mean/max branching on the reference solution,
shortest-path count, dependency count, delayed exits / temporary moves, structural
fingerprint. Solver gate: every level `SOLVED` with witness replay; pairwise structural
similarity < 0.80; band targets met or the deviation justified in the level card.

**Human difficulty** (currently "unmeasured"): playtest with at least 5 people on device,
recording solve time, restarts and undo use per level. Playtest gate: median solve time rises
by band; no level with > 40% abandonment. Solver metrics alone are not a difficulty sign-off.
Passing both gates plus owner sign-off is what moves the launch sequence to phase 3 (§4.2).

## 8. Acceptance criteria

### 8.1 Automated (local and CI)
- All existing suites stay green (CI: headless suite; locally also `test_layout` and shot tests).
- **M1.3-A** `test_progress_store`: fresh store; v1 → v2 mapping; v1 file untouched by
  migration; idempotent reload; malformed v1 values; best-stars-only; separate campaigns;
  every interruption point in §5.3 (torn tmp, newer tmp, missing primary, corrupt primary,
  checksum tamper); dual-write output readable by the legacy `Catalog`; v1 dual-write failure
  (pending flag, retry); v2 write failure (state kept, v1 still written, recovered by merge);
  rollback (legacy-build progress merged back, Chapter 1 intact); newer version read-only;
  repeated saves (rename without overwrite); real `user://` saves untouched by the test.
- **M1.3-B** `test_classic_equivalence`: §3 comparison as a committed test (bounded, widened);
  021/080/090 expected to differ only via the pass-through pattern; v2 solves them at `par`
  with witness replay.
- **M1.3-C** `test_classic_score`: commit +1, rejected action 0, Undo no refund, Restart
  reset, win → stars from score and `par`, stars persist and never decrease (replay worse,
  Undo, Restart, quit mid-level, app restart).
- **M1.3-C** `test_game_screen`: Play resume point per campaign, Levels gating, Next, Undo,
  Restart, Pause routes, editor Test path (no progress writes), default campaign setting.
- Exit-threshold defaults (0.34 / 0.12) asserted in the drag tests.
- `validate_all` (legacy) and `SolverV2` witness replay for every Classic and Chapter 1 level;
  benchmarks and witness replay unchanged against the baseline.

### 8.2 Physical Galaxy M31 (non-destructive)
- `adb install -r` over the current install; `firstInstallTime` unchanged; **no** `pm clear`
  or uninstall. Record the menu's level label and Level Select stars before and after.
- Existing Classic progress visible unchanged; Play resumes at the right level; Levels gating
  and stars match; Next / Undo / Restart / Pause work; complete at least 3 Classic levels
  including one of 021/080/090; Undo during a level does not change the stars awarded.
- Editor Test plays a custom level and writes no progress.
- Visual sign-off of the Pearl theme on the device before it is enabled by default (D3).
- Rollback rehearsal: install the `gameplay/engine = legacy` build with `install -r`, confirm
  progress (dual-write), play one Classic level, reinstall the `v2` build, confirm the new
  progress is merged.
- Logcat: no crash, ANR or Godot script error; commit handling time recorded. FPS is not
  claimed without a profiler.

## 9. Delivery plan (one reviewed PR per step; none merged automatically)

| PR | Scope | Gate |
|---|---|---|
|**M1.3-A**|`ProgressStore`: v2 format, crash-safe writes, recovery, v1 merge/migration, dual-write and failure handling, read-only newer version, tests. **No gameplay routing changes.**|`test_progress_store` + full regression green; CI green|
|M1.3-B|`CampaignCatalog` + `test_classic_equivalence`; D1 documentation in `LEVEL_SYSTEM.md`|Equivalence/par regression committed|
|M1.3-C|`GameScreen` + `ClassicScore` behind `gameplay/engine` (default `legacy`); LevelSelect campaign tabs; editor Test path; exit-threshold settings|`test_classic_score`, `test_game_screen` green; legacy route untouched|
|M1.3-D|Device visual sign-off; flip Play to Classic on v2 (launch phase 1); device acceptance incl. rollback rehearsal|Owner sign-off|
|M1.3-E|Chapter 1 content + metrics (phase 2), playtest, then the separate `default_campaign` PR (phase 3)|Solver gate, playtest gate, owner sign-off|

## 10. Risks
- Equivalence evidence is bounded (§3.1): an unexplored-state difference is possible;
  mitigated by the widened regression test and device play.
- Rule correction for 021/080/090 changes available moves; mitigated by `par` regression and
  documentation (D1).
- No `fsync` from GDScript: a power loss can drop the last write, never corrupt the store (§5.3).
- Android filesystem behaviour is covered by design, not by an automated device test; the
  store's tests run on desktop, and on-device evidence comes from M1.3-D acceptance.
- Two engines in the tree during the rollback window — time-boxed; removal is a separate PR.
- Visual identity change for existing players — gated by device visual sign-off (D3).
