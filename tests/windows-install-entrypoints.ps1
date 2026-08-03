$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot

# Given the double-click launcher, when its test seam is enabled, then cmd.exe
# reaches the PowerShell installer hand-off without downloading or installing.
$env:STARTER_KIT_LAUNCHER_SELF_TEST = '1'
$launcher = & cmd.exe /d /c (Join-Path $Root 'windows\Install-lazy-starter-kit.cmd') 2>&1 | Out-String
if ($LASTEXITCODE -ne 0) { throw "Windows launcher self-test failed: $launcher" }
if ($launcher -notmatch 'launcher-ready') { throw "Windows launcher did not reach its self-test contract: $launcher" }
Remove-Item Env:STARTER_KIT_LAUNCHER_SELF_TEST
Write-Host 'ok   Windows double-click launcher reaches installer hand-off'

# Given the GUI installer, when it runs in self-test mode, then it exposes the
# profiles and preview support consumed by the release/QA checks.
$gui = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
  (Join-Path $Root 'gui\windows\installer.ps1') -SelfTest | Out-String
if ($LASTEXITCODE -ne 0) { throw "Windows GUI self-test failed: $gui" }
$contract = $gui | ConvertFrom-Json
if (($contract.profiles -join ',') -ne 'full,minimal,work') {
  throw "Windows GUI profiles are incomplete: $gui"
}
if (-not $contract.supportsDryRun) { throw "Windows GUI does not report dry-run support: $gui" }
Write-Host 'ok   Windows GUI reports its contract'

Write-Host 'PASS Windows install entrypoints'
