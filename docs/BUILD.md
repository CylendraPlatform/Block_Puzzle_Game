# BUILD — Reproducible Android build (Godot 4.7.2)

## Toolchain (verified 2026-11-23)
- **Godot 4.7.2-stable** editor: `D:\Tools\Godot\Godot_v4.7.2-stable_win64.exe` (console variant `_console.exe` for CLI).
- **Export templates** 4.7.2.stable: installed at `%APPDATA%\Godot\export_templates\4.7.2.stable\`.
- **Android SDK**: `D:\Android\Sdk` (build-tools 36.0.0 used for apksigner; platforms 35/36; NDK 27).
- **JDK**: `C:\Program Files\Java\jdk-21.0.11` (Godot `export/android/java_sdk_path`).
- **Debug keystore**: auto-generated at `%APPDATA%\Godot\keystores\debug.keystore` (pass `android`).

Godot editor settings (`%APPDATA%\Godot\editor_settings-4.7.tres`) already hold the SDK/JDK/keystore paths above. These are machine-global, not in the repo.

## Export preset
`export_presets.cfg` -> preset **"Android"**, package `com.blockpuzzle.game`, arm64-v8a + armeabi-v7a, `use_gradle_build=false` (repacks the prebuilt template — no Android Studio/Gradle needed), no INTERNET permission.

## Build a debug APK (headless, one command)
```bash
GODOT="D:/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe"
"$GODOT" --headless --path . --export-debug "Android" build/android/BlockPuzzle-debug.apk
```
Output: `build/android/BlockPuzzle-debug.apk` (~55 MB; signed with the debug keystore, verified by apksigner).

The local `export_presets.cfg` is gitignored. Its `include_filter` must list `levels/*.json`, `levels_v2/pilot/*.json`, and `levels_v2/td36/*.json`, or the debug APK will omit those JSON packs. Debug exports show **Editor**, **v2 Pilot**, and **TD-3.6 QA** because `OS.is_debug_build()` is true. A release export does not. Signing stays on the machine debug keystore at `%APPDATA%\Godot\keystores\debug.keystore`. Do not commit that keystore or an APK.

A TD-3 QA package uses the same debug preset and this output path:

```bash
"$GODOT" --headless --path . --export-debug "Android" build/android/BlockPuzzle-TD3-QA-debug.apk
```

A TD-3.6 QA package uses the same preset:

```bash
"$GODOT" --headless --path . --export-debug "Android" build/android/BlockPuzzle-TD36-QA-debug.apk
```

## Smoke-test without a device (headless)
```bash
"$GODOT" --headless --path .
# expect: "Block Puzzle Game booted ..." then "headless smoke OK"
```

## Install / run on the emulator
```bash
ADB="D:/Android/Sdk/platform-tools/adb.exe"
"D:/Android/Sdk/emulator/emulator.exe" -avd Pixel_10_Pro_XL &   # start AVD
"$ADB" wait-for-device
"$ADB" install -r build/android/BlockPuzzle-debug.apk
"$ADB" shell monkey -p com.blockpuzzle.game -c android.intent.category.LAUNCHER 1
```

## Release build (later)
Generate a release keystore (`keytool -genkeypair ...`), set it in the export preset's release signing fields, then `--export-release "Android" <out>.apk` (or AAB via `gradle_build/export_format=1` with `use_gradle_build=true`). Do **not** commit keystores.

## Notes
- First `--export-debug` on a clean checkout may need `--import` once to generate `.godot/`.
- `build/`, `*.apk`, `*.keystore`, `.godot/` are git-ignored.
