<#
.SYNOPSIS
Applies ordered syntax-tree replacements to text content.
#>
function ConvertTo-PSDependencyCanaryReplacedContent {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Content, [object[]]$Replacement)

    foreach ($item in @($Replacement | Sort-Object StartOffset -Descending)) {
        $Content = $Content.Substring(0, $item.StartOffset) +
            $item.Text +
            $Content.Substring($item.EndOffset)
    }
    $Content
}
