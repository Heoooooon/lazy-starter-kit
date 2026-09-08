#requires -Version 5.1
$ErrorActionPreference = 'Stop'
$worktree = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).ProviderPath
$fixtureBase = Join-Path $worktree '.tmp-tests'
$fixtureRoot = Join-Path $fixtureBase ('windows-profiles-' + [Guid]::NewGuid().ToString('N'))
$ownerToken = [Guid]::NewGuid().ToString('N')
$ownerPath = Join-Path $fixtureRoot '.windows-profiles-owner'
function Assert-Equal($Actual, $Expected, [string]$Label) {
  if ($Actual -cne $Expected) { throw "${Label}: expected [$Expected], got [$Actual]" }
}
function Assert-FixtureBoundary([string]$Path) {
  $full = [IO.Path]::GetFullPath($Path)
  $prefix = $fixtureBase + [IO.Path]::DirectorySeparatorChar
  if (-not $full.StartsWith($prefix, [StringComparison]::Ordinal)) {
    throw "Fixture path must be strictly below ${fixtureBase}: $Path"
  }
  # Reject links in every existing ancestor before writing any fixture data.
  $cursor = $full
  while ($cursor) {
    if (Test-Path -LiteralPath $cursor) {
      if (((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "Fixture path crosses a reparse point: $cursor"
      }
    }
    if ($cursor -eq $worktree) { break }
    $cursor = [IO.Path]::GetDirectoryName($cursor)
  }
  if ($cursor -ne $worktree) { throw "Fixture path escapes worktree: $Path" }
}


Assert-FixtureBoundary $fixtureRoot
if (-not (Test-Path -LiteralPath $fixtureBase)) {
  New-Item -ItemType Directory -Path $fixtureBase | Out-Null
}
New-Item -ItemType Directory -Path $fixtureRoot | Out-Null
[IO.File]::WriteAllText($ownerPath, $ownerToken)
$savedEnvironment = @{}
foreach ($name in @('HOME', 'USERPROFILE', 'APPDATA', 'LOCALAPPDATA', 'TMPDIR', 'TMP', 'TEMP', 'XDG_CACHE_HOME', 'STARTER_KIT_HANDOFF_CHILD')) {
  $savedEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
}
$savedHome = $HOME
try {
  foreach ($name in @('home', 'temp', 'cache', 'scripts')) {
    New-Item -ItemType Directory -Path (Join-Path $fixtureRoot $name) | Out-Null
  }
  $env:HOME = Join-Path $fixtureRoot 'home'
  $env:USERPROFILE = $env:HOME
  Set-Variable -Name HOME -Scope Script -Value $env:HOME -Force
  $env:APPDATA = Join-Path $env:HOME 'AppData/Roaming'
  $env:LOCALAPPDATA = Join-Path $env:HOME 'AppData/Local'
  $env:TMPDIR = Join-Path $fixtureRoot 'temp'
  $env:TMP = $env:TMPDIR
  $env:TEMP = $env:TMPDIR
  $env:XDG_CACHE_HOME = Join-Path $fixtureRoot 'cache'
  $env:STARTER_KIT_HANDOFF_CHILD = '1'
  Write-Host "Owned fixture: $fixtureRoot; marker: $ownerPath"
  Write-Host "HOME/USERPROFILE: $env:HOME; temp: $env:TEMP; cache: $env:XDG_CACHE_HOME"

  # Execute the unmodified entrypoint: parameter binding, registry, selectors,
  # rendered plan and dispatch. Only OS/install boundaries are replaced.
  $installer = Join-Path $fixtureRoot 'install.ps1'
  Copy-Item (Join-Path $worktree 'windows/install.ps1') $installer
  @'
function Test-IsWindows { $true }
function Stop-Kit([string]$Message) { throw $Message }
function Write-Info([string]$Message) { Write-Output $Message }
function Write-Step([string]$Message) {}
function Write-Warn([string]$Message) {}
function Test-HasCommand([string]$Name) { $false }
'@ | Set-Content (Join-Path $fixtureRoot 'scripts/lib.ps1') -Encoding UTF8
  $ids = @('prereqs', 'packages', 'runtimes', 'shell', 'docker', 'git', 'agents', 'wsl')
  for ($i = 0; $i -lt $ids.Count; $i++) {
    $id = $ids[$i]
    $step = 'function Step-' + $id + ' { if (-not $script:DryRun -or -not $script:AssumeYes) { throw "Unsafe fixture invocation" }; "dispatch:' + $id + '" }'
    $step | Set-Content (Join-Path $fixtureRoot ('scripts/{0:00}-{1}.ps1' -f ($i + 1), $id)) -Encoding UTF8
  }
  $full = $ids -join ' '
  $recommended = 'prereqs packages runtimes shell git agents'
  $minimal = 'prereqs packages runtimes shell git'
  $cases = @(
    @{ Name = 'recommended'; Params = @{ Profile = 'recommended' }; Plan = $recommended },
    @{ Name = 'default AI'; Params = @{}; Plan = 'prereqs packages runtimes shell agents' },
    @{ Name = 'explicit AI'; Params = @{ Profile = 'ai' }; Plan = 'prereqs packages runtimes shell agents' },
    @{ Name = 'full'; Params = @{ Profile = 'full' }; Plan = $full },
    @{ Name = 'minimal'; Params = @{ Profile = 'minimal' }; Plan = $minimal },
    @{ Name = 'work'; Params = @{ Profile = 'work' }; Plan = $recommended },
    @{ Name = 'recommended skip union'; Params = @{ Profile = 'recommended'; Skip = @('shell,git', 'docker') }; Plan = 'prereqs packages runtimes agents' },
    @{ Name = 'recommended NoAgents'; Params = @{ Profile = 'recommended'; NoAgents = $true }; Plan = $minimal },
    @{ Name = 'full skip'; Params = @{ Profile = 'full'; Skip = 'agents,wsl' }; Plan = 'prereqs packages runtimes shell docker git' },
    @{ Name = 'minimal skip'; Params = @{ Profile = 'minimal'; Skip = 'shell' }; Plan = 'prereqs packages runtimes git' },
    @{ Name = 'work skip'; Params = @{ Profile = 'work'; Skip = 'agents' }; Plan = $minimal },
    @{ Name = 'only preserves registry order'; Params = @{ Only = @(' agents, shell ', 'agents') }; Plan = 'shell agents' },
    @{ Name = 'only takes precedence over skip'; Params = @{ Only = 'agents,shell'; Skip = 'agents'; NoAgents = $true }; Plan = 'shell agents' },
    @{ Name = 'case insensitive profile'; Params = @{ Profile = 'RECOMMENDED' }; Plan = $recommended },
    @{ Name = 'skip every step'; Params = @{ Profile = 'recommended'; Skip = $ids }; Plan = '' },
    @{ Name = 'unknown profile'; Params = @{ Profile = 'recomended' }; Reject = $true },
    @{ Name = 'unknown only token'; Params = @{ Only = 'shell,typo' }; Reject = $true },
    @{ Name = 'unknown skip token'; Params = @{ Profile = 'recommended'; Skip = 'typo' }; Reject = $true },
    @{ Name = 'only still validates skip'; Params = @{ Only = 'shell'; Skip = 'typo' }; Reject = $true }
  )
  foreach ($preset in @('ai', 'recommended', 'full', 'minimal', 'work')) {
    $cases += @{ Name = "$preset rejects only"; Params = @{ Profile = $preset; Only = 'shell' }; Reject = $true }
  }
  $failures = @()
  foreach ($case in $cases) {
    try {
      $params = $case.Params
      $output = @()
      $failure = $null
      try { $output = @(& $installer -DryRun -Yes @params) } catch { $failure = $_ }
      if ($case.Reject) {
        if (-not $failure) { throw 'Invalid selector accepted' }
      } else {
        if ($failure) { throw $failure }
        $plans = @($output | Where-Object { $_ -match '^steps: ' })
        Assert-Equal $plans.Count 1 'one parsed plan'
        $plan = ($plans[0] -replace '^steps: ', '' -replace '\s+\(profile: [^)]+\)$', '').Trim()
        Assert-Equal $plan $case.Plan 'selected steps'
        $dispatched = @($output | Where-Object { $_ -match '^dispatch:' } | ForEach-Object { $_ -replace '^dispatch:', '' })
        Assert-Equal ($dispatched -join ' ') $case.Plan 'actual dispatch order'
      }
      Write-Host "PASS: $($case.Name)"
    } catch {
      $failures += "$($case.Name): $($_.Exception.Message)"
      Write-Host "FAIL: $($failures[-1])"
    }
  }
  if ($failures.Count) { throw ($failures -join [Environment]::NewLine) }
  Write-Host "PASS: Windows profiles ($($cases.Count) cases)"
} finally {
  try {
    # Cleanup authority comes from this fresh root and its independent token,
    # never from HOME/USERPROFILE or the machine's temporary-directory setting.
    . (Join-Path $worktree 'windows/scripts/lib.ps1')
    Assert-FixtureBoundary $ownerPath
    Assert-Equal ([IO.File]::ReadAllText($ownerPath)) $ownerToken 'cleanup ownership'
    # Inspect one directory at a time, rejecting links before descending.
    $pending = New-Object 'System.Collections.Generic.Stack[string]'
    $pending.Push($fixtureRoot)
    while ($pending.Count) {
      $directory = $pending.Pop()
      Assert-FixtureBoundary $directory
      foreach ($item in (Get-ChildItem -LiteralPath $directory -Force)) {
        Assert-FixtureBoundary $item.FullName
        if ($item.PSIsContainer) { $pending.Push($item.FullName) }
      }
    }
    if (Test-IsWindows) {
      $script:DryRun = $false
      Remove-KitTree -AllowedRoot $fixtureBase -Path $fixtureRoot
      Assert-Equal (Test-Path -LiteralPath $fixtureRoot) $false 'owned fixture cleanup'
      Write-Host "Cleaned owned fixture through Remove-KitTree: $fixtureRoot"
    } else {
      # The existing helper requires native Windows drive paths. Do not widen
      # it or substitute another recursive deleter for portable Docker tests.
      Write-Host "Retained owned fixture: $fixtureRoot (Remove-KitTree requires Windows drive paths)"
    }
  } finally {
    # No cleanup runs after restoring the caller's real environment.
    foreach ($name in $savedEnvironment.Keys) {
      [Environment]::SetEnvironmentVariable($name, $savedEnvironment[$name], 'Process')
    }
    Set-Variable -Name HOME -Scope Script -Value $savedHome -Force
  }
}
