#!/usr/bin/env bash
# Write the files of one commit (default HEAD) into a new directory outside the repository, so a
# release export sees only committed content: no untracked scripts or resources, no ignored files,
# no local .godot cache or export_credentials.cfg. Uses `git archive`, so nothing in the working
# tree or the repository's refs is changed.
# Usage: tools/release/stage_release_tree.sh <new-directory> [<commit>]
set -euo pipefail
fail() { echo "stage: $*" >&2; exit 1; }
[ $# -ge 1 ] && [ $# -le 2 ] || fail "usage: stage_release_tree.sh <new-directory> [<commit>]"
dest=$1
rev=${2:-HEAD}
root=$(git rev-parse --show-toplevel)
root=$(cd "$root" && pwd -P)
commit=$(git rev-parse --verify --quiet "$rev^{commit}") || fail "unknown commit: $rev"

[ ! -e "$dest" ] || [ -z "$(ls -A "$dest")" ] || fail "destination is not empty: $dest"
parent=$(dirname "$dest")
[ -d "$parent" ] || fail "parent directory does not exist: $parent"
dest_abs="$(cd "$parent" && pwd -P)/$(basename "$dest")"
case "$dest_abs/" in "$root/"*) fail "destination must be outside the repository" ;; esac
mkdir -p "$dest_abs"

git -C "$root" archive --format=tar "$commit" | tar -x -C "$dest_abs"
echo "$commit"
