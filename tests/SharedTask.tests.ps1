BeforeAll {
    $outputManifest = Join-Path -Path $env:BHBuildOutput -ChildPath 'PSDependencyCanary.psd1'
    Get-Module PSDependencyCanary -All | Remove-Module -Force -ErrorAction SilentlyContinue
    Import-Module -Name $outputManifest -Force -Global -ErrorAction Stop
}

Describe 'PSDependencyCanary shared psake task' {
    It 'packages a Canary task and self-hosts it from the root psake file' {
        $packagedTask = Join-Path -Path $env:BHBuildOutput -ChildPath 'psakeFile.ps1'
        $rootPsake = Get-Content -Raw -LiteralPath (Join-Path $env:BHProjectPath 'psakeFile.ps1')
        $taskContent = Get-Content -Raw -LiteralPath $packagedTask

        Test-Path -LiteralPath $packagedTask -PathType Leaf | Should -BeTrue
        $taskContent | Should -Match '(?im)^Task\s+Canary\s*\{'
        $taskContent | Should -Match 'PSDependencyCanaryRequirementsPath'
        $taskContent | Should -Match 'PSDependencyCanaryChangelogPath'
        $taskContent | Should -Match 'PSDependencyCanarySkipChangelog'
        $taskContent | Should -Match 'PSDependencyCanarySkipResult'
        $rootPsake | Should -Match "(?im)^Task Canary -FromModule PSDependencyCanary -minimumVersion '1\.0\.0'$"
    }

    It 'runs through psake and writes structured candidate metadata' {
        $fixture = Join-Path $TestDrive 'task-fixture'
        [void](New-Item -ItemType Directory -Path (Join-Path $fixture 'src/TaskFixture') -Force)
        @'
@{
    RootModule = 'TaskFixture.psm1'
    ModuleVersion = '1.0.0'
    GUID = '22222222-2222-2222-2222-222222222222'
    Author = 'Test'
    Description = 'Task fixture'
    PowerShellVersion = '5.1'
    FunctionsToExport = @()
}
'@ | Set-Content -LiteralPath (Join-Path $fixture 'src/TaskFixture/TaskFixture.psd1') -Encoding UTF8
        '' | Set-Content -LiteralPath (Join-Path $fixture 'src/TaskFixture/TaskFixture.psm1') -Encoding UTF8
        [void](New-Item -ItemType Directory -Path (Join-Path $fixture 'config') -Force)
        @'
@{
    PSDependOptions = @{ Target = 'CurrentUser' }
}
'@ | Set-Content -LiteralPath (Join-Path $fixture 'config/dependencies.psd1') -Encoding UTF8
        "# Change Log`n`n## [1.0.0] 2026-01-01`n" | Set-Content -LiteralPath (Join-Path $fixture 'CHANGELOG.md') -Encoding UTF8
        $resultPath = Join-Path $fixture 'canary.json'
        $taskFile = Join-Path -Path $env:BHBuildOutput -ChildPath 'psakeFile.ps1'
        $properties = @{
            PSDependencyCanaryProjectRoot = $fixture
            PSDependencyCanaryRequirementsPath = 'config/dependencies.psd1'
            PSDependencyCanaryResultPath = $resultPath
            PSDependencyCanarySkipChangelog = $true
        }

        Invoke-psake -buildFile $taskFile -taskList Canary -nologo -properties $properties
        $psake.build_success | Should -BeTrue -Because $psake.error_message
        $metadata = Get-Content -Raw -LiteralPath $resultPath | ConvertFrom-Json
        $metadata.ModuleName | Should -Be 'TaskFixture'
        $metadata.Changed | Should -BeFalse
        $metadata.CandidateVersion | Should -Be '1.0.0'
        $metadata.RequirementsPath.Replace('\', '/') | Should -Be 'config/dependencies.psd1'
        $metadata.ChangelogSkipped | Should -BeTrue
        $metadata.ChangelogPath | Should -BeNullOrEmpty
    }

    It 'can disable the structured result file' {
        $fixture = Join-Path $TestDrive 'task-without-result'
        [void](New-Item -ItemType Directory -Path (Join-Path $fixture 'src/TaskFixture') -Force)
        @'
@{
    RootModule = 'TaskFixture.psm1'
    ModuleVersion = '1.0.0'
    GUID = '33333333-3333-3333-3333-333333333333'
    Author = 'Test'
    Description = 'Dependency canary fixture'
    PowerShellVersion = '5.1'
    FunctionsToExport = @()
}
'@ | Set-Content -LiteralPath (Join-Path $fixture 'src/TaskFixture/TaskFixture.psd1') -Encoding UTF8
        '' | Set-Content -LiteralPath (Join-Path $fixture 'src/TaskFixture/TaskFixture.psm1') -Encoding UTF8
        "@{ PSDependOptions = @{ Target = 'CurrentUser' } }" |
            Set-Content -LiteralPath (Join-Path $fixture 'requirements.psd1') -Encoding UTF8
        $resultPath = Join-Path $fixture 'canary.json'
        $taskFile = Join-Path -Path $env:BHBuildOutput -ChildPath 'psakeFile.ps1'
        $properties = @{
            PSDependencyCanaryProjectRoot = $fixture
            PSDependencyCanaryResultPath = $resultPath
            PSDependencyCanarySkipChangelog = $true
            PSDependencyCanarySkipResult = $true
        }

        Invoke-psake -buildFile $taskFile -taskList Canary -nologo -properties $properties

        $psake.build_success | Should -BeTrue -Because $psake.error_message
        Test-Path -LiteralPath $resultPath | Should -BeFalse
    }
}
