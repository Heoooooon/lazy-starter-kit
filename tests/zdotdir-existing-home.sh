#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/lib/common.sh"
TMP_BASE="${TMPDIR:-/tmp}"; TMP_BASE="${TMP_BASE%/}"
TMP_ROOT="$(mktemp -d "$TMP_BASE/lsk-zdotdir.XXXXXX")"
trap 'safe_rm_rf_under "$TMP_BASE" "$TMP_ROOT" >/dev/null 2>&1 || true' EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

prepare_home() {
  local home="$1" zdot="$2" legacy_zshrc="$1/home-zshrc"
  mkdir -p "$zdot" \
    "$home/bin" \
    "$home/.oh-my-zsh/custom/plugins/zsh-autosuggestions" \
    "$home/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"
  printf '%s\n' ':' > "$home/.oh-my-zsh/oh-my-zsh.sh"
  printf '%s\n' 'function _zsh_autosuggest_start() { :; }' \
    > "$home/.oh-my-zsh/custom/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"
  printf '%s\n' 'function _zsh_highlight_main__precmd_hook() { :; }' \
    > "$home/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
  printf '%s\n' 'typeset -g EXISTING_RC=1' > "$zdot/.zshrc"
  printf '%s\n' \
    '# >>> lazy-starter-kit:main >>>' \
    'typeset -g STALE_HOME_BLOCK=1' \
    '# <<< lazy-starter-kit:main <<<' \
    'typeset -g HOME_USER_LINE=1' \
    > "$legacy_zshrc"
  ln -s "$legacy_zshrc" "$home/.zshrc"
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    'printf '\''export STARSHIP_SHELL=zsh\n'\''' \
    > "$home/bin/starship"
  chmod +x "$home/bin/starship"
}

run_shell_step() {
  local variant="$1" home="$2" zdot="$3" kit_root
  case "$variant" in
    macos) kit_root="$ROOT" ;;
    linux) kit_root="$ROOT/linux" ;;
    *) fail "unknown fixture variant: $variant" ;;
  esac
  HOME="$home" ZDOTDIR="$zdot" ROOT="$kit_root" DRY_RUN=0 ASSUME_YES=1 \
    SHELL=/bin/zsh PATH="$home/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
    /bin/bash -c 'set -euo pipefail; source "$ROOT/scripts/lib.sh"; load_brew() { :; }; source "$ROOT/scripts/04-shell.sh"; step_shell' \
    >/dev/null
}

assert_active_zshrc() {
  local label="$1" home="$2" zdot="$3" actual blocks
  blocks="$(grep -cxF '# >>> lazy-starter-kit:main >>>' "$zdot/.zshrc" || true)"
  [[ "$blocks" == "1" ]] \
    || fail "$label: expected one active ZDOTDIR/.zshrc block, got $blocks"
  if grep -qsF '# >>> lazy-starter-kit:main >>>' "$home/.zshrc" 2>/dev/null; then
    fail "$label: installer left the managed block in inactive HOME/.zshrc"
  fi
  [[ -L "$home/.zshrc" ]] || fail "$label: stale HOME .zshrc symlink was replaced"
  grep -qF 'HOME_USER_LINE=1' "$home/.zshrc" \
    || fail "$label: existing HOME .zshrc content was not preserved"
  actual="$(
    HOME="$home" ZDOTDIR="$zdot" TERM=xterm \
      PATH="$home/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
      env -u STARSHIP_SHELL /bin/zsh -ic \
      'printf "\n__LSK_ACTIVE__%s %s %s %s\n" "${EXISTING_RC:-0}" "${+functions[_zsh_autosuggest_start]}" "${+functions[_zsh_highlight_main__precmd_hook]}" "${STARSHIP_SHELL:-0}"' \
      2>/dev/null | sed -n 's/^__LSK_ACTIVE__//p' | tail -n 1
  )"
  [[ "$actual" == "1 1 1 zsh" ]] \
    || fail "$label: active zsh startup did not load existing config, plugins, and Starship (got: $actual)"
}

exported_home="$TMP_ROOT/exported-home"
exported_zdot="$exported_home/.config/zsh"
prepare_home "$exported_home" "$exported_zdot"
run_shell_step macos "$exported_home" "$exported_zdot"
run_shell_step macos "$exported_home" "$exported_zdot"
assert_active_zshrc exported_zdotdir "$exported_home" "$exported_zdot"

zshenv_home="$TMP_ROOT/zshenv-home"
zshenv_zdot="$zshenv_home/.config/zsh"
prepare_home "$zshenv_home" "$zshenv_zdot"
printf '%s\n' 'printf "zshenv-noise\n"' 'ZDOTDIR="$HOME/.config/zsh"' > "$zshenv_home/.zshenv"
env -u ZDOTDIR HOME="$zshenv_home" ROOT="$ROOT/linux" DRY_RUN=0 ASSUME_YES=1 \
  SHELL=/bin/zsh PATH="$zshenv_home/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
  /bin/bash -c 'set -euo pipefail; source "$ROOT/scripts/lib.sh"; source "$ROOT/scripts/04-shell.sh"; step_shell' \
  >/dev/null
assert_active_zshrc zshenv_zdotdir "$zshenv_home" "$zshenv_zdot"

resolved_profile="$(
  env -u ZDOTDIR HOME="$zshenv_home" /bin/bash -c \
    'source "$1/lib/common.sh"; zsh_config_file .zprofile' _ "$ROOT"
)"
[[ "$resolved_profile" == "$zshenv_zdot/.zprofile" ]] \
  || fail "zprofile: expected $zshenv_zdot/.zprofile, got $resolved_profile"

default_home="$TMP_ROOT/default-home"
mkdir -p "$default_home"
resolved_default="$(
  env -u ZDOTDIR HOME="$default_home" /bin/bash -c \
    'source "$1/lib/common.sh"; zsh_config_file .zshrc' _ "$ROOT"
)"
[[ "$resolved_default" == "$default_home/.zshrc" ]] \
  || fail "unset_zdotdir: expected $default_home/.zshrc, got $resolved_default"

set +e
empty_output="$(
  HOME="$default_home" ZDOTDIR='' /bin/bash -c \
    'source "$1/lib/common.sh"; zsh_config_file .zshrc' _ "$ROOT" 2>&1
)"
empty_status=$?
relative_output="$(
  HOME="$default_home" ZDOTDIR=relative /bin/bash -c \
    'source "$1/lib/common.sh"; zsh_config_file .zshrc' _ "$ROOT" 2>&1
)"
relative_status=$?
set -e
[[ "$empty_status" -ne 0 && "$empty_output" == *"must not be empty"* ]] \
  || fail "empty_zdotdir: expected a clear failure"
[[ "$relative_status" -ne 0 && "$relative_output" == *"must be absolute"* ]] \
  || fail "relative_zdotdir: expected a clear failure"

deferred_home="$TMP_ROOT/deferred-home"
deferred_bin="$TMP_ROOT/deferred-bin"
mkdir -p "$deferred_home" "$deferred_bin"
printf '%s\n' 'ZDOTDIR="$HOME/.config/zsh"' > "$deferred_home/.zshenv"
printf '%s\n' \
  '#!/bin/sh' \
  'printf '\''\n__LSK_ZDOTDIR__%s/.config/zsh\n'\'' "$HOME"' \
  > "$deferred_bin/zsh"
chmod +x "$deferred_bin/zsh"
HOME="$deferred_home" ROOT="$ROOT" FAKE_BIN="$deferred_bin" /bin/bash -c '
  set -euo pipefail
  source "$ROOT/lib/common.sh"
  PHASE=0
  have() {
    if [[ "$1" == "zsh" ]]; then [[ "$PHASE" == "1" ]]; else command -v "$1" >/dev/null 2>&1; fi
  }
  set +e
  zsh_config_file .zshrc >/dev/null 2>&1
  first_status=$?
  set -e
  [[ "$first_status" -ne 0 && "$_KIT_ZSH_CONFIG_DIR_RESOLVED" == "0" ]]
  PHASE=1
  PATH="$FAKE_BIN:$PATH"
  [[ "$(zsh_config_file .zshrc)" == "$HOME/.config/zsh/.zshrc" ]]
' || fail "deferred_zdotdir: zsh-missing fallback was cached before prereqs"

damaged="$TMP_ROOT/damaged-zshrc"
damaged_copy="$TMP_ROOT/damaged-zshrc.copy"
printf '%s\n' \
  '# <<< lazy-starter-kit:main <<<' \
  'typeset -g KEEP_MIDDLE=1' \
  '# >>> lazy-starter-kit:main >>>' \
  'typeset -g KEEP_AFTER=1' \
  > "$damaged"
cp "$damaged" "$damaged_copy"
HOME="$TMP_ROOT" ROOT="$ROOT" FILE="$damaged" /bin/bash -c '
  set -euo pipefail
  source "$ROOT/lib/common.sh"
  inject_block "$FILE" "lazy-starter-kit:main" <<< "replacement"
  remove_block "$FILE" "lazy-starter-kit:main"
' >/dev/null 2>&1
cmp -s "$damaged" "$damaged_copy" \
  || fail "damaged_markers: out-of-order markers caused user content loss"

quote_sentinel="$TMP_ROOT/quote-sentinel"
backtick_sentinel="$TMP_ROOT/backtick-sentinel"
hostile_path="$TMP_ROOT/zsh \"quote\" \$(touch $quote_sentinel) \`touch $backtick_sentinel\`/.zshrc"
quoted_path="$(HOME="$TMP_ROOT" ROOT="$ROOT" VALUE="$hostile_path" /bin/bash -c '
  source "$ROOT/lib/common.sh"
  shell_quote "$VALUE"
')"
roundtrip="$(QUOTED="$quoted_path" /bin/zsh -c 'eval "set -- $QUOTED"; print -r -- "$1"')"
[[ "$roundtrip" == "$hostile_path" && ! -e "$quote_sentinel" && ! -e "$backtick_sentinel" ]] \
  || fail "source_guidance: path was not safely shell-escaped"

printf '%s\n' \
  '# >>> lazy-starter-kit:brew >>>' \
  ':' \
  '# <<< lazy-starter-kit:brew <<<' \
  > "$zshenv_zdot/.zprofile"

case "$(uname -s)" in
  Darwin)
    platform_root="$ROOT"
    ;;
  Linux)
    platform_root="$ROOT/linux"
    ;;
  *)
    fail "unsupported test platform: $(uname -s)"
    ;;
esac

space_zdot="$zshenv_home/config/zsh active"
mkdir -p "$space_zdot"
space_output="$(
  HOME="$zshenv_home" ZDOTDIR="$space_zdot" SHELL=/bin/zsh \
    PATH="$zshenv_home/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
    /bin/bash "$platform_root/install.sh" --dry-run --only shell --yes 2>&1
)"
space_expected="$(HOME="$zshenv_home" ROOT="$ROOT" VALUE="$space_zdot/.zshrc" /bin/bash -c '
  source "$ROOT/lib/common.sh"
  shell_quote "$VALUE"
')"
[[ "$space_output" == *"$space_expected"* ]] \
  || fail "space_zdotdir: dry-run guidance did not quote the active path"

doctor_output="$(
  env -u ZDOTDIR HOME="$zshenv_home" SHELL=/bin/zsh \
    PATH="$zshenv_home/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
    /bin/bash "$platform_root/install.sh" --doctor 2>&1 || true
)"
grep -q "has 'lazy-starter-kit:main' block" <<< "$doctor_output" \
  || fail "doctor: active ZDOTDIR/.zshrc was reported missing"
if [[ "$(uname -s)" == "Darwin" ]]; then
  grep -q "has 'lazy-starter-kit:brew' block" <<< "$doctor_output" \
    || fail "doctor: active ZDOTDIR/.zprofile was reported missing"
fi

env -u ZDOTDIR HOME="$zshenv_home" SHELL=/bin/zsh \
  PATH="$zshenv_home/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
  /bin/bash "$platform_root/uninstall.sh" --only shell --yes >/dev/null 2>&1
if grep -qsF '# >>> lazy-starter-kit:' "$zshenv_zdot/.zshrc"; then
  fail "uninstall: managed blocks remained in the active ZDOTDIR/.zshrc"
fi
if [[ "$(uname -s)" == "Darwin" ]] \
  && grep -qsF '# >>> lazy-starter-kit:' "$zshenv_zdot/.zprofile"; then
  fail "uninstall: managed blocks remained in the active ZDOTDIR/.zprofile"
fi

printf 'ok: install targets the Zsh startup directory used by existing users\n'
