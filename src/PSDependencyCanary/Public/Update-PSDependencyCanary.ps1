function Update-PSDependencyCanary {
    <#
    .SYNOPSIS
    Updates a module project's dependencies only after baseline and candidate tests pass.
    .DESCRIPTION
    Finds newer PSGallery versions for dependencies declared in requirements.psd1
    and RequiredModules. When updates are available, the unchanged project must pass
    its Test build task before any files are edited. The complete candidate is then
    applied temporarily and tested again with dependency bootstrap enabled.
    Failed candidates are restored. Build-only updates do not change the module
    version; a RequiredModules update patch-bumps the shipped module manifest and
    updates the changelog. This supporting command is invoked by the shared Canary
    task in PSDepend, PowerShellBuild, and psake projects.
    .PARAMETER ProjectRoot
    Root directory of the PowerShell module project. Defaults to BHProjectPath
    when available and otherwise to the current directory.
    .PARAMETER ModuleManifestPath
    Optional module manifest path. Conventional src layouts are auto-discovered.
    .PARAMETER RequirementsPath
    PSDepend build requirements file. Defaults to requirements.psd1.
    .PARAMETER ChangelogPath
    Keep a Changelog document updated when RequiredModules changes. Defaults to
    CHANGELOG.md in the project root. The file is required only when a runtime
    dependency changes and changelog updates are enabled.
    .PARAMETER SkipChangelog
    Patch-bump runtime dependency candidates without reading or updating a changelog.
    .EXAMPLE
    Update-PSDependencyCanary -ProjectRoot . -WhatIf

    Previews available changes in a compatible project without bootstrapping,
    testing, or editing. Use the shared Canary task to apply a candidate.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [string]$ProjectRoot,
        [string]$ModuleManifestPath,
        [string]$RequirementsPath,
        [string]$ChangelogPath,
        [switch]$SkipChangelog
    )

    if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
        $ProjectRoot = if ($env:BHProjectPath) { $env:BHProjectPath } else { (Get-Location).Path }
    }
    $ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path

    if ([string]::IsNullOrWhiteSpace($ModuleManifestPath)) {
        $ModuleManifestPath = Get-PSDependencyCanaryProjectManifest -Root $ProjectRoot
    } elseif (-not [IO.Path]::IsPathRooted($ModuleManifestPath)) {
        $ModuleManifestPath = Join-Path -Path $ProjectRoot -ChildPath $ModuleManifestPath
    }
    $ModuleManifestPath = (Resolve-Path -LiteralPath $ModuleManifestPath).Path

    if ([string]::IsNullOrWhiteSpace($RequirementsPath)) {
        $RequirementsPath = Join-Path -Path $ProjectRoot -ChildPath 'requirements.psd1'
    } elseif (-not [IO.Path]::IsPathRooted($RequirementsPath)) {
        $RequirementsPath = Join-Path -Path $ProjectRoot -ChildPath $RequirementsPath
    }
    $RequirementsPath = (Resolve-Path -LiteralPath $RequirementsPath).Path

    if ($SkipChangelog -and $PSBoundParameters.ContainsKey('ChangelogPath')) {
        throw 'ChangelogPath and SkipChangelog cannot be used together.'
    }
    if (-not $SkipChangelog) {
        if ([string]::IsNullOrWhiteSpace($ChangelogPath)) {
            $ChangelogPath = Join-Path -Path $ProjectRoot -ChildPath 'CHANGELOG.md'
        } elseif (-not [IO.Path]::IsPathRooted($ChangelogPath)) {
            $ChangelogPath = Join-Path -Path $ProjectRoot -ChildPath $ChangelogPath
        }
        $ChangelogPath = [IO.Path]::GetFullPath($ChangelogPath)
    } else {
        $ChangelogPath = $null
    }

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    $originalRequirements = [IO.File]::ReadAllText($RequirementsPath)
    $originalManifest = [IO.File]::ReadAllText($ModuleManifestPath)
    $changelogExists = $ChangelogPath -and (Test-Path -LiteralPath $ChangelogPath -PathType Leaf)
    $originalChangelog = if ($changelogExists) { [IO.File]::ReadAllText($ChangelogPath) } else { $null }
    $manifestData = Import-PowerShellDataFile -LiteralPath $ModuleManifestPath
    $moduleName = [IO.Path]::GetFileNameWithoutExtension($ModuleManifestPath)
    $currentVersion = [version]$manifestData.ModuleVersion

    $buildSpecifications = @(
        Get-PSDependencyCanaryRequirement -Content $originalRequirements -Path $RequirementsPath |
            ForEach-Object {
                [pscustomobject]@{
                    Type = 'Requirement'
                    ModuleName = $_.ModuleName
                    CurrentVersion = $_.CurrentVersion
                }
            }
    )
    $runtimeSpecifications = @(
        Get-PSDependencyCanaryRequiredModule -Content $originalManifest -Path $ModuleManifestPath |
            ForEach-Object {
                [pscustomobject]@{
                    Type = 'RequiredModule'
                    ModuleName = $_.ModuleName
                    CurrentVersion = $_.CurrentVersion
                }
            }
    )
    $allSpecifications = @($buildSpecifications + $runtimeSpecifications)
    $requirementNames = @($buildSpecifications.ModuleName | Sort-Object -Unique)
    $missingRuntimeRequirements = @(
        $runtimeSpecifications.ModuleName |
            Sort-Object -Unique |
            Where-Object { $requirementNames -notcontains $_ }
    )
    if ($missingRuntimeRequirements.Count -gt 0) {
        throw "RequiredModules must also be declared in requirements.psd1: $($missingRuntimeRequirements -join ', ')."
    }
    $candidateVersions = @{}
    $updates = @()

    foreach ($dependencyName in @($allSpecifications.ModuleName | Sort-Object -Unique)) {
        $latestVersion = [version](Find-PSDependencyCanaryModuleVersion -Name $dependencyName)
        $declaredVersions = @(
            $allSpecifications |
                Where-Object ModuleName -EQ $dependencyName |
                ForEach-Object {
                    $parsedVersion = $null
                    if ([version]::TryParse([string]$_.CurrentVersion, [ref]$parsedVersion)) {
                        $parsedVersion
                    }
                }
        )
        $candidateVersion = @($declaredVersions + $latestVersion | Sort-Object -Descending | Select-Object -First 1)[0]
        $candidateVersions[$dependencyName] = [string]$candidateVersion

        foreach ($specification in @($allSpecifications | Where-Object ModuleName -EQ $dependencyName)) {
            $current = $null
            $hasVersion = [version]::TryParse([string]$specification.CurrentVersion, [ref]$current)
            if (-not $hasVersion -or $candidateVersion -gt $current) {
                $updates += [pscustomobject][ordered]@{
                    Type = $specification.Type
                    Name = $dependencyName
                    CurrentVersion = if ($hasVersion) { [string]$current } else { [string]$specification.CurrentVersion }
                    CandidateVersion = [string]$candidateVersion
                }
            }
        }
    }

    $requirementsChanged = @($updates | Where-Object Type -EQ 'Requirement').Count -gt 0
    $requiredModulesChanged = @($updates | Where-Object Type -EQ 'RequiredModule').Count -gt 0
    $changed = $requirementsChanged -or $requiredModulesChanged
    $candidateVersion = $currentVersion
    $candidateRequirements = $originalRequirements
    $candidateManifest = $originalManifest
    $candidateChangelog = $originalChangelog

    if ($requirementsChanged) {
        $candidateRequirements = ConvertTo-PSDependencyCanaryRequirementContent `
            -Content $originalRequirements `
            -Path $RequirementsPath `
            -Version $candidateVersions
    }
    if ($requiredModulesChanged) {
        $candidateManifest = ConvertTo-PSDependencyCanaryRequiredModuleContent `
            -Content $originalManifest `
            -Path $ModuleManifestPath `
            -Version $candidateVersions
        $candidateVersion = Get-PSDependencyCanaryNextVersion -Version $currentVersion
        $candidateManifest = ConvertTo-PSDependencyCanaryManifestContent `
            -Content $candidateManifest `
            -Path $ModuleManifestPath `
            -Version $candidateVersion
        $runtimeVersionMap = @{}
        foreach ($update in @($updates | Where-Object Type -EQ 'RequiredModule')) {
            $runtimeVersionMap[$update.Name] = $update.CandidateVersion
        }
    }

    $applied = $false
    $baselineTested = $false
    $tested = $false
    if ($changed -and $PSCmdlet.ShouldProcess(
        $ProjectRoot,
        'Run baseline tests, bootstrap dependency updates, run candidate tests, and retain the passing candidate'
    )) {
        if ($requiredModulesChanged -and -not $SkipChangelog) {
            if (-not $changelogExists) {
                throw "The changelog was not found at '$ChangelogPath'. Specify -ChangelogPath or use -SkipChangelog."
            }
            $candidateChangelog = ConvertTo-PSDependencyCanaryChangelog `
                -Content $originalChangelog `
                -Version $candidateVersion `
                -Dependency $runtimeVersionMap
        }

        $powerShellPath = (Get-Process -Id $PID).Path
        Write-Verbose "Running the unchanged project's baseline Test task."
        Invoke-PSDependencyCanaryProjectBuild `
            -ProjectRoot $ProjectRoot `
            -Task Test `
            -PowerShellPath $powerShellPath
        $baselineTested = $true

        try {
            if ($requirementsChanged) {
                [IO.File]::WriteAllText($RequirementsPath, $candidateRequirements, $utf8NoBom)
            }
            if ($requiredModulesChanged) {
                [IO.File]::WriteAllText($ModuleManifestPath, $candidateManifest, $utf8NoBom)
                if (-not $SkipChangelog) {
                    [IO.File]::WriteAllText($ChangelogPath, $candidateChangelog, $utf8NoBom)
                }
            }

            Write-Verbose 'Bootstrapping the updated requirements and running the dependency candidate Test task.'
            Invoke-PSDependencyCanaryProjectBuild `
                -ProjectRoot $ProjectRoot `
                -Task Test `
                -PowerShellPath $powerShellPath `
                -Bootstrap
            $tested = $true
            $applied = $true
        } catch {
            [IO.File]::WriteAllText($RequirementsPath, $originalRequirements, $utf8NoBom)
            [IO.File]::WriteAllText($ModuleManifestPath, $originalManifest, $utf8NoBom)
            if ($requiredModulesChanged -and -not $SkipChangelog) {
                [IO.File]::WriteAllText($ChangelogPath, $originalChangelog, $utf8NoBom)
            }
            throw
        }
    }

    [pscustomobject][ordered]@{
        Changed = $changed
        RequirementsChanged = $requirementsChanged
        RequiredModulesChanged = $requiredModulesChanged
        Applied = $applied
        BaselineTested = $baselineTested
        Tested = $tested
        ModuleName = $moduleName
        CurrentVersion = [string]$currentVersion
        CandidateVersion = [string]$candidateVersion
        Updates = @($updates)
        RequirementsPath = $RequirementsPath.Substring($ProjectRoot.Length).TrimStart('\', '/')
        ModuleManifestPath = $ModuleManifestPath.Substring($ProjectRoot.Length).TrimStart('\', '/')
        ChangelogPath = if ($ChangelogPath) { $ChangelogPath.Substring($ProjectRoot.Length).TrimStart('\', '/') } else { $null }
        ChangelogSkipped = [bool]$SkipChangelog
    }
}
