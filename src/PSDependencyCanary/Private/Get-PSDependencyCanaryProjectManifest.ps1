<#
.SYNOPSIS
Finds the single module manifest in a conventional PowerShell project.
#>
function Get-PSDependencyCanaryProjectManifest {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Root)

    $sourceRoot = Join-Path -Path $Root -ChildPath 'src'
    $sourceCandidates = @(
        if (Test-Path -LiteralPath $sourceRoot -PathType Container) {
            Get-ChildItem -LiteralPath $sourceRoot -Directory |
                ForEach-Object {
                    $candidate = Join-Path -Path $_.FullName -ChildPath "$($_.Name).psd1"
                    if (Test-Path -LiteralPath $candidate -PathType Leaf) { $candidate }
                }
        }
    )
    if ($sourceCandidates.Count -eq 1) { return $sourceCandidates[0] }
    if ($sourceCandidates.Count -gt 1) {
        throw "Expected one module manifest beneath '$sourceRoot'; found $($sourceCandidates.Count)."
    }

    $rootCandidates = @(
        Get-ChildItem -LiteralPath $Root -Directory |
            Where-Object Name -ne 'src' |
            ForEach-Object {
                $candidate = Join-Path -Path $_.FullName -ChildPath "$($_.Name).psd1"
                if (Test-Path -LiteralPath $candidate -PathType Leaf) { $candidate }
            }
    )
    if ($rootCandidates.Count -ne 1) {
        throw "Expected one project module manifest beneath '$Root'; found $($rootCandidates.Count)."
    }
    $rootCandidates[0]
}
