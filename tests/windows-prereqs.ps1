#requires -Version 5.1
$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot
$Installer = Join-Path $Root 'windows\install.ps1'
$HostExe = (Get-Process -Id $PID).Path

function Set-CurrentUserPolicy {
  param([Parameter(Mandatory)][string]$Policy)
  try {
    Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy $Policy -Force
  } catch {
    if ($_.FullyQualifiedErrorId -notlike 'ExecutionPolicyOverride*') { throw }
  }
  if ((Get-ExecutionPolicy -Scope CurrentUser) -ne $Policy) {
    throw "could not prepare CurrentUser execution policy $Policy"
  }
}

$original = [string](Get-ExecutionPolicy -Scope CurrentUser)
try {
  # The README runs the installer with a process-scoped Bypass, which outranks
  # CurrentUser and makes Set-ExecutionPolicy report an override.
  Set-CurrentUserPolicy -Policy 'Undefined'
  # A Windows PowerShell child of a PowerShell 7 process inherits PowerShell 7
  # module paths; the installer must still load its own core modules.
  $previousPreference = $ErrorActionPreference
  $savedModulePath = $env:PSModulePath
  $pwshModules = Join-Path $env:ProgramFiles 'PowerShell\7\Modules'
  if (Test-Path -LiteralPath $pwshModules) { $env:PSModulePath = "$pwshModules;$savedModulePath" }
  $ErrorActionPreference = 'Continue'
  try {
    $output = & $HostExe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $Installer -Only prereqs -Yes 2>&1 | Out-String
    $code = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $previousPreference
    $env:PSModulePath = $savedModulePath
  }
  Write-Host $output
  if ($code -ne 0) { throw "prereqs step exited $code" }
  if ($output -match 'could not adjust execution policy') {
    throw 'prereqs warned that the execution policy could not be adjusted after adjusting it'
  }
  if ($output -notmatch 'execution policy \(CurrentUser\) -> RemoteSigned') {
    throw 'prereqs did not report the CurrentUser execution policy change'
  }
  $after = [string](Get-ExecutionPolicy -Scope CurrentUser)
  if ($after -ne 'RemoteSigned') { throw "CurrentUser execution policy is $after; expected RemoteSigned" }
} finally {
  Set-CurrentUserPolicy -Policy $original
}
Write-Host 'ok   prereqs adjusts the execution policy under a process-scoped Bypass without a false warning'
