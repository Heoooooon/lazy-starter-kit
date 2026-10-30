#!/usr/bin/env bash
# lib.sh — macOS helpers for lazy-starter-kit.
# sourced by install.sh and every scripts/NN-*.sh step.
#
# OS-agnostic helpers (colors, run, ask/confirm, inject_block, …) live in
# lib/common.sh so the macOS and Linux kits share ONE copy. This file adds only
# the macOS-specific bits below. Resolve our own dir via BASH_SOURCE so sourcing
# works regardless of $ROOT / cwd.
_KIT_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$_KIT_LIB_DIR/../lib/common.sh"

# ---------------------------------------------------------------------------
# macOS-specific predicates
# ---------------------------------------------------------------------------
is_macos()    { [[ "$(uname -s)" == "Darwin" ]]; }
is_arm()      { [[ "$(uname -m)" == "arm64" ]]; }

# brew_prefix — echo the Homebrew prefix for the current arch
brew_prefix() {
  if [[ -x /opt/homebrew/bin/brew ]]; then echo /opt/homebrew
  elif [[ -x /usr/local/bin/brew ]]; then echo /usr/local
  else echo /opt/homebrew; fi
}

# load brew into the current shell env (so steps see freshly-installed brew)
load_brew() {
  local p; p="$(brew_prefix)"
  # No Homebrew yet (a dry-run on a fresh Mac) is not an error for callers.
  [[ -x "$p/bin/brew" ]] || return 0
  eval "$("$p/bin/brew" shellenv)"
}

# ---------------------------------------------------------------------------
# Homebrew pre-flight — run before any step so a doomed Homebrew install stops
# at the start with a reason and a fix, not halfway through prereqs.
# ---------------------------------------------------------------------------
# kit_user_is_admin — 0 when the current user is in the macOS admin group.
# Homebrew's installer needs an administrator (sudo) account.
kit_user_is_admin() {
  local user="${USER:-}" answer=""
  [[ -n "$user" ]] || user="$(id -un)"
  if have dseditgroup; then
    answer="$(dseditgroup -o checkmember -m "$user" admin 2>/dev/null || true)"
    case "$answer" in
      yes*) return 0 ;;
      no*)  return 1 ;;
    esac
  fi
  # Directory service unavailable: fall back to the user's group list.
  id -Gn "$user" 2>/dev/null | tr ' ' '\n' | grep -qx admin
}

# kit_has_tty — 0 when a controlling terminal can answer password prompts.
kit_has_tty() { ( : </dev/tty ) 2>/dev/null; }

# homebrew_preflight — 0 when the prereqs step can install (or skip) Homebrew.
# Otherwise sets KIT_PREFLIGHT_REASON / KIT_PREFLIGHT_FIX, prints both, returns 1.
# Dry-runs and machines that already have Homebrew always pass.
homebrew_preflight() {
  KIT_PREFLIGHT_REASON=""; KIT_PREFLIGHT_FIX=""
  [[ "$DRY_RUN" != "1" ]] || return 0
  [[ ! -x "$(brew_prefix)/bin/brew" ]] || return 0
  if ! kit_user_is_admin; then
    KIT_PREFLIGHT_REASON="Homebrew is not installed and this account is not an administrator · Homebrew 설치에는 관리자 계정이 필요합니다"
    KIT_PREFLIGHT_FIX="log in as an administrator, then run ./install.sh again · 관리자 계정으로 로그인한 뒤 ./install.sh 를 다시 실행하세요"
  elif [[ "$ASSUME_YES" != "1" ]] && ! kit_has_tty; then
    KIT_PREFLIGHT_REASON="Homebrew is not installed and no interactive terminal is available for the password prompt · 비밀번호를 입력할 터미널이 없습니다"
    KIT_PREFLIGHT_FIX="open the Terminal app and run ./install.sh there · 터미널 앱에서 ./install.sh 를 실행하세요"
  else
    return 0
  fi
  err "$KIT_PREFLIGHT_REASON"
  info "Fix · 해결: $KIT_PREFLIGHT_FIX"
  return 1
}
