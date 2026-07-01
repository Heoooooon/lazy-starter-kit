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
    info "[dry-run] (optional) curl -fsSL https://get.docker.com | sh   (installs docker-ce + compose + buildx)"
    info "[dry-run] $SUDO usermod -aG docker \$USER"
    return 0
  fi

  if confirm "Install Docker Engine now? (official get.docker.com script, needs root)"; then
    curl -fsSL https://get.docker.com | run $SUDO sh || { warn "docker install failed"; return 0; }
    # let the current user run docker without sudo (takes effect on next login)
    run $SUDO usermod -aG docker "$USER" || warn "could not add $USER to docker group"
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
