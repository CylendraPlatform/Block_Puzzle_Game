# Reference Evidence Register — Color Block Jam (Phase REA-02)

**Reference subject:** `com.GybeGames.ColorBlockJam`, version 13.2.0 (Rollic / Gybe Games).
**Engine:** Unity, IL2CPP, arm64-v8a.
**Local reference package (NOT committed, NOT uploaded):**
`C:\Users\derma\Documents\GameReferenceResearch\ColorBlockJam\` — `base.apk`,
`split_UnityDataAssetPack.apk`, `split_config.arm64_v8a.apk`.
**Date of analysis:** 2026-11-25.

> Purpose: record exactly *how* each reference claim is supported, so no inference is
> mistaken for a confirmed feature. This register is the source of truth for the
> confidence tags used in `REFERENCE_FEATURE_INVENTORY.md`.

## Evidence classes

| Tag | Meaning | What it can and cannot prove |
|-----|---------|------------------------------|
| **DO** Directly observed | Seen running in live gameplay / captured screenshot or video | Proves runtime behavior. **Not used in this phase** — the reference package contained APKs only; no gameplay capture, screenshots, or video were available. |
| **PD** Public documentation | Stated by Rollic help center or a third-party guide | Proves the publisher/community *describes* the behavior. Version- and source-dependent. |
| **TI** Technically indicated (RE) | A named type / method / field / save-key is present in the IL2CPP `global-metadata.dat` | Proves the shipped binary *contains code* for the named system. **Does not** prove the behavior's tuning, the exact rules, or that it appears in any given level. |
| **INF** Inferred | A reasonable deduction from TI + PD, not independently confirmed | A hypothesis. Flagged as such everywhere. |
| **UNK** Unknown | Not established by any of the above | Requires live testing or additional capture. |

## What REA actually did

1. `open_binary` on `base.apk` (sha256 `083da716…50bd3`), `inspect_artifact` → located
   `assets/bin/Data/Managed/Metadata/global-metadata.dat` (19.5 MB).
2. `extract_artifact` → materialized the APK's regular files to a REA temp dir.
3. Offline token scan of `global-metadata.dat` (printable-ASCII, identifier-shaped
   tokens, ~123,694 distinct). IL2CPP retains managed type/method/field names in this
   file, so these tokens are genuine symbol names from the shipped game code and its
   embedded SDKs.
4. No native disassembly of `libil2cpp.so` was performed in this pass (it lives in the
   `split_config.arm64_v8a.apk` slice). Symbol-name evidence below is therefore
   **declaration-level**, not control-flow-level.

**REA did NOT:** run the game, read Unity asset bundles / level data, decrypt remote
config, extract art/audio, or establish any runtime value (timer seconds, grid sizes,
booster costs, level counts). None of that is claimed anywhere in this research.

## TI evidence log — representative symbols found in `global-metadata.dat`

Grouped by the system they indicate. Each row is a verbatim symbol substring observed
in the metadata token set. Presence = the code declares it; behavior is not proven.

### Core movement, gates, "claim" (block exit)
- `GateOpen`, `OpenGate`, `ApplyGateColorToProximityVfxs`, `TintParticlesToGateColor`
- `CLAIM_OPEN_GATE_TIMEOUT_SECONDS`, `CLAIM_DRAIN_ARM_TIMEOUT_SECONDS`,
  `CLAIM_BOWL_SETTLE_TIMEOUT_SECONDS` (block exit is modeled as a timed "claim")
- `AddCell`, `AddEmptyCell`, `AlignmentOfCellsInGroup`, `ApplyGridSpacing`,
  `AllocateDynamicBlockId`, `AddBlockGroup`, `AppendUnitBlockCounts`

### Gate variants (color-switching, laser)
- `DoorColorChanger`, `DoorColorSwitcher`, `ColorfulJumpingDoorColorIndex`,
  `LaserDoorColorIndex`, `FailedGateColorChanger`, `gateColorSwitcherFail`

### Obstacles / special block types
- `AddGrinderBlocks`, `AnimateGrinderWithAnimateItemOrProceed` (grinder)
- `AddStickyPieces` (sticky pieces)
- `AddMagnetPoint`, `ApplyDrainMagnet`, `drainMagnetAccel` (magnet / drain)
- `AddLock`, `AddJoinedLocks`, `AddJoinedLockDatas` (locks)
- `ActivateUnderCrateObject` (crate / cover)
- Feeders: `AnyDispenserHasQueuedBlockOfType`, `AnyDispenserPermanentlyBlocked`,
  `AnySpawnerHasQueuedBlockOfType`, `AnyElevatorHasQueuedBlockOfType`

### Boosters / assistance
- `Booster`, `BoosterButton`, `ApplyBoosterSlots`, `ApplyTimedBoosterSlots`,
  `AnyActiveBooster`, `BoosterPurchasedEvent`, `BoosterPriceRow`, `BoosterInfoPanel`
- `AutoRocket`, `AddAutoRocketAction`, `AddTimedRocketBoosterTime` (rocket)
- `AddTimedTimeIncreaserBoosterTime`, `ArmFirstRoundsExtraTime` (extra time)
- `AddedTimedPreBoosterEvent` (pre-level booster), `ActivateContinueBoosterUI` (continue)
- `BOOSTER_FREE_USE_COUNT_PREFIX_SAVE_KEY`, `BOOSTER_TUTORIAL_SHOWN_PREFIX_SAVE_KEY`

### Timer / win / fail / continue
- `Countdown`, `CountdownTimerCoroutine`, `CountdownFrom`, `CountdownTo`,
  `CountdownCompleteEvent`, `CanTimeout`, `CheckTimers`, `ApplyTimerPlacement`
- `ArmTimerBombOnExit` (timer-bomb object), `BRICK_FLY_TIMEOUT_MS`
- `ContinueLevel`, `ContinueLevelAfterOfferPurchase`, `ContinueLevelCount`,
  `GiveUp`, `GiveUpContext`, `GiveUpRunLosePanel`, `FailWindowGiveUpFailTypeElement`

### Lives / economy
- `GetHeartLimit`, `DEFAULTH_MAX_HEARTH_AMOUNT`, `HasHeartLimitPerk`,
  `HasDiamondHeartLimitPerk`, `DIAMOND_PASS_BOUGHT_HEARTH_AMOUNT` (hearts = lives)
- `You received extra {0} coins due to the economy update` (coin economy literal)

### Meta-progression & modes (live-ops)
- PvP: `AddBlocksToOpponent`, `AddBlocksToPlayer`, `ActiveDuel`, `AdminSetDuelTargetScore`,
  `AreBotTimersPaused`, `You {0} (+{1} live) vs Bot {2}` (bot opponents)
- League: `BLOCK_LEAGUE`, `BLOCK_LEAGUE_CURRENT_TIER_KEY`, `BLOCK_LEAGUE_CAN_FAIL_KEY`,
  `AllLeagueRewards`, `Admin_SetLeagueBots`
- Tournament: `AddJoinedTournamentSchedule`, `AreTournamentDatasEqual`
- Season / battle pass: `ApplySeasonReset`, `ActiveBlockPassVersion`, `DIAMOND_PASS…`
- Collection album: `AddBlockCollection{Small,Medium,Large,Super,Legendary}Box`,
  `BLOCK_COLLECTION_CURRENT_SEASON_INDEX_SAVE_KEY`, `AnimateClaimToChest`
- Daily tasks / rewards: `AutoClaimDailyTasks`, `AddClaimCollectionBoxesProgress`,
  `AddPendingTierClaim`, `AddRewardToClaimedList`, leaderboards (`AddPointsToLeaderboard`)

### Third-party SDKs observed (names only; not our concern to reproduce)
Firebase, AppsFlyer, Facebook, Google, AppLovin/IronSource (ad mediation), UniWebView,
ZLinq. Listed only to characterize the reference build as a commercial live-ops title.

## PD evidence log — public documentation (one standard web search, 2026-11-25)

Rollic help center + third-party guides/app listings. Treated as **PD**, lower
confidence than TI, and explicitly cross-checked against the risk that several search
hits describe *different* games ("Block Jam", "Gem Jam", "Color Block: Puzzle Block Jam").

- Core loop: slide colored blocks across a grid to **matching-color doors/gates**,
  goal = clear all colored blocks **before the timer runs out**. (Rollic help center.)
- **Move dependencies:** some blocks must move before others; identifying these matters.
- **Gates:** "may be blocked or change color"; one guide describes a gate that **peels
  off the top layer** when the first block reaches it, freeing the next block.
- **Timer:** levels are timed; guides advise deliberate moves when time is low.
- **Boosters:** reported sets vary by source and version — Freeze (stop timer), Hammer,
  Magic Wand, "Destroy Color", "Rainbow/any-color gate". **Low confidence**: some of
  these are explicitly from *Gem Jam*, a similar but different title. Tagged UNK/INF in
  the inventory unless also TI-supported.
- Progression: clearing a grid earns coins; harder levels unlock as you advance.

Sources:
- https://rollic.helpshift.com/hc/en/24-color-block-jam/faq/1222-how-do-i-play-color-block-jam
- https://rollic.helpshift.com/hc/en/24-color-block-jam/faq/570-what-are-the-obstacles-1737731206
- https://apps.apple.com/us/app/color-block-jam/id6504332779
- https://pipspuzzle.com/game/guides/color-block-jam-guide

## Integrity and limitations

- Symbol tokens are declaration-level; a few may belong to shared Rollic/SDK libraries
  rather than this game's puzzle code. Where a system rests on a single ambiguous token
  it is tagged INF, not TI.
- No gameplay was observed. Every runtime value is UNK.
- This register will be extended if a later pass disassembles `libil2cpp.so` or captures
  live gameplay. Until then, do not promote any TI/PD item to DO.
