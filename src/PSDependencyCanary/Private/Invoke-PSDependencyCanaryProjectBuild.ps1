<#
.SYNOPSIS
Runs a project build task in an isolated PowerShell child process.
#>
function Invoke-PSDependencyCanaryProjectBuild {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ProjectRoot,
        [Parameter(Mandatory)][string]$Task,
        [Parameter(Mandatory)][string]$PowerShellPath,
        [switch]$Bootstrap
    )

    $buildPath = Join-Path -Path $ProjectRoot -ChildPath 'build.ps1'
    if (-not (Test-Path -LiteralPath $buildPath -PathType Leaf)) {
        throw "The project build script was not found at '$buildPath'."
    }
    $hadWorkspace = Test-Path -LiteralPath Env:GITHUB_WORKSPACE
    $originalWorkspace = $env:GITHUB_WORKSPACE
    Push-Location -LiteralPath $ProjectRoot
    try {
        $env:GITHUB_WORKSPACE = $ProjectRoot
        $arguments = @('-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $buildPath, '-Task', $Task)
        if ($Bootstrap) { $arguments += '-Bootstrap' }
        & $PowerShellPath @arguments | Out-Host
        if ($LASTEXITCODE -ne 0) {
            throw "Build task '$Task' failed in '$ProjectRoot' with exit code $LASTEXITCODE."
        }
    } finally {
        if ($hadWorkspace) { $env:GITHUB_WORKSPACE = $originalWorkspace }
        else { Remove-Item -LiteralPath Env:GITHUB_WORKSPACE -ErrorAction SilentlyContinue }
        Pop-Location
    }
}
