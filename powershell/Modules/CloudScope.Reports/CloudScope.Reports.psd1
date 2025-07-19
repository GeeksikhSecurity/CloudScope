@{
    # Module manifest for CloudScope.Reports
    RootModule = 'CloudScope.Reports.psm1'
    ModuleVersion = '1.0.0'
    GUID = '11223344-5566-7788-99aa-bbccddeeff00'
    Author = 'CloudScope Team'
    CompanyName = 'CloudScope'
    Copyright = '(c) 2025 CloudScope. All rights reserved.'
    Description = 'Power BI integration and compliance reporting for CloudScope'
    
    # Minimum version of PowerShell required
    PowerShellVersion = '7.0'
    
    # Required modules
    RequiredModules = @(
        @{ ModuleName = 'MicrosoftPowerBIMgmt'; ModuleVersion = '1.2.0' },
        @{ ModuleName = 'ImportExcel'; ModuleVersion = '7.0.0' },
        @{ ModuleName = 'PSWriteHTML'; ModuleVersion = '0.0.180' }
    )
    
    # Functions to export
    FunctionsToExport = @(
        'Initialize-ComplianceReporting',
        'New-ComplianceReport',
        'New-ComplianceDashboard',
        'Export-ComplianceReport',
        'Publish-ComplianceReport',
        'Get-ComplianceReportTemplates',
        'New-ExecutiveSummary',
        'New-FrameworkReport',
        'New-ViolationsReport',
        'New-UserComplianceReport',
        'New-DataClassificationReport',
        'New-AuditReport',
        'Schedule-ComplianceReport',
        'Send-ComplianceReport'
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
            Tags = @('PowerBI', 'Reporting', 'Compliance', 'Dashboard', 'CloudScope')
            LicenseUri = 'https://github.com/your-org/cloudscope/blob/main/LICENSE'
            ProjectUri = 'https://github.com/your-org/cloudscope'
            ReleaseNotes = 'Initial release of CloudScope Reports module'
        }
    }
}
