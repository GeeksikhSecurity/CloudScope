# CloudScope PowerShell Installation Guide

## Table of Contents
- [Prerequisites](#prerequisites)
- [Installation Methods](#installation-methods)
  - [Quick Install from PowerShell Gallery](#quick-install-from-powershell-gallery)
  - [Manual Installation](#manual-installation)
  - [Azure Automation Installation](#azure-automation-installation)
  - [Development Installation](#development-installation)
- [Configuration](#configuration)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)
- [Updating](#updating)
- [Uninstallation](#uninstallation)

## Prerequisites

### System Requirements
- **PowerShell**: Version 7.0 or later
- **Operating System**: Windows 10/11, Windows Server 2016+, macOS, Linux
- **Memory**: Minimum 4GB RAM
- **Storage**: 500MB free space

### Required Permissions
- **Local Installation**: Administrator rights (Windows) or sudo access (macOS/Linux)
- **Azure**: Contributor access to subscription
- **Microsoft 365**: Global Administrator or Compliance Administrator role
- **Microsoft Graph**: Application permissions for compliance operations

### Dependencies
The following PowerShell modules will be automatically installed:
- Microsoft.Graph (v2.0.0+)
- Az.Accounts (v2.10.0+)
- Az.Monitor (v4.0.0+)
- Az.KeyVault (v4.0.0+)
- ImportExcel (v7.0.0+)
- PSWriteHTML (v0.0.180+)

## Installation Methods

### Quick Install from PowerShell Gallery

The easiest way to install CloudScope is from the PowerShell Gallery:

```powershell
# Install all CloudScope modules
Install-Module -Name CloudScope.Compliance -Repository PSGallery -Force
Install-Module -Name CloudScope.Graph -Repository PSGallery -Force
Install-Module -Name CloudScope.Monitoring -Repository PSGallery -Force
Install-Module -Name CloudScope.Reports -Repository PSGallery -Force

# Import modules
Import-Module CloudScope.Compliance
Import-Module CloudScope.Graph
Import-Module CloudScope.Monitoring
Import-Module CloudScope.Reports
```

### Manual Installation

1. **Download the CloudScope repository**
   ```powershell
   # Clone from GitHub
   git clone https://github.com/your-org/cloudscope.git
   cd cloudscope/powershell
   
   # Or download and extract ZIP
   Invoke-WebRequest -Uri "https://github.com/your-org/cloudscope/archive/main.zip" -OutFile "cloudscope.zip"
   Expand-Archive -Path "cloudscope.zip" -DestinationPath "."
   cd cloudscope-main/powershell
   ```

2. **Run the deployment script**
   ```powershell
   # Install locally
   .\Scripts\Deployment\Deploy-CloudScope.ps1 -DeploymentType Local -Force
   ```

3. **Verify installation**
   ```powershell
   Get-Module -ListAvailable CloudScope.*
   ```

### Azure Automation Installation

1. **Create Azure Automation Account**
   ```powershell
   # Connect to Azure
   Connect-AzAccount
   
   # Create resource group
   $resourceGroup = "rg-cloudscope-automation"
   $location = "eastus"
   New-AzResourceGroup -Name $resourceGroup -Location $location
   
   # Create automation account
   $automationAccount = "CloudScope-Automation"
   New-AzAutomationAccount -ResourceGroupName $resourceGroup `
       -Name $automationAccount `
       -Location $location `
       -Plan Basic
   ```

2. **Deploy modules to Azure Automation**
   ```powershell
   # Run deployment script
   .\Scripts\Deployment\Deploy-CloudScope.ps1 `
       -DeploymentType AzureAutomation `
       -ResourceGroup $resourceGroup `
       -AutomationAccount $automationAccount
   ```

3. **Import runbooks**
   ```powershell
   # Import monitoring runbook
   Import-AzAutomationRunbook -ResourceGroupName $resourceGroup `
       -AutomationAccountName $automationAccount `
       -Path ".\Scripts\Automation\Monitor-ComplianceRunbook.ps1" `
       -Type PowerShell `
       -Name "Monitor-Compliance"
   
   # Publish runbook
   Publish-AzAutomationRunbook -ResourceGroupName $resourceGroup `
       -AutomationAccountName $automationAccount `
       -Name "Monitor-Compliance"
   ```

### Development Installation

For development and testing:

1. **Clone the repository**
   ```powershell
   git clone https://github.com/your-org/cloudscope.git
   cd cloudscope/powershell
   ```

2. **Install development dependencies**
   ```powershell
   # Install required modules
   Install-Module -Name Pester -MinimumVersion 5.3.0 -Force
   Install-Module -Name PSScriptAnalyzer -MinimumVersion 1.20.0 -Force
   Install-Module -Name platyPS -MinimumVersion 0.14.2 -Force
   ```

3. **Import modules from source**
   ```powershell
   # Add to PowerShell profile for persistent access
   $modulePath = "$PWD\Modules"
   if ($env:PSModulePath -notcontains $modulePath) {
       $env:PSModulePath = "$modulePath;$env:PSModulePath"
   }
   
   # Import modules
   Import-Module "$modulePath\CloudScope.Compliance" -Force
   Import-Module "$modulePath\CloudScope.Graph" -Force
   Import-Module "$modulePath\CloudScope.Monitoring" -Force
   Import-Module "$modulePath\CloudScope.Reports" -Force
   ```

## Configuration

### 1. Create Configuration File

Create a configuration file at `~/.cloudscope/config.json`:

```json
{
  "tenantId": "your-tenant-id",
  "subscriptionId": "your-subscription-id",
  "environment": "Production",
  "defaultFramework": "GDPR",
  "monitoring": {
    "workspaceName": "CloudScope-LogAnalytics",
    "resourceGroup": "rg-cloudscope-monitoring",
    "alertRecipients": ["compliance@yourcompany.com"]
  },
  "keyVault": {
    "name": "kv-cloudscope-prod",
    "resourceGroup": "rg-cloudscope-security"
  },
  "reporting": {
    "powerBIWorkspace": "CloudScope Compliance",
    "defaultFormat": "HTML"
  }
}
```

### 2. Set Environment Variables

```powershell
# Set environment variables
$env:CLOUDSCOPE_TENANT_ID = "your-tenant-id"
$env:CLOUDSCOPE_SUBSCRIPTION_ID = "your-subscription-id"
$env:CLOUDSCOPE_KEYVAULT_NAME = "kv-cloudscope-prod"

# Add to PowerShell profile for persistence
Add-Content $PROFILE @"
`$env:CLOUDSCOPE_TENANT_ID = "your-tenant-id"
`$env:CLOUDSCOPE_SUBSCRIPTION_ID = "your-subscription-id"
`$env:CLOUDSCOPE_KEYVAULT_NAME = "kv-cloudscope-prod"
"@
```

### 3. Configure Microsoft Graph Permissions

1. **Register Azure AD Application**
   ```powershell
   # Install Azure AD module if needed
   Install-Module -Name AzureAD -Force
   
   # Connect to Azure AD
   Connect-AzureAD
   
   # Create application
   $app = New-AzureADApplication -DisplayName "CloudScope Compliance" `
       -RequiredResourceAccess @{
           ResourceAppId = "00000003-0000-0000-c000-000000000000" # Microsoft Graph
           ResourceAccess = @(
               @{ Id = "df021288-bdef-4463-88db-98f22de89214"; Type = "Role" }, # User.Read.All
               @{ Id = "5b567255-7703-4780-807c-7be8301ae99b"; Type = "Role" }, # Group.Read.All
               @{ Id = "7ab1d382-f21e-4acd-a863-ba3e13f7da61"; Type = "Role" }, # Directory.Read.All
               @{ Id = "dc50a0fb-09a3-484d-be87-e023b12c6440"; Type = "Role" }, # InformationProtectionPolicy.Read.All
               @{ Id = "b0afded3-3588-46d8-8b3d-9842eff778da"; Type = "Role" }  # AuditLog.Read.All
           )
       }
   ```

2. **Grant Admin Consent**
   Navigate to Azure Portal > Azure Active Directory > App registrations > CloudScope Compliance > API permissions > Grant admin consent

### 4. Configure Azure Resources

```powershell
# Create Key Vault
$keyVault = New-AzKeyVault -Name "kv-cloudscope-prod" `
    -ResourceGroupName "rg-cloudscope-security" `
    -Location "eastus"

# Create Log Analytics Workspace
$workspace = New-AzOperationalInsightsWorkspace `
    -ResourceGroupName "rg-cloudscope-monitoring" `
    -Name "CloudScope-LogAnalytics" `
    -Location "eastus" `
    -Sku "PerGB2018"

# Create Application Insights
$appInsights = New-AzApplicationInsights `
    -ResourceGroupName "rg-cloudscope-monitoring" `
    -Name "CloudScope-AppInsights" `
    -Location "eastus" `
    -WorkspaceResourceId $workspace.ResourceId
```

## Verification

### 1. Test Module Import

```powershell
# Test each module
@('CloudScope.Compliance', 'CloudScope.Graph', 'CloudScope.Monitoring', 'CloudScope.Reports') | ForEach-Object {
    try {
        Import-Module $_ -Force
        Write-Host "✅ $_ imported successfully" -ForegroundColor Green
    } catch {
        Write-Host "❌ Failed to import $_`: $($_.Exception.Message)" -ForegroundColor Red
    }
}
```

### 2. Test Basic Functionality

```powershell
# Initialize CloudScope
Initialize-CloudScopeCompliance -Framework GDPR

# Connect to Microsoft Graph
Connect-CloudScopeGraph

# Run a simple compliance check
$users = Get-ComplianceUsers -Top 5
Write-Host "Found $($users.Count) users"

# Test monitoring
$metric = New-ComplianceMetric -Name "TestMetric" -Value 100 -Category "Test"
Write-Host "Created test metric: $($metric.Name)"
```

### 3. Run Diagnostic Script

```powershell
# Create and run diagnostic script
@'
Write-Host "CloudScope Diagnostics" -ForegroundColor Cyan
Write-Host "=====================" -ForegroundColor Cyan

# Check PowerShell version
Write-Host "`nPowerShell Version: $($PSVersionTable.PSVersion)"

# Check modules
Write-Host "`nInstalled CloudScope Modules:"
Get-Module -ListAvailable CloudScope.* | Format-Table Name, Version

# Check Azure connection
try {
    $context = Get-AzContext
    Write-Host "`n✅ Connected to Azure: $($context.Subscription.Name)" -ForegroundColor Green
} catch {
    Write-Host "`n❌ Not connected to Azure" -ForegroundColor Red
}

# Check Graph connection
try {
    $graphContext = Get-MgContext
    Write-Host "✅ Connected to Microsoft Graph" -ForegroundColor Green
} catch {
    Write-Host "❌ Not connected to Microsoft Graph" -ForegroundColor Red
}

# Check environment variables
Write-Host "`nEnvironment Variables:"
@('CLOUDSCOPE_TENANT_ID', 'CLOUDSCOPE_SUBSCRIPTION_ID', 'CLOUDSCOPE_KEYVAULT_NAME') | ForEach-Object {
    $value = [Environment]::GetEnvironmentVariable($_)
    if ($value) {
        Write-Host "✅ $_ is set" -ForegroundColor Green
    } else {
        Write-Host "❌ $_ is not set" -ForegroundColor Red
    }
}
'@ | Out-File "Test-CloudScope.ps1"

.\Test-CloudScope.ps1
```

## Troubleshooting

### Common Issues

1. **Module not found error**
   ```powershell
   # Update PSModulePath
   $env:PSModulePath = "$env:PSModulePath;$HOME\Documents\PowerShell\Modules"
   
   # Refresh module list
   Get-Module -ListAvailable -Refresh
   ```

2. **Permission denied errors**
   ```powershell
   # Run PowerShell as Administrator (Windows)
   Start-Process pwsh -Verb RunAs
   
   # Or set execution policy
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

3. **Graph connection failures**
   ```powershell
   # Clear token cache
   Disconnect-MgGraph
   Clear-MgContext
   
   # Reconnect with explicit scopes
   Connect-MgGraph -Scopes @(
       "User.Read.All",
       "Group.Read.All",
       "Directory.Read.All",
       "AuditLog.Read.All"
   )
   ```

4. **Azure connection issues**
   ```powershell
   # Clear Azure context
   Clear-AzContext -Force
   
   # Re-authenticate
   Connect-AzAccount -TenantId "your-tenant-id"
   ```

### Debug Mode

Enable verbose logging:

```powershell
# Enable debug output
$DebugPreference = 'Continue'
$VerbosePreference = 'Continue'

# Run commands with -Debug and -Verbose
Initialize-CloudScopeCompliance -Framework GDPR -Debug -Verbose
```

## Updating

### Update from PowerShell Gallery

```powershell
# Update all CloudScope modules
Update-Module -Name CloudScope.* -Force

# Verify versions
Get-Module -ListAvailable CloudScope.* | Format-Table Name, Version
```

### Update from Source

```powershell
# Pull latest changes
cd cloudscope
git pull origin main

# Redeploy
.\powershell\Scripts\Deployment\Deploy-CloudScope.ps1 -DeploymentType Local -Force
```

## Uninstallation

### Remove Local Installation

```powershell
# Uninstall modules
@('CloudScope.Compliance', 'CloudScope.Graph', 'CloudScope.Monitoring', 'CloudScope.Reports') | ForEach-Object {
    Uninstall-Module -Name $_ -AllVersions -Force
}

# Remove configuration
Remove-Item -Path "~/.cloudscope" -Recurse -Force -ErrorAction SilentlyContinue

# Remove environment variables
Remove-Item env:CLOUDSCOPE_* -ErrorAction SilentlyContinue
```

### Remove from Azure Automation

```powershell
# Remove modules from automation account
$modules = @('CloudScope.Compliance', 'CloudScope.Graph', 'CloudScope.Monitoring', 'CloudScope.Reports')
foreach ($module in $modules) {
    Remove-AzAutomationModule -ResourceGroupName $resourceGroup `
        -AutomationAccountName $automationAccount `
        -Name $module `
        -Force
}

# Remove runbooks
Get-AzAutomationRunbook -ResourceGroupName $resourceGroup `
    -AutomationAccountName $automationAccount | 
    Where-Object { $_.Name -like "*CloudScope*" } | 
    Remove-AzAutomationRunbook -Force
```

## Next Steps

1. Review the [Quick Start Guide](QUICKSTART.md)
2. Configure your compliance frameworks
3. Set up monitoring and alerting
4. Schedule automated compliance assessments
5. Create custom compliance policies

For additional help, visit our [documentation](https://docs.cloudscope.io) or [open an issue](https://github.com/your-org/cloudscope/issues).
