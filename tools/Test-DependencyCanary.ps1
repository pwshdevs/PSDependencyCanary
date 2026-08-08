[CmdletBinding()]
param([string]$ProjectRoot)

$moduleManifest = Join-Path -Path (Split-Path $PSScriptRoot -Parent) -ChildPath 'src/PSDependencyCanary/PSDependencyCanary.psd1'
Import-Module -Name $moduleManifest -Force -ErrorAction Stop
PSDependencyCanary\Test-PSDependencyCanary -ProjectRoot $ProjectRoot
