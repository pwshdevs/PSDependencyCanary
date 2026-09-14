@{
    PSDepend = @{
        Version = '0.5.0'
    }
    PSDependOptions = @{
        Target = 'CurrentUser'
    }
    'Pester' = @{
        Version = '6.2.0'
        Parameters = @{
            SkipPublisherCheck = $true
        }
    }
    'psake' = @{
        Version = '5.0.4'
    }
    'BuildHelpers' = @{
        Version = '2.0.16'
    }
    'PowerShellBuild' = @{
        Version = '0.8.2'
    }
    'PSScriptAnalyzer' = @{
        Version = '1.25.0'
    }
}
