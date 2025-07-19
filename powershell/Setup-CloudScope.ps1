<#
.SYNOPSIS
    CloudScope PowerShell Setup Script
    
.DESCRIPTION
    One-click setup script for CloudScope compliance framework.
    Installs dependencies, configures environment, and performs initial setup.
    
.PARAMETER Environment
    Target environment: Development, Production, or Demo
    
.PARAMETER SkipAzureSetup
    Skip Azure resource creation
    
.PARAMETER SkipModuleInstall
    Skip PowerShell module installation
    
.EXAMPLE
    .\Setup-CloudScope.ps1 -Environment Demo
    
.EXAMPLE
    .\Setup-CloudScope.ps1 -Environment Production -SkipModuleInstall
    
.NOTES
    File: Setup-CloudScope.ps1
    Author: CloudScope Team
    Version: 1.0.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet('Development', 'Production', 'Demo')]
    [string]$Environment = 'Demo',
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipAzureSetup,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipModuleInstall,
    
    [Parameter(Mandatory = $false)]
    [string]$ConfigPath = (Join-Path $PSScriptRoot 'config.json'),
    
    [Parameter(Mandatory = $false)]
    [switch]$Interactive = $true
)

# Script variables
$script:SetupLog = @()
$script:Config = @{
    Environment = $Environment
    AzureSubscriptionId = $null
    TenantId = $null
    ResourceGroup = $null
    AutomationAccount = $null
    KeyVaultName = $null
    LogAnalyticsWorkspace = $null
    AppInsightsName = $null
    StorageAccount = $null
    ComplianceOfficerEmail = $null
    Modules = @{}
    SetupDate = Get-Date
}

# Display banner
Write-Host @"

   _____ _                 _  _____                      
  / ____| |               | |/ ____|                     
 | |    | | ___  _   _  __| | (___   ___ ___  _ __   ___ 
 | |    | |/ _ \| | | |/ _` |\___ \ / __/ _ \| '_ \ / _ \
 | |____| | (_) | |_| | (_| |____) | (_| (_) | |_) |  __/
  \_____|_|\___/ \__,_|\__,_|_____/ \___\___/| .__/ \___|
                                              | |         
           PowerShell Compliance Framework    |_|         
                                              
"@ -ForegroundColor Cyan

Write-Host "Welcome to CloudScope Setup!" -ForegroundColor Green
Write-Host "Environment: $Environment" -ForegroundColor Yellow
Write-Host "=" * 50 -ForegroundColor Gray

#region Helper Functions

function Write-SetupLog {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Success', 'Warning', 'Error')]
        [string]$Level = 'Info'
    )
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $script:SetupLog += "$timestamp [$Level] $Message"
    
    switch ($Level) {
        'Success' { Write-Host "✅ $Message" -ForegroundColor Green }
        'Warning' { Write-Host "⚠️  $Message" -ForegroundColor Yellow }
        'Error' { Write-Host "❌ $Message" -ForegroundColor Red }
        default { Write-Host "ℹ️  $Message" -ForegroundColor Cyan }
    }
}

function Test-Administrator {
    if ($IsWindows -ne $false) {
        $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    return $true
}

function Test-PowerShellVersion {
    $requiredVersion = [version]'7.0.0'
    $currentVersion = $PSVersionTable.PSVersion
    
    if ($currentVersion -lt $requiredVersion) {
        Write-SetupLog "PowerShell $requiredVersion or higher is required. Current version: $currentVersion" -Level Error
        
        if ($Interactive) {
            $install = Read-Host "Would you like to install PowerShell 7? (Y/N)"
            if ($install -eq 'Y') {
                Install-PowerShell7
            } else {
                return $false
            }
        } else {
            return $false
        }
    }
    
    Write-SetupLog "PowerShell version check passed: $currentVersion" -Level Success
    return $true
}

function Install-PowerShell7 {
    Write-SetupLog "Installing PowerShell 7..."
    
    if ($IsWindows -ne $false) {
        # Windows
        Invoke-Expression "& { $(Invoke-RestMethod https://aka.ms/install-powershell.ps1) } -UseMSI -Quiet"
    } elseif ($IsMacOS) {
        # macOS
        brew install --cask powershell
    } else {
        # Linux
        wget -q https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb
        sudo dpkg -i packages-microsoft-prod.deb
        sudo apt-get update
        sudo apt-get install -y powershell
    }
    
    Write-SetupLog "PowerShell 7 installation completed. Please restart the script in PowerShell 7." -Level Warning
}

function Install-RequiredModules {
    Write-SetupLog "Installing required PowerShell modules..."
    
    $modules = @(
        @{ Name = 'Microsoft.Graph'; MinimumVersion = '2.0.0' }
        @{ Name = 'Az.Accounts'; MinimumVersion = '2.10.0' }
        @{ Name = 'Az.Resources'; MinimumVersion = '5.0.0' }
        @{ Name = 'Az.Automation'; MinimumVersion = '1.7.0' }
        @{ Name = 'Az.KeyVault'; MinimumVersion = '4.0.0' }
        @{ Name = 'Az.Monitor'; MinimumVersion = '4.0.0' }
        @{ Name = 'Az.OperationalInsights'; MinimumVersion = '3.0.0' }
        @{ Name = 'Az.ApplicationInsights'; MinimumVersion = '2.0.0' }
        @{ Name = 'Az.Storage'; MinimumVersion = '4.0.0' }
        @{ Name = 'MicrosoftPowerBIMgmt'; MinimumVersion = '1.2.0' }
        @{ Name = 'ImportExcel'; MinimumVersion = '7.0.0' }
        @{ Name = 'PSWriteHTML'; MinimumVersion = '0.0.180' }
        @{ Name = 'Pester'; MinimumVersion = '5.3.0' }
        @{ Name = 'PSScriptAnalyzer'; MinimumVersion = '1.20.0' }
    )
    
    $totalModules = $modules.Count
    $currentModule = 0
    
    foreach ($module in $modules) {
        $currentModule++
        Write-Progress -Activity "Installing PowerShell Modules" -Status "$($module.Name)" -PercentComplete (($currentModule / $totalModules) * 100)
        
        $installed = Get-Module -Name $module.Name -ListAvailable | 
            Where-Object { $_.Version -ge [version]$module.MinimumVersion }
        
        if (-not $installed) {
            try {
                Install-Module @module -Force -Scope CurrentUser -SkipPublisherCheck -AllowClobber
                Write-SetupLog "Installed $($module.Name) v$($module.MinimumVersion)" -Level Success
                $script:Config.Modules[$module.Name] = $module.MinimumVersion
            } catch {
                Write-SetupLog "Failed to install $($module.Name): $_" -Level Error
            }
        } else {
            Write-SetupLog "$($module.Name) already installed (v$($installed.Version))" -Level Success
            $script:Config.Modules[$module.Name] = $installed.Version.ToString()
        }
    }
    
    Write-Progress -Activity "Installing PowerShell Modules" -Completed
}

function Initialize-AzureEnvironment {
    Write-SetupLog "Initializing Azure environment..."
    
    # Connect to Azure
    try {
        $context = Get-AzContext
        if (-not $context) {
            Write-SetupLog "Please sign in to Azure..."
            Connect-AzAccount
            $context = Get-AzContext
        }
        
        $script:Config.AzureSubscriptionId = $context.Subscription.Id
        $script:Config.TenantId = $context.Tenant.Id
        
        Write-SetupLog "Connected to Azure subscription: $($context.Subscription.Name)" -Level Success
    } catch {
        Write-SetupLog "Failed to connect to Azure: $_" -Level Error
        return $false
    }
    
    # Set up resource names
    $prefix = "cloudscope-$($Environment.ToLower())"
    $script:Config.ResourceGroup = "rg-$prefix"
    $script:Config.AutomationAccount = "$prefix-automation"
    $script:Config.KeyVaultName = "$prefix-kv$(Get-Random -Maximum 999)"
    $script:Config.LogAnalyticsWorkspace = "$prefix-logs"
    $script:Config.AppInsightsName = "$prefix-appinsights"
    $script:Config.StorageAccount = "$($prefix)storage$(Get-Random -Maximum 999)".Replace('-', '')
    
    # Create resource group
    Write-SetupLog "Creating resource group: $($script:Config.ResourceGroup)"
    try {
        $rg = Get-AzResourceGroup -Name $script:Config.ResourceGroup -ErrorAction SilentlyContinue
        if (-not $rg) {
            $location = if ($Interactive) {
                $locations = Get-AzLocation | Where-Object { $_.Providers -contains 'Microsoft.Automation' }
                Write-Host "`nAvailable locations:" -ForegroundColor Yellow
                for ($i = 0; $i -lt $locations.Count; $i++) {
                    Write-Host "$($i + 1). $($locations[$i].DisplayName) ($($locations[$i].Location))"
                }
                $selection = Read-Host "Select location (1-$($locations.Count))"
                $locations[[int]$selection - 1].Location
            } else {
                'eastus'
            }
            
            $rg = New-AzResourceGroup -Name $script:Config.ResourceGroup -Location $location
            Write-SetupLog "Resource group created" -Level Success
        } else {
            Write-SetupLog "Resource group already exists" -Level Success
        }
    } catch {
        Write-SetupLog "Failed to create resource group: $_" -Level Error
        return $false
    }
    
    # Create resources based on environment
    if ($Environment -ne 'Demo') {
        # Create Key Vault
        Write-SetupLog "Creating Key Vault: $($script:Config.KeyVaultName)"
        try {
            $kv = Get-AzKeyVault -VaultName $script:Config.KeyVaultName -ErrorAction SilentlyContinue
            if (-not $kv) {
                $kv = New-AzKeyVault -Name $script:Config.KeyVaultName `
                    -ResourceGroupName $script:Config.ResourceGroup `
                    -Location $rg.Location `
                    -EnabledForDeployment `
                    -EnabledForTemplateDeployment `
                    -EnabledForDiskEncryption
                Write-SetupLog "Key Vault created" -Level Success
            }
        } catch {
            Write-SetupLog "Failed to create Key Vault: $_" -Level Error
        }
        
        # Create Log Analytics Workspace
        Write-SetupLog "Creating Log Analytics Workspace: $($script:Config.LogAnalyticsWorkspace)"
        try {
            $workspace = Get-AzOperationalInsightsWorkspace -ResourceGroupName $script:Config.ResourceGroup `
                -Name $script:Config.LogAnalyticsWorkspace -ErrorAction SilentlyContinue
            if (-not $workspace) {
                $workspace = New-AzOperationalInsightsWorkspace -ResourceGroupName $script:Config.ResourceGroup `
                    -Name $script:Config.LogAnalyticsWorkspace `
                    -Location $rg.Location `
                    -Sku 'PerGB2018'
                Write-SetupLog "Log Analytics Workspace created" -Level Success
            }
        } catch {
            Write-SetupLog "Failed to create Log Analytics Workspace: $_" -Level Error
        }
        
        # Create Application Insights
        Write-SetupLog "Creating Application Insights: $($script:Config.AppInsightsName)"
        try {
            $appInsights = Get-AzApplicationInsights -ResourceGroupName $script:Config.ResourceGroup `
                -Name $script:Config.AppInsightsName -ErrorAction SilentlyContinue
            if (-not $appInsights) {
                $appInsights = New-AzApplicationInsights -ResourceGroupName $script:Config.ResourceGroup `
                    -Name $script:Config.AppInsightsName `
                    -Location $rg.Location `
                    -WorkspaceResourceId $workspace.ResourceId
                Write-SetupLog "Application Insights created" -Level Success
            }
        } catch {
            Write-SetupLog "Failed to create Application Insights: $_" -Level Error
        }
        
        # Create Automation Account
        if ($Environment -eq 'Production') {
            Write-SetupLog "Creating Automation Account: $($script:Config.AutomationAccount)"
            try {
                $automation = Get-AzAutomationAccount -ResourceGroupName $script:Config.ResourceGroup `
                    -Name $script:Config.AutomationAccount -ErrorAction SilentlyContinue
                if (-not $automation) {
                    $automation = New-AzAutomationAccount -ResourceGroupName $script:Config.ResourceGroup `
                        -Name $script:Config.AutomationAccount `
                        -Location $rg.Location `
                        -Plan 'Basic'
                    Write-SetupLog "Automation Account created" -Level Success
                }
            } catch {
                Write-SetupLog "Failed to create Automation Account: $_" -Level Error
            }
        }
    }
    
    return $true
}

function Initialize-GraphEnvironment {
    Write-SetupLog "Initializing Microsoft Graph environment..."
    
    try {
        # Connect to Microsoft Graph
        Write-SetupLog "Connecting to Microsoft Graph..."
        Connect-MgGraph -Scopes @(
            "User.Read.All",
            "Group.Read.All",
            "Directory.Read.All",
            "InformationProtectionPolicy.Read",
            "SecurityEvents.Read.All",
            "AuditLog.Read.All"
        )
        
        $context = Get-MgContext
        Write-SetupLog "Connected to Microsoft Graph for tenant: $($context.TenantId)" -Level Success
        
        # Get compliance officer email
        if ($Interactive) {
            $script:Config.ComplianceOfficerEmail = Read-Host "Enter compliance officer email address"
        }
        
        return $true
    } catch {
        Write-SetupLog "Failed to connect to Microsoft Graph: $_" -Level Error
        return $false
    }
}

function Deploy-CloudScopeModules {
    Write-SetupLog "Deploying CloudScope modules..."
    
    $deployScript = Join-Path $PSScriptRoot 'Scripts' 'Deployment' 'Deploy-CloudScope.ps1'
    
    if (Test-Path $deployScript) {
        try {
            # Deploy locally
            & $deployScript -DeploymentType Local -Force
            Write-SetupLog "CloudScope modules deployed locally" -Level Success
            
            # Deploy to Azure Automation if in Production
            if ($Environment -eq 'Production' -and $script:Config.AutomationAccount) {
                & $deployScript -DeploymentType AzureAutomation `
                    -ResourceGroup $script:Config.ResourceGroup `
                    -AutomationAccount $script:Config.AutomationAccount `
                    -Force
                Write-SetupLog "CloudScope modules deployed to Azure Automation" -Level Success
            }
            
            return $true
        } catch {
            Write-SetupLog "Failed to deploy CloudScope modules: $_" -Level Error
            return $false
        }
    } else {
        Write-SetupLog "Deployment script not found: $deployScript" -Level Error
        return $false
    }
}

function Set-EnvironmentVariables {
    Write-SetupLog "Setting environment variables..."
    
    $envVars = @{
        'CLOUDSCOPE_TENANT_ID' = $script:Config.TenantId
        'CLOUDSCOPE_SUBSCRIPTION_ID' = $script:Config.AzureSubscriptionId
        'CLOUDSCOPE_RESOURCE_GROUP' = $script:Config.ResourceGroup
        'CLOUDSCOPE_KEYVAULT_NAME' = $script:Config.KeyVaultName
        'CLOUDSCOPE_WORKSPACE_NAME' = $script:Config.LogAnalyticsWorkspace
        'CLOUDSCOPE_COMPLIANCE_OFFICER' = $script:Config.ComplianceOfficerEmail
        'CLOUDSCOPE_ENVIRONMENT' = $Environment
    }
    
    foreach ($var in $envVars.GetEnumerator()) {
        if ($var.Value) {
            [System.Environment]::SetEnvironmentVariable($var.Key, $var.Value, 'User')
            Write-SetupLog "Set $($var.Key)" -Level Success
        }
    }
}

function Save-Configuration {
    Write-SetupLog "Saving configuration..."
    
    try {
        $script:Config | ConvertTo-Json -Depth 10 | Out-File -FilePath $ConfigPath -Encoding UTF8
        Write-SetupLog "Configuration saved to: $ConfigPath" -Level Success
    } catch {
        Write-SetupLog "Failed to save configuration: $_" -Level Error
    }
}

function Test-CloudScopeSetup {
    Write-SetupLog "`nTesting CloudScope setup..."
    
    $tests = @(
        @{
            Name = "CloudScope.Compliance Module"
            Test = { Get-Module -Name CloudScope.Compliance -ListAvailable }
        },
        @{
            Name = "CloudScope.Graph Module"
            Test = { Get-Module -Name CloudScope.Graph -ListAvailable }
        },
        @{
            Name = "CloudScope.Monitoring Module"
            Test = { Get-Module -Name CloudScope.Monitoring -ListAvailable }
        },
        @{
            Name = "CloudScope.Reports Module"
            Test = { Get-Module -Name CloudScope.Reports -ListAvailable }
        },
        @{
            Name = "Azure Connection"
            Test = { Get-AzContext }
        },
        @{
            Name = "Microsoft Graph Connection"
            Test = { Get-MgContext }
        }
    )
    
    $passed = 0
    $failed = 0
    
    foreach ($test in $tests) {
        try {
            $result = & $test.Test
            if ($result) {
                Write-SetupLog "$($test.Name): Passed" -Level Success
                $passed++
            } else {
                Write-SetupLog "$($test.Name): Failed" -Level Error
                $failed++
            }
        } catch {
            Write-SetupLog "$($test.Name): Failed - $_" -Level Error
            $failed++
        }
    }
    
    Write-SetupLog "`nSetup test results: $passed passed, $failed failed" -Level $(if ($failed -eq 0) { 'Success' } else { 'Warning' })
    
    return $failed -eq 0
}

function Show-NextSteps {
    Write-Host "`n" + "=" * 50 -ForegroundColor Cyan
    Write-Host "CloudScope Setup Complete!" -ForegroundColor Green
    Write-Host "=" * 50 -ForegroundColor Cyan
    
    Write-Host "`n📋 Configuration Summary:" -ForegroundColor Yellow
    Write-Host "  Environment: $Environment"
    Write-Host "  Tenant ID: $($script:Config.TenantId)"
    Write-Host "  Resource Group: $($script:Config.ResourceGroup)"
    
    if ($script:Config.KeyVaultName) {
        Write-Host "  Key Vault: $($script:Config.KeyVaultName)"
    }
    if ($script:Config.LogAnalyticsWorkspace) {
        Write-Host "  Log Analytics: $($script:Config.LogAnalyticsWorkspace)"
    }
    
    Write-Host "`n🚀 Next Steps:" -ForegroundColor Yellow
    Write-Host "  1. Import CloudScope modules:"
    Write-Host "     Import-Module CloudScope.Compliance" -ForegroundColor Cyan
    Write-Host "     Import-Module CloudScope.Graph" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  2. Initialize compliance framework:"
    Write-Host "     Initialize-CloudScopeCompliance -Framework GDPR" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  3. Run your first compliance assessment:"
    Write-Host "     Invoke-ComplianceAssessment -Framework GDPR" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  4. View example scripts:"
    Write-Host "     Get-ChildItem .\\Scripts\\Examples" -ForegroundColor Cyan
    
    Write-Host "`n📚 Documentation:" -ForegroundColor Yellow
    Write-Host "  README: .\\README.md"
    Write-Host "  Examples: .\\Scripts\\Examples"
    Write-Host "  DSC Configs: .\\Scripts\\Configuration"
    
    Write-Host "`n✨ Happy Compliance Monitoring! ✨" -ForegroundColor Green
}

#endregion

# Main setup process

try {
    # Check if running as administrator (Windows only)
    if ($IsWindows -ne $false -and -not (Test-Administrator)) {
        Write-SetupLog "This script should be run as Administrator for best results" -Level Warning
        if ($Interactive) {
            $continue = Read-Host "Continue anyway? (Y/N)"
            if ($continue -ne 'Y') {
                exit 1
            }
        }
    }
    
    # Check PowerShell version
    if (-not (Test-PowerShellVersion)) {
        Write-SetupLog "PowerShell version requirement not met" -Level Error
        exit 1
    }
    
    # Install required modules
    if (-not $SkipModuleInstall) {
        Install-RequiredModules
    }
    
    # Initialize Azure environment
    if (-not $SkipAzureSetup) {
        if (-not (Initialize-AzureEnvironment)) {
            Write-SetupLog "Azure setup failed" -Level Error
            exit 1
        }
    }
    
    # Initialize Microsoft Graph
    if (-not (Initialize-GraphEnvironment)) {
        Write-SetupLog "Microsoft Graph setup failed" -Level Error
        exit 1
    }
    
    # Deploy CloudScope modules
    if (-not (Deploy-CloudScopeModules)) {
        Write-SetupLog "Module deployment failed" -Level Error
        exit 1
    }
    
    # Set environment variables
    Set-EnvironmentVariables
    
    # Save configuration
    Save-Configuration
    
    # Test setup
    $testResult = Test-CloudScopeSetup
    
    # Show next steps
    Show-NextSteps
    
    # Save setup log
    $logPath = Join-Path $PSScriptRoot "CloudScope-Setup-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
    $script:SetupLog | Out-File -FilePath $logPath -Encoding UTF8
    Write-Host "`n📄 Setup log saved to: $logPath" -ForegroundColor Gray
    
    exit 0
    
} catch {
    Write-SetupLog "Setup failed with error: $_" -Level Error
    exit 1
}
