<#
.SYNOPSIS
Updates module-manifest RequiredModules entries to validated versions.
#>
function ConvertTo-PSDependencyCanaryRequiredModuleContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Content,
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Version
    )

    $replacements = @()
    foreach ($specification in @(Get-PSDependencyCanaryRequiredModule -Content $Content -Path $Path)) {
        if (-not $Version.Contains($specification.ModuleName)) {
            throw "No resolved version was found for required module '$($specification.ModuleName)'."
        }
        $candidateVersion = [string]$Version[$specification.ModuleName]
        if ($specification.IsString -or -not $specification.VersionPair) {
            $replacements += [pscustomobject]@{
                StartOffset = $specification.EntryAst.Extent.StartOffset
                EndOffset = $specification.EntryAst.Extent.EndOffset
                Text = "@{ ModuleName = '$($specification.ModuleName)'; RequiredVersion = '$candidateVersion' }"
            }
            continue
        }
        $versionAst = Get-PSDependencyCanaryPairStringAst -Pair $specification.VersionPair
        $replacements += [pscustomobject]@{
            StartOffset = $versionAst.Extent.StartOffset
            EndOffset = $versionAst.Extent.EndOffset
            Text = "'$candidateVersion'"
        }
    }
    ConvertTo-PSDependencyCanaryReplacedContent -Content $Content -Replacement $replacements
}
