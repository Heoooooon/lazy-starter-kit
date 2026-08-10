#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/lib/common.sh"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

TMP_ROOT="$ROOT/.tmp-tests"
mkdir -p "$TMP_ROOT"
TMP="$(mktemp -d "$TMP_ROOT/update-kit.XXXXXX")"
cleanup() {
  safe_rm_rf_under "$TMP_ROOT" "$TMP"
  rmdir "$TMP_ROOT" 2>/dev/null || true
}
trap cleanup EXIT

repo="$TMP/checkout"
mkdir -p "$repo"
git -C "$repo" init -q
git -C "$repo" config user.name test
git -C "$repo" config user.email test@example.com
printf '0.0.0\n' > "$repo/VERSION"
git -C "$repo" add VERSION
git -C "$repo" commit -qm initial
git -C "$repo" checkout -q --detach HEAD
git -C "$repo" remote add origin "$TMP/missing-origin"

set +e
output="$(
  set -e
  STARTER_KIT_BRANCH='' update_kit "$repo" 2>&1
)"
status=$?
set -e

[[ "$status" -ne 0 ]] || fail "detached update unexpectedly succeeded"
[[ "$output" == *"git fetch of 'main' failed"* ]] \
  || fail "detached update hid the remote failure: $output"

printf 'ok: detached update reports an unreachable release remote\n'
