# Change Log

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/).

## [1.0.0] Unreleased

### Added

- Shared psake `Canary` task for PSDepend and PowerShellBuild module projects.
- Discovery and installation of newer `requirements.psd1` and `RequiredModules` versions.
- Baseline testing before source edits, followed by candidate rebootstrap and testing with exact source-file rollback on failure.
- Build-only updates without a module version change and automatic patch releases for runtime dependency updates.
- PowerShell 7 and Windows PowerShell 5.1 candidate validation.
- CI/CD guidance and examples for GitHub Actions, GitLab CI, and Azure Pipelines.
- Configurable or optional changelog handling through shared Canary task properties.

