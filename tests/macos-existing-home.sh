#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/lib/common.sh"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

grep -qF 'tap  "stablyai/orca", trusted: { cask: "orca" }' "$ROOT/Brewfile" \
  || fail 'Brewfile does not limit third-party trust to the Orca cask'
grep -qF 'cask "stablyai/orca/orca"' "$ROOT/Brewfile" \
  || fail 'Brewfile does not use the fully qualified Orca cask'

run_fixture() {
  local mode="$1" output status
  set +e
  output="$(/bin/bash "$0" "__fixture_$mode" 2>&1)"
  status=$?
  set -e

  if [[ "$status" -ne 0 ]]; then
    printf '%s\n' "$output" >&2
    fail "$mode: brew failure stopped the installer before the shell step (exit $status)"
  fi
  printf '%s\n' "$output"
}

if [[ "${1:-}" == __fixture_* ]]; then
  mode="${1#__fixture_}"
  DRY_RUN=0
  ASSUME_YES=1
  KIT_INSTALL_FAILED=0
  source "$ROOT/lib/common.sh"
  source "$ROOT/scripts/02-brew.sh"

  load_brew() { :; }
  have() {
    [[ "$1" == "brew" || ( "$mode" == "existing_orca" && "$1" == "orca" ) ]]
  }
  brew() {
    if [[ "$1" == "update" ]]; then return 0; fi
    if [[ "$1" == "bundle" ]]; then
      [[ "${HOMEBREW_BUNDLE_NO_UPGRADE:-}" == "1" ]] || return 16
      if [[ "$mode" == "existing_orca" ]]; then
        [[ " ${HOMEBREW_BUNDLE_CASK_SKIP:-} " == *" orca "* ]] || return 17
        [[ " ${HOMEBREW_BUNDLE_TAP_SKIP:-} " == *" stablyai/orca "* ]] || return 18
        return 0
      fi
      return 19
    fi
    return 0
  }

  step_brew
  if [[ "$mode" == "partial_bundle_failure" ]]; then
    source "$ROOT/scripts/03-runtimes.sh"
    step_runtimes
  fi
  printf 'SHELL_STEP_REACHED errors=%s\n' "$KIT_INSTALL_FAILED"
  exit 0
fi

existing_output="$(run_fixture existing_orca)"
[[ "$existing_output" == *"SHELL_STEP_REACHED errors=0"* ]] \
  || fail "existing_orca: shell step marker missing"

failure_output="$(run_fixture partial_bundle_failure)"
[[ "$failure_output" == *"SHELL_STEP_REACHED errors=1"* ]] \
  || fail "partial_bundle_failure: shell step marker missing"
[[ "$failure_output" != *"Brewfile applied"* ]] \
  || fail "partial_bundle_failure: printed a false success"

TMP_BASE="${TMPDIR:-/tmp}"; TMP_BASE="${TMP_BASE%/}"
custom_home="$(mktemp -d "$TMP_BASE/lsk-zsh-custom.XXXXXX")"
trap 'safe_rm_rf_under "$TMP_BASE" "$custom_home" >/dev/null 2>&1 || true' EXIT
mkdir -p "$custom_home/.oh-my-zsh/custom/plugins/zsh-autosuggestions"
mkdir -p "$custom_home/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"
mkdir -p "$custom_home/custom"
printf '%s\n' '_zsh_autosuggest_start() { :; }' \
  > "$custom_home/.oh-my-zsh/custom/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"
printf '%s\n' '_zsh_highlight_main__precmd_hook() { :; }' \
  > "$custom_home/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
for block in "$ROOT/config/zshrc.block.sh" "$ROOT/linux/config/zshrc.block.sh"; do
  set +e
  env -i HOME="$custom_home" ZSH_CUSTOM="$custom_home/custom" \
    BLOCK="$block" PATH=/usr/bin:/bin \
    /bin/zsh -c 'source "$BLOCK"; (( ${+functions[_zsh_autosuggest_start]} && ${+functions[_zsh_highlight_main__precmd_hook]} ))'
  custom_status=$?
  set -e
  [[ "$custom_status" -eq 0 ]] \
    || fail "custom_zsh_custom: installed plugins were not activated by $block"
done
safe_rm_rf_under "$TMP_BASE" "$custom_home"
trap - EXIT

printf 'ok: existing Homebrew state cannot block shell activation\n'
