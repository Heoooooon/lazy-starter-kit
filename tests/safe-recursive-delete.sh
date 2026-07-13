#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/lib/common.sh"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
expect_reject() {
  if safe_rm_rf_under "$@" >/dev/null 2>&1; then
    fail "expected rejection: $*"
  fi
}

TMP_BASE="${TMPDIR:-/tmp}"; TMP_BASE="${TMP_BASE%/}"
TMP_ROOT="$(mktemp -d "$TMP_BASE/lsk-safe-delete.XXXXXX")"
trap 'safe_rm_rf_under "$TMP_BASE" "$TMP_ROOT" >/dev/null 2>&1 || true' EXIT
allowed="$TMP_ROOT/allowed"
outside="$TMP_ROOT/outside"
mkdir -p "$allowed" "$outside"
printf 'keep\n' > "$outside/sentinel"

mkdir -p "$allowed/child/nested"
printf 'remove\n' > "$allowed/child/nested/file"
safe_rm_rf_under "$allowed" "$allowed/child"
[[ ! -e "$allowed/child" && -f "$outside/sentinel" ]] || fail 'valid child deletion crossed its boundary'

safe_rm_rf_under "$allowed" "$allowed/missing"

mkdir -p "$allowed/first"
expect_reject "$allowed" "$allowed/first" "$outside"
[[ -d "$allowed/first" ]] || fail 'batch validation deleted a safe target before rejecting an unsafe target'

expect_reject "$allowed" "$allowed"
expect_reject "$allowed" /
expect_reject "$allowed" relative
expect_reject "$allowed" ''
expect_reject "$allowed" "$allowed/../outside"
expect_reject "$allowed" "$TMP_ROOT/allowed-sibling"

ln -s "$outside" "$allowed/link"
expect_reject "$allowed" "$allowed/link"
expect_reject "$allowed" "$allowed/link/child"
[[ -f "$outside/sentinel" ]] || fail 'symlink rejection did not protect the outside sentinel'

mkdir -p "$allowed/path with spaces/한글" "$allowed/-leading-dash"
safe_rm_rf_under "$allowed" "$allowed/path with spaces/한글" "$allowed/-leading-dash"
[[ ! -e "$allowed/path with spaces/한글" && ! -e "$allowed/-leading-dash" ]] || fail 'literal path deletion failed'

mkdir -p "$allowed/dry-run"
DRY_RUN=1 safe_rm_rf_under "$allowed" "$allowed/dry-run" >/dev/null
[[ -d "$allowed/dry-run" ]] || fail 'dry-run deleted a target'

recursive_lines="$(grep -RnsE '(^|[[:space:]])(run[[:space:]]+)?rm[[:space:]]+-[^[:space:]]*[rR]' \
  "$ROOT/lib" "$ROOT/scripts" "$ROOT/linux" "$ROOT/uninstall.sh" 2>/dev/null || true)"
[[ "$(printf '%s\n' "$recursive_lines" | grep -c . || true)" == "1" ]] \
  || fail "recursive rm escaped the shared helper:\n$recursive_lines"
[[ "$recursive_lines" == "$ROOT/lib/common.sh:"* ]] \
  || fail "recursive rm primitive is not in lib/common.sh: $recursive_lines"

printf 'ok: recursive deletion is confined to a validated strict descendant\n'
