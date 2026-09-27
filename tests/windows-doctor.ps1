#requires -Version 5.1
$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot
$Installer = Join-Path $Root 'windows\install.ps1'
$HostExe = (Get-Process -Id $PID).Path

# Refresh the paths persisted by installers; GitHub Actions step processes do
# not inherit the previous step's in-process PATH refresh.
$pathParts = @(
  $env:Path,
  [Environment]::GetEnvironmentVariable('Path', 'Machine'),
  [Environment]::GetEnvironmentVariable('Path', 'User'),
  (Join-Path $env:USERPROFILE '.cargo\bin'),
  (Join-Path $env:USERPROFILE '.bun\bin'),
  (Join-Path $env:USERPROFILE '.local\bin'),
  (Join-Path $env:LOCALAPPDATA 'mise\shims'),
  (Join-Path $env:APPDATA 'npm')
) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
$env:Path = $pathParts -join ';'

function Invoke-DoctorProcess {
  $process = Start-Process `
    -FilePath $HostExe `
    -ArgumentList @('-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $Installer, '-Doctor') `
    -NoNewWindow `
    -Wait `
    -PassThru
  return $process.ExitCode
}

function Assert-DoctorFailsWithoutFile {
  param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Label)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Doctor regression fixture is missing $Label before the test: $Path"
  }
  $hidden = "$Path.doctor-test-$PID"
  if (Test-Path -LiteralPath $hidden) {
    throw "Doctor regression backup path already exists: $hidden"
  }
  Move-Item -LiteralPath $Path -Destination $hidden
  try {
    $code = Invoke-DoctorProcess
    if ($code -ne 1) { throw "Doctor returned $code with $Label missing; expected 1" }
  } finally {
    Move-Item -LiteralPath $hidden -Destination $Path
  }
}

if ((Invoke-DoctorProcess) -ne 0) {
  throw 'Doctor did not return 0 for the healthy installed environment'
}

$script:RunFromFile = $false
. (Join-Path $Root 'windows\scripts\lib.ps1')
$profilePath = @(Get-AllHostsProfilePaths)[0]
$starshipPath = Join-Path $env:USERPROFILE '.config\starship.toml'

Assert-DoctorFailsWithoutFile -Path $profilePath -Label 'managed PowerShell profile'
Assert-DoctorFailsWithoutFile -Path $starshipPath -Label 'starship.toml'

if ((Invoke-DoctorProcess) -ne 0) {
  throw 'Doctor did not return to healthy status after restoring config fixtures'
}

Write-Output 'PASS Windows Doctor config exit-code contract'
