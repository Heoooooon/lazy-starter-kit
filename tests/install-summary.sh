#!/usr/bin/env bash
# install-summary.sh — macOS installer results board, install log and Homebrew
# pre-flight. Runs the real install.sh/lib files with harmless step bodies.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/common.sh
source "$ROOT/lib/common.sh"

TMP_ROOT="$ROOT/.tmp-tests"
mkdir -p "$TMP_ROOT"
TMP="$(mktemp -d "$TMP_ROOT/install-summary.XXXXXX")"
cleanup() {
  safe_rm_rf_under "$TMP_ROOT" "$TMP"
  rmdir "$TMP_ROOT" 2>/dev/null || true
}
trap cleanup EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

# --- unit: homebrew_preflight / kit_user_is_admin ----------------------------
unit() {
  # Each case runs in a subshell so stubs never leak between cases.
  (
    # shellcheck source=scripts/lib.sh
    source "$ROOT/scripts/lib.sh"
    BREW_STATE="$1" ADMIN="$2" TTY="$3" DRY_RUN="$4" ASSUME_YES="$5"
    mkdir -p "$TMP/brew/bin"; : > "$TMP/brew/bin/brew"; chmod +x "$TMP/brew/bin/brew"
    brew_prefix() { if [[ "$BREW_STATE" == present ]]; then echo "$TMP/brew"; else echo "$TMP/no-brew"; fi; }
    kit_user_is_admin() { [[ "$ADMIN" == 1 ]]; }
    kit_has_tty() { [[ "$TTY" == 1 ]]; }
    status=0
    homebrew_preflight >/dev/null 2>&1 || status=$?
    if [[ "$status" != 0 && ( -z "$KIT_PREFLIGHT_REASON" || -z "$KIT_PREFLIGHT_FIX" ) ]]; then
      echo "missing-guidance"; exit 0
    fi
    echo "$status"
  )
}
expect_unit() {
  local expected="$1" label="$2" got
  shift 2
  got="$(unit "$@")"
  [[ "$got" == "$expected" ]] || fail "preflight $label: expected $expected, got $got"
  printf 'ok   preflight %s\n' "$label"
}
#             expected label                          brew    admin tty dry yes
expect_unit 0 "passes when Homebrew is present"       present 0     0   0   0
expect_unit 0 "passes for a dry-run"                  missing 0     0   1   0
expect_unit 1 "stops a non-admin account"             missing 0     1   0   0
expect_unit 1 "stops a non-admin account under --yes" missing 0     0   0   1
expect_unit 1 "stops without a terminal"              missing 1     0   0   0
expect_unit 0 "lets --yes run without a terminal"     missing 1     0   0   1
expect_unit 0 "passes an admin in a terminal"         missing 1     1   0   0

admin_with() {
  local reply="$1" groups="$2" fake="$TMP/fake-admin-bin"
  mkdir -p "$fake"
  printf '#!/bin/bash\nprintf "%%s\\n" "%s"\n' "$reply" > "$fake/dseditgroup"
  printf '#!/bin/bash\n[[ "$1" == -Gn ]] && { printf "%%s\\n" "%s"; exit 0; }\n/usr/bin/id "$@"\n' "$groups" > "$fake/id"
  chmod +x "$fake/dseditgroup" "$fake/id"
  ( PATH="$fake:$PATH"; source "$ROOT/scripts/lib.sh"; kit_user_is_admin && echo admin || echo user )
}
[[ "$(admin_with 'yes alice is a member of admin' 'staff')" == admin ]] || fail "dseditgroup member not detected"
[[ "$(admin_with 'no alice is NOT a member of admin' 'staff admin')" == user ]] || fail "dseditgroup non-member not detected"
[[ "$(admin_with 'Group not found.' 'staff admin everyone')" == admin ]] || fail "group-list fallback ignored admin"
[[ "$(admin_with 'Group not found.' 'staff everyone')" == user ]] || fail "group-list fallback accepted a non-admin"
printf 'ok   admin detection (dseditgroup + group-list fallback)\n'

( set -e; source "$ROOT/scripts/lib.sh"; brew_prefix() { echo "$TMP/no-brew"; }; load_brew ) \
  || fail "load_brew fails without Homebrew, killing a fresh-Mac dry-run under set -e"
printf 'ok   load_brew tolerates a Mac without Homebrew\n'

# --- end to end: real install.sh, harmless steps ------------------------------
KIT="$TMP/kit"
mkdir -p "$KIT/scripts" "$KIT/lib" "$KIT/config"
cp "$ROOT/install.sh" "$ROOT/VERSION" "$KIT/"
cp "$ROOT/lib/common.sh" "$KIT/lib/"
cp "$ROOT/scripts/lib.sh" "$KIT/scripts/"
cp "$ROOT/config/zshrc.block.sh" "$KIT/config/"
cat >> "$KIT/scripts/lib.sh" <<'SH'
brew_prefix() { printf '%s\n' "$FIXTURE/${BREW_DIR:-brew}"; }
load_brew() { :; }
kit_user_is_admin() { [[ "${FAKE_ADMIN:-1}" == 1 ]]; }
SH
mkdir -p "$TMP/brew/bin"; : > "$TMP/brew/bin/brew"; chmod +x "$TMP/brew/bin/brew"
for spec in 01-prereqs 02-brew 03-runtimes 04-shell 05-docker 06-git 07-agents; do
  id="${spec#*-}"
  cat > "$KIT/scripts/$spec.sh" <<SH
step_$id() {
  printf '%s\n' "$id" >> "\$FIXTURE/trace"
  printf 'STEP=%s\n' "$id"
  [[ "\${FAIL_STEP:-}" != "$id" ]] || die "forced failure in $id"
}
SH
done

CASE_OUT=""; CASE_STATUS=0; CASE_HOME=""
run_install() {
  local name="$1"; shift
  CASE_HOME="$TMP/$name/home"
  mkdir -p "$CASE_HOME" "$TMP/$name/tmp"
  : > "$TMP/trace"
  CASE_STATUS=0
  # setsid + </dev/null: no controlling terminal, whatever started the test.
  CASE_OUT="$(env HOME="$CASE_HOME" TMPDIR="$TMP/$name/tmp" FIXTURE="$TMP" \
    PATH="/usr/bin:/bin:/usr/sbin:/sbin" STARTER_KIT_AUTO_DOCTOR=0 "${CASE_ENV[@]}" \
    perl -MPOSIX=setsid -e 'setsid(); exec @ARGV or die' \
    /bin/bash "$KIT/install.sh" "$@" </dev/null 2>&1)" || CASE_STATUS=$?
  printf '%s\n' "$CASE_OUT" > "$TMP/$name.out"
}
row() { printf '%s\n' "$CASE_OUT" | grep -E "^  $1 +$2 " >/dev/null; }
final_line() { printf '%s\n' "$CASE_OUT" | grep -E '^(🎉|❌) ' | tail -1; }
log_path() { printf '%s\n' "$CASE_OUT" | sed -n 's/^📄 .*: //p'; }

CASE_ENV=(FAKE_ADMIN=1)
run_install success --yes --only shell
[[ "$CASE_STATUS" == 0 ]] || fail "success run exited $CASE_STATUS: $CASE_OUT"
row ✅ shell && row '⏭' docker && row '⏭' prereqs || fail "success board rows wrong: $CASE_OUT"
[[ "$(final_line)" == 🎉* ]] || fail "success run did not end with the success line"
log="$(log_path)"
[[ -n "$log" && -f "$log" && "$log" == "$CASE_HOME/Library/Logs/lazy-starter-kit/install-"*.log ]] \
  || fail "install log missing: '$log'"
grep -qx 'STEP=shell' "$log" || fail "install log does not contain step output"
grep -q '설치 결과' "$log" || fail "install log does not contain the results board"
! grep -q $'\033' "$log" || fail "install log kept terminal color codes"
printf 'ok   success: ✅ row, success line, log file with full output\n'

CASE_ENV=(FAKE_ADMIN=1 FAIL_STEP=brew)
run_install die --yes --only brew,shell
[[ "$CASE_STATUS" == 1 ]] || fail "failed step exit code not preserved: $CASE_STATUS"
row ❌ brew || fail "failed step has no ❌ row: $CASE_OUT"
printf '%s\n' "$CASE_OUT" | grep -E '^  ❌ brew .*forced failure in brew' >/dev/null \
  || fail "failed row does not carry the error"
row '⏭' shell || fail "unreached step not marked ⏭"
[[ "$(cat "$TMP/trace")" == brew ]] || fail "steps after a failure still ran"
[[ "$(final_line)" == "❌ 1"*"brew → "* ]] || fail "failure line missing step and fix: $(final_line)"
[[ -f "$(log_path)" ]] || fail "failed run has no log"
printf 'ok   failure: ❌ row with error, later steps ⏭, failure line, exit 1\n'

CASE_ENV=(FAKE_ADMIN=1)
run_install preview --dry-run --only shell
[[ "$CASE_STATUS" == 0 ]] || fail "dry-run exited $CASE_STATUS"
row ✅ shell || fail "dry-run board missing"
[[ ! -e "$CASE_HOME/Library" && -z "$(log_path)" ]] || fail "dry-run wrote an install log"
printf 'ok   dry-run: board shown, no log written\n'

CASE_ENV=(FAKE_ADMIN=0 BREW_DIR=no-brew)
run_install non-admin --yes --only prereqs,shell
[[ "$CASE_STATUS" == 1 ]] || fail "non-admin pre-flight did not stop: $CASE_STATUS"
[[ ! -s "$TMP/trace" ]] || fail "a step ran after the non-admin pre-flight failed"
row ❌ precheck || fail "pre-flight failure has no ❌ row: $CASE_OUT"
printf 'ok   pre-flight: non-admin stops before any step\n'

CASE_ENV=(FAKE_ADMIN=1 BREW_DIR=no-brew)
run_install no-tty --only prereqs,shell
[[ "$CASE_STATUS" == 1 ]] || fail "no-terminal pre-flight did not stop: $CASE_STATUS"
[[ ! -s "$TMP/trace" ]] || fail "a step ran after the no-terminal pre-flight failed"
row ❌ precheck || fail "no-terminal failure has no ❌ row"
run_install no-tty-preview --dry-run --only prereqs,shell
[[ "$CASE_STATUS" == 0 && "$(cat "$TMP/trace")" == $'prereqs\nshell' ]] \
  || fail "pre-flight blocked a dry-run"
printf 'ok   pre-flight: no terminal stops before any step; dry-run unaffected\n'

CASE_ENV=(FAKE_ADMIN=1 STARTER_KIT_AUTO_DOCTOR=1)
run_install doctor --yes --only shell
[[ "$CASE_STATUS" == 0 ]] || fail "doctor run exited $CASE_STATUS"
printf '%s\n' "$CASE_OUT" | grep -E '^  🩺 doctor ' >/dev/null || fail "board has no doctor summary"
printf 'ok   doctor runs automatically and is summarized\n'

printf 'PASS install summary regression\n'
