#!/usr/bin/env pwsh
<#
.SYNOPSIS
    CloudScope PowerShell Collector Manager
    
.DESCRIPTION
    Manages PowerShell-based collectors for CloudScope, including module installation,
    authentication, and collector execution.
    
.PARAMETER Action
    Action to perform: Install, Configure, Run, Test, List
    
.PARAMETER Collector
    Specific collector to manage (e.g., Microsoft365, Azure, Exchange)
    
.PARAMETER ConfigFile
    Path to CloudScope configuration file
    
.EXAMPLE
    ./Manage-Collectors.ps1 -Action Install
    ./Manage-Collectors.ps1 -Action Run -Collector Microsoft365
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Install', 'Configure', 'Run', 'Test', 'List', 'Update')]
    [string]$Action,
    
    [Parameter()]
    [string]$Collector,
    
    [Parameter()]
    [string]$ConfigFile = "../../config/cloudscope-config.json",
    
    [Parameter()]
    [switch]$Force
)

# Set strict mode
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Script configuration
$script:RequiredPSVersion = [Version]"7.0.0"
$script:CollectorPath = Join-Path $PSScriptRoot "../../collectors/powershell"
$script:LogPath = Join-Path $PSScriptRoot "../../data/logs"

# Logging functions
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Warning', 'Error', 'Success')]
        [string]$Level = 'Info'
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    switch ($Level) {
        'Error' { Write-Host $logMessage -ForegroundColor Red }
        'Warning' { Write-Host $logMessage -ForegroundColor Yellow }
        'Success' { Write-Host $logMessage -ForegroundColor Green }
        default { Write-Host $logMessage -ForegroundColor Cyan }
    }
    
    # Also write to log file
    $logFile = Join-Path $script:LogPath "powershell-manager.log"
    $logMessage | Out-File -FilePath $logFile -Append -Encoding UTF8
}

# Check PowerShell version
function Test-PSVersion {
    Write-Log "Checking PowerShell version..."
    
    if ($PSVersionTable.PSVersion -lt $script:RequiredPSVersion) {
        throw "PowerShell $($script:RequiredPSVersion) or higher is required. Current version: $($PSVersionTable.PSVersion)"
    }
    
    Write-Log "PowerShell version check passed: $($PSVersionTable.PSVersion)" -Level Success
}

# Required modules configuration
$script:RequiredModules = @(
    @{
        Name = 'Microsoft.Graph'
        MinVersion = '2.0.0'
        Purpose = 'Microsoft 365 and Azure AD management'
    },
    @{
        Name = 'Microsoft.Graph.Beta'
        MinVersion = '2.0.0'
        Purpose = 'Microsoft Graph Beta APIs'
    },
    @{
        Name = 'Az'
        MinVersion = '11.0.0'
        Purpose = 'Azure Resource Management'
    },
    @{
        Name = 'ExchangeOnlineManagement'
        MinVersion = '3.0.0'
        Purpose = 'Exchange Online management'
    },
    @{
        Name = 'MicrosoftTeams'
        MinVersion = '5.0.0'
        Purpose = 'Microsoft Teams management'
    },
    @{
        Name = 'SharePointPnPPowerShellOnline'
        MinVersion = '1.12.0'
        Purpose = 'SharePoint Online management'
    }
)

# Install required modules
function Install-RequiredModules {
    Write-Log "Installing required PowerShell modules..."
    
    # Set PSGallery as trusted
    if ((Get-PSRepository -Name PSGallery).InstallationPolicy -ne 'Trusted') {
        Write-Log "Setting PSGallery as trusted repository..."
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    }
    
    foreach ($module in $script:RequiredModules) {
        Write-Log "Checking module: $($module.Name)"
        
        $installed = Get-Module -ListAvailable -Name $module.Name | 
                     Where-Object { $_.Version -ge [Version]$module.MinVersion }
        
        if (-not $installed -or $Force) {
            Write-Log "Installing $($module.Name) (Purpose: $($module.Purpose))..."
            
            try {
                Install-Module -Name $module.Name `
                               -MinimumVersion $module.MinVersion `
                               -Force:$Force `
                               -AllowClobber `
                               -Scope CurrentUser `
                               -Repository PSGallery
                
                Write-Log "Successfully installed $($module.Name)" -Level Success
            }
            catch {
                Write-Log "Failed to install $($module.Name): $_" -Level Error
                throw
            }
        }
        else {
            Write-Log "$($module.Name) version $($installed.Version) is already installed" -Level Success
        }
    }
    
    Write-Log "All required modules installed successfully" -Level Success
}

# Update modules
function Update-RequiredModules {
    Write-Log "Updating PowerShell modules..."
    
    foreach ($module in $script:RequiredModules) {
        Write-Log "Updating $($module.Name)..."
        
        try {
            Update-Module -Name $module.Name -Force -ErrorAction Stop
            Write-Log "Successfully updated $($module.Name)" -Level Success
        }
        catch {
            Write-Log "Failed to update $($module.Name): $_" -Level Warning
        }
    }
}

# Configure authentication
function Set-CollectorAuthentication {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CollectorType
    )
    
    Write-Log "Configuring authentication for $CollectorType..."
    
    switch ($CollectorType) {
        'Microsoft365' {
            Write-Log "Configuring Microsoft Graph authentication..."
            
            # Check for app registration details
            $appId = Read-Host "Enter Azure AD App ID (Client ID)"
            $tenantId = Read-Host "Enter Tenant ID"
            $certPath = Read-Host "Enter path to certificate (.pfx) or press Enter for interactive auth"
            
            if ($certPath -and (Test-Path $certPath)) {
                # Certificate-based auth
                $cert = Get-PfxCertificate -FilePath $certPath
                
                # Save to secure credential store
                $credPath = Join-Path $PSScriptRoot "../../config/credentials"
                New-Item -ItemType Directory -Force -Path $credPath | Out-Null
                
                @{
                    AppId = $appId
                    TenantId = $tenantId
                    CertificateThumbprint = $cert.Thumbprint
                } | ConvertTo-Json | Out-File (Join-Path $credPath "microsoft365.json") -Encoding UTF8
                
                Write-Log "Certificate authentication configured" -Level Success
            }
            else {
                # Interactive auth
                Write-Log "Interactive authentication will be used" -Level Warning
                
                @{
                    AppId = $appId
                    TenantId = $tenantId
                    AuthType = "Interactive"
                } | ConvertTo-Json | Out-File (Join-Path $PSScriptRoot "../../config/credentials/microsoft365.json") -Encoding UTF8
            }
        }
        
        'Azure' {
            Write-Log "Configuring Azure authentication..."
            
            # Use Azure CLI or Service Principal
            $authMethod = Read-Host "Authentication method (CLI/ServicePrincipal)"
            
            if ($authMethod -eq 'ServicePrincipal') {
                $appId = Read-Host "Enter Service Principal App ID"
                $secret = Read-Host "Enter Service Principal Secret" -AsSecureString
                $tenantId = Read-Host "Enter Tenant ID"
                
                # Save encrypted credentials
                $credPath = Join-Path $PSScriptRoot "../../config/credentials"
                New-Item -ItemType Directory -Force -Path $credPath | Out-Null
                
                @{
                    AppId = $appId
                    TenantId = $tenantId
                    SecretEncrypted = ConvertFrom-SecureString $secret
                } | ConvertTo-Json | Out-File (Join-Path $credPath "azure.json") -Encoding UTF8
                
                Write-Log "Service Principal authentication configured" -Level Success
            }
            else {
                Write-Log "Azure CLI authentication will be used" -Level Success
            }
        }
        
        default {
            Write-Log "No specific authentication required for $CollectorType" -Level Warning
        }
    }
}

# List available collectors
function Get-AvailableCollectors {
    Write-Log "Listing available collectors..."
    
    $collectors = @()
    
    # Find all PowerShell collectors
    Get-ChildItem -Path $script:CollectorPath -Directory | ForEach-Object {
        $collectorScript = Get-ChildItem -Path $_.FullName -Filter "*.ps1" | Select-Object -First 1
        
        if ($collectorScript) {
            $info = @{
                Name = $_.Name
                Path = $collectorScript.FullName
                LastModified = $collectorScript.LastWriteTime
            }
            
            # Try to get description from script
            $helpContent = Get-Help $collectorScript.FullName -ErrorAction SilentlyContinue
            if ($helpContent) {
                $info.Description = $helpContent.Synopsis
            }
            
            $collectors += [PSCustomObject]$info
        }
    }
    
    # Display collectors
    if ($collectors.Count -gt 0) {
        Write-Host "`nAvailable Collectors:" -ForegroundColor Green
        $collectors | Format-Table -AutoSize -Property Name, Description, LastModified
    }
    else {
        Write-Log "No collectors found in $script:CollectorPath" -Level Warning
    }
    
    return $collectors
}

# Run collector
function Invoke-Collector {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CollectorName,
        
        [Parameter()]
        [hashtable]$Parameters = @{}
    )
    
    Write-Log "Running collector: $CollectorName"
    
    # Find collector script
    $collectorPath = Join-Path $script:CollectorPath $CollectorName
    $collectorScript = Get-ChildItem -Path $collectorPath -Filter "*.ps1" | Select-Object -First 1
    
    if (-not $collectorScript) {
        throw "Collector script not found for: $CollectorName"
    }
    
    # Add default parameters
    if (-not $Parameters.ContainsKey('OutputFormat')) {
        $Parameters['OutputFormat'] = 'Database'
    }
    if (-not $Parameters.ContainsKey('ConfigFile')) {
        $Parameters['ConfigFile'] = $ConfigFile
    }
    
    # Create log file for collector
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $logFile = Join-Path $script:LogPath "${CollectorName}_${timestamp}.log"
    $Parameters['LogFile'] = $logFile
    
    Write-Log "Executing: $($collectorScript.FullName)"
    Write-Log "Parameters: $($Parameters | ConvertTo-Json -Compress)"
    
    try {
        # Execute collector
        & $collectorScript.FullName @Parameters
        
        Write-Log "Collector $CollectorName completed successfully" -Level Success
    }
    catch {
        Write-Log "Collector $CollectorName failed: $_" -Level Error
        throw
    }
}

# Test collector
function Test-Collector {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CollectorName
    )
    
    Write-Log "Testing collector: $CollectorName"
    
    # Find collector script
    $collectorPath = Join-Path $script:CollectorPath $CollectorName
    $collectorScript = Get-ChildItem -Path $collectorPath -Filter "*.ps1" | Select-Object -First 1
    
    if (-not $collectorScript) {
        throw "Collector script not found for: $CollectorName"
    }
    
    # Test script syntax
    Write-Log "Testing script syntax..."
    $errors = @()
    $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $collectorScript.FullName -Raw), [ref]$errors)
    
    if ($errors.Count -gt 0) {
        Write-Log "Syntax errors found:" -Level Error
        $errors | ForEach-Object { Write-Log "  Line $($_.Token.StartLine): $_" -Level Error }
        throw "Script has syntax errors"
    }
    
    Write-Log "Syntax check passed" -Level Success
    
    # Check required modules
    Write-Log "Checking required modules..."
    $scriptContent = Get-Content $collectorScript.FullName -Raw
    
    $requiredModules = @()
    if ($scriptContent -match 'Import-Module\s+([^\s]+)') {
        $requiredModules = $Matches[1]
    }
    
    foreach ($module in $requiredModules) {
        if (Get-Module -ListAvailable -Name $module) {
            Write-Log "  Module available: $module" -Level Success
        }
        else {
            Write-Log "  Module missing: $module" -Level Error
        }
    }
    
    # Test with dry run if supported
    Write-Log "Attempting dry run..."
    try {
        & $collectorScript.FullName -WhatIf -ErrorAction Stop
        Write-Log "Dry run completed successfully" -Level Success
    }
    catch {
        Write-Log "Dry run not supported or failed: $_" -Level Warning
    }
    
    Write-Log "Collector test completed" -Level Success
}

# Load configuration
function Get-CloudScopeConfig {
    if (Test-Path $ConfigFile) {
        Write-Log "Loading configuration from: $ConfigFile"
        return Get-Content $ConfigFile | ConvertFrom-Json
    }
    else {
        Write-Log "Configuration file not found: $ConfigFile" -Level Warning
        return @{}
    }
}

# Main execution
try {
    # Ensure log directory exists
    New-Item -ItemType Directory -Force -Path $script:LogPath | Out-Null
    
    Write-Log "CloudScope PowerShell Collector Manager started"
    Write-Log "Action: $Action, Collector: $($Collector ?? 'All')"
    
    # Check PowerShell version
    Test-PSVersion
    
    # Execute action
    switch ($Action) {
        'Install' {
            Install-RequiredModules
        }
        
        'Update' {
            Update-RequiredModules
        }
        
        'Configure' {
            if ($Collector) {
                Set-CollectorAuthentication -CollectorType $Collector
            }
            else {
                Write-Log "Please specify a collector to configure with -Collector parameter" -Level Error
                exit 1
            }
        }
        
        'List' {
            Get-AvailableCollectors
        }
        
        'Run' {
            if ($Collector) {
                Invoke-Collector -CollectorName $Collector
            }
            else {
                # Run all collectors
                $collectors = Get-AvailableCollectors
                foreach ($col in $collectors) {
                    try {
                        Invoke-Collector -CollectorName $col.Name
                    }
                    catch {
                        Write-Log "Failed to run collector $($col.Name): $_" -Level Error
                        # Continue with other collectors
                    }
                }
            }
        }
        
        'Test' {
            if ($Collector) {
                Test-Collector -CollectorName $Collector
            }
            else {
                Write-Log "Please specify a collector to test with -Collector parameter" -Level Error
                exit 1
            }
        }
    }
    
    Write-Log "CloudScope PowerShell Collector Manager completed successfully" -Level Success
}
catch {
    Write-Log "Fatal error: $_" -Level Error
    exit 1
}
