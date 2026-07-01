# 03-runtimes.ps1 -- language runtimes: mise (node/python/go/ast-grep) + rustup

$script:MiseTools = @('node@lts', 'python@latest', 'go@latest', 'ubi:ast-grep/ast-grep')

function Step-Runtimes {
  Write-Step "Runtimes: mise (node/python/go/ast-grep) + rustup (rust)"
  Update-SessionPath

  if (-not (Test-HasCommand mise) -or -not (Test-HasCommand rustup)) {
    if ($script:DryRun) {
      Write-Info "[dry-run] would install via mise: $($script:MiseTools -join ', '); Rust stable via rustup (after the packages step provides them)"
      return
    }
    if (-not (Test-HasCommand mise))   { Stop-Kit "mise not found -- run the 'packages' step first." }
    if (-not (Test-HasCommand rustup)) { Stop-Kit "rustup not found -- run the 'packages' step first." }
  }

  # Heads-up: a runtime already installed elsewhere (system MSI, nvm-windows,
  # scoop) is NOT removed -- mise installs its own and shadows it via PATH.
  foreach ($t in @('node', 'python', 'go')) {
    $cmd = Get-Command $t -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source -notmatch 'mise') {
      Write-Warn "existing $t at $($cmd.Source) -- mise will install its own and shadow it (verify later: Get-Command $t -All)"
    }
  }

  # --- mise-managed runtimes --------------------------------------------
  Write-Info "mise: $($script:MiseTools -join ', ')"
  Invoke-Run -Exe 'mise' -Arguments (@('use', '-g') + $script:MiseTools) | Out-Null
  if (-not $script:DryRun) { & mise reshim 2>$null }
  Update-SessionPath

  # --- rust via rustup ---------------------------------------------------
  if ($script:DryRun) {
    Write-Info "[dry-run] rustup default stable; rustup component add rust-analyzer"
  } else {
    $active = (& rustup show active-toolchain 2>$null)
    if ($active) {
      Write-Ok "rust toolchain: $active"
    } else {
      Write-Info "Installing Rust stable toolchain..."
      & rustup default stable
    }
    & rustup component add rust-analyzer 2>$null
    if ($LASTEXITCODE -ne 0) { Write-Warn "rust-analyzer component add skipped" }
  }

  if (-not $script:DryRun) {
    $nodev = (& node -v 2>$null); $rustv = (& rustc --version 2>$null)
    Write-Ok "node $nodev  $rustv"
  }
}
