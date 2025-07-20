<#
.SYNOPSIS
    CloudScope PowerShell Setup Script
    
.DESCRIPTION
    Sets up CloudScope PowerShell modules without Docker dependencies.
    Installs required modules, configures environment, and performs initial setup.
    
.PARAMETER Environment
    Target environment: Development, Production, or Demo
    
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
    [string]$Environment = 'Development',
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipModuleInstall,
    
    [Parameter(Mandatory = $false)]
    [string]$ConfigPath = (Join-Path $HOME '.cloudscope' 'config.json'),
    
    [Parameter(Mandatory = $false)]
    [switch]$Interactive = $true
)

# Script variables
$script:SetupLog = @()
$script:Config = @{
    Environment = $Environment
    TenantId = $null
    SubscriptionId = $null
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
        @{ Name = 'Az.KeyVault'; MinimumVersion = '4.0.0' }
        @{ Name = 'Az.Monitor'; MinimumVersion = '4.0.0' }
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

function Initialize-MicrosoftGraphEnvironment {
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
        
        $script:Config.TenantId = $context.TenantId
        
        return $true
    } catch {
        Write-SetupLog "Failed to connect to Microsoft Graph: $_" -Level Error
        return $false
    }
}

function Initialize-AzureEnvironment {
    Write-SetupLog "Initializing Azure environment..."
    
    try {
        # Connect to Azure
        $context = Get-AzContext
        if (-not $context) {
            Write-SetupLog "Please sign in to Azure..."
            Connect-AzAccount
            $context = Get-AzContext
        }
        
        $script:Config.SubscriptionId = $context.Subscription.Id
        
        Write-SetupLog "Connected to Azure subscription: $($context.Subscription.Name)" -Level Success
        return $true
    } catch {
        Write-SetupLog "Failed to connect to Azure: $_" -Level Warning
        return $true  # Non-fatal error
    }
}

function Deploy-CloudScopeModules {
    Write-SetupLog "Deploying CloudScope modules..."
    
    try {
        # Create module directory if it doesn't exist
        $modulesDir = if ($IsWindows) {
            Join-Path $env:USERPROFILE "Documents\PowerShell\Modules"
        } else {
            Join-Path $HOME ".local/share/powershell/Modules"
        }
        
        if (-not (Test-Path -Path $modulesDir)) {
            New-Item -Path $modulesDir -ItemType Directory -Force | Out-Null
        }
        
        # Copy modules
        $sourceDir = Join-Path $PSScriptRoot "CloudScope"
        $modules = @("Core", "Compliance", "Graph", "Monitoring", "Reports", "FinOps", "Visualization")
        
        foreach ($module in $modules) {
            $moduleName = "CloudScope.$module"
            $source = Join-Path $sourceDir $module
            $destination = Join-Path $modulesDir $moduleName
            
            if (Test-Path -Path $source) {
                if (Test-Path -Path $destination) {
                    Remove-Item -Path $destination -Recurse -Force
                }
                
                Copy-Item -Path $source -Destination $destination -Recurse -Force
                Write-SetupLog "Deployed $moduleName module" -Level Success
            } else {
                Write-SetupLog "Module source not found: $source" -Level Warning
            }
        }
        
        return $true
    } catch {
        Write-SetupLog "Failed to deploy CloudScope modules: $_" -Level Error
        return $false
    }
}

function Set-EnvironmentVariables {
    Write-SetupLog "Setting environment variables..."
    
    $envVars = @{
        'CLOUDSCOPE_TENANT_ID' = $script:Config.TenantId
        'CLOUDSCOPE_SUBSCRIPTION_ID' = $script:Config.SubscriptionId
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
        # Create config directory if it doesn't exist
        $configDir = Split-Path -Parent $ConfigPath
        if (-not (Test-Path -Path $configDir)) {
            New-Item -Path $configDir -ItemType Directory -Force | Out-Null
        }
        
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
            Name = "CloudScope.Core Module"
            Test = { Get-Module -Name CloudScope.Core -ListAvailable }
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
    
    Write-Host "`n🚀 Next Steps:" -ForegroundColor Yellow
    Write-Host "  1. Import CloudScope modules:"
    Write-Host "     Import-Module CloudScope.Core" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  2. Initialize CloudScope:"
    Write-Host "     Initialize-CloudScope" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  3. Connect to Microsoft services:"
    Write-Host "     Connect-CloudScopeServices" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  4. Run your first compliance assessment:"
    Write-Host "     Invoke-ComplianceAssessment -Framework GDPR" -ForegroundColor Cyan
    
    Write-Host "`n📚 Documentation:" -ForegroundColor Yellow
    Write-Host "  README: .\\README.md"
    Write-Host "  Examples: .\\Examples"
    
    Write-Host "`n✨ Happy Compliance Monitoring! ✨" -ForegroundColor Green
}

#endregion

# Main setup process

try {
    # Check PowerShell version
    if (-not (Test-PowerShellVersion)) {
        Write-SetupLog "PowerShell version requirement not met" -Level Error
        exit 1
    }
    
    # Install required modules
    if (-not $SkipModuleInstall) {
        Install-RequiredModules
    }
    
    # Initialize Microsoft Graph
    if (-not (Initialize-MicrosoftGraphEnvironment)) {
        Write-SetupLog "Microsoft Graph setup failed" -Level Error
        exit 1
    }
    
    # Initialize Azure (optional)
    Initialize-AzureEnvironment
    
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