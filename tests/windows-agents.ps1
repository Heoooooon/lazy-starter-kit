#requires -Version 5.1
$ErrorActionPreference = 'Stop'
$Root = Join-Path $PSScriptRoot '..\windows'
. (Join-Path $Root 'scripts\lib.ps1')
. (Join-Path $Root 'scripts\07-agents.ps1')

function Assert-Equal($Actual, $Expected, [string]$Label) {
  if ($Actual -cne $Expected) {
    throw "FAIL: ${Label}: expected [$Expected], got [$Actual]"
  }
}

# Mock command boundaries, not Step-Agents or its real invocation helpers.
function Record-Command([string]$Name, [string[]]$Arguments) {
  $script:Calls.Add((@($Name) + @($Arguments) -join ' '))
  $global:LASTEXITCODE = 0
}
function npm { Record-Command 'npm' $args }
# PowerShell consumes the -- separator when binding a function mock.
function mise { Record-Command 'mise' $args }
function bun { Record-Command 'bun' $args }
function npx { Record-Command 'npx' $args }
function node { Record-Command 'node' $args }
function gjc { Record-Command 'gjc' $args; 'legacy-version' }
function codex { Record-Command 'codex' $args; 'codex-version' }
function claude { Record-Command 'claude' $args; 'claude-version' }
function Update-SessionPath {}
function Test-HasCommand([string]$Name) {
  $script:Probes.Add($Name)
  return $script:Available -contains $Name
}
function Invoke-RestMethod([string]$Uri) {
  Record-Command 'Invoke-RestMethod' @($Uri)
  return 'Invoke-ClaudeInstallerMock'
}
function Invoke-ClaudeInstallerMock {
  Record-Command 'claude-native-install' @()
  $script:Available += 'claude'
}

$worktree = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).ProviderPath)
$fixtureBase = Join-Path $worktree '.tmp-tests'
$fixtureRoot = Join-Path $fixtureBase ("windows-agents-{0}" -f [Guid]::NewGuid().ToString('N'))
$ownerToken = [Guid]::NewGuid().ToString('N')
$ownerPath = Join-Path $fixtureRoot '.windows-agents-owner'

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
# No -Force: an existing fixture is never adopted or overwritten.
New-Item -ItemType Directory -Path $fixtureRoot | Out-Null
Assert-FixtureBoundary $ownerPath
[IO.File]::WriteAllText($ownerPath, $ownerToken)
$tempRoot = Join-Path $fixtureRoot 'home'
$doctorHome = Join-Path $fixtureRoot 'doctor-home'
$fixtureTemp = Join-Path $fixtureRoot 'temp'
foreach ($path in @($tempRoot, $doctorHome, $fixtureTemp)) {
  Assert-FixtureBoundary $path
  Assert-Equal ([IO.File]::ReadAllText($ownerPath)) $ownerToken 'fixture ownership'
  New-Item -ItemType Directory -Path $path | Out-Null
}
$savedEnvironment = @{}
foreach ($name in @('HOME', 'USERPROFILE', 'APPDATA', 'LOCALAPPDATA', 'TMPDIR', 'TMP', 'TEMP')) {
  $savedEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
}
$savedHome = $HOME
try {
  Set-Variable -Name HOME -Scope Script -Value $tempRoot -Force
  $env:HOME = $tempRoot
  $env:USERPROFILE = $tempRoot
  $env:APPDATA = Join-Path $tempRoot 'AppData\Roaming'
  $env:LOCALAPPDATA = Join-Path $tempRoot 'AppData\Local'
  $env:TMPDIR = $fixtureTemp
  $env:TMP = $fixtureTemp
  $env:TEMP = $fixtureTemp
  Write-Host "Fixture boundary: $fixtureRoot; owner marker: $ownerPath"
  Write-Host "HOME/USERPROFILE: $tempRoot; doctor home: $doctorHome; temp: $fixtureTemp"
  # Legacy executables, config, plugins, and session data must be left alone.
  $sentinels = @(
    '.bun/bin/gjc.exe', '.bun/install/global/node_modules/gajae-code/package.json',
    '.gjc/config.json', '.gjc/sessions/keep.json',
    '.local/bin/lazycodex', 'AppData/Roaming/npm/lazycodex.cmd',
    '.codex/config.toml', '.codex/hooks.json',
    '.codex/plugins/cache/sisyphuslabs/omo/keep.json',
    '.codex/sessions/keep.jsonl', '.claude/settings.json'
  )
  $hashes = @{}
  foreach ($relative in $sentinels) {
    $path = Join-Path $tempRoot $relative
    Assert-FixtureBoundary $path
    New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force | Out-Null
    [IO.File]::WriteAllText($path, "legacy sentinel: $relative`n")
    $hashes[$relative] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
  }
  $guard = Join-Path (Split-Path -Parent $Root) 'scripts\ai\install-shell-guard.js'
  if (-not (Test-Path -LiteralPath $guard)) { throw 'Missing real guard installer' }
  $guardCommand = "node $guard --home $tempRoot"
  $nativeClaude = @(
    'Invoke-RestMethod https://claude.ai/install.ps1',
    'claude-native-install', 'claude --version'
  )
  $cases = @(
    @{ Name = 'fresh npm'; Available = @('bun', 'npm', 'node'); Dry = $false;
      Expected = @('npm install -g @openai/codex') + $nativeClaude + @($guardCommand) },
    @{ Name = 'fresh mise'; Available = @('bun', 'mise', 'node'); Dry = $false;
      Expected = @('mise exec npm install -g @openai/codex', 'mise reshim') + $nativeClaude + @($guardCommand) },
    @{ Name = 'existing agents and legacy tools'; Available = @('bun', 'npm', 'mise', 'node', 'gjc', 'lazycodex', 'codex', 'claude'); Dry = $false;
      Expected = @('codex --version', 'claude --version', $guardCommand) },
    @{ Name = 'fresh dry-run'; Available = @('bun', 'npm', 'node'); Dry = $true;
      Expected = @("$guardCommand --dry-run") },
    @{ Name = 'existing dry-run'; Available = @('bun', 'npm', 'node', 'gjc', 'lazycodex', 'codex', 'claude'); Dry = $true;
      Expected = @('codex --version', 'claude --version', "$guardCommand --dry-run") }
  )
  $failures = New-Object 'System.Collections.Generic.List[string]'
  foreach ($case in $cases) {
    $script:Calls = New-Object 'System.Collections.Generic.List[string]'
    $script:Probes = New-Object 'System.Collections.Generic.List[string]'
    $script:Available = $case.Available
    $script:DryRun = $case.Dry
    try {
      Step-Agents
      Assert-Equal ($script:Calls -join ' | ') ($case.Expected -join ' | ') $case.Name
      Assert-Equal (@($script:Probes | Where-Object { $_ -in @('gjc', 'lazycodex') }).Count) 0 'no legacy command probes'
      foreach ($relative in $sentinels) {
        $path = Join-Path $tempRoot $relative
        Assert-Equal (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash $hashes[$relative] "preserved $relative"
      }
      Assert-Equal (@(Get-ChildItem -LiteralPath $tempRoot -File -Recurse -Force).Count) $sentinels.Count 'no extra home files'
      Write-Host "PASS: $($case.Name); legacy sentinels unchanged"
    } catch {
      $failures.Add("$($case.Name): $($_.Exception.Message)")
    }
  }

  # Load the actual doctor function without running installer preflight/bootstrap.
  $tokens = $null
  $parseErrors = $null
  $ast = [Management.Automation.Language.Parser]::ParseFile(
    (Join-Path $Root 'install.ps1'), [ref]$tokens, [ref]$parseErrors)
  Assert-Equal $parseErrors.Count 0 'installer parses'
  $doctor = $ast.Find({
    param($entry)
    $entry -is [Management.Automation.Language.FunctionDefinitionAst] -and
      $entry.Name -eq 'Invoke-Doctor'
  }, $true)
  if (-not $doctor) { throw 'Invoke-Doctor not found' }
  . ([scriptblock]::Create($doctor.Extent.Text))
  & {
    $KitVersion = 'test'
    $HomeDir = $tempRoot
    $required = @('git', 'gh', 'jq', 'rg', 'fd', 'bat', 'fzf', 'starship',
      'mise', 'uv', 'rustup', 'bun', 'codex', 'claude')
    function Get-Command {
      param([string]$Name, [string]$ErrorAction)
      $script:Probes.Add($Name)
      if ($required -contains $Name -and $Name -ne $missingTool) {
        [pscustomobject]@{ Name = $Name }
      }
    }
    function Invoke-NativeSilently {
      param([string]$Exe, [string[]]$Arguments)
      $global:LASTEXITCODE = 0
      'mock-version-or-runtime-path'
    }
    function Get-AllHostsProfilePaths { @() }
    # Doctor probes a clean home: legacy binaries must not mask a requirement.
    $HomeDir = $doctorHome
    Set-Variable -Name HOME -Scope Local -Value $doctorHome -Force
    $env:HOME = $doctorHome
    $env:USERPROFILE = $doctorHome
    $env:APPDATA = Join-Path $env:USERPROFILE 'AppData\Roaming'
    $env:LOCALAPPDATA = Join-Path $env:USERPROFILE 'AppData\Local'
    foreach ($missingTool in @('', 'codex', 'claude')) {
      $script:Probes.Clear()
      try {
        $expected = if ($missingTool) { 1 } else { 0 }
        Assert-Equal (Invoke-Doctor) $expected "doctor missing=[$missingTool]"
        Assert-Equal (@($script:Probes | Where-Object { $_ -in @('gjc', 'lazycodex') }).Count) 0 'doctor ignores legacy tools'
        Write-Host "PASS: doctor missing=[$missingTool]"
      } catch {
        $failures.Add("doctor missing=[$missingTool]: $($_.Exception.Message)")
      }
    }
  }
  Assert-FixtureBoundary $ownerPath
  Assert-Equal ([IO.File]::ReadAllText($ownerPath)) $ownerToken 'fixture ownership retained'
  if ($failures.Count) { throw ($failures -join "`n") }
  Write-Host 'PASS: Windows agents regression'
} finally {
  try {
    # Cleanup authority comes from this fresh root and its independent token,
    # never from HOME/USERPROFILE or the machine's temporary-directory setting.
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
