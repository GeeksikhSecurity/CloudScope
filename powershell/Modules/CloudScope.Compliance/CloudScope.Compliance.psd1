@{
    # Module manifest for CloudScope.Compliance
    RootModule = 'CloudScope.Compliance.psm1'
    ModuleVersion = '1.0.0'
    GUID = '12345678-1234-1234-1234-123456789012'
    Author = 'CloudScope Team'
    CompanyName = 'CloudScope'
    Copyright = '(c) 2025 CloudScope. All rights reserved.'
    Description = 'PowerShell module for compliance-as-code using Microsoft Graph and Azure services'
    
    # Minimum version of PowerShell required
    PowerShellVersion = '7.0'
    
    # Required modules
    RequiredModules = @(
        @{ ModuleName = 'Microsoft.Graph.Authentication'; ModuleVersion = '2.0.0' },
        @{ ModuleName = 'Microsoft.Graph.Users'; ModuleVersion = '2.0.0' },
        @{ ModuleName = 'Microsoft.Graph.InformationProtection'; ModuleVersion = '2.0.0' },
        @{ ModuleName = 'Az.KeyVault'; ModuleVersion = '4.0.0' },
        @{ ModuleName = 'Az.Monitor'; ModuleVersion = '4.0.0' }
    )
    
    # Functions to export
    FunctionsToExport = @(
        'Initialize-CloudScopeCompliance',
        'Set-DataClassification',
        'Enable-DataEncryption',
        'Add-AuditLog',
        'Test-AccessControl',
        'Invoke-ComplianceAssessment',
        'Get-ComplianceViolations',
        'New-ComplianceReport',
        'Set-GDPRCompliance',
        'Set-PCICompliance',
        'Set-HIPAACompliance',
        'Set-SOC2Compliance',
        'Get-ComplianceMetrics',
        'Start-ComplianceMonitoring',
        'Stop-ComplianceMonitoring'
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
            Tags = @('Compliance', 'GDPR', 'PCI', 'HIPAA', 'SOC2', 'Microsoft', 'Graph', 'Azure')
            LicenseUri = 'https://github.com/your-org/cloudscope/blob/main/LICENSE'
            ProjectUri = 'https://github.com/your-org/cloudscope'
            ReleaseNotes = 'Initial release of CloudScope PowerShell Compliance module'
        }
    }
}
