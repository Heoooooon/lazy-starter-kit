#!/usr/bin/env bash
# 01-prereqs.sh — base toolchain: compiler, git, curl, zsh, unzip …

step_prereqs() {
  if [[ "${PROFILE:-}" == ai ]]; then
    step "Preparing Git and download tools"
    [[ -n "$PM" && "$PM" != apk ]] || die "AI setup needs a glibc Linux distro with apt/dnf/yum/pacman/zypper."
    if [[ "$DRY_RUN" != 1 ]] && ! can_sudo; then
      have git && have curl && have tar && have xz \
        || die "Action needed: ask an administrator to install git, curl, ca-certificates, tar and xz."
      info "Using existing system prerequisites (no administrator access)."
    else
      case "$PM" in
        apt) pm_install git curl ca-certificates tar xz-utils ;;
        *)   pm_install git curl ca-certificates tar xz ;;
      esac
    fi
    load_ai_bins
    return 0
  fi
  step "Prerequisites: base build tools + git/curl/zsh"

  [[ -n "$PM" ]] || die "no supported package manager found (need apt/dnf/yum/pacman/zypper/apk)"
  info "distro: $(distro_id)   package manager: $PM"
  if [[ "$PM" == "apk" ]]; then
    warn "Alpine/musl is NOT supported: upstream node, ast-grep and bun ship no"
    warn "musl builds, so the 'runtimes'/'agents' steps will fail. Use a glibc"
    warn "distro (Debian/Ubuntu, Fedora/RHEL, Arch, openSUSE). Continuing best-effort…"
  fi
  # Without effective root (not root AND cannot escalate via sudo) the whole
  # system-package phase can't run. Warn ONCE and skip refresh + installs
  # rather than letting the first pm_install abort the installer — this matches
  # the "system packages are skipped with a warning" contract in lib.sh /
  # linux/README.md. (Under --dry-run we still fall through to print actions.)
  if [[ "$DRY_RUN" != "1" ]] && ! can_sudo; then
    warn "not root and cannot escalate with sudo — skipping ALL system packages."
    warn "Install these manually later: a C toolchain (gcc/make), git, curl, wget,"
    warn "unzip, zip, zsh, xz. User-space tools (mise, uv, bun, rustup) still install."
    ok "base prerequisites step skipped (no privileges)"
    return 0
  fi

  pm_refresh

  # Base packages differ per family. build tools + the essentials the later
  # steps and tool installers (rustup, mise, oh-my-zsh) depend on. Each family's
  # installs are best-effort: a failure warns and continues (they run under the
  # non-fatal pm_try, or pm_install whose failure we tolerate) so a single
  # unavailable package or a mid-run sudo timeout can't kill the installer.
  case "$PM" in
    apt)
      pm_try build-essential curl wget git ca-certificates unzip zip \
             zsh procps file xz-utils ;;
    dnf|yum)
      pm_try curl wget git ca-certificates unzip zip zsh procps-ng file xz
      # @development-tools provides gcc/make; group install syntax varies
      run $SUDO "$PM" -y groupinstall "Development Tools" 2>/dev/null \
        || pm_try gcc gcc-c++ make ;;
    pacman)
      pm_try base-devel curl wget git ca-certificates unzip zip zsh procps-ng file xz ;;
    zypper)
      # keep pm_install here: its exit status drives the gcc/make fallback
      # (pm_try always succeeds, which would swallow that fallback).
      pm_install -t pattern devel_basis 2>/dev/null || pm_try gcc gcc-c++ make
      pm_try curl wget git ca-certificates unzip zip zsh procps file xz ;;
    apk)
      pm_try build-base curl wget git ca-certificates unzip zip zsh procps file xz bash ;;
  esac

  have git  && ok "git present ($(git --version 2>/dev/null | awk '{print $3}'))" || warn "git still missing"
  have curl && ok "curl present" || warn "curl still missing"
  ok "base prerequisites ready"
}
