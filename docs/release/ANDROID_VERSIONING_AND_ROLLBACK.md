# Android versionCode and rollback release plan (M1.3 activation)

## Current state (2026-11-27)

- Version settings live in `export_presets.cfg`, tracked since PR #24 (no secrets; CI checks
  it against `RELEASES.md`): `version/code=1`, `version/name="0.1.0"`,
  `package/unique_name="com.blockpuzzle.game"`.
- Whether any code was ever distributed through the Play Console is **not known from the
  repository**; the owner confirms it (`M1_3_ACTIVATION_CHECKLIST.md` §1).
- The local Android preset has **no release keystore configured**; every APK built so far is
  signed with the Godot editor's debug key (certificate SHA-256 `f3349434…a00fea87d`).
- No build has been published to a store. CI does not build APKs.

## Rules

1. Every build distributed outside the development machine gets a **new, higher**
   `version/code`; a code is never reused or lowered. Android and Google Play refuse a lower
   code as an update.
2. A rollback is a **new release with a higher code**, built with `gameplay/engine = legacy`.
   Installing an older APK is not a rollback path for players (plan §5.5).
3. Activation and rollback builds must be signed with the **same release key**, or players
   cannot update between them.
4. Each release adds its row to `RELEASES.md` **in the same PR** that changes
   `export_presets.cfg` (CI requires the preset code to equal the last row, and every row to be
   higher than the one before). `tools/release/build_android_release.sh` exports a
   committed-files-only copy and checks the APK's `versionCode` and signing certificate.

## Planned codes

|Release|`version/code`|`version/name`|`gameplay/engine`|Contents|
|---|---|---|---|---|
|Current dev / QA builds|1|0.1.0|legacy (QA builds also v2)|M1.3-A…D, editor touch fix|
|**Activation** (phase 1)|**2**|**0.2.0**|**v2**|Classic on the v2 GameScreen; release note `M1_3_ACTIVATION_RELEASE_NOTE.md`|
|**Rollback** (only if needed)|**3**|**0.2.1**|**legacy**|Same commit as activation except the flag|
|Next forward release after a rollback|4|0.2.2 / 0.3.0|v2 or legacy|Fix that caused the rollback|

If the activation ships without needing a rollback, the next release simply takes code 3.

## Rollback procedure (code 3)

1. Branch from the activation release commit; set `gameplay/engine = "legacy"` in
   `project.godot` (the only change) and update the shipped-default test assertion.
2. Set `version/code=3`, `version/name="0.2.1"` in `export_presets.cfg`; record them in the table
   above in the same PR.
3. Run the full regression and both CI jobs; build with the release key.
4. Device smoke test on a phone that has the activation build and real progress:
   `adb install -r` the rollback APK (never uninstall or clear data), confirm the menu level
   label and Level Select stars are unchanged, play one Classic level on the legacy route.
   `ProgressStore` stays in the rollback build and resyncs `progress.save` at startup, so the
   legacy route sees all progress made on v2 (plan §5.5, `test_progress_store`).
5. Publish with a staged rollout. Progress made on the legacy build is merged back when the
   player later updates to a v2 build again.

## Before the activation release (prerequisites)

- Create and back up a release keystore outside the repository; pass it only through the
  `GODOT_ANDROID_KEYSTORE_RELEASE_*` variables (`ANDROID_SIGNING.md`; never commit it).
- Owner confirms the highest previously distributed code.
- Owner approval of the activation PR (`gameplay/engine = v2`), separate from this plan.
  Full list: `M1_3_ACTIVATION_CHECKLIST.md`.
