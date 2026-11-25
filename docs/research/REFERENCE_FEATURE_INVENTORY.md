# Reference Feature Inventory — Color Block Jam (Phase REA-02)

Subject: `com.GybeGames.ColorBlockJam` 13.2.0 (Unity IL2CPP). Confidence tags are defined
in `REFERENCE_EVIDENCE_REGISTER.md`: **DO** observed · **PD** public doc · **TI**
RE symbol present · **INF** inferred · **UNK** unknown. No item here is **DO** — no
gameplay was captured in this phase. Nothing below authorizes copying reference code,
assets, art, audio, or level layouts; it is a functional target for *original* work.

## 1. Piece geometry & movement
| # | Capability | Confidence | Basis |
|---|-----------|-----------|-------|
|1.1|Colored blocks slide on a grid toward matching exits|PD + TI|Help center; `AddCell`, `ApplyGridSpacing`, `AllocateDynamicBlockId`|
|1.2|Multi-cell / grouped pieces (polyomino-like)|TI|`AddBlockGroup`, `AlignmentOfCellsInGroup`, `AppendUnitBlockCounts`|
|1.3|Straight-line slide until blocked (no free rotation implied)|INF|No rotation symbol surfaced for blocks; consistent with genre. UNK whether any piece rotates|
|1.4|Per-block color identity|TI|gate-color matching symbols; coin/economy unrelated|
|1.5|Exact move model (step vs continuous drag, snap rules)|UNK|not established without capture|

## 2. Color rules & exit gates
| # | Capability | Confidence | Basis |
|---|-----------|-----------|-------|
|2.1|Gates/doors accept a matching color; block "claims" the exit|PD + TI|`OpenGate`, `GateOpen`, `CLAIM_OPEN_GATE_TIMEOUT_SECONDS`|
|2.2|Gate VFX tinted to its color / proximity feedback|TI|`ApplyGateColorToProximityVfxs`, `TintParticlesToGateColor`|
|2.3|**Color-switching gates** (required color changes over time)|TI|`DoorColorChanger`, `DoorColorSwitcher`, `ColorfulJumpingDoorColorIndex`|
|2.4|**Laser door** variant|TI|`LaserDoorColorIndex`|
|2.5|Multi-layer gate that "peels" on first contact, freeing next block|PD|third-party guide; not independently TI-confirmed → treat as INF for rules|
|2.6|Gate blocked / temporarily unusable|PD + INF|"gates may be blocked"; relates to feeder `PermanentlyBlocked` symbols|
|2.7|Exact span/width rules of a gate|UNK|our v2 models `lo/hi` span; reference span rules not captured|

## 3. Board layouts & obstacles
| # | Capability | Confidence | Basis |
|---|-----------|-----------|-------|
|3.1|Walls / fixed obstacles bounding movement|INF + PD|genre-standard; obstacle help page exists|
|3.2|**Grinder** blocks (destroy/transform)|TI|`AddGrinderBlocks`, `AnimateGrinderWithAnimateItemOrProceed`|
|3.3|**Sticky** pieces (adhere / drag neighbors)|TI|`AddStickyPieces`|
|3.4|**Magnet / drain** (pulls blocks, acceleration)|TI|`AddMagnetPoint`, `ApplyDrainMagnet`, `drainMagnetAccel`|
|3.5|**Locks** (and joined/linked locks)|TI|`AddLock`, `AddJoinedLocks`, `AddJoinedLockDatas`|
|3.6|**Crates / covers** over objects|TI|`ActivateUnderCrateObject`|
|3.7|**Feeders**: dispenser / spawner / elevator queue blocks of a type|TI|`AnyDispenserHasQueuedBlockOfType`, `AnySpawnerHasQueuedBlockOfType`, `AnyElevatorHasQueuedBlockOfType`|
|3.8|Exact obstacle roster & interactions|UNK|symbol presence ≠ full rules|

## 4. Advanced / conditional mechanics
| # | Capability | Confidence | Basis |
|---|-----------|-----------|-------|
|4.1|Timed "claim" pipeline (open gate → arm drain → settle)|TI|`CLAIM_OPEN_GATE_TIMEOUT_SECONDS`, `CLAIM_DRAIN_ARM_TIMEOUT_SECONDS`, `CLAIM_BOWL_SETTLE_TIMEOUT_SECONDS`|
|4.2|**Timer bomb** that arms on a block exit|TI|`ArmTimerBombOnExit`|
|4.3|Dependency ordering (some blocks must move first)|PD|help/guide; matches our trigger/lock model|
|4.4|Dynamic block allocation mid-level (from feeders)|TI|`AllocateDynamicBlockId` + feeder symbols|

## 5. Timer, pause, timeout
| # | Capability | Confidence | Basis |
|---|-----------|-----------|-------|
|5.1|Per-level **countdown timer**; timeout = fail|PD + TI|`CountdownTimerCoroutine`, `CountdownFrom/To`, `CountdownCompleteEvent`, `CanTimeout`|
|5.2|Timer placement / countdown material (UI)|TI|`ApplyTimerPlacement`, `ApplyCountdownMaterial`|
|5.3|Timer pause (menus / PvP bot pause)|TI|`AreBotTimersPaused`, `CheatTimerPaused`|
|5.4|Exact timer durations per level|UNK|not captured|

## 6. Boosters & assistance
| # | Capability | Confidence | Basis |
|---|-----------|-----------|-------|
|6.1|Booster framework w/ slots, shop price, tutorial, free uses|TI|`ApplyBoosterSlots`, `BoosterPriceRow`, `BoosterPurchasedEvent`, `BOOSTER_FREE_USE_COUNT_PREFIX_SAVE_KEY`|
|6.2|**Rocket / auto-rocket** booster|TI|`AutoRocket`, `AddAutoRocketAction`, `AddTimedRocketBoosterTime`|
|6.3|**Extra-time / time-increaser** booster|TI|`AddTimedTimeIncreaserBoosterTime`, `ArmFirstRoundsExtraTime`|
|6.4|**Pre-level** booster (armed before start)|TI|`AddedTimedPreBoosterEvent`|
|6.5|**Continue** booster (revive after fail)|TI|`ActivateContinueBoosterUI`, `ContinueLevel`|
|6.6|Freeze / Hammer / Magic-Wand / Destroy-Color|PD (low)|guides; partly from *Gem Jam*. UNK/INF for this title unless TI-confirmed|

## 7. Lives, retries, continuation
| # | Capability | Confidence | Basis |
|---|-----------|-----------|-------|
|7.1|**Hearts = lives**, max cap, perks raise cap|TI|`GetHeartLimit`, `DEFAULTH_MAX_HEARTH_AMOUNT`, `HasHeartLimitPerk`, `HasDiamondHeartLimitPerk`|
|7.2|Give-up / fail window; continue vs lose|TI|`GiveUp`, `GiveUpRunLosePanel`, `FailWindowGiveUpFailTypeElement`|
|7.3|Continue after purchase/offer|TI|`ContinueLevelAfterOfferPurchase`, `ContinueLevelCount`|
|7.4|Heart regeneration timing|UNK|standard in genre; value not captured|

## 8. Scoring, stars, rewards
| # | Capability | Confidence | Basis |
|---|-----------|-----------|-------|
|8.1|Coin economy; rewards on clear|TI + PD|coin literals; guides|
|8.2|Collection "album" boxes (Small→Legendary), claim to chest|TI|`AddBlockCollection*Box`, `AnimateClaimToChest`|
|8.3|Leaderboards / points|TI|`AddPointsToLeaderboard`, `AddServerScoreToLeaderboardEvent`|
|8.4|Star rating per level|UNK|not surfaced as a symbol; our game already has stars (original)|

## 9. Menus & supporting screens
Booster shop/info panels, fail/continue window, league/duel/tournament UI, season/battle
pass, collection album, daily tasks, settings/age-gate. Confidence TI (panel/UI symbols).
Exact layout/art UNK and intentionally **not** to be reproduced.

## 10. Touch controls, animation, feedback
Proximity gate VFX, countdown material, booster glow, claim-to-chest animation, rotation
tweens (`AnimateRotation*`). Confidence TI for *existence*; feel/curves UNK.

## 11. Save / session behavior
Heavy `PlayerPrefs`-style save keys for boosters, league tiers, collection season index,
pass version, daily claims. Confidence TI. Our game uses local JSON under `user://`
(original). No reference save format is adopted.

## 12. Modes / live-ops (beyond single-player campaign)
| Mode | Confidence | Basis |
|------|-----------|-------|
|PvP **Duel** vs bots (add blocks to opponent)|TI|`ActiveDuel`, `AddBlocksToOpponent`, `You … vs Bot`|
|**League** w/ tiers, can-fail, bots|TI|`BLOCK_LEAGUE*`|
|**Tournament** schedules|TI|`AddJoinedTournamentSchedule`|
|**Season** reset / **Battle pass** (BlockPass, Diamond Pass)|TI|`ApplySeasonReset`, `ActiveBlockPassVersion`|
|**Collection album** seasons|TI|`BLOCK_COLLECTION_CURRENT_SEASON_INDEX_SAVE_KEY`|

> These modes make the reference a full live-ops product. They are **out of scope for
> core gameplay parity** and are deferred (see roadmap P4+). Several (PvP w/ bots,
> leagues) carry significant original-design and server cost.

## 13. Monetization & analytics (reference only — NOT to be enabled here)
Ad mediation (AppLovin/IronSource), IAP (passes, booster packs, heart limit perks, remove
ads via offers), analytics (Firebase, AppsFlyer, Facebook). Confidence TI. Our project
keeps these **stubbed and off** per AGENTS.md until explicitly approved.

## Summary of what is and isn't established
- **Established by RE (TI):** the *existence* of color-matching timed-claim gates,
  color-switching + laser gate variants, grinder/sticky/magnet/lock/crate obstacles,
  dispenser/spawner/elevator feeders, a full booster framework (rocket, extra-time, pre,
  continue), hearts/lives, give-up/continue flow, and an extensive live-ops meta layer.
- **Established by PD:** the player-facing core loop (slide to matching door before
  timer), move dependencies, and that gates can be blocked or change color.
- **Unknown (UNK):** every numeric value and exact rule — grid sizes, timer seconds,
  booster economy, obstacle interaction rules, level count/curve, animation feel, and
  which mechanics appear at which point in progression.
