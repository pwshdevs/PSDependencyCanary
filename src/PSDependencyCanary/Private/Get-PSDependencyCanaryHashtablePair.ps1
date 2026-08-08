<#
.SYNOPSIS
Gets a named key-value pair from a PowerShell hashtable syntax tree.
#>
function Get-PSDependencyCanaryHashtablePair {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][System.Management.Automation.Language.HashtableAst]$Hashtable,
        [Parameter(Mandatory)][string]$Key
    )

    @($Hashtable.KeyValuePairs | Where-Object { $_.Item1.Value -eq $Key }) |
        Select-Object -First 1
}
