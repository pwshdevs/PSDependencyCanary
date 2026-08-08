BeforeDiscovery {
    $projectRoot = if ($env:BHProjectPath) { $env:BHProjectPath } else { Split-Path $PSScriptRoot -Parent }
    $workflowFiles = @(
        Get-Item -LiteralPath (Join-Path $projectRoot '.github/workflows/canary.yml')
        Get-Item -LiteralPath (Join-Path $projectRoot 'examples/ci/github-actions.yml')
    )
}

Describe 'GitHub Canary workflow <_.FullName>' -ForEach $workflowFiles {
    BeforeAll {
        $workflowContent = Get-Content -Raw -LiteralPath $_.FullName
        $installIndex = $workflowContent.IndexOf('Install-Module -Name PSDependencyCanary')
        $cleanIndex = $workflowContent.IndexOf('Clear-PSDependencyCanaryEnvironment')
        $bootstrapIndex = $workflowContent.IndexOf('./build.ps1 -Task Init -Bootstrap')
    }

    It 'installs PSDependencyCanary 1.1 or newer before cleaning' {
        $workflowContent | Should -Match "minimumCanaryVersion\s*=\s*'1\.1\.0'"
        $installIndex | Should -BeGreaterThan -1
        $cleanIndex | Should -BeGreaterThan $installIndex
    }

    It 'verifies that the temporary Canary installation removed itself' {
        $workflowContent | Should -Match 'Test-Path -LiteralPath \$canaryModule\.ModuleBase'
        $workflowContent | Should -Match 'temporary PSDependencyCanary installation was not removed'
    }

    It 'bootstraps committed pins after the clean step' {
        $bootstrapIndex | Should -BeGreaterThan $cleanIndex
    }

    It 'does not depend on a copied cleanup helper' {
        $workflowContent | Should -Not -Match 'Remove-BuildDependencies\.ps1'
    }
}
