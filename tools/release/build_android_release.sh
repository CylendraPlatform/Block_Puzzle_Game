#!/usr/bin/env bash
# Build a release-signed Android APK and record reproducible metadata next to it.
# Secrets come only from the environment and are never printed or written:
#   GODOT_ANDROID_KEYSTORE_RELEASE_PATH      keystore file, outside this repository
#   GODOT_ANDROID_KEYSTORE_RELEASE_USER      key alias
#   GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD  keystore / key password
# (Godot 4.7 reads these in platform/android/export/export_plugin.cpp via get_or_env.)
# Optional: GODOT (editor binary), ANDROID_BUILD_TOOLS (directory with aapt2 and apksigner).
# Usage: tools/release/build_android_release.sh
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
root=$(pwd -P)
fail() { echo "release: $*" >&2; exit 1; }

GODOT=${GODOT:-D:/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe}
BUILD_TOOLS=${ANDROID_BUILD_TOOLS:-$(ls -d /d/Android/Sdk/build-tools/*/ 2>/dev/null | tail -1)}
# Debug key used for every development build so far: a release must not be signed with it.
DEBUG_CERT_SHA256=f3349434a95846500d88ee18a114d1d6e135498667674956d39e719a00fea87d

for v in GODOT_ANDROID_KEYSTORE_RELEASE_PATH GODOT_ANDROID_KEYSTORE_RELEASE_USER GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD; do
	[ -n "${!v:-}" ] || fail "$v is not set"
done
ks="$GODOT_ANDROID_KEYSTORE_RELEASE_PATH"
[ -f "$ks" ] || fail "release keystore file not found"
ks_dir=$(cd "$(dirname "$ks")" && pwd -P)
case "$ks_dir/" in "$root/"*) fail "the release keystore must be stored outside the repository" ;; esac

[ -z "$(git status --porcelain --untracked-files=no)" ] || fail "commit or stash tracked changes first; a release is built from a clean commit"
code=$(tools/release/check_release_metadata.sh)
name=$(sed -n 's/^version\/name="\(.*\)"[[:space:]]*$/\1/p' export_presets.cfg)
engine=$(sed -n 's/^engine="\(.*\)"[[:space:]]*$/\1/p' project.godot)
commit=$(git rev-parse HEAD)
[ -n "$name" ] || fail "version/name missing in export_presets.cfg"
[ -n "$engine" ] || fail "gameplay/engine missing in project.godot"

out="$root/build/release"
mkdir -p "$out"
apk="$out/BlockPuzzle-$name-$code-$engine.apk"
log="$out/export-$code.log"

# Export from a fresh copy of HEAD outside the repository. The preset uses
# export_filter="all_resources", so exporting this working tree would also pack any untracked or
# ignored file under res://; the staged copy holds committed files only. Credentials still come
# only from the GODOT_ANDROID_KEYSTORE_RELEASE_* variables above.
stage_parent=$(mktemp -d)
trap 'rm -rf "$stage_parent"' EXIT
stage="$stage_parent/project"
staged_commit=$(tools/release/stage_release_tree.sh "$stage" "$commit")
[ "$staged_commit" = "$commit" ] || fail "staged $staged_commit, expected $commit"
[ ! -e "$stage/.godot" ] || fail "staged tree unexpectedly contains .godot"
"$GODOT" --headless --path "$stage" --import > "$log" 2>&1 || fail "import of the staged tree failed; see $log"
"$GODOT" --headless --path "$stage" --export-release "Android" "$apk" >> "$log" 2>&1 || fail "export failed; see $log"
[ -f "$apk" ] || fail "export produced no APK"

aapt2="$BUILD_TOOLS/aapt2"
apksigner="$BUILD_TOOLS/apksigner"
[ -f "$apksigner.bat" ] && apksigner="$apksigner.bat"
badging=$("$aapt2" dump badging "$apk" | head -1)
apk_code=$(echo "$badging" | sed -n "s/.*versionCode='\([0-9]*\)'.*/\1/p")
apk_name=$(echo "$badging" | sed -n "s/.*versionName='\([^']*\)'.*/\1/p")
[ "$apk_code" = "$code" ] || fail "APK versionCode $apk_code does not match export_presets.cfg ($code)"
cert=$("$apksigner" verify --print-certs "$apk" | sed -n 's/.*certificate SHA-256 digest: \([0-9a-f]*\).*/\1/p' | head -1)
[ -n "$cert" ] || fail "apksigner could not verify the APK"
[ "$cert" != "$DEBUG_CERT_SHA256" ] || fail "the APK is signed with the development debug key"
apk_sha=$(sha256sum "$apk" | cut -d' ' -f1)

cat > "$out/BlockPuzzle-$name-$code-$engine.json" <<EOF
{
  "version_code": $code,
  "version_name": "$apk_name",
  "gameplay_engine": "$engine",
  "commit": "$commit",
  "signing_cert_sha256": "$cert",
  "apk_sha256": "$apk_sha",
  "godot": "$("$GODOT" --version | tr -d '\r')"
}
EOF
echo "release: built $apk (code $code, $engine, cert ${cert:0:16}…); metadata written next to it."
echo "release: add or confirm the ledger row in docs/release/RELEASES.md with this commit and certificate."
