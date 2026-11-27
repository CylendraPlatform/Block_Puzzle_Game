# Android versionCode and rollback release plan (M1.3 activation)

## Current state (2026-11-27)

- Version settings live in `export_presets.cfg`, which is **gitignored** (`.gitignore`), so
  they exist only on the build machine: `version/code=1`, `version/name="0.1.0"`,
  `package/unique_name="com.blockpuzzle.game"`.
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
4. Because `export_presets.cfg` is not tracked, each release records its `version/code`,
   `version/name`, commit and engine flag in the table below **in the same PR** that prepares
   the release, and the built APK is checked before upload:
   `"<build-tools>/aapt2" dump badging <apk> | grep -E "versionCode|versionName"` and
   `apksigner verify --print-certs <apk>`.

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

- Create and back up a release keystore; configure it in the build machine's preset (never
  commit it; `*.keystore` is gitignored).
- Decide whether to track a sanitised `export_presets.cfg` (no passwords) so version codes are
  reviewable in Git; until then, the table above is the record.
- Owner approval of the activation PR (`gameplay/engine = v2`), separate from this plan.
