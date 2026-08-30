#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib/common.sh
source "$ROOT/lib/common.sh"
TMP_ROOT="$ROOT/.tmp-tests"
mkdir -p "$TMP_ROOT"
TMP="$(mktemp -d "$TMP_ROOT/bootstrap-working-tree.XXXXXX")"
cleanup() {
  safe_rm_rf_under "$TMP_ROOT" "$TMP"
  rmdir "$TMP_ROOT" 2>/dev/null || true
}
trap cleanup EXIT

fail() {
  printf 'FAIL %s\n' "$*" >&2
  exit 1
}

# Build a local remote whose entrypoints only record that the verified checkout
# ran. The real bootstrap scripts can then be exercised without network or OS
# package mutations.
FIXTURE_REPO="$TMP/fixture-repo"
mkdir -p "$FIXTURE_REPO/linux"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf "macos\n" > "$STARTER_KIT_PAYLOAD_MARKER"' \
  > "$FIXTURE_REPO/install.sh"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf "linux\n" > "$STARTER_KIT_PAYLOAD_MARKER"' \
  > "$FIXTURE_REPO/linux/install.sh"
git -C "$FIXTURE_REPO" init --quiet
git -C "$FIXTURE_REPO" add install.sh linux/install.sh
git -C "$FIXTURE_REPO" \
  -c user.name='Bootstrap Test' \
  -c user.email='bootstrap-test@example.invalid' \
  commit --quiet -m fixture
FIXTURE_REF="$(git -C "$FIXTURE_REPO" symbolic-ref --short HEAD)"

# Bash gives a stdin script the pseudo-source name "main" inside a function.
# A decoy cwd containing both that filename and scripts/lib.sh must never be
# mistaken for the installer source tree.
DECOY="$TMP/decoy-cwd"
mkdir -p "$DECOY/scripts"
printf 'pseudo source sentinel\n' > "$DECOY/main"
printf '%s\n' \
  'printf "decoy\n" > "$STARTER_KIT_DECOY_MARKER"' \
  'exit 97' \
  > "$DECOY/scripts/lib.sh"

run_piped_bootstrap() {
  local platform="$1" installer="$2" expected="$3"
  local clone_dir="$TMP/$platform-clone"
  local payload_marker="$TMP/$platform-payload"
  local decoy_marker="$TMP/$platform-decoy"

  if ! (
    cd "$DECOY"
    STARTER_KIT_REPO="$FIXTURE_REPO" \
    STARTER_KIT_DIR="$clone_dir" \
    STARTER_KIT_BRANCH="$FIXTURE_REF" \
    STARTER_KIT_PAYLOAD_MARKER="$payload_marker" \
    STARTER_KIT_DECOY_MARKER="$decoy_marker" \
      bash -s -- --list < "$installer"
  ) >/dev/null 2>&1; then
    fail "$platform piped bootstrap did not execute its verified checkout"
  fi
  [[ ! -e "$decoy_marker" ]] \
    || fail "$platform piped bootstrap sourced code from its current directory"
  [[ -f "$payload_marker" && "$(<"$payload_marker")" == "$expected" ]] \
    || fail "$platform piped bootstrap did not hand off to the cloned payload"
}

run_piped_bootstrap macos "$ROOT/install.sh" macos
run_piped_bootstrap linux "$ROOT/linux/install.sh" linux
printf 'ok   piped bootstraps ignore decoy working-tree code\n'

# An existing Linux checkout whose tracked payload was modified must be rejected
# before fetch/checkout can retain and execute that local content.
DIRTY_CHECKOUT="$TMP/dirty-checkout"
git clone --quiet --branch "$FIXTURE_REF" "$FIXTURE_REPO" "$DIRTY_CHECKOUT"
DIRTY_MARKER="$TMP/dirty-payload"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf "dirty\n" > "$STARTER_KIT_PAYLOAD_MARKER"' \
  > "$DIRTY_CHECKOUT/linux/install.sh"
mkdir -p "$TMP/neutral-cwd"
status=0
(
  cd "$TMP/neutral-cwd"
  STARTER_KIT_REPO="$FIXTURE_REPO" \
  STARTER_KIT_DIR="$DIRTY_CHECKOUT" \
  STARTER_KIT_BRANCH="$FIXTURE_REF" \
  STARTER_KIT_PAYLOAD_MARKER="$DIRTY_MARKER" \
    bash -s -- --list < "$ROOT/linux/install.sh"
) >/dev/null 2>&1 || status=$?
[[ "$status" -ne 0 ]] \
  || fail "Linux bootstrap accepted a dirty existing checkout"
[[ ! -e "$DIRTY_MARKER" ]] \
  || fail "Linux bootstrap executed modified tracked content"
printf 'ok   Linux bootstrap rejects a dirty existing checkout\n'

printf 'PASS bootstrap working-tree trust boundary\n'
