@{
    # CloudScope PowerShell Module Requirements
    # This file defines all module dependencies for CloudScope
    
    # PowerShell Gallery Modules
    'Microsoft.Graph' = @{
        Version = '2.0.0'
        Repository = 'PSGallery'
        Description = 'Microsoft Graph PowerShell SDK'
    }
    
    'Microsoft.Graph.Authentication' = @{
        Version = '2.0.0'
        Repository = 'PSGallery'
        Description = 'Microsoft Graph Authentication'
    }
    
    'Microsoft.Graph.Users' = @{
        Version = '2.0.0'
        Repository = 'PSGallery'
        Description = 'Microsoft Graph Users API'
    }
    
    'Microsoft.Graph.Groups' = @{
        Version = '2.0.0'
        Repository = 'PSGallery'
        Description = 'Microsoft Graph Groups API'
    }
    
    'Microsoft.Graph.Identity.DirectoryManagement' = @{
        Version = '2.0.0'
        Repository = 'PSGallery'
        Description = 'Microsoft Graph Directory Management'
    }
    
    'Microsoft.Graph.Security' = @{
        Version = '2.0.0'
        Repository = 'PSGallery'
        Description = 'Microsoft Graph Security API'
    }
    
    'Microsoft.Graph.Compliance' = @{
        Version = '2.0.0'
        Repository = 'PSGallery'
        Description = 'Microsoft Graph Compliance API'
    }
    
    'Microsoft.Graph.InformationProtection' = @{
        Version = '2.0.0'
        Repository = 'PSGallery'
        Description = 'Microsoft Information Protection API'
    }
    
    'Az.Accounts' = @{
        Version = '2.10.0'
        Repository = 'PSGallery'
        Description = 'Azure Account Management'
    }
    
    'Az.Resources' = @{
        Version = '5.0.0'
        Repository = 'PSGallery'
        Description = 'Azure Resource Management'
    }
    
    'Az.KeyVault' = @{
        Version = '4.0.0'
        Repository = 'PSGallery'
        Description = 'Azure Key Vault Management'
    }
    
    'Az.Monitor' = @{
        Version = '4.0.0'
        Repository = 'PSGallery'
        Description = 'Azure Monitor'
    }
    
    'Az.OperationalInsights' = @{
        Version = '3.0.0'
        Repository = 'PSGallery'
        Description = 'Azure Log Analytics'
    }
    
    'Az.ApplicationInsights' = @{
        Version = '2.0.0'
        Repository = 'PSGallery'
        Description = 'Azure Application Insights'
    }
    
    'Az.Automation' = @{
        Version = '1.7.0'
        Repository = 'PSGallery'
        Description = 'Azure Automation'
    }
    
    'Az.Storage' = @{
        Version = '4.0.0'
        Repository = 'PSGallery'
        Description = 'Azure Storage'
    }
    
    'MicrosoftPowerBIMgmt' = @{
        Version = '1.2.0'
        Repository = 'PSGallery'
        Description = 'Power BI Management'
    }
    
    'ImportExcel' = @{
        Version = '7.0.0'
        Repository = 'PSGallery'
        Description = 'Excel Import/Export without Excel'
    }
    
    'PSWriteHTML' = @{
        Version = '0.0.180'
        Repository = 'PSGallery'
        Description = 'HTML Report Generation'
    }
    
    'PnP.PowerShell' = @{
        Version = '1.12.0'
        Repository = 'PSGallery'
        Description = 'SharePoint PnP PowerShell'
        Optional = $true
    }
    
    # Development Dependencies
    'Pester' = @{
        Version = '5.3.0'
        Repository = 'PSGallery'
        Description = 'PowerShell Testing Framework'
        Development = $true
    }
    
    'PSScriptAnalyzer' = @{
        Version = '1.20.0'
        Repository = 'PSGallery'
        Description = 'PowerShell Script Analyzer'
        Development = $true
    }
    
    'platyPS' = @{
        Version = '0.14.2'
        Repository = 'PSGallery'
        Description = 'PowerShell Help Generation'
        Development = $true
    }
    
    # DSC Resources (Optional)
    'SecurityPolicyDsc' = @{
        Version = '2.10.0.0'
        Repository = 'PSGallery'
        Description = 'Security Policy DSC Resource'
        Optional = $true
    }
    
    'AuditPolicyDsc' = @{
        Version = '1.4.0.0'
        Repository = 'PSGallery'
        Description = 'Audit Policy DSC Resource'
        Optional = $true
    }
    
    'NetworkingDsc' = @{
        Version = '8.2.0'
        Repository = 'PSGallery'
        Description = 'Networking DSC Resource'
        Optional = $true
    }
    
    'xWebAdministration' = @{
        Version = '3.2.0'
        Repository = 'PSGallery'
        Description = 'IIS DSC Resource'
        Optional = $true
    }
    
    'xWindowsUpdate' = @{
        Version = '2.8.0.0'
        Repository = 'PSGallery'
        Description = 'Windows Update DSC Resource'
        Optional = $true
    }
}
