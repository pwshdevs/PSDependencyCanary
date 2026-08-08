BeforeAll {
    $outputManifest = Join-Path -Path $env:BHBuildOutput -ChildPath 'PSDependencyCanary.psd1'
    Get-Module PSDependencyCanary -All | Remove-Module -Force -ErrorAction SilentlyContinue
    Import-Module -Name $outputManifest -Force -Global -ErrorAction Stop

    function New-DependencyCanaryFixture {
        param(
            [string]$Root,
            [switch]$LegacyRequiredModule,
            [switch]$OmitRuntimeRequirement,
            [switch]$OmitChangelog
        )

        [void](New-Item -ItemType Directory -Path (Join-Path $Root 'src/FixtureModule') -Force)
        $requiredVersionKey = if ($LegacyRequiredModule) { 'ModuleVersion' } else { 'RequiredVersion' }
        @"
@{
    RootModule = 'FixtureModule.psm1'
    ModuleVersion = '1.0.0'
    GUID = '11111111-1111-1111-1111-111111111111'
    Author = 'Test'
    Description = 'Dependency canary fixture'
    PowerShellVersion = '5.1'
    FunctionsToExport = @()
    RequiredModules = @(
        @{ ModuleName = 'RuntimeDependency'; $requiredVersionKey = '1.0.0' }
    )
}
"@ | Set-Content -LiteralPath (Join-Path $Root 'src/FixtureModule/FixtureModule.psd1') -Encoding UTF8
        '' | Set-Content -LiteralPath (Join-Path $Root 'src/FixtureModule/FixtureModule.psm1') -Encoding UTF8
        $runtimeRequirement = if ($OmitRuntimeRequirement) { '' } else {
            "    RuntimeDependency = @{ Version = '1.0.0' }`r`n"
        }
        @"
@{
    PSDepend = @{ Version = '0.4.1' }
    Pester = '5.0.0'
$runtimeRequirement    PSDependOptions = @{ Target = 'CurrentUser' }
}
"@ | Set-Content -LiteralPath (Join-Path $Root 'requirements.psd1') -Encoding UTF8
        @'
# Change Log

## [1.0.0] 2026-01-01

### Added

- Initial fixture.
'@ | ForEach-Object {
            if (-not $OmitChangelog) {
                $_ | Set-Content -LiteralPath (Join-Path $Root 'CHANGELOG.md') -Encoding UTF8
            }
        }
    }

    function Get-DependencyCanaryFixtureContent {
        param([string]$Root)
        [ordered]@{
            Requirements = Get-Content -Raw -LiteralPath (Join-Path $Root 'requirements.psd1')
            Manifest = Get-Content -Raw -LiteralPath (Join-Path $Root 'src/FixtureModule/FixtureModule.psd1')
            Changelog = Get-Content -Raw -LiteralPath (Join-Path $Root 'CHANGELOG.md')
        }
    }
}

Describe 'Update-PSDependencyCanary' {
    BeforeEach {
        $global:PSDependencyCanaryAvailableVersions = [ordered]@{
            PSDepend = '0.4.2'
            Pester = '6.0.1'
            RuntimeDependency = '2.0.0'
        }
        Mock -ModuleName PSDependencyCanary Find-PSDependencyCanaryModuleVersion {
            [version]$global:PSDependencyCanaryAvailableVersions[$Name]
        }
        $global:PSDependencyCanaryBuildInvocations = 0
        Mock -ModuleName PSDependencyCanary Invoke-PSDependencyCanaryProjectBuild {
            $global:PSDependencyCanaryBuildInvocations++
        }
    }

    AfterAll {
        Remove-Variable -Name PSDependencyCanaryAvailableVersions -Scope Global -ErrorAction SilentlyContinue
        Remove-Variable -Name PSDependencyCanaryBuildInvocations -Scope Global -ErrorAction SilentlyContinue
    }

    It 'tests the combined candidate before retaining requirements and RequiredModules updates' {
        $fixture = Join-Path $TestDrive 'changed'
        New-DependencyCanaryFixture -Root $fixture -LegacyRequiredModule
        Mock -ModuleName PSDependencyCanary Invoke-PSDependencyCanaryProjectBuild {
            $global:PSDependencyCanaryBuildInvocations++
            $requirements = Import-PowerShellDataFile -LiteralPath (Join-Path $ProjectRoot 'requirements.psd1')
            $manifest = Import-PowerShellDataFile -LiteralPath (Join-Path $ProjectRoot 'src/FixtureModule/FixtureModule.psd1')
            if ($global:PSDependencyCanaryBuildInvocations -eq 1) {
                if ([string]$requirements.RuntimeDependency.Version -ne '1.0.0') { throw 'The baseline requirements were modified before testing.' }
                if ([string]$manifest.RequiredModules[0].ModuleVersion -ne '1.0.0') { throw 'The baseline RequiredModules were modified before testing.' }
                if ([string]$manifest.ModuleVersion -ne '1.0.0') { throw 'The baseline module version was modified before testing.' }
                return
            }
            if ([string]$requirements.RuntimeDependency.Version -ne '2.0.0') { throw 'Runtime requirement was not staged before testing.' }
            if ([string]$manifest.RequiredModules[0].ModuleVersion -ne '2.0.0') { throw 'RequiredModules was not staged before testing.' }
            if ([string]$manifest.ModuleVersion -ne '1.0.1') { throw 'Patch version was not staged before testing.' }
        }

        $result = Update-PSDependencyCanary -ProjectRoot $fixture -Confirm:$false
        $requirements = Import-PowerShellDataFile -LiteralPath (Join-Path $fixture 'requirements.psd1')
        $manifest = Import-PowerShellDataFile -LiteralPath (Join-Path $fixture 'src/FixtureModule/FixtureModule.psd1')
        $changelog = Get-Content -Raw -LiteralPath (Join-Path $fixture 'CHANGELOG.md')

        $result.Changed | Should -BeTrue
        $result.RequirementsChanged | Should -BeTrue
        $result.RequiredModulesChanged | Should -BeTrue
        $result.BaselineTested | Should -BeTrue
        $result.Tested | Should -BeTrue
        $result.Applied | Should -BeTrue
        $result.CandidateVersion | Should -Be '1.0.1'
        [string]$requirements.PSDepend.Version | Should -Be '0.4.2'
        [string]$requirements.Pester | Should -Be '6.0.1'
        [string]$requirements.RuntimeDependency.Version | Should -Be '2.0.0'
        [string]$manifest.ModuleVersion | Should -Be '1.0.1'
        [string]$manifest.RequiredModules[0].ModuleVersion | Should -Be '2.0.0'
        $changelog | Should -Match '## \[1\.0\.1\]'
        $changelog | Should -Match 'Validated and pinned `RuntimeDependency` at `2\.0\.0`'
        Should -Invoke -ModuleName PSDependencyCanary Invoke-PSDependencyCanaryProjectBuild -Times 2 -Exactly -ParameterFilter {
            $Task -eq 'Test'
        }
    }

    It 'tests and retains a build-only update without changing the shipped module version' {
        $fixture = Join-Path $TestDrive 'build-only'
        New-DependencyCanaryFixture -Root $fixture
        $before = Get-DependencyCanaryFixtureContent -Root $fixture
        $global:PSDependencyCanaryAvailableVersions.RuntimeDependency = '1.0.0'

        $result = Update-PSDependencyCanary -ProjectRoot $fixture -Confirm:$false
        $after = Get-DependencyCanaryFixtureContent -Root $fixture
        $manifest = Import-PowerShellDataFile -LiteralPath (Join-Path $fixture 'src/FixtureModule/FixtureModule.psd1')

        $result.RequirementsChanged | Should -BeTrue
        $result.RequiredModulesChanged | Should -BeFalse
        $result.CandidateVersion | Should -Be '1.0.0'
        $result.BaselineTested | Should -BeTrue
        $result.Tested | Should -BeTrue
        $after.Manifest | Should -BeExactly $before.Manifest
        $after.Changelog | Should -BeExactly $before.Changelog
        [string]$manifest.ModuleVersion | Should -Be '1.0.0'
    }

    It 'does not require a changelog for a build-only update' {
        $fixture = Join-Path $TestDrive 'build-only-without-changelog'
        New-DependencyCanaryFixture -Root $fixture -OmitChangelog
        $global:PSDependencyCanaryAvailableVersions.RuntimeDependency = '1.0.0'

        $result = Update-PSDependencyCanary -ProjectRoot $fixture -Confirm:$false

        $result.RequirementsChanged | Should -BeTrue
        $result.RequiredModulesChanged | Should -BeFalse
        $result.ChangelogSkipped | Should -BeFalse
        Test-Path -LiteralPath (Join-Path $fixture 'CHANGELOG.md') | Should -BeFalse
    }

    It 'requires a changelog path when a runtime dependency changes' {
        $fixture = Join-Path $TestDrive 'missing-changelog'
        New-DependencyCanaryFixture -Root $fixture -OmitChangelog

        { Update-PSDependencyCanary -ProjectRoot $fixture -Confirm:$false } |
            Should -Throw '*The changelog was not found*Specify -ChangelogPath or use -SkipChangelog*'
        (Import-PowerShellDataFile -LiteralPath (Join-Path $fixture 'src/FixtureModule/FixtureModule.psd1')).ModuleVersion |
            Should -Be '1.0.0'
        Should -Invoke -ModuleName PSDependencyCanary Invoke-PSDependencyCanaryProjectBuild -Times 0 -Exactly
    }

    It 'previews runtime updates without requiring a changelog' {
        $fixture = Join-Path $TestDrive 'preview-without-changelog'
        New-DependencyCanaryFixture -Root $fixture -OmitChangelog

        $result = Update-PSDependencyCanary -ProjectRoot $fixture -WhatIf

        $result.Changed | Should -BeTrue
        $result.RequiredModulesChanged | Should -BeTrue
        $result.Applied | Should -BeFalse
        Test-Path -LiteralPath (Join-Path $fixture 'CHANGELOG.md') | Should -BeFalse
        Should -Invoke -ModuleName PSDependencyCanary Invoke-PSDependencyCanaryProjectBuild -Times 0 -Exactly
    }

    It 'patch-bumps runtime updates without a changelog when explicitly skipped' {
        $fixture = Join-Path $TestDrive 'skip-changelog'
        New-DependencyCanaryFixture -Root $fixture -OmitChangelog

        $result = Update-PSDependencyCanary -ProjectRoot $fixture -SkipChangelog -Confirm:$false
        $manifest = Import-PowerShellDataFile -LiteralPath (Join-Path $fixture 'src/FixtureModule/FixtureModule.psd1')

        $result.RequiredModulesChanged | Should -BeTrue
        $result.ChangelogSkipped | Should -BeTrue
        $result.ChangelogPath | Should -BeNullOrEmpty
        [string]$manifest.ModuleVersion | Should -Be '1.0.1'
        [string]$manifest.RequiredModules[0].RequiredVersion | Should -Be '2.0.0'
        Test-Path -LiteralPath (Join-Path $fixture 'CHANGELOG.md') | Should -BeFalse
    }

    It 'updates an explicitly configured changelog path' {
        $fixture = Join-Path $TestDrive 'custom-changelog'
        New-DependencyCanaryFixture -Root $fixture
        $customDirectory = Join-Path $fixture 'docs'
        [void](New-Item -ItemType Directory -Path $customDirectory -Force)
        Move-Item -LiteralPath (Join-Path $fixture 'CHANGELOG.md') -Destination (Join-Path $customDirectory 'CHANGE_LOG.md')

        $result = Update-PSDependencyCanary `
            -ProjectRoot $fixture `
            -ChangelogPath 'docs/CHANGE_LOG.md' `
            -Confirm:$false
        $changelog = Get-Content -Raw -LiteralPath (Join-Path $customDirectory 'CHANGE_LOG.md')

        $result.ChangelogSkipped | Should -BeFalse
        $result.ChangelogPath.Replace('\', '/') | Should -Be 'docs/CHANGE_LOG.md'
        $changelog | Should -Match '## \[1\.0\.1\]'
        Test-Path -LiteralPath (Join-Path $fixture 'CHANGELOG.md') | Should -BeFalse
    }

    It 'rejects a changelog path when changelog updates are skipped' {
        $fixture = Join-Path $TestDrive 'conflicting-changelog-options'
        New-DependencyCanaryFixture -Root $fixture

        { Update-PSDependencyCanary -ProjectRoot $fixture -ChangelogPath 'CHANGELOG.md' -SkipChangelog } |
            Should -Throw '*ChangelogPath and SkipChangelog cannot be used together*'
        Should -Invoke -ModuleName PSDependencyCanary Find-PSDependencyCanaryModuleVersion -Times 0 -Exactly
    }

    It 'does nothing when requirements and RequiredModules are current' {
        $fixture = Join-Path $TestDrive 'unchanged'
        New-DependencyCanaryFixture -Root $fixture
        $global:PSDependencyCanaryAvailableVersions = [ordered]@{
            PSDepend = '0.4.1'
            Pester = '5.0.0'
            RuntimeDependency = '1.0.0'
        }

        $result = Update-PSDependencyCanary -ProjectRoot $fixture -Confirm:$false

        $result.Changed | Should -BeFalse
        $result.BaselineTested | Should -BeFalse
        $result.Tested | Should -BeFalse
        $result.Applied | Should -BeFalse
        $result.CandidateVersion | Should -Be '1.0.0'
        Should -Invoke -ModuleName PSDependencyCanary Invoke-PSDependencyCanaryProjectBuild -Times 0 -Exactly
    }

    It 'restores every source file when the candidate test suite fails' {
        $fixture = Join-Path $TestDrive 'failed-test'
        New-DependencyCanaryFixture -Root $fixture
        $before = Get-DependencyCanaryFixtureContent -Root $fixture
        Mock -ModuleName PSDependencyCanary Invoke-PSDependencyCanaryProjectBuild {
            $global:PSDependencyCanaryBuildInvocations++
            if ($global:PSDependencyCanaryBuildInvocations -eq 2) { throw 'candidate tests failed' }
        }

        { Update-PSDependencyCanary -ProjectRoot $fixture -Confirm:$false } | Should -Throw '*candidate tests failed*'
        $after = Get-DependencyCanaryFixtureContent -Root $fixture
        $after.Requirements | Should -BeExactly $before.Requirements
        $after.Manifest | Should -BeExactly $before.Manifest
        $after.Changelog | Should -BeExactly $before.Changelog
        Should -Invoke -ModuleName PSDependencyCanary Invoke-PSDependencyCanaryProjectBuild -Times 2 -Exactly
    }

    It 'stops before editing or candidate bootstrap when the unchanged project already fails' {
        $fixture = Join-Path $TestDrive 'failed-baseline'
        New-DependencyCanaryFixture -Root $fixture
        $before = Get-DependencyCanaryFixtureContent -Root $fixture
        Mock -ModuleName PSDependencyCanary Invoke-PSDependencyCanaryProjectBuild { throw 'baseline tests failed' }

        { Update-PSDependencyCanary -ProjectRoot $fixture -Confirm:$false } | Should -Throw '*baseline tests failed*'
        $after = Get-DependencyCanaryFixtureContent -Root $fixture
        $after.Requirements | Should -BeExactly $before.Requirements
        $after.Manifest | Should -BeExactly $before.Manifest
        $after.Changelog | Should -BeExactly $before.Changelog
        Should -Invoke -ModuleName PSDependencyCanary Invoke-PSDependencyCanaryProjectBuild -Times 1 -Exactly -ParameterFilter {
            $Task -eq 'Test'
        }
    }

    It 'does not bootstrap, test, or edit under WhatIf' {
        $fixture = Join-Path $TestDrive 'whatif'
        New-DependencyCanaryFixture -Root $fixture
        $before = Get-DependencyCanaryFixtureContent -Root $fixture

        $result = Update-PSDependencyCanary -ProjectRoot $fixture -WhatIf
        $after = Get-DependencyCanaryFixtureContent -Root $fixture

        $result.Changed | Should -BeTrue
        $result.BaselineTested | Should -BeFalse
        $result.Tested | Should -BeFalse
        $result.Applied | Should -BeFalse
        $after.Requirements | Should -BeExactly $before.Requirements
        $after.Manifest | Should -BeExactly $before.Manifest
        $after.Changelog | Should -BeExactly $before.Changelog
        Should -Invoke -ModuleName PSDependencyCanary Invoke-PSDependencyCanaryProjectBuild -Times 0 -Exactly
    }

    It 'rejects a RequiredModules entry missing from requirements.psd1' {
        $fixture = Join-Path $TestDrive 'missing-runtime-requirement'
        New-DependencyCanaryFixture -Root $fixture -OmitRuntimeRequirement

        { Update-PSDependencyCanary -ProjectRoot $fixture -Confirm:$false } |
            Should -Throw '*RequiredModules must also be declared in requirements.psd1: RuntimeDependency*'
        Should -Invoke -ModuleName PSDependencyCanary Find-PSDependencyCanaryModuleVersion -Times 0 -Exactly
    }
}
