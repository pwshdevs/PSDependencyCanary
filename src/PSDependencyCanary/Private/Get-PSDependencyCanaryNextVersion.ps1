<#
.SYNOPSIS
Calculates the next patch version for a module.
#>
function Get-PSDependencyCanaryNextVersion {
    [CmdletBinding()]
    param([Parameter(Mandatory)][version]$Version)

    $patch = if ($Version.Build -lt 0) { 1 } else { $Version.Build + 1 }
    New-Object System.Version -ArgumentList $Version.Major, $Version.Minor, $patch
}
