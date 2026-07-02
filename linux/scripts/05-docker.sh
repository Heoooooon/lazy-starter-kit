#!/usr/bin/env bash
# 05-docker.sh — Docker Engine (native) + compose/buildx plugins

step_docker() {
  step "Containers: Docker Engine + compose/buildx"

  if have docker; then
    ok "docker present ($(docker --version 2>/dev/null))"
    docker compose version  >/dev/null 2>&1 && ok "docker compose plugin present"
    docker buildx version   >/dev/null 2>&1 && ok "docker buildx plugin present"
    _docker_group_hint
    return 0
  fi

  # Docker's official convenience script supports all major distros and pulls
  # compose + buildx plugins. Heavy + needs root, so it's confirm-gated.
  if [[ "$DRY_RUN" == "1" ]]; then
    info "[dry-run] (optional) download https://get.docker.com to a temp file, verify it, then $SUDO sh <file>   (installs docker-ce + compose + buildx)"
    info "[dry-run] $SUDO usermod -aG docker \$USER"
    return 0
  fi

  if confirm "Install Docker Engine now? (official get.docker.com script, needs root)"; then
    # Download the convenience script to a file and sanity-check it before we
    # run it as root, rather than piping curl straight into a root shell — a
    # truncated or hijacked download would otherwise execute unreviewed. We log
    # the path so the user can inspect it. Stays non-fatal: any failure warns
    # and returns 0 so the rest of the install still runs.
    # (get.docker.com honors VERSION=<x.y.z> for users who want to pin a Docker
    #  version; we don't pin here — staleness risk outweighs it.)
    docker_tmp="$(mktemp)"
    info "downloading get.docker.com installer to $docker_tmp (inspect it there if you like)"
    if curl -fsSL https://get.docker.com -o "$docker_tmp" \
       && [[ -s "$docker_tmp" ]] \
       && head -n1 "$docker_tmp" | grep -q '^#!' \
       && grep -q 'do_install' "$docker_tmp"; then
      run $SUDO sh "$docker_tmp" || { warn "docker install failed"; rm -f "$docker_tmp"; return 0; }
    else
      warn "could not download/verify the get.docker.com installer — skipping Docker"
      rm -f "$docker_tmp"
      return 0
    fi
    rm -f "$docker_tmp"
    # let the current user run docker without sudo (takes effect on next login).
    # bash doesn't set $USER; fall back to `id -un` so `set -u` can't abort here.
    _u="${USER:-$(id -un)}"
    run $SUDO usermod -aG docker "$_u" || warn "could not add $_u to docker group"
    # enable + start the daemon where systemd is available
    if have systemctl; then
      run $SUDO systemctl enable --now docker || warn "could not enable docker service"
    fi
    ok "Docker installed"
    info "Log out and back in (or run 'newgrp docker') so group membership applies."
  else
    info "Skipped. Install later:  curl -fsSL https://get.docker.com | sh"
  fi
}

# _docker_group_hint — warn if the user isn't in the docker group yet
_docker_group_hint() {
  if have docker && ! id -nG 2>/dev/null | tr ' ' '\n' | grep -qx docker \
     && [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    info "You're not in the 'docker' group — add yourself: $SUDO usermod -aG docker \$USER (then re-login)"
  fi
}
