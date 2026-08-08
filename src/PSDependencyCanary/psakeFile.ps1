properties {
    $PSDependencyCanaryProjectRoot = if ($env:BHProjectPath) { $env:BHProjectPath } else { (Get-Location).Path }
    $PSDependencyCanaryModuleManifestPath = $null
    $PSDependencyCanaryRequirementsPath = $null
    $PSDependencyCanaryChangelogPath = $null
    $PSDependencyCanarySkipChangelog = $false
    $PSDependencyCanarySkipResult = $false
    $PSDependencyCanaryResultPath = if ($env:PSDEPENDENCYCANARY_RESULT_PATH) {
        $env:PSDEPENDENCYCANARY_RESULT_PATH
    } else {
        Join-Path -Path $PSDependencyCanaryProjectRoot -ChildPath 'out/dependency-canary.json'
    }
}

Task Canary {
    $parameters = @{
        ProjectRoot = $PSDependencyCanaryProjectRoot
        Confirm = $false
        SkipChangelog = [bool]$PSDependencyCanarySkipChangelog
    }
    if ($PSDependencyCanaryModuleManifestPath) {
        $parameters.ModuleManifestPath = $PSDependencyCanaryModuleManifestPath
    }
    if ($PSDependencyCanaryRequirementsPath) {
        $parameters.RequirementsPath = $PSDependencyCanaryRequirementsPath
    }
    if ($PSDependencyCanaryChangelogPath) {
        $parameters.ChangelogPath = $PSDependencyCanaryChangelogPath
    }

    $result = PSDependencyCanary\Update-PSDependencyCanary @parameters
    if (-not $PSDependencyCanarySkipResult -and $PSDependencyCanaryResultPath) {
        $resultDirectory = Split-Path -Path $PSDependencyCanaryResultPath -Parent
        if ($resultDirectory -and -not (Test-Path -LiteralPath $resultDirectory -PathType Container)) {
            [void](New-Item -ItemType Directory -Path $resultDirectory -Force)
        }
        $result | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $PSDependencyCanaryResultPath -Encoding UTF8
    }
    $result
}
