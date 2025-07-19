@{
    # Module manifest for CloudScope.Monitoring
    RootModule = 'CloudScope.Monitoring.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'fedcba98-7654-3210-fedc-ba9876543210'
    Author = 'CloudScope Team'
    CompanyName = 'CloudScope'
    Copyright = '(c) 2025 CloudScope. All rights reserved.'
    Description = 'Azure Monitor integration and real-time compliance monitoring for CloudScope'
    
    # Minimum version of PowerShell required
    PowerShellVersion = '7.0'
    
    # Required modules
    RequiredModules = @(
        @{ ModuleName = 'Az.Monitor'; ModuleVersion = '4.0.0' },
        @{ ModuleName = 'Az.OperationalInsights'; ModuleVersion = '3.0.0' },
        @{ ModuleName = 'Az.ApplicationInsights'; ModuleVersion = '2.0.0' },
        @{ ModuleName = 'Az.LogicApp'; ModuleVersion = '1.5.0' }
    )
    
    # Functions to export
    FunctionsToExport = @(
        'Initialize-ComplianceMonitoring',
        'Start-RealtimeMonitoring',
        'Stop-RealtimeMonitoring',
        'New-ComplianceMetric',
        'Send-ComplianceMetric',
        'New-ComplianceAlert',
        'Get-ComplianceMetrics',
        'New-ComplianceDashboard',
        'Export-ComplianceMetrics',
        'Set-AlertingRules',
        'Get-AlertingRules',
        'Test-ComplianceThreshold',
        'New-AutomationResponse',
        'Get-MonitoringStatus'
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
            Tags = @('Monitoring', 'Azure', 'Compliance', 'Metrics', 'Alerts')
            LicenseUri = 'https://github.com/your-org/cloudscope/blob/main/LICENSE'
            ProjectUri = 'https://github.com/your-org/cloudscope'
            ReleaseNotes = 'Initial release of CloudScope Monitoring module'
        }
    }
}
