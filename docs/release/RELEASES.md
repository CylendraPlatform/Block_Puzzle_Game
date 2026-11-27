# Android release ledger

Every Android `version/code` that has been built for anyone other than a developer is recorded
here, in the same PR that changes `export_presets.cfg`. Codes only go up and are never reused.
The last row is the code currently in `export_presets.cfg`; it must be higher than every earlier
row. CI and `tools/release/build_android_release.sh` both check this.

|Code|Name|Engine|Signing|Distributed|Commit|Notes|
|---|---|---|---|---|---|---|
|1|0.1.0|legacy (QA builds also v2)|debug key (`f3349434…a00fea87d`)|no (dev / QA devices only)|various|All builds to date. No store listing or distributed APK is known from the repository; the owner confirms in the Play Console before the first release.|

Planned (not built yet): code 2 / 0.2.0 activation (`v2`), code 3 / 0.2.1 rollback (`legacy`) —
see `ANDROID_VERSIONING_AND_ROLLBACK.md`. Add a row when a release build is made.
