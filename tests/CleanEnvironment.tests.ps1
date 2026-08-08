BeforeAll {
    $outputManifest = Join-Path -Path $env:BHBuildOutput -ChildPath 'PSDependencyCanary.psd1'
    Get-Module PSDependencyCanary -All | Remove-Module -Force -ErrorAction SilentlyContinue
    Import-Module -Name $outputManifest -Force -Global -ErrorAction Stop
}

Describe 'Clear-PSDependencyCanaryEnvironment' {
    BeforeEach {
        $moduleRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        [void](New-Item -ItemType Directory -Path $moduleRoot -Force)
        $projectRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        [void](New-Item -ItemType Directory -Path (Join-Path $projectRoot 'src/FixtureModule') -Force)
        @'
@{
    RootModule = 'FixtureModule.psm1'
    ModuleVersion = '1.0.0'
    GUID = '44444444-4444-4444-4444-444444444444'
    Author = 'Test'
    Description = 'Clean environment fixture'
    PowerShellVersion = '5.1'
    FunctionsToExport = @()
    RequiredModules = @('RuntimeDependency')
}
'@ | Set-Content -LiteralPath (Join-Path $projectRoot 'src/FixtureModule/FixtureModule.psd1') -Encoding UTF8
        '' | Set-Content -LiteralPath (Join-Path $projectRoot 'src/FixtureModule/FixtureModule.psm1') -Encoding UTF8
        @'
@{
    PSDepend = @{ Version = '0.4.1' }
    PSDependOptions = @{ Target = 'CurrentUser' }
    Pester = @{ Version = '5.7.1' }
    BuildHelpers = @{ Version = '2.0.16' }
    PSDependencyCanary = @{ Version = '1.1.0' }
}
'@ | Set-Content -LiteralPath (Join-Path $projectRoot 'requirements.psd1') -Encoding UTF8
    }

    It 'removes declared project dependencies while preserving unrelated modules and Pester 3' {
        $removedModulePaths = @(
            (Join-Path $moduleRoot 'BuildHelpers/2.0.16')
            (Join-Path $moduleRoot 'PSDepend/0.4.1')
            (Join-Path $moduleRoot 'PSDependencyCanary/1.1.0')
            (Join-Path $moduleRoot 'RuntimeDependency/1.0.0')
            (Join-Path $moduleRoot 'Pester/5.7.1')
            (Join-Path $moduleRoot 'Pester/6.0.1')
        )
        $preservedModulePaths = @(
            (Join-Path $moduleRoot 'PackageManagement/1.4.8.1')
            (Join-Path $moduleRoot 'PowerShellGet/2.2.5')
            (Join-Path $moduleRoot 'UnrelatedRunnerModule/9.9.9')
            (Join-Path $moduleRoot 'Pester/3.4.0')
        )
        foreach ($path in @($removedModulePaths + $preservedModulePaths)) {
            [void](New-Item -ItemType Directory -Path $path -Force)
            'fixture' | Set-Content -LiteralPath (Join-Path $path 'fixture.txt') -Encoding UTF8
        }

        $result = Clear-PSDependencyCanaryEnvironment `
            -ProjectRoot $projectRoot `
            -ModulePath $moduleRoot `
            -Confirm:$false

        foreach ($path in $removedModulePaths) {
            Test-Path -LiteralPath $path | Should -BeFalse
        }
        foreach ($path in $preservedModulePaths) {
            Test-Path -LiteralPath $path | Should -BeTrue
        }
        $result.RemovedPaths | Should -Contain (Join-Path $moduleRoot 'BuildHelpers')
        $result.RemovedPaths | Should -Contain (Join-Path $moduleRoot 'PSDepend')
        $result.RemovedPaths | Should -Contain (Join-Path $moduleRoot 'PSDependencyCanary')
        $result.RemovedPaths | Should -Contain (Join-Path $moduleRoot 'RuntimeDependency')
        $result.ModuleNames | Should -Contain 'RuntimeDependency'
        $result.PreservedPesterMajorVersion | Should -Be 3
        $result.FailedPaths | Should -BeNullOrEmpty
    }

    It 'supports WhatIf without removing module directories' {
        $modulePath = Join-Path $moduleRoot 'RunnerModule/1.0.0'
        [void](New-Item -ItemType Directory -Path $modulePath -Force)

        $result = Clear-PSDependencyCanaryEnvironment `
            -ProjectRoot $projectRoot `
            -ModulePath $moduleRoot `
            -WhatIf

        Test-Path -LiteralPath $modulePath | Should -BeTrue
        $result.RemovedPaths | Should -BeNullOrEmpty
        $result.FailedPaths | Should -BeNullOrEmpty
    }

    It 'rejects dependency names that could escape a module root' {
        @'
@{
    '../OutsideModuleRoot' = @{ Version = '1.0.0' }
    PSDependOptions = @{ Target = 'CurrentUser' }
}
'@ | Set-Content -LiteralPath (Join-Path $projectRoot 'requirements.psd1') -Encoding UTF8
        $outsidePath = Join-Path (Split-Path $moduleRoot -Parent) 'OutsideModuleRoot'
        [void](New-Item -ItemType Directory -Path $outsidePath -Force)

        {
            Clear-PSDependencyCanaryEnvironment `
                -ProjectRoot $projectRoot `
                -ModulePath $moduleRoot `
                -Confirm:$false
        } | Should -Throw "*Refusing to clean invalid module name '../OutsideModuleRoot'*"
        Test-Path -LiteralPath $outsidePath | Should -BeTrue
    }

    It 'can remove the installed files of the module executing the command' {
        $installedModuleRoot = Join-Path $moduleRoot 'PSDependencyCanary/1.1.0'
        [void](New-Item -ItemType Directory -Path $installedModuleRoot -Force)
        Copy-Item -Path (Join-Path $env:BHBuildOutput '*') -Destination $installedModuleRoot -Recurse -Force
        $installedManifest = Join-Path $installedModuleRoot 'PSDependencyCanary.psd1'
        $childScript = Join-Path $TestDrive 'clear-self.ps1'
        @"
`$ErrorActionPreference = 'Stop'
`$env:PSModulePath = '$moduleRoot'
Import-Module -Name '$installedManifest' -Force -ErrorAction Stop
PSDependencyCanary\Clear-PSDependencyCanaryEnvironment -ProjectRoot '$projectRoot' -ModulePath '$moduleRoot' -Confirm:`$false | Out-Null
if (Test-Path -LiteralPath '$installedModuleRoot') {
    throw 'The temporary PSDependencyCanary installation was not removed.'
}
"@ | Set-Content -LiteralPath $childScript -Encoding UTF8
        $powerShellPath = (Get-Process -Id $PID).Path

        & $powerShellPath -NoLogo -NoProfile -ExecutionPolicy Bypass -File $childScript

        $LASTEXITCODE | Should -Be 0
        Test-Path -LiteralPath $installedModuleRoot | Should -BeFalse
    }
}
