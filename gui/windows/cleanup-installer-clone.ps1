#requires -Version 5.1
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$AllowedRoot,
  [Parameter(Mandatory)][string]$Path
)

$bundledLibrary = Join-Path $PSScriptRoot 'cleanup-lib.ps1'
$libraryPath = if (Test-Path -LiteralPath $bundledLibrary) {
  $bundledLibrary
} else {
  [System.IO.Path]::GetFullPath(
    (Join-Path $PSScriptRoot '..\..\windows\scripts\lib.ps1')
  )
}
if (-not (Test-Path -LiteralPath $libraryPath)) {
  throw "Safe cleanup library not found: $libraryPath"
}

. $libraryPath
Remove-KitTree -AllowedRoot $AllowedRoot -Path $Path
