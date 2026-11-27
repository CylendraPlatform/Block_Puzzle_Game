#!/usr/bin/env bash
# Release metadata guard (CI and release builds). Checks, without reading any secret:
#   - export_presets.cfg is tracked-safe: no keystore paths, users or passwords;
#   - its version/code is an integer equal to the last row of docs/release/RELEASES.md;
#   - that last row is higher than every earlier row (codes only go up).
# Prints the code on success; exits non-zero with a reason otherwise.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
fail() { echo "release metadata: $*" >&2; exit 1; }

preset=export_presets.cfg
ledger=docs/release/RELEASES.md
[ -f "$preset" ] || fail "$preset is missing"
[ -f "$ledger" ] || fail "$ledger is missing"
if grep -qiE '^[[:space:]]*keystore/|password' "$preset"; then
	fail "$preset contains keystore or password settings; keep them in .godot/export_credentials.cfg or GODOT_ANDROID_KEYSTORE_* variables"
fi
code=$(sed -n 's/^version\/code=\([0-9][0-9]*\)[[:space:]]*$/\1/p' "$preset")
[ -n "$code" ] || fail "version/code in $preset is missing or not an integer"

codes=$(awk -F'|' '$2 ~ /^[[:space:]]*[0-9]+[[:space:]]*$/ { gsub(/[[:space:]]/, "", $2); print $2 }' "$ledger")
[ -n "$codes" ] || fail "no release rows found in $ledger"
last=$(echo "$codes" | tail -1)
earlier=$(echo "$codes" | sed '$d')
[ "$code" = "$last" ] || fail "version/code $code in $preset does not match the last ledger row ($last)"
for c in $earlier; do
	[ "$last" -gt "$c" ] || fail "ledger code $last is not higher than earlier code $c"
done
echo "$code"
