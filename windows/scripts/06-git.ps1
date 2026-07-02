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
    Invoke-NativeSilently 'gh' @('auth', 'status') | Out-Null
    if ($LASTEXITCODE -eq 0) {
      $ghAuthed = $true
      Write-Ok "gh authenticated ($(Invoke-NativeSilently 'gh' @('api', 'user', '--jq', '.login')))"
    } elseif ($script:DryRun) {
      Write-Info "[dry-run] gh auth login"
    } elseif (-not [Console]::IsInputRedirected) {
      Write-Info "Launching 'gh auth login' (choose GitHub.com -> HTTPS)..."
      & gh auth login
      Invoke-NativeSilently 'gh' @('auth', 'status') | Out-Null
      if ($LASTEXITCODE -eq 0) { $ghAuthed = $true }
    } else {
      Write-Warn "gh not authenticated and input is redirected -- run 'gh auth login' later"
    }
    if (-not $script:DryRun -and $ghAuthed) { Invoke-NativeSilently 'gh' @('auth', 'setup-git') | Out-Null }
  } else {
    Write-Warn "gh CLI not installed -- skipping GitHub auth"
  }

  # --- identity ----------------------------------------------------------
  $curName  = (Invoke-NativeSilently 'git' @('config', '--global', 'user.name'))
  $curEmail = (Invoke-NativeSilently 'git' @('config', '--global', 'user.email'))

  if ($curName -and $curEmail) {
    Write-Ok "git identity already set: $curName <$curEmail>"
  } else {
    $name = $null; $email = $null
    if ($ghAuthed) {
      $login = (Invoke-NativeSilently 'gh' @('api', 'user', '--jq', '.login'))
      $id    = (Invoke-NativeSilently 'gh' @('api', 'user', '--jq', '.id'))
      $name  = (Invoke-NativeSilently 'gh' @('api', 'user', '--jq', '.name // .login'))
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
    $existing = (Invoke-NativeSilently 'git' @('config', '--global', $key))
    if (-not $existing) {
      Invoke-Run -Exe 'git' -Arguments @('config', '--global', $key, $defaults[$key]) | Out-Null
    }
  }
  # On Windows, keep line-endings sane for cross-platform repos
  $autocrlf = (Invoke-NativeSilently 'git' @('config', '--global', 'core.autocrlf'))
  if (-not $autocrlf) { Invoke-Run -Exe 'git' -Arguments @('config', '--global', 'core.autocrlf', 'true') | Out-Null }
  Write-Ok "git defaults ensured (main branch, autoSetupRemote, autocrlf, ...)"
}
