# Android release signing

Nothing secret is ever committed: no keystore file (`*.keystore`, `*.jks` are gitignored), no
alias, no password. Godot 4.7 stores keystore settings as secret export options in
`.godot/export_credentials.cfg` (gitignored) and also reads them from environment variables
(`platform/android/export/export_plugin.cpp`, `get_or_env`):

|Variable|Value|
|---|---|
|`GODOT_ANDROID_KEYSTORE_RELEASE_PATH`|absolute path of the release keystore, **outside** this repository|
|`GODOT_ANDROID_KEYSTORE_RELEASE_USER`|key alias|
|`GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD`|keystore / key password|

`tools/release/build_android_release.sh` uses only these variables. It refuses to run when any
is missing, when the keystore lies inside the repository, when tracked files have uncommitted
changes, when `export_presets.cfg` and `docs/release/RELEASES.md` disagree, when the APK's
`versionCode` differs from the preset, or when the APK is signed with the development debug key.
It writes `build/release/<name>.json` with the commit, version, engine flag, signing
certificate SHA-256 and APK SHA-256 (no secrets).

The export never runs on the working tree. `tools/release/stage_release_tree.sh` copies the
committed files of `HEAD` (`git archive`) into a new temporary directory outside the repository;
the script imports and exports that copy, then deletes it. The preset uses
`export_filter="all_resources"`, so an in-place export packs everything under `res://`:
a check on 2026-11-27 found a debug export of the working tree carried 658 extra entries from
the gitignored `build/` folder (QA screenshots and a compiled scratch QA script) that the staged
export did not. Untracked, ignored and uncommitted files, and the local
`.godot/export_credentials.cfg`, cannot reach a release build. The keystore stays where the
environment variable points, outside both directories.

## Creating the release key (owner, once)

Run on a trusted machine; `keytool` asks for the passwords interactively, so they never appear
in shell history:

```sh
keytool -genkeypair -v -keystore <outside-the-repo>/blockpuzzle-upload.jks -alias blockpuzzle-upload -keyalg RSA -keysize 4096 -validity 10000
```

- Keep at least two offline backups of the `.jks` and store the password in a password manager.
  Losing the key means no further updates can be published under the same signing identity.
- With **Play App Signing** (recommended), this key is the *upload* key; Google re-signs with
  the app signing key it holds. Devices that install from Play see Google's app signing
  certificate, not the upload certificate. Record both SHA-256 fingerprints in
  `RELEASES.md` when the app is created in the Play Console.

## Debug-signed installs vs release-signed builds

Every build so far, including the one on the Galaxy M31 used for QA, is signed with the Godot
debug key (`f3349434…a00fea87d`). Android only updates an installed app with an APK signed by
the **same** key:

- A release-signed APK cannot be installed over a debug-signed install of
  `com.blockpuzzle.game`; `adb install -r` fails with `INSTALL_FAILED_UPDATE_INCOMPATIBLE`.
- **Do not uninstall or clear data to get around it.** That deletes the local progress; on the
  Galaxy M31 it is not permitted at all.
- Development devices (including the M31) stay on debug builds for daily work.
- Release-candidate QA runs on a device or Android user profile that has **no** debug install,
  or through the Play internal testing track on such a device.
- Optional side-by-side check: a second export preset with package `com.blockpuzzle.game.rc`
  installs next to the debug app with its own, separate data. It cannot test progress
  migration from an existing install, so it does not replace the M31 debug-build QA.
- Players: no debug APK has been distributed (`RELEASES.md`), so players never hold a
  debug-signed install and see no mismatch. If a debug build was ever given to a tester, that
  tester must uninstall it (losing local progress) before installing a release build — an owner
  decision, case by case.
