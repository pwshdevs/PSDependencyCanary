<#
.SYNOPSIS
Parses a PowerShell data file and returns its root hashtable syntax tree.
#>
function Get-PSDependencyCanaryHashtableAst {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Content, [Parameter(Mandatory)][string]$Path)

    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput(
        $Content,
        $Path,
        [ref]$tokens,
        [ref]$parseErrors
    )
    if ($parseErrors.Count -gt 0) { throw "Unable to parse $Path`: $($parseErrors[0].Message)" }
    $hashtable = $ast.Find(
        { param($node) $node -is [System.Management.Automation.Language.HashtableAst] },
        $false
    )
    if (-not $hashtable) { throw "No root hashtable was found in $Path." }
    $hashtable
}
