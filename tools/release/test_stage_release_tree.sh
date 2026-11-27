#!/usr/bin/env bash
# Deterministic test for stage_release_tree.sh: in a throwaway git repository, the staged copy
# must contain committed files only (not untracked, ignored, .godot or uncommitted edits), and
# the script must refuse a destination inside the repository or a non-empty one.
# Usage: bash tools/release/test_stage_release_tree.sh  (exit code = number of failures)
set -uo pipefail
stage_script="$(cd "$(git rev-parse --show-toplevel)" && pwd -P)/tools/release/stage_release_tree.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
failures=0
ok() { echo "PASS $1"; }
bad() { echo "FAIL $1"; failures=$((failures + 1)); }

repo="$tmp/repo"
mkdir -p "$repo/scripts" "$repo/levels"
cd "$repo"
git init -q
git config user.name test
git config user.email test@example.invalid
git config core.autocrlf false
printf 'tracked\n' > scripts/game.gd
printf '{}\n' > levels/001.json
printf '.godot/\nbuild/\n' > .gitignore
git add -A
git commit -q -m fixture
committed=$(git rev-parse HEAD)
# Working-tree content that must never reach a release:
printf 'untracked\n' > scripts/stray.gd
printf 'untracked\n' > scripts/game.gd.uid
mkdir -p .godot build
printf 'secret-free placeholder\n' > .godot/export_credentials.cfg
printf 'ignored\n' > build/out.apk
printf 'edited\n' > scripts/game.gd

out=$(bash "$stage_script" "$tmp/stage" 2>&1) && [ "$out" = "$committed" ] && ok "prints the staged commit" || bad "prints the staged commit ($out)"
[ -f "$tmp/stage/scripts/game.gd" ] && [ -f "$tmp/stage/levels/001.json" ] && ok "committed files present" || bad "committed files present"
[ "$(cat "$tmp/stage/scripts/game.gd" 2>/dev/null)" = "tracked" ] && ok "committed content, not working-tree edit" || bad "committed content, not working-tree edit"
[ ! -e "$tmp/stage/scripts/stray.gd" ] && [ ! -e "$tmp/stage/scripts/game.gd.uid" ] && ok "untracked files absent" || bad "untracked files absent"
[ ! -e "$tmp/stage/.godot" ] && ok ".godot (credentials cache) absent" || bad ".godot (credentials cache) absent"
[ ! -e "$tmp/stage/build" ] && ok "ignored files absent" || bad "ignored files absent"
staged=$(cd "$tmp/stage" && find . -type f | sed 's|^\./||' | sort | tr '\n' ' ')
[ "$staged" = ".gitignore levels/001.json scripts/game.gd " ] && ok "staged file list exact" || bad "staged file list exact ($staged)"
[ "$(git status --porcelain | tr '\n' ' ')" = " M scripts/game.gd ?? scripts/game.gd.uid ?? scripts/stray.gd " ] && [ "$(cat scripts/game.gd)" = "edited" ] && ok "source working tree untouched" || bad "source working tree untouched"

bash "$stage_script" "$repo/inside" >/dev/null 2>&1 && bad "refuses destination inside repo" || ok "refuses destination inside repo"
[ ! -e "$repo/inside" ] && ok "creates nothing inside repo on refusal" || bad "creates nothing inside repo on refusal"
bash "$stage_script" "$tmp/stage" >/dev/null 2>&1 && bad "refuses non-empty destination" || ok "refuses non-empty destination"
bash "$stage_script" "$tmp/stage2" no-such-rev >/dev/null 2>&1 && bad "refuses unknown commit" || ok "refuses unknown commit"

echo "stage_release_tree tests: $failures failure(s)"
exit "$failures"
