[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ProjectRoot,
    [string]$ModuleManifestPath
)

$moduleManifest = Join-Path -Path (Split-Path $PSScriptRoot -Parent) -ChildPath 'src/PSDependencyCanary/PSDependencyCanary.psd1'
Import-Module -Name $moduleManifest -Force -ErrorAction Stop
$parameters = @{}
foreach ($name in @('ProjectRoot', 'ModuleManifestPath')) {
    if ($PSBoundParameters.ContainsKey($name)) { $parameters[$name] = $PSBoundParameters[$name] }
}
PSDependencyCanary\Update-PSDependencyCanary @parameters -WhatIf:$WhatIfPreference
