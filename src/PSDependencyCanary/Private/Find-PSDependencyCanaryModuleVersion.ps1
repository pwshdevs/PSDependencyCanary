<#
.SYNOPSIS
Finds the newest stable PSGallery version of a module.
#>
function Find-PSDependencyCanaryModuleVersion {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Name)

    if (-not (Get-Command -Name Find-Module -ErrorAction SilentlyContinue)) {
        throw 'Find-Module is required to resolve dependency updates from PSGallery.'
    }
    $module = Find-Module -Name $Name -Repository PSGallery -ErrorAction Stop |
        Sort-Object Version -Descending |
        Select-Object -First 1
    if (-not $module) { throw "Module '$Name' was not found in PSGallery." }
    [version]$module.Version
}
