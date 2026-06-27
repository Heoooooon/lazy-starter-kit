#!/usr/bin/env bash
# 02-brew.sh — install everything in the Brewfile

step_brew() {
  step "Homebrew packages (Brewfile)"
  load_brew
  local brewfile="$ROOT/Brewfile"
  [[ -f "$brewfile" ]] || die "missing Brewfile at $brewfile"

  # In a full dry-run on a bare machine, Homebrew isn't installed yet (the
  # prereqs step only previewed it). Preview gracefully instead of dying.
  if ! have brew; then
    if [[ "$DRY_RUN" == "1" ]]; then
      info "[dry-run] Homebrew not present yet (prereqs would install it) — would then: brew bundle install --file=$brewfile"
      return 0
    fi
    die "Homebrew not found — run the 'prereqs' step first."
  fi

  export HOMEBREW_NO_ENV_HINTS=1
  if [[ "$DRY_RUN" == "1" ]]; then
    info "[dry-run] brew bundle --file=$brewfile  (would install missing formulae/casks)"
    info "[dry-run] pending entries:"
    brew bundle check --file="$brewfile" --verbose 2>/dev/null | sed 's/^/    /' || true
    return 0
  fi

  run brew update --quiet || warn "brew update failed (continuing)"
  # --no-lock was removed in modern Homebrew; bundle no longer writes a lockfile by default
  run brew bundle install --file="$brewfile"
  ok "Brewfile applied"
}
