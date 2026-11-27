#!/usr/bin/env bash
# Deterministic regression test for check_release_metadata.sh. Uses synthetic preset/ledger
# fixtures in a temporary directory; never reads secrets or the network.
# Usage: bash tools/release/test_check_release_metadata.sh  (exit code = number of failures)
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"
check=${CHECK_SCRIPT:-tools/release/check_release_metadata.sh}
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
failures=0

preset() { printf '[preset.0]\nname="Android"\n\n[preset.0.options]\nversion/code=%s\nversion/name="0.0.0"\n' "$1" > "$tmp/preset.cfg"; }
ledger() {
	{ echo "# ledger"; echo; echo "|Code|Name|Engine|Signing|Distributed|Commit|Notes|"; echo "|---|---|---|---|---|---|---|"
	  for c in "$@"; do echo "|$c|0.0.$c|legacy|test|no|-|-|"; done; } > "$tmp/ledger.md"
}
run() { RELEASE_PRESET="$tmp/preset.cfg" RELEASE_LEDGER="$tmp/ledger.md" bash "$check" 2>&1; }

expect_pass() { # name expected_output
	local out; if out=$(run); then
		[ "$out" = "$2" ] && echo "PASS $1" || { echo "FAIL $1: printed '$out', expected '$2'"; failures=$((failures + 1)); }
	else echo "FAIL $1: rejected: $out"; failures=$((failures + 1)); fi
}
expect_fail() { # name expected_substring
	local out; if out=$(run); then echo "FAIL $1: accepted (printed '$out')"; failures=$((failures + 1))
	elif [[ "$out" == *"$2"* ]]; then echo "PASS $1"
	else echo "FAIL $1: wrong reason: $out"; failures=$((failures + 1)); fi
}

preset 1; ledger 1;              expect_pass "single row" 1
preset 3; ledger 1 2 3;          expect_pass "strictly increasing" 3
preset 10; ledger 1 2 9 10;      expect_pass "gaps allowed" 10
# Regression: the old check only compared the last row with earlier rows, so 3 then 2 slipped through.
preset 4; ledger 1 3 2 4;        expect_fail "middle rows out of order" "ledger code 2 is not higher than the row before it (3)"
preset 3; ledger 1 2 2 3;        expect_fail "duplicate middle code" "ledger code 2 is not higher than the row before it (2)"
preset 2; ledger 1 2 2;          expect_fail "duplicate last code" "ledger code 2 is not higher than the row before it (2)"
preset 2; ledger 3 1 2;          expect_fail "first row too high" "ledger code 1 is not higher than the row before it (3)"
preset 2; ledger 1 2 3;          expect_fail "preset behind ledger" "does not match the last ledger row (3)"
preset 4; ledger 1 2 3;          expect_fail "preset ahead of ledger" "does not match the last ledger row (3)"
preset x; ledger 1;              expect_fail "non-integer code" "missing or not an integer"
preset 1; ledger;                expect_fail "empty ledger" "no release rows"
preset 1; ledger 1; echo 'keystore/release="/k.jks"' >> "$tmp/preset.cfg"
                                 expect_fail "keystore path in preset" "keystore or password"
preset 1; ledger 1; echo 'keystore/release_password="x"' >> "$tmp/preset.cfg"
                                 expect_fail "password in preset" "keystore or password"

# The real repository files must pass.
if out=$(bash "$check" 2>&1); then echo "PASS repository metadata ($out)"; else echo "FAIL repository metadata: $out"; failures=$((failures + 1)); fi

echo "check_release_metadata tests: $failures failure(s)"
exit "$failures"
