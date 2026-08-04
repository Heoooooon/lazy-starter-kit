#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/common.sh
source "$ROOT/lib/common.sh"

TMP_ROOT="$ROOT/.tmp-tests"
mkdir -p "$TMP_ROOT"
TMP="$(mktemp -d "$TMP_ROOT/homebrew-installer.XXXXXX")"
cleanup() {
  safe_rm_rf_under "$TMP_ROOT" "$TMP"
  rmdir "$TMP_ROOT" 2>/dev/null || true
}
trap cleanup EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

run_fixture() {
  local mode="$1" output status fixture_dir="$TMP/$1"
  mkdir -p "$fixture_dir"
  set +e
  output="$(LSK_HOMEBREW_TEST_DIR="$fixture_dir" /bin/bash "$0" "__fixture_$mode" 2>&1)"
  status=$?
  set -e
  printf '%s\n%s\n' "$status" "$output"
}

run_tty_fixture() {
  local fixture_dir="$TMP/interactive" output
  mkdir -p "$fixture_dir"
  if script --version 2>/dev/null | grep -q 'util-linux'; then
    output="$(LSK_HOMEBREW_TEST_DIR="$fixture_dir" \
      script -qec "/bin/bash '$0' __fixture_interactive" /dev/null </dev/null 2>&1)"
  else
    output="$(LSK_HOMEBREW_TEST_DIR="$fixture_dir" \
      script -q /dev/null /bin/bash "$0" __fixture_interactive </dev/null 2>&1)"
  fi
  printf '%s\n' "$output"
}

if [[ "${1:-}" == __fixture_* ]]; then
  mode="${1#__fixture_}"
  export HOME="$LSK_HOMEBREW_TEST_DIR/home"
  mkdir -p "$HOME"

  DRY_RUN=0
  ASSUME_YES=1
  if [[ "$mode" == "no_tty" || "$mode" == "interactive" ]]; then
    ASSUME_YES=0
  fi

  # shellcheck source=lib/common.sh
  source "$ROOT/lib/common.sh"
  # shellcheck source=scripts/01-prereqs.sh
  source "$ROOT/scripts/01-prereqs.sh"

  xcode-select() { [[ "$1" == "-p" ]]; }
  brew_prefix() { printf '%s\n' "$LSK_HOMEBREW_TEST_DIR/missing-homebrew"; }
  load_brew() { :; }
  zsh_config_file() { printf '%s/.zprofile\n' "$HOME"; }

  curl() {
    local output_file=""
    while [[ "$#" -gt 0 ]]; do
      if [[ "$1" == "-o" ]]; then
        output_file="$2"
        shift
      fi
      shift
    done
    [[ "$mode" != "download_failure" ]] || return 22
    if [[ "$mode" == "invalid_download" ]]; then
      printf '%s\n' 'not a shell installer' > "$output_file"
      return 0
    fi
    cat > "$output_file" <<'EOF'
#!/bin/bash
printf 'FAKE_INSTALLER:NONINTERACTIVE=%s:INTERACTIVE=%s\n' "${NONINTERACTIVE:-}" "${INTERACTIVE:-}"
exit "${LSK_FAKE_BREW_STATUS:-0}"
EOF
  }

  if [[ "$mode" == "installer_failure" ]]; then
    export LSK_FAKE_BREW_STATUS=23
  fi
  step_prereqs
  exit 0
fi

result="$(run_fixture noninteractive)"
[[ "${result%%$'\n'*}" == "0" ]] || fail "--yes Homebrew fixture failed"
[[ "$result" == *"Installing Homebrew non-interactively"* ]] \
  || fail "--yes did not select the non-interactive installer path"
[[ "$result" == *"FAKE_INSTALLER:NONINTERACTIVE=1:INTERACTIVE="* ]] \
  || fail "--yes did not pass NONINTERACTIVE=1 to Homebrew"
printf 'ok   --yes keeps Homebrew fully non-interactive\n'

result="$(run_tty_fixture)"
[[ "$result" == *"Homebrew may request your macOS administrator password"* ]] \
  || fail "a real TTY did not select the interactive installer path"
[[ "$result" == *"FAKE_INSTALLER:NONINTERACTIVE=:INTERACTIVE=1"* ]] \
  || fail "interactive mode did not pass INTERACTIVE=1 to Homebrew"
printf 'ok   a real TTY selects Homebrew interactive mode\n'

result="$(run_fixture no_tty)"
[[ "${result%%$'\n'*}" != "0" ]] || fail "a missing TTY unexpectedly succeeded"
[[ "$result" == *"Homebrew installation requires an interactive terminal"* ]] \
  || fail "a missing TTY did not produce actionable guidance"
[[ "$result" != *"FAKE_INSTALLER:"* ]] \
  || fail "the Homebrew installer ran without a TTY"
printf 'ok   interactive mode fails clearly when no TTY exists\n'

result="$(run_fixture invalid_download)"
[[ "${result%%$'\n'*}" != "0" ]] || fail "an invalid installer unexpectedly succeeded"
[[ "$result" == *"Downloaded Homebrew installer is invalid"* ]] \
  || fail "an invalid installer was not rejected"
[[ "$result" != *"FAKE_INSTALLER:"* ]] \
  || fail "an invalid installer was executed"
printf 'ok   invalid Homebrew downloads are rejected before execution\n'

result="$(run_fixture download_failure)"
[[ "${result%%$'\n'*}" != "0" ]] || fail "a failed download unexpectedly succeeded"
[[ "$result" == *"Could not download the Homebrew installer"* ]] \
  || fail "a failed download did not produce the expected error"
printf 'ok   Homebrew download failures stop cleanly\n'

result="$(run_fixture installer_failure)"
[[ "${result%%$'\n'*}" != "0" ]] || fail "a failed Homebrew installer unexpectedly succeeded"
[[ "$result" == *"Homebrew installation failed with exit code 23"* ]] \
  || fail "the Homebrew installer exit code was not preserved"
printf 'ok   Homebrew installer failures preserve the exit code\n'

printf 'PASS Homebrew installer regression\n'
