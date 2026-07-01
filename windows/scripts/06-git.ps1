# 06-git.ps1 -- git identity + sensible defaults + GitHub auth

function Step-Git {
  Write-Step "git identity + GitHub auth"
  Update-SessionPath

  if (-not (Test-HasCommand git)) {
    if ($script:DryRun) { Write-Info "[dry-run] git would be present after the 'packages' step"; return }
    Stop-Kit "git not found -- run the 'packages' step first."
  }

  # --- gh login (derive identity + wire HTTPS credentials) ---------------
  $ghAuthed = $false
  if (Test-HasCommand gh) {
    & gh auth status 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
      $ghAuthed = $true
      Write-Ok "gh authenticated ($(& gh api user --jq .login 2>$null))"
    } elseif ($script:DryRun) {
      Write-Info "[dry-run] gh auth login"
    } elseif (-not [Console]::IsInputRedirected) {
      Write-Info "Launching 'gh auth login' (choose GitHub.com -> HTTPS)..."
      & gh auth login
      & gh auth status 2>$null | Out-Null
      if ($LASTEXITCODE -eq 0) { $ghAuthed = $true }
    } else {
      Write-Warn "gh not authenticated and input is redirected -- run 'gh auth login' later"
    }
    if (-not $script:DryRun -and $ghAuthed) { & gh auth setup-git 2>$null | Out-Null }
  } else {
    Write-Warn "gh CLI not installed -- skipping GitHub auth"
  }

  # --- identity ----------------------------------------------------------
  $curName  = (& git config --global user.name 2>$null)
  $curEmail = (& git config --global user.email 2>$null)

  if ($curName -and $curEmail) {
    Write-Ok "git identity already set: $curName <$curEmail>"
  } else {
    $name = $null; $email = $null
    if ($ghAuthed) {
      $login = (& gh api user --jq .login 2>$null)
      $id    = (& gh api user --jq .id 2>$null)
      $name  = (& gh api user --jq '.name // .login' 2>$null)
      if ($login -and $id) { $email = "$id+$login@users.noreply.github.com" }
    }
    if (-not $name)  { $name  = Read-Default 'git author name:'  $curName }
    if (-not $email) { $email = Read-Default 'git author email:' $curEmail }

    if ($name -and $email) {
      Invoke-Run -Exe 'git' -Arguments @('config', '--global', 'user.name', $name)  | Out-Null
      Invoke-Run -Exe 'git' -Arguments @('config', '--global', 'user.email', $email) | Out-Null
      Write-Ok "git identity: $name <$email>"
    } else {
      Write-Warn "git identity left unset -- set later: git config --global user.name/.email"
    }
  }

  # --- sensible defaults (only fill if empty; never clobber) -------------
  $defaults = [ordered]@{
    'init.defaultBranch'    = 'main'
    'pull.rebase'           = 'false'
    'push.default'          = 'simple'
    'push.autoSetupRemote'  = 'true'
  }
  foreach ($key in $defaults.Keys) {
    $existing = (& git config --global $key 2>$null)
    if (-not $existing) {
      Invoke-Run -Exe 'git' -Arguments @('config', '--global', $key, $defaults[$key]) | Out-Null
    }
  }
  # On Windows, keep line-endings sane for cross-platform repos
  $autocrlf = (& git config --global core.autocrlf 2>$null)
  if (-not $autocrlf) { Invoke-Run -Exe 'git' -Arguments @('config', '--global', 'core.autocrlf', 'true') | Out-Null }
  Write-Ok "git defaults ensured (main branch, autoSetupRemote, autocrlf, ...)"
}
