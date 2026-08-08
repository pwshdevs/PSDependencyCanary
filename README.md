# PSDependencyCanary

**Github**

[![GitHub Actions Status][github-actions-badge]][github-actions-build] [![GitHub Actions Status][github-actions-badge-publish]][github-actions-build] [![GitHub Actions Status][github-actions-badge-canary]][github-actions-build] [![GitHub Open Issues Status][github-open-issues-badge]][github-open-issues] [![GitHub Closed Issues Status][github-closed-issues-badge]][github-closed-issues] [![License][license-badge]][license]

**PSGallery**

[![PowerShell Gallery][psgallery-badge]][psgallery] [![PSGallery Version][psgallery-version-badge]][psgallery] [![PSGallery Playform][psgallery-platform-badge]][psgallery] [![PSGallery Playform][ps-desktop-badge]][psgallery]

Dependency update canaries for PSDepend, PowerShellBuild, and psake projects.

## Overview

PSDependencyCanary is an add-on for PowerShell module projects built with PSDepend, PowerShellBuild, and psake. It supplies a shared psake `Canary` task that first runs the project's current `Test` task as a baseline. Only a passing baseline proceeds to update the declarations, bootstrap the complete candidate environment, and run the same test task again before retaining any dependency changes.

Those tools are the supported project model, not optional adapters. PSDependencyCanary intentionally standardizes dependency declaration, bootstrap, build, and test orchestration around that ecosystem instead of abstracting arbitrary build systems.

`requirements.psd1` defines the complete build and test environment. Every module listed in the shipped manifest's `RequiredModules` must also be present in `requirements.psd1`, allowing the canary to install and test a reproducible environment. Runtime dependency updates are written to both files at the same validated version.

Candidate file edits preserve the layout of `requirements.psd1` and the module manifest. A failed baseline makes no candidate edits. A failed candidate bootstrap or test restores the original files. `-WhatIf` reports available updates without bootstrapping, testing, or editing.

Build-only dependency updates change only `requirements.psd1`. They do not change the shipped module version. An update to `RequiredModules` changes the source manifest, patch-bumps `ModuleVersion`, and adds the corresponding changelog release.

## Installation

```powershell
Install-PSResource -Name PSDependencyCanary
```

For Windows PowerShell 5.1:

```powershell
Install-Module -Name PSDependencyCanary
```

## PowerShellBuild, psake, and CI/CD

The supported project contract is:

- `build.ps1` accepts `-Task <name>` and `-Bootstrap`.
- PowerShellBuild provides the project's `Test` task and returns a failing exit code when the build, analysis, or tests fail.
- `-Bootstrap` installs and imports the exact versions in `requirements.psd1`.
- The source manifest is at `src/<ModuleName>/<ModuleName>.psd1`. For another layout, set the shared task's `PSDependencyCanaryModuleManifestPath` property.
- Every module in the manifest's `RequiredModules` is also pinned in `requirements.psd1`.

Add PSDependencyCanary to the existing `requirements.psd1`:

```powershell
@{
    PSDepend = @{ Version = '0.4.1' }
    PowerShellBuild = @{ Version = '0.8.2' }
    PSDependencyCanary = @{ Version = '1.0.0' }

    # Existing build, test, and runtime dependencies belong here too.
    Pester = @{ Version = '6.0.1' }

    PSDependOptions = @{ Target = 'CurrentUser' }
}
```

Add the shared task to the existing `psakeFile.ps1`:

```powershell
Task Test -FromModule PowerShellBuild -MinimumVersion '0.8.2'
Task Canary -FromModule PSDependencyCanary -MinimumVersion '1.0.0'
```

The shared task exposes paths and optional output features through psake properties:

| Property | Default | Purpose |
| --- | --- | --- |
| `PSDependencyCanaryProjectRoot` | `BHProjectPath`, then the current directory | Project containing the build entry point. |
| `PSDependencyCanaryModuleManifestPath` | Auto-discovered under `src` | Source module manifest. |
| `PSDependencyCanaryRequirementsPath` | `requirements.psd1` | Complete PSDepend environment. |
| `PSDependencyCanaryChangelogPath` | `CHANGELOG.md` | Changelog updated for runtime dependency changes. |
| `PSDependencyCanaryResultPath` | `out/dependency-canary.json` | Structured task result for CI. |
| `PSDependencyCanarySkipChangelog` | `$false` | Patch-bump runtime updates without requiring or changing a changelog. |
| `PSDependencyCanarySkipResult` | `$false` | Return the task result without writing a JSON result file. |

The changelog is required only when a runtime dependency changes and changelog updates are enabled. Configure a different location or explicitly disable that feature:

```powershell
$properties = @{
    PSDependencyCanaryChangelogPath = './docs/CHANGE_LOG.md'
}
./build.ps1 -Task Canary -Properties $properties

# Or patch-bump runtime updates without a changelog:
$properties = @{
    PSDependencyCanarySkipChangelog = $true
}
./build.ps1 -Task Canary -Properties $properties
```

Then schedule these commands in CI:

```powershell
# Install the currently committed pins.
./build.ps1 -Task Init -Bootstrap

# Baseline-test, stage updates, rebootstrap, and test the candidate.
./build.ps1 -Task Canary
```

The shared task writes `out/dependency-canary.json` by default. A CI promotion step should require `BaselineTested`, `Tested`, and `Applied` before committing a changed candidate:

```powershell
$result = Get-Content -Raw out/dependency-canary.json | ConvertFrom-Json
if ($result.Changed -and (-not $result.BaselineTested -or -not $result.Tested -or -not $result.Applied)) {
    throw 'The unchanged project and dependency candidate were not both validated.'
}
```

Copyable pipeline examples are available for:

- [GitHub Actions](examples/ci/github-actions.yml), which can be copied to `.github/workflows/canary.yml` and includes automatic pull-request creation
- [GitLab CI](examples/ci/gitlab-ci.yml), producing a validated patch artifact
- [Azure Pipelines](examples/ci/azure-pipelines.yml), producing a validated patch artifact

The patch-artifact examples leave repository writes to a separate protected job. Applying the generated `dependency-canary.patch` reproduces the exact candidate that passed Canary.

[github-actions-badge]: https://img.shields.io/github/actions/workflow/status/pwshdevs/PSDependencyCanary/test.yml?label=build&style=for-the-badge
[github-actions-badge-publish]: https://img.shields.io/github/actions/workflow/status/pwshdevs/PSDependencyCanary/publish.yml?label=publish&style=for-the-badge
[github-actions-badge-canary]: https://img.shields.io/github/actions/workflow/status/pwshdevs/PSDependencyCanary/canary.yml?label=canary&style=for-the-badge
[github-actions-build]: https://github.com/pwshdevs/PSDependencyCanary/actions
[psgallery-badge]: https://img.shields.io/powershellgallery/dt/PSDependencyCanary?label=downloads&style=for-the-badge
[psgallery]: https://www.powershellgallery.com/packages/PSDependencyCanary
[psgallery-version-badge]: https://img.shields.io/powershellgallery/v/PSDependencyCanary?label=version&style=for-the-badge
[license-badge]: https://img.shields.io/github/license/pwshdevs/PSDependencyCanary?style=for-the-badge
[license]: https://raw.githubusercontent.com/pwshdevs/PSDependencyCanary/main/LICENSE
[github-open-issues-badge]: https://img.shields.io/github/issues/pwshdevs/PSDependencyCanary?style=for-the-badge
[github-closed-issues-badge]: https://img.shields.io/github/issues-closed/pwshdevs/PSDependencyCanary?style=for-the-badge
[github-closed-issues]: https://github.com/pwshdevs/PSDependencyCanary/issues?q=is%3Aissue%20state%3Aclosed
[github-open-issues]: https://github.com/pwshdevs/PSDependencyCanary/issues
[psgallery-platform-badge]: https://img.shields.io/powershellgallery/p/PSDependencyCanary?style=for-the-badge
[ps-desktop-badge]: https://img.shields.io/badge/powershell-5.1,_7.0+-blue?style=for-the-badge
[ps-core-badge]: https://img.shields.io/badge/powershell-5.1,_7.0+-blue?style=for-the-badge
