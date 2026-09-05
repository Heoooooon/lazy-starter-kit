#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck source=lib/common.sh
source "$REPO_ROOT/lib/common.sh"
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

TMP_BASE="$REPO_ROOT/.tmp-tests"
[[ ! -L "$TMP_BASE" ]] || fail 'fixture base must not be a symlink'
mkdir -p "$TMP_BASE"
[[ "$(cd "$TMP_BASE" && pwd -P)" == "$TMP_BASE" && -O "$TMP_BASE" ]] \
  || fail 'fixture base escapes worktree or is not owned'
WORK="$(mktemp -d "$TMP_BASE/profiles.XXXXXX")"
OWNER_TOKEN="profiles:$$:$RANDOM:$RANDOM"
readonly REPO_ROOT TMP_BASE WORK OWNER_TOKEN
printf '%s\n' "$OWNER_TOKEN" > "$WORK/.profiles-owner"
validate_fixture_root() {
  [[ "$1" == "$WORK" && "$1" == "$TMP_BASE"/profiles.* \
    && ! -L "$TMP_BASE" && ! -L "$1" && -d "$1" && -O "$1" \
    && ! -L "$1/.profiles-owner" && -f "$1/.profiles-owner" ]] || return 1
  [[ "$(cd "$1" && pwd -P)" == "$1" ]] || return 1
  printf '%s\n' "$OWNER_TOKEN" | cmp -s - "$1/.profiles-owner"
}
cleanup() {
  local status=$?
  validate_fixture_root "$WORK" || {
    printf 'FAIL: refusing cleanup: fixture boundary or ownership changed: %s\n' "$WORK" >&2
    return 1
  }
  printf 'cleanup: safe_rm_rf_under "%s" "%s"\n' "$TMP_BASE" "$WORK"
  DRY_RUN=0 safe_rm_rf_under "$TMP_BASE" "$WORK" || return 1
  return "$status"
}
trap cleanup EXIT
validate_fixture_root "$WORK" || fail 'invalid fixture ownership'
for boundary in "$REPO_ROOT" "$TMP_BASE" "${HOME:-/}"; do
  if validate_fixture_root "$boundary"; then fail "accepted non-fixture boundary: $boundary"; fi
done
mkdir "$WORK/runner-home" "$WORK/tmp" "$WORK/cache" "$WORK/bin"
export HOME="$WORK/runner-home" USERPROFILE="$WORK/runner-home"
export TMPDIR="$WORK/tmp" TMP="$WORK/tmp" TEMP="$WORK/tmp" XDG_CACHE_HOME="$WORK/cache"
unset BASH_ENV ENV
printf 'fixtures: root=%s HOME=%s USERPROFILE=%s TMPDIR=%s cache=%s\n' \
  "$WORK" "$HOME" "$USERPROFILE" "$TMPDIR" "$XDG_CACHE_HOME"

# Execute byte-identical installer copies with harmless step boundaries. The
# actual macOS brew step consumes selected() unchanged, rather than a test model.
for platform in macos linux; do
  root="$WORK/$platform"
  mkdir -p "$root/scripts"
  source_root="$REPO_ROOT"
  [[ "$platform" != linux ]] || source_root="$REPO_ROOT/linux"
  cp "$source_root/install.sh" "$root/install.sh"
  cmp "$source_root/install.sh" "$root/install.sh"
  cp "$REPO_ROOT/VERSION" "$root/VERSION"
  cp "$REPO_ROOT/lib/common.sh" "$root/common.sh"
  printf '%s\n' 'source "$ROOT/common.sh"' > "$root/scripts/lib.sh"
  # Never load host shell config or Homebrew; no network or auth is performed.
  cat >> "$root/scripts/lib.sh" <<'SH'
is_macos() { return 0; }
is_arm() { return 0; }
is_linux() { return 0; }
cache_zsh_config_dir() { :; }
zsh_config_file() { printf '%s/%s\n' "$HOME" "$1"; }
load_brew() { :; }
have() { [[ "$1" == brew ]]; }
brew() {
  case "$*" in
    'update --quiet') return 0 ;;
    'bundle install --file='*|'bundle check --file='*)
      printf 'brew %s\n' "${3##*/}" >> "$TRACE"
      [[ "${FAIL_BREW:-0}" != 1 ]] ;;
    *) printf 'unexpected brew %s\n' "$*" >> "$TRACE"; return 92 ;;
  esac
}
SH
  for spec in 01-prereqs 02-packages 03-runtimes 04-shell 05-docker 06-git 07-agents; do
    id="${spec#*-}"
    printf 'step_%s() { printf "step %s\\n" >> "$TRACE"; }\n' "$id" "$id" > "$root/scripts/$spec.sh"
  done
  if [[ "$platform" == macos ]]; then
    printf '%s\n' 'printf "step brew\n" >> "$TRACE"' > "$root/scripts/02-brew.sh"
    cat "$REPO_ROOT/scripts/02-brew.sh" >> "$root/scripts/02-brew.sh"
    cp "$REPO_ROOT/"Brewfile.* "$root/"
  fi
done
cp "$REPO_ROOT/VERSION" "$WORK/VERSION"
# Tripwires detect accidental external actions, including during RED runs.
for command in curl git npm sudo docker gh codex claude; do
  printf '#!/bin/bash\nprintf "unexpected %s %%s\\n" "$*" >> "$TRACE"\nexit 93\n' "$command" > "$WORK/bin/$command"
  chmod +x "$WORK/bin/$command"
done
# gh auth status is an existing read-only completion probe, not an auth action.
printf '#!/bin/bash\n[[ "$*" == "auth status" ]] && exit 1\nprintf "unexpected gh %%s\\n" "$*" >> "$TRACE"\nexit 93\n' > "$WORK/bin/gh"

failures=0; cases=0
run_case() {
  local platform="$1" label="$2" expected_status="$3" steps="$4" bundles="$5"
  [[ "$platform" != linux ]] || bundles=""
  shift 5
  local case_dir="$WORK/$platform-$label" status=0 id bundle
  validate_fixture_root "$WORK" || fail 'invalid fixture boundary before entrypoint'
  mkdir -p "$case_dir/home" "$case_dir/tmp" "$case_dir/cache"
  : > "$case_dir/trace"
  env -i HOME="$case_dir/home" USERPROFILE="$case_dir/home" \
    TMPDIR="$case_dir/tmp" TMP="$case_dir/tmp" TEMP="$case_dir/tmp" \
    XDG_CACHE_HOME="$case_dir/cache" PATH="$WORK/bin:/usr/bin:/bin" \
    TRACE="$case_dir/trace" FAIL_BREW="${FAIL_BREW:-0}" \
    /bin/bash "$WORK/$platform/install.sh" --yes "$@" > "$case_dir/output" 2>&1 || status=$?
  : > "$case_dir/expected"
  for id in $steps; do
    printf 'step %s\n' "$id" >> "$case_dir/expected"
    if [[ "$id" == brew ]]; then
      for bundle in $bundles; do printf 'brew Brewfile.%s\n' "$bundle" >> "$case_dir/expected"; done
    fi
  done
  cases=$((cases + 1))
  if [[ "$status" != "$expected_status" ]] || ! diff -u "$case_dir/expected" "$case_dir/trace"; then
    printf 'FAIL: %s/%s expected exit %s, got %s; args:' "$platform" "$label" "$expected_status" "$status"
    printf ' <%s>' "$@"; printf '\n'
    awk '{print}' "$case_dir/output"
    failures=$((failures + 1))
  else
    printf 'ok: %s/%s exit=%s steps=[%s] Brewfiles=[%s]\n' "$platform" "$label" "$status" "$steps" "$bundles"
  fi
  # Output is evidence for manual first-use review, never a prose assertion.
  if [[ "$label" == recommended || "$label" == minimal || "$label" == brew-failure || "$label" == preview ]]; then
    printf '%s\n' "--- $platform/$label output ---"
    awk '{print}' "$case_dir/output"
  fi
}

for platform in macos linux; do
  package=brew; [[ "$platform" != linux ]] || package=packages
  full="prereqs $package runtimes shell docker git agents"
  recommended="prereqs $package runtimes shell git agents"
  minimal="prereqs $package runtimes shell git"
  run_case "$platform" recommended 0 "$recommended" 'core runtimes' --profile recommended
  run_case "$platform" recommended-equals 0 "$recommended" 'core runtimes' --profile=recommended
  run_case "$platform" default 0 "$full" 'core runtimes docker'
  run_case "$platform" full 0 "$full" 'core runtimes docker' --profile full
  run_case "$platform" minimal 0 "$minimal" 'core runtimes' --profile minimal
  run_case "$platform" work 0 "$recommended" 'core runtimes' --profile work
  run_case "$platform" skip-union 0 "prereqs $package shell git" core --profile recommended --skip 'runtimes, agents'
  run_case "$platform" skip-first 0 "prereqs $package shell git" core --skip=runtimes,agents --profile=recommended
  run_case "$platform" no-agents 0 "$minimal" 'core runtimes' --profile recommended --no-agents
  run_case "$platform" full-skip 0 "$recommended" 'core runtimes' --profile full --skip docker
  run_case "$platform" only 0 "$package shell" core --only "$package, shell"
  run_case "$platform" only-runtimes 0 "$package runtimes" 'core runtimes' --only "$package,runtimes"
  run_case "$platform" only-precedence 0 agents '' --only agents --skip agents
  run_case "$platform" preview 0 "$recommended" 'core runtimes' --profile recommended --dry-run
  run_case "$platform" empty-plan 0 '' '' --skip "prereqs,$package,runtimes,shell,docker,git,agents"
  run_case "$platform" profile-only 1 '' '' --profile recommended --only agents
  run_case "$platform" only-profile 1 '' '' --only=agents --profile=full
  run_case "$platform" unknown-profile 1 '' '' --profile unknown
  run_case "$platform" unknown-only 1 '' '' --only typo
  run_case "$platform" unknown-skip 1 '' '' --profile full --skip typo
  for selector in only skip profile; do
    run_case "$platform" "$selector-missing" 1 '' '' "--$selector"
    run_case "$platform" "$selector-next-option" 1 '' '' "--$selector" --yes
    run_case "$platform" "$selector-empty" 1 '' '' "--$selector="
    run_case "$platform" "$selector-blank" 1 '' '' "--$selector" ' '
  done
  for selector in only skip; do
    run_case "$platform" "$selector-leading-comma" 1 '' '' "--$selector=,agents"
    run_case "$platform" "$selector-trailing-comma" 1 '' '' "--$selector=agents,"
    run_case "$platform" "$selector-double-comma" 1 '' '' "--$selector=shell,,agents"
  done
  if [[ "$platform" == macos ]]; then
    FAIL_BREW=1 run_case "$platform" brew-failure 1 "$recommended" 'core runtimes' --profile recommended
  fi
done
[[ "$failures" == 0 ]] || fail "$failures of $cases profile scenarios failed"
printf 'ok: profile entrypoint contracts (%s scenarios)\n' "$cases"
