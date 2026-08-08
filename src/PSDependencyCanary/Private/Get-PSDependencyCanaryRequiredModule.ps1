<#
.SYNOPSIS
Gets RequiredModules entries from a module manifest syntax tree.
#>
function Get-PSDependencyCanaryRequiredModule {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Content, [Parameter(Mandatory)][string]$Path)

    $rootHashtable = Get-PSDependencyCanaryHashtableAst -Content $Content -Path $Path
    $requiredModulesPair = Get-PSDependencyCanaryHashtablePair -Hashtable $rootHashtable -Key 'RequiredModules'
    if (-not $requiredModulesPair) { return @() }
    $specifications = @()

    foreach ($hashtable in @($requiredModulesPair.Item2.FindAll(
        { param($node) $node -is [System.Management.Automation.Language.HashtableAst] },
        $true
    ))) {
        $namePair = Get-PSDependencyCanaryHashtablePair -Hashtable $hashtable -Key 'ModuleName'
        if (-not $namePair) { continue }
        $versionPair = Get-PSDependencyCanaryHashtablePair -Hashtable $hashtable -Key 'RequiredVersion'
        if (-not $versionPair) {
            $versionPair = Get-PSDependencyCanaryHashtablePair -Hashtable $hashtable -Key 'ModuleVersion'
        }
        $specifications += [pscustomobject]@{
            ModuleName = [string](Get-PSDependencyCanaryPairStringAst -Pair $namePair).Value
            CurrentVersion = if ($versionPair) {
                [string](Get-PSDependencyCanaryPairStringAst -Pair $versionPair).Value
            } else {
                $null
            }
            VersionPair = $versionPair
            EntryAst = $hashtable
            IsString = $false
        }
    }

    foreach ($stringAst in @($requiredModulesPair.Item2.FindAll(
        { param($node) $node -is [System.Management.Automation.Language.StringConstantExpressionAst] },
        $true
    ))) {
        $ancestor = $stringAst.Parent
        $insideHashtable = $false
        while ($ancestor -and $ancestor -ne $requiredModulesPair.Item2) {
            if ($ancestor -is [System.Management.Automation.Language.HashtableAst]) {
                $insideHashtable = $true
                break
            }
            $ancestor = $ancestor.Parent
        }
        if (-not $insideHashtable) {
            $specifications += [pscustomobject]@{
                ModuleName = [string]$stringAst.Value
                CurrentVersion = $null
                VersionPair = $null
                EntryAst = $stringAst
                IsString = $true
            }
        }
    }
    @($specifications)
}
