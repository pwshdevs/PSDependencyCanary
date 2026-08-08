<#
.SYNOPSIS
Rewrites a module manifest version while preserving its layout.
#>
function ConvertTo-PSDependencyCanaryManifestContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Content,
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][version]$Version
    )

    $hashtable = Get-PSDependencyCanaryHashtableAst -Content $Content -Path $Path
    $versionPair = Get-PSDependencyCanaryHashtablePair -Hashtable $hashtable -Key 'ModuleVersion'
    if (-not $versionPair) { throw "ModuleVersion was not found in $Path." }
    $versionAst = Get-PSDependencyCanaryPairStringAst -Pair $versionPair
    ConvertTo-PSDependencyCanaryReplacedContent -Content $Content -Replacement @(
        [pscustomobject]@{
            StartOffset = $versionAst.Extent.StartOffset
            EndOffset = $versionAst.Extent.EndOffset
            Text = "'$Version'"
        }
    )
}
