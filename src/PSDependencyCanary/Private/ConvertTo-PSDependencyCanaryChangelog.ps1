<#
.SYNOPSIS
Adds a dependency validation release entry to a Keep a Changelog document.
#>
function ConvertTo-PSDependencyCanaryChangelog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Content,
        [Parameter(Mandatory)][version]$Version,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Dependency
    )

    $newline = if ($Content.Contains("`r`n")) { "`r`n" } else { "`n" }
    $dependencyEntries = @(
        $Dependency.Keys |
            Sort-Object |
            ForEach-Object { "- Validated and pinned ``$_`` at ``$($Dependency[$_])``." }
    )
    $section = @(
        "## [$Version] $(Get-Date -Format 'yyyy-MM-dd')"
        ''
        '### Changed'
        ''
        $dependencyEntries
        ''
        ''
    ) -join $newline
    $firstReleaseHeading = [regex]::Match($Content, '(?m)^##\s+\[')
    if ($firstReleaseHeading.Success) { return $Content.Insert($firstReleaseHeading.Index, $section) }
    $Content.TrimEnd() + $newline + $newline + $section
}
