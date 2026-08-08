@{
    RootModule = 'PSDependencyCanary.psm1'
    ModuleVersion = '1.1.0'
    GUID = '6ac2534d-1d38-4e61-8116-67bfbcf79391'

    Author = 'PwshDevs'
    CompanyName = 'PwshDevs'
    Copyright = '(c) PwshDevs. All rights reserved.'
    Description = 'Dependency update canary tasks for PSDepend, PowerShellBuild, and psake projects.'

    PowerShellVersion = '5.1'
    RequiredModules = @()

    FunctionsToExport = @(
        'Clear-PSDependencyCanaryEnvironment'
        'Test-PSDependencyCanary'
        'Update-PSDependencyCanary'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()

    PrivateData = @{
        PSData = @{
            Tags = @(
                'Dependency'
                'Canary'
                'Build'
                'PSDepend'
                'PowerShellBuild'
                'psake'
                'PSEdition_Core'
                'PSEdition_Desktop'
                'Windows'
                'Linux'
                'MacOS'
            )
            LicenseUri = 'https://github.com/pwshdevs/PSDependencyCanary/blob/main/LICENSE'
            ProjectUri = 'https://github.com/pwshdevs/PSDependencyCanary'
            ReleaseNotes = 'https://github.com/pwshdevs/PSDependencyCanary/blob/main/CHANGELOG.md'
        }
    }
}
