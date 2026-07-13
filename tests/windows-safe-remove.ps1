#requires -Version 5.1
$ErrorActionPreference = 'Stop'
$script:RunFromFile = $false
. (Join-Path $PSScriptRoot '..\windows\scripts\lib.ps1')

function Fail([string]$Message) { throw "FAIL: $Message" }
function Expect-Throw([scriptblock]$Action, [string]$Label) {
  try { & $Action; Fail "$Label was accepted" } catch {
    if ($_.Exception.Message -like 'FAIL:*') { throw }
  }
}

$tempBase = [IO.Path]::GetTempPath()
$tempRoot = Join-Path $tempBase ("lsk-safe-remove-{0}-{1}" -f $PID, [Guid]::NewGuid().ToString('N'))
$allowed = Join-Path $tempRoot 'allowed'
$outside = Join-Path $tempRoot 'outside'
New-Item -ItemType Directory -Path $allowed, $outside -Force | Out-Null
Set-Content -LiteralPath (Join-Path $outside 'sentinel') -Value 'keep'

try {
  $child = Join-Path $allowed 'child'
  New-Item -ItemType Directory -Path $child -Force | Out-Null
  Set-Content -LiteralPath (Join-Path $child 'file') -Value 'remove'
  Remove-KitTree -AllowedRoot $allowed -Path $child
  if (Test-Path -LiteralPath $child) { Fail 'valid child remained' }
  if (-not (Test-Path -LiteralPath (Join-Path $outside 'sentinel'))) { Fail 'outside sentinel was removed' }

  Remove-KitTree -AllowedRoot $allowed -Path (Join-Path $allowed 'missing')
  Expect-Throw { Remove-KitTree -AllowedRoot $allowed -Path $allowed } 'allowed root'
  Expect-Throw { Remove-KitTree -AllowedRoot ([IO.Path]::GetPathRoot($allowed)) -Path $allowed } 'drive root boundary'
  Expect-Throw { Remove-KitTree -AllowedRoot $allowed -Path $outside } 'outside target'
  Expect-Throw { Remove-KitTree -AllowedRoot $allowed -Path (Join-Path $allowed '..\outside') } 'dot escape'
  Expect-Throw { Remove-KitTree -AllowedRoot $allowed -Path 'relative\target' } 'relative target'

  $literal = Join-Path $allowed 'space [literal] 한글'
  New-Item -ItemType Directory -LiteralPath $literal -Force | Out-Null
  Remove-KitTree -AllowedRoot $allowed -Path $literal
  if (Test-Path -LiteralPath $literal) { Fail 'literal path remained' }

  $dry = Join-Path $allowed 'dry-run'
  New-Item -ItemType Directory -Path $dry -Force | Out-Null
  $script:DryRun = $true
  Remove-KitTree -AllowedRoot $allowed -Path $dry
  $script:DryRun = $false
  if (-not (Test-Path -LiteralPath $dry)) { Fail 'dry-run deleted a target' }

  $junction = Join-Path $allowed 'junction'
  New-Item -ItemType Junction -Path $junction -Target $outside | Out-Null
  Expect-Throw { Remove-KitTree -AllowedRoot $allowed -Path $junction } 'junction target'
  if (-not (Test-Path -LiteralPath (Join-Path $outside 'sentinel'))) { Fail 'junction rejection lost outside data' }
  [IO.Directory]::Delete($junction)

  $recursive = @(Get-ChildItem (Join-Path $PSScriptRoot '..\windows') -Recurse -Filter '*.ps1' |
    Select-String -Pattern 'Remove-Item.*-Recurse')
  if ($recursive.Count -ne 1 -or $recursive[0].Path -notlike '*scripts\lib.ps1') {
    Fail "recursive Remove-Item escaped Remove-KitTree: $($recursive | ForEach-Object { $_.Path + ':' + $_.LineNumber })"
  }

  if (Get-Command node -ErrorAction SilentlyContinue) {
    $agentHome = Join-Path $tempRoot 'agent-home'
    New-Item -ItemType Directory -Path (Join-Path $agentHome '.codex'), (Join-Path $agentHome '.claude') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $agentHome '.codex\hooks.json') -Encoding UTF8 -Value '{"existing":true}'
    Set-Content -LiteralPath (Join-Path $agentHome '.claude\settings.json') -Encoding UTF8 -Value '{"existing":true}'
    $installer = Join-Path $PSScriptRoot '..\scripts\ai\install-shell-guard.js'
    & node $installer --home $agentHome
    if ($LASTEXITCODE -ne 0) { Fail 'Windows AI guard install failed' }
    & node $installer --home $agentHome
    if ($LASTEXITCODE -ne 0) { Fail 'Windows AI guard reinstall failed' }
    foreach ($file in @((Join-Path $agentHome '.codex\hooks.json'), (Join-Path $agentHome '.claude\settings.json'))) {
      $config = Get-Content -LiteralPath $file -Raw | ConvertFrom-Json
      if (-not $config.existing) { Fail "existing AI config was lost: $file" }
      $managed = @($config.hooks.PreToolUse | ForEach-Object { $_.hooks } |
        Where-Object { $_.command -like '*shell-command-guard.js*' })
      if ($managed.Count -ne 1) { Fail "expected one AI guard hook in $file" }
    }
    if (-not (Test-Path -LiteralPath (Join-Path $agentHome '.local\bin\lazy-safe-rm.cmd'))) {
      Fail 'Windows lazy-safe-rm.cmd was not installed'
    }
    & node $installer uninstall --home $agentHome
    if ($LASTEXITCODE -ne 0) { Fail 'Windows AI guard uninstall failed' }
  }

  Write-Output 'ok: Windows recursive deletion is confined to Remove-KitTree'
} finally {
  $script:DryRun = $false
  if (Test-Path -LiteralPath $tempRoot) { Remove-KitTree -AllowedRoot $tempBase -Path $tempRoot }
}
