function Test-PSDependencyCanary {
    <#
    .SYNOPSIS
    Runs a module project's complete test build for a dependency candidate.
    .DESCRIPTION
    Executes the project's Test task in a clean child PowerShell process with
    dependency bootstrap enabled, then verifies the expected module artifact. This
    supporting command is used by the cross-edition validation stage after the
    shared Canary task creates a candidate in a PSDepend, PowerShellBuild, and psake
    project.
    .PARAMETER ProjectRoot
    Root directory of the candidate project.
    .EXAMPLE
    Test-PSDependencyCanary -ProjectRoot .

    Validates an already-created candidate in the current PowerShell edition and
    verifies its staged module manifest.
    #>
    [CmdletBinding()]
    param([string]$ProjectRoot)

    if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
        $ProjectRoot = if ($env:BHProjectPath) { $env:BHProjectPath } else { (Get-Location).Path }
    }
    $ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
    $manifestPath = Get-PSDependencyCanaryProjectManifest -Root $ProjectRoot
    $manifest = Import-PowerShellDataFile -LiteralPath $manifestPath
    $moduleName = [IO.Path]::GetFileNameWithoutExtension($manifestPath)
    $powerShellPath = (Get-Process -Id $PID).Path

    Invoke-PSDependencyCanaryProjectBuild `
        -ProjectRoot $ProjectRoot `
        -Task Test `
        -PowerShellPath $powerShellPath `
        -Bootstrap
    $builtManifestPath = Join-Path -Path $ProjectRoot `
        -ChildPath "Output/$moduleName/$($manifest.ModuleVersion)/$moduleName.psd1"
    if (-not (Test-Path -LiteralPath $builtManifestPath -PathType Leaf)) {
        throw "The built module manifest was not found at '$builtManifestPath'."
    }
    [void](Test-ModuleManifest -Path $builtManifestPath -ErrorAction Stop -WarningAction SilentlyContinue)

    [pscustomobject][ordered]@{
        Success = $true
        ModuleName = $moduleName
        ModuleVersion = [string]$manifest.ModuleVersion
        PowerShellVersion = [string]$PSVersionTable.PSVersion
        BuiltManifestPath = $builtManifestPath
    }
}
