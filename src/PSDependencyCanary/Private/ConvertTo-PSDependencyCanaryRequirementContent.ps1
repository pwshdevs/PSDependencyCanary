<#
.SYNOPSIS
Rewrites PSDepend requirement versions while preserving the data-file layout.
#>
function ConvertTo-PSDependencyCanaryRequirementContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Content,
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Version
    )

    $hashtable = Get-PSDependencyCanaryHashtableAst -Content $Content -Path $Path
    $replacements = @()
    foreach ($pair in $hashtable.KeyValuePairs) {
        $moduleName = [string]$pair.Item1.Value
        if ($moduleName -eq 'PSDependOptions') { continue }
        if (-not $Version.Contains($moduleName)) {
            throw "No resolved version was found for build dependency '$moduleName'."
        }
        $nestedHashtable = $pair.Item2.Find(
            { param($node) $node -is [System.Management.Automation.Language.HashtableAst] },
            $true
        )
        $versionAst = if ($nestedHashtable) {
            $versionPair = Get-PSDependencyCanaryHashtablePair -Hashtable $nestedHashtable -Key 'Version'
            if (-not $versionPair) { throw "The '$moduleName' entry in $Path has no Version property." }
            Get-PSDependencyCanaryPairStringAst -Pair $versionPair
        } else {
            Get-PSDependencyCanaryPairStringAst -Pair $pair
        }
        if (-not $versionAst) { throw "The version for '$moduleName' in $Path is not a string." }
        $newVersion = [string]$Version[$moduleName]
        $replacements += [pscustomobject]@{
            StartOffset = $versionAst.Extent.StartOffset
            EndOffset = $versionAst.Extent.EndOffset
            Text = "'$newVersion'"
        }
    }
    ConvertTo-PSDependencyCanaryReplacedContent -Content $Content -Replacement $replacements
}
