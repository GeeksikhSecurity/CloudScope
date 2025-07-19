@{
    # Module manifest for CloudScope.Graph
    RootModule = 'CloudScope.Graph.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'abcdef12-3456-7890-abcd-ef1234567890'
    Author = 'CloudScope Team'
    CompanyName = 'CloudScope'
    Copyright = '(c) 2025 CloudScope. All rights reserved.'
    Description = 'Microsoft Graph integration module for CloudScope compliance operations'
    
    # Minimum version of PowerShell required
    PowerShellVersion = '7.0'
    
    # Required modules
    RequiredModules = @(
        @{ ModuleName = 'Microsoft.Graph.Authentication'; ModuleVersion = '2.0.0' },
        @{ ModuleName = 'Microsoft.Graph.Users'; ModuleVersion = '2.0.0' },
        @{ ModuleName = 'Microsoft.Graph.Groups'; ModuleVersion = '2.0.0' },
        @{ ModuleName = 'Microsoft.Graph.Identity.DirectoryManagement'; ModuleVersion = '2.0.0' },
        @{ ModuleName = 'Microsoft.Graph.Security'; ModuleVersion = '2.0.0' },
        @{ ModuleName = 'Microsoft.Graph.Compliance'; ModuleVersion = '2.0.0' }
    )
    
    # Functions to export
    FunctionsToExport = @(
        'Connect-CloudScopeGraph',
        'Disconnect-CloudScopeGraph',
        'Get-CloudScopeGraphContext',
        'Get-ComplianceUsers',
        'Get-UserComplianceData',
        'Get-SensitiveDataLocations',
        'Get-ComplianceAlerts',
        'New-ComplianceAlert',
        'Get-DataGovernanceLabels',
        'Set-DataGovernanceLabel',
        'Get-DLPPolicies',
        'New-DLPPolicy',
        'Get-ComplianceReports',
        'Export-ComplianceData',
        'Get-RiskAssessment',
        'Get-SecurityIncidents',
        'Invoke-GraphAPIRequest'
    )
    
    # Cmdlets to export
    CmdletsToExport = @()
    
    # Variables to export
    VariablesToExport = @()
    
    # Aliases to export
    AliasesToExport = @()
    
    # Private data
    PrivateData = @{
        PSData = @{
            Tags = @('MicrosoftGraph', 'Compliance', 'API', 'Integration', 'CloudScope')
            LicenseUri = 'https://github.com/your-org/cloudscope/blob/main/LICENSE'
            ProjectUri = 'https://github.com/your-org/cloudscope'
            ReleaseNotes = 'Initial release of CloudScope Microsoft Graph integration module'
        }
    }
}
