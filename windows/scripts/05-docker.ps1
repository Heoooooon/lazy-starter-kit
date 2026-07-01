# 05-docker.ps1 -- Docker Desktop (optional; requires WSL2/virtualization)

function Step-Docker {
  Write-Step "Containers: Docker Desktop (optional)"

  if (Test-HasCommand docker) {
    Write-Ok "docker present ($(docker --version 2>$null))"
    return
  }

  Write-Info "Docker Desktop needs WSL2 (or Hyper-V) and virtualization enabled in BIOS."
  Write-Info "Enable WSL2 first if needed:  wsl --install"
  Write-Warn "LICENSING: Docker Desktop is PAID for larger orgs (>250 employees OR >`$10M revenue)."
  Write-Info "Free alternative (recommended for work machines): run Docker/Podman INSIDE WSL2:"
  Write-Info "  wsl --install; then in the WSL distro:  curl -fsSL https://get.docker.com | sh"
  Write-Info "(Running the lazy-starter-kit Linux installer inside WSL sets this up for you.)"

  if ($script:DryRun) {
    Write-Info "[dry-run] (optional) winget install --id Docker.DockerDesktop -e (large; reboot likely required)"
    return
  }

  # Declined by default / when non-interactive, because of the licensing caveat.
  if (Confirm-Action "Install Docker Desktop anyway? (confirm your org's license first)") {
    Install-WingetPackage -Id 'Docker.DockerDesktop' -Name 'Docker Desktop'
    Write-Info "After install: launch Docker Desktop once to finish setup, then reboot if prompted."
  } else {
    Write-Info "Skipped. If your org allows it: winget install --id Docker.DockerDesktop -e"
  }
}
