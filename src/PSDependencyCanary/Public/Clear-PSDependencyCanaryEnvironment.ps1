function Clear-PSDependencyCanaryEnvironment {
    <#
    .SYNOPSIS
    Removes a project's installed PowerShell dependencies before bootstrapping.
    .DESCRIPTION
    Removes every installed version of PSDepend, PSDependencyCanary, modules
    declared in requirements.psd1, and modules declared by RequiredModules in the
    project manifest. Pester 3.x is preserved for Windows PowerShell compatibility.

    Run this command in its own process or CI step. The executing
    PSDependencyCanary module remains loaded in memory until the process exits even
    after its installed files have been removed. The next process can then install
    only the project's committed dependency pins.
    .PARAMETER ProjectRoot
    Root directory of the PowerShell module project. Defaults to BHProjectPath
    when available and otherwise to the current directory.
    .PARAMETER ModulePath
    Module roots to clean. Defaults to the current process PSModulePath entries.
    This parameter is primarily useful for isolated validation.
    .PARAMETER AllowPreinstalledModules
    Warn instead of failing when a protected or locked dependency cannot be removed.
    .EXAMPLE
    Clear-PSDependencyCanaryEnvironment -ProjectRoot . -Confirm:$false

    Cleans installed project dependencies before the committed bootstrap.
    .EXAMPLE
    Clear-PSDependencyCanaryEnvironment -ProjectRoot . -WhatIf

    Shows which installed dependency directories would be removed.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [string]$ProjectRoot,

        [string[]]$ModulePath,

        [switch]$AllowPreinstalledModules
    )

    if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
        $ProjectRoot = if ($env:BHProjectPath) { $env:BHProjectPath } else { (Get-Location).Path }
    }
    $ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
    $requirementsPaths = @((Join-Path -Path $ProjectRoot -ChildPath 'requirements.psd1'))
    $moduleNames = @('PSDepend', 'PSDependencyCanary')
    $preservedPesterMajorVersion = 3
    $sourceRoot = Join-Path -Path $ProjectRoot -ChildPath 'src'
    $projectModuleRoots = @(
        if (Test-Path -LiteralPath $sourceRoot -PathType Container) {
            Get-ChildItem -LiteralPath $sourceRoot -Directory
        }
        Get-ChildItem -LiteralPath $ProjectRoot -Directory |
            Where-Object Name -ne 'src'
    )
    $manifestCandidates = @(
        $projectModuleRoots |
            ForEach-Object {
                $candidate = Join-Path -Path $_.FullName -ChildPath "$($_.Name).psd1"
                if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                    $candidate
                }
            }
    )
    if ($manifestCandidates.Count -eq 1) {
        $manifestData = Import-PowerShellDataFile -LiteralPath $manifestCandidates[0]
        foreach ($requiredModule in @($manifestData.RequiredModules)) {
            if ($requiredModule -is [string]) {
                $moduleNames += $requiredModule
            } elseif ($requiredModule.ModuleName) {
                $moduleNames += [string]$requiredModule.ModuleName
            }
        }

        $templateRequirements = Join-Path -Path (Split-Path -Path $manifestCandidates[0] -Parent) `
            -ChildPath 'template/requirements.psd1'
        if (Test-Path -LiteralPath $templateRequirements -PathType Leaf) {
            $requirementsPaths += $templateRequirements
        }
    }

    foreach ($requirementsPath in $requirementsPaths) {
        if (-not (Test-Path -LiteralPath $requirementsPath -PathType Leaf)) {
            continue
        }
        $requirements = Import-PowerShellDataFile -LiteralPath $requirementsPath
        $moduleNames += @($requirements.Keys | Where-Object { $_ -ne 'PSDependOptions' })
    }
    $moduleNames = @($moduleNames | ForEach-Object { [string]$_ } | Sort-Object -Unique)
    foreach ($moduleName in $moduleNames) {
        if ([string]::IsNullOrWhiteSpace($moduleName) -or $moduleName -in @('.', '..') -or
            $moduleName -match '[/\\]') {
            throw "Refusing to clean invalid module name '$moduleName'."
        }
    }
    $cleanPester = $moduleNames -contains 'Pester'
    $moduleNamesWithoutPester = @($moduleNames | Where-Object { $_ -ne 'Pester' })

    if (-not $PSBoundParameters.ContainsKey('ModulePath')) {
        $ModulePath = @($env:PSModulePath -split [System.IO.Path]::PathSeparator)
    }
    $moduleRoots = @(
        $ModulePath |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            ForEach-Object {
                try {
                    [System.IO.Path]::GetFullPath(
                        $_.TrimEnd(
                            [System.IO.Path]::DirectorySeparatorChar,
                            [System.IO.Path]::AltDirectorySeparatorChar
                        )
                    )
                } catch {
                    Write-Verbose "Ignoring malformed PSModulePath entry: $_"
                }
            } |
            Sort-Object -Unique
    )
    $removedPaths = @()
    $preservedPaths = @()
    $failedPaths = @()

    foreach ($loadedModule in @(Get-Module)) {
        if (-not $loadedModule.ModuleBase) {
            continue
        }
        $loadedModuleBase = [System.IO.Path]::GetFullPath($loadedModule.ModuleBase)
        $isInCleanRoot = @(
            $moduleRoots |
                Where-Object {
                    $loadedModuleBase.Equals($_, [System.StringComparison]::OrdinalIgnoreCase) -or
                    $loadedModuleBase.StartsWith(
                        $_ + [System.IO.Path]::DirectorySeparatorChar,
                        [System.StringComparison]::OrdinalIgnoreCase
                    )
                }
        ).Count -gt 0
        $isTargetedModule = $moduleNamesWithoutPester -contains $loadedModule.Name
        $isTargetedPester = $cleanPester -and $loadedModule.Name -eq 'Pester' -and
            $loadedModule.Version.Major -ne $preservedPesterMajorVersion
        $isExecutingModule = $loadedModule.Name -eq $MyInvocation.MyCommand.ModuleName
        if ($isInCleanRoot -and ($isTargetedModule -or $isTargetedPester) -and -not $isExecutingModule) {
            $loadedModule | Remove-Module -Force -ErrorAction SilentlyContinue
        }
    }

    foreach ($moduleRoot in $moduleRoots) {
        foreach ($moduleName in $moduleNamesWithoutPester) {
            $moduleDirectory = Join-Path -Path $moduleRoot -ChildPath $moduleName
            if (-not (Test-Path -LiteralPath $moduleDirectory -PathType Container)) {
                continue
            }
            if ($PSCmdlet.ShouldProcess($moduleDirectory, 'Remove installed project dependency')) {
                try {
                    Remove-Item -LiteralPath $moduleDirectory -Recurse -Force
                    $removedPaths += $moduleDirectory
                } catch {
                    $failedPaths += $moduleDirectory
                    if (-not $AllowPreinstalledModules) {
                        throw
                    }
                    Write-Warning "Unable to remove module path: $moduleDirectory"
                }
            }
        }
    }

    if ($cleanPester) {
        foreach ($moduleRoot in $moduleRoots) {
            $pesterDirectory = Join-Path -Path $moduleRoot -ChildPath 'Pester'
            if (-not (Test-Path -LiteralPath $pesterDirectory -PathType Container)) {
                continue
            }

            $flatManifestPath = Join-Path -Path $pesterDirectory -ChildPath 'Pester.psd1'
            if (Test-Path -LiteralPath $flatManifestPath -PathType Leaf) {
                $flatPesterVersion = [version](
                    (Import-PowerShellDataFile -LiteralPath $flatManifestPath).ModuleVersion
                )
                if ($flatPesterVersion.Major -eq $preservedPesterMajorVersion) {
                    $preservedPaths += $pesterDirectory
                    continue
                }
                if ($PSCmdlet.ShouldProcess($pesterDirectory, 'Remove installed project dependency')) {
                    try {
                        Remove-Item -LiteralPath $pesterDirectory -Recurse -Force
                        $removedPaths += $pesterDirectory
                    } catch {
                        $failedPaths += $pesterDirectory
                        if (-not $AllowPreinstalledModules) {
                            throw
                        }
                        Write-Warning "Unable to remove module path: $pesterDirectory"
                    }
                }
                continue
            }

            foreach ($pesterEntry in @(Get-ChildItem -LiteralPath $pesterDirectory -Force)) {
                $parsedVersion = $null
                $isPreservedVersion = $pesterEntry.PSIsContainer -and
                    [version]::TryParse($pesterEntry.Name, [ref]$parsedVersion) -and
                    $parsedVersion.Major -eq $preservedPesterMajorVersion
                if ($isPreservedVersion) {
                    $preservedPaths += $pesterEntry.FullName
                    continue
                }
                if ($PSCmdlet.ShouldProcess($pesterEntry.FullName, 'Remove installed project dependency')) {
                    try {
                        Remove-Item -LiteralPath $pesterEntry.FullName -Recurse -Force
                        $removedPaths += $pesterEntry.FullName
                    } catch {
                        $failedPaths += $pesterEntry.FullName
                        if (-not $AllowPreinstalledModules) {
                            throw
                        }
                        Write-Warning "Unable to remove module path: $($pesterEntry.FullName)"
                    }
                }
            }
        }
    }

    if (-not $WhatIfPreference) {
        $remainingPaths = @(
            foreach ($moduleRoot in $moduleRoots) {
                foreach ($moduleName in $moduleNamesWithoutPester) {
                    $moduleDirectory = Join-Path -Path $moduleRoot -ChildPath $moduleName
                    if (Test-Path -LiteralPath $moduleDirectory -PathType Container) {
                        $moduleDirectory
                    }
                }
            }
            if ($cleanPester) {
                foreach ($moduleRoot in $moduleRoots) {
                    $pesterDirectory = Join-Path -Path $moduleRoot -ChildPath 'Pester'
                    if (-not (Test-Path -LiteralPath $pesterDirectory -PathType Container)) {
                        continue
                    }
                    $flatManifestPath = Join-Path -Path $pesterDirectory -ChildPath 'Pester.psd1'
                    if (Test-Path -LiteralPath $flatManifestPath -PathType Leaf) {
                        $flatPesterVersion = [version](
                            (Import-PowerShellDataFile -LiteralPath $flatManifestPath).ModuleVersion
                        )
                        if ($flatPesterVersion.Major -ne $preservedPesterMajorVersion) {
                            $pesterDirectory
                        }
                        continue
                    }
                    foreach ($pesterEntry in @(Get-ChildItem -LiteralPath $pesterDirectory -Force)) {
                        $parsedVersion = $null
                        $isPreservedVersion = $pesterEntry.PSIsContainer -and
                            [version]::TryParse($pesterEntry.Name, [ref]$parsedVersion) -and
                            $parsedVersion.Major -eq $preservedPesterMajorVersion
                        if (-not $isPreservedVersion) {
                            $pesterEntry.FullName
                        }
                    }
                }
            }
        )
        if ($remainingPaths.Count -gt 0) {
            $message = "Unable to remove project dependencies: $($remainingPaths -join ', ')"
            if (-not $AllowPreinstalledModules) {
                throw $message
            }
            Write-Warning $message
        }
    }

    [pscustomobject][ordered]@{
        ProjectRoot = $ProjectRoot
        ModuleNames = @($moduleNames)
        ModuleRoots = @($moduleRoots)
        RemovedPaths = @($removedPaths)
        PreservedPaths = @($preservedPaths | Sort-Object -Unique)
        FailedPaths = @($failedPaths | Sort-Object -Unique)
        PreservedPesterMajorVersion = $preservedPesterMajorVersion
    }
}
