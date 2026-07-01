# 04-shell.ps1 -- PowerShell profile: mise/starship/bun wiring + PSFzf + starship.toml

function Step-Shell {
  Write-Step "Shell: PowerShell profile + prompt + fuzzy finder"
  Update-SessionPath

  # --- PSReadLine 2.2+ (inline prediction = zsh-autosuggestions equivalent) --
  # Windows PowerShell 5.1 ships an old PSReadLine (2.0) with no inline
  # prediction, so upgrade to >= 2.2 from the gallery when needed.
  $psrl = Get-Module -ListAvailable -Name PSReadLine | Sort-Object Version -Descending | Select-Object -First 1
  if (-not $psrl -or $psrl.Version -lt [version]'2.2.0') {
    Write-Info "Installing/upgrading PSReadLine (>= 2.2 for inline prediction)..."
    if ($script:DryRun) {
      Write-Info "[dry-run] Install-Module PSReadLine -Scope CurrentUser -Force"
    } else {
      try {
        if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
          Install-PackageProvider -Name NuGet -Scope CurrentUser -Force -ErrorAction SilentlyContinue | Out-Null
        }
        Install-Module PSReadLine -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
        Write-Ok "PSReadLine installed/upgraded (restart PowerShell to load it)"
      } catch { Write-Warn "PSReadLine install skipped: $($_.Exception.Message)" }
    }
  } else {
    Write-Ok "PSReadLine $($psrl.Version) present"
  }

  # --- CompletionPredictor (command-based predictions for HistoryAndPlugin) ---
  if (-not (Get-Module -ListAvailable -Name CompletionPredictor)) {
    if ($script:DryRun) {
      Write-Info "[dry-run] Install-Module CompletionPredictor -Scope CurrentUser"
    } else {
      Write-Info "Installing CompletionPredictor (richer autosuggestions)..."
      try {
        if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
          Install-PackageProvider -Name NuGet -Scope CurrentUser -Force -ErrorAction SilentlyContinue | Out-Null
        }
        Install-Module CompletionPredictor -Scope CurrentUser -Force -ErrorAction Stop
        Write-Ok "CompletionPredictor installed"
      } catch { Write-Warn "CompletionPredictor install skipped: $($_.Exception.Message)" }
    }
  } else {
    Write-Ok "CompletionPredictor present"
  }

  # --- PSFzf (fzf keybindings for PowerShell) ----------------------------
  if (-not (Get-Module -ListAvailable -Name PSFzf)) {
    if ($script:DryRun) {
      Write-Info "[dry-run] Install-Module PSFzf -Scope CurrentUser"
    } else {
      Write-Info "Installing PSFzf (CurrentUser)..."
      try {
        if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
          Install-PackageProvider -Name NuGet -Scope CurrentUser -Force -ErrorAction SilentlyContinue | Out-Null
        }
        Install-Module PSFzf -Scope CurrentUser -Force -ErrorAction Stop
        Write-Ok "PSFzf installed"
      } catch { Write-Warn "PSFzf install skipped: $($_.Exception.Message)" }
    }
  } else {
    Write-Ok "PSFzf present"
  }

  # --- inject our managed profile block ----------------------------------
  $profilePath = $PROFILE.CurrentUserAllHosts
  $blockFile = Join-Path $PSScriptRoot '..\config\profile.block.ps1'
  $blockFile = [System.IO.Path]::GetFullPath($blockFile)
  if (Test-Path $blockFile) {
    $content = [System.IO.File]::ReadAllText($blockFile)
    Update-ManagedBlock -Path $profilePath -Tag 'lazy-starter-kit:main' -Content $content
  } else {
    Write-Warn "profile block file missing: $blockFile"
  }

  # --- starship preset (don't clobber an existing one) -------------------
  $starshipToml = Join-Path $env:USERPROFILE '.config\starship.toml'
  if (Test-Path $starshipToml) {
    Write-Ok "starship.toml present (left untouched)"
  } elseif ($script:DryRun) {
    Write-Info "[dry-run] copy starship.toml -> ~\.config\starship.toml"
  } else {
    $src = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\config\starship.toml'))
    $dir = Split-Path -Parent $starshipToml
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    Copy-Item $src $starshipToml
    Write-Ok "installed ~\.config\starship.toml"
  }

  Write-Info "Nerd Font installed -- set your terminal font to 'JetBrainsMono Nerd Font' (Windows Terminal: Settings > Profiles > Appearance)."
}
