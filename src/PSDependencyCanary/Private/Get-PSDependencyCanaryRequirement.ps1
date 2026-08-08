<#
.SYNOPSIS
Gets versioned build dependencies from a PSDepend requirements data file.
#>
function Get-PSDependencyCanaryRequirement {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Content, [Parameter(Mandatory)][string]$Path)

    $hashtable = Get-PSDependencyCanaryHashtableAst -Content $Content -Path $Path
    @(
        foreach ($pair in $hashtable.KeyValuePairs) {
            $moduleName = [string]$pair.Item1.Value
            if ($moduleName -eq 'PSDependOptions') { continue }
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
            [pscustomobject]@{
                ModuleName = $moduleName
                CurrentVersion = [string]$versionAst.Value
            }
        }
    )
}
