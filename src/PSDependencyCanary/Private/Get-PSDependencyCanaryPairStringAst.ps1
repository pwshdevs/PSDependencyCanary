<#
.SYNOPSIS
Gets the first string syntax tree contained in a hashtable key-value pair.
#>
function Get-PSDependencyCanaryPairStringAst {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$Pair)

    $Pair.Item2.Find(
        { param($node) $node -is [System.Management.Automation.Language.StringConstantExpressionAst] },
        $true
    )
}
