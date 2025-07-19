<#
.SYNOPSIS
    CloudScope PowerShell Deployment Script
    
.DESCRIPTION
    Deploys CloudScope compliance modules to local machine, Azure Automation,
    or PowerShell Gallery.
    
.PARAMETER DeploymentType
    Type of deployment: Local, AzureAutomation, PSGallery, All
    
.PARAMETER ResourceGroup
    Azure resource group for Azure Automation deployment
    
.PARAMETER AutomationAccount
    Azure Automation account name
    
.PARAMETER PSGalleryApiKey
    API key for PowerShell Gallery publishing
    
.EXAMPLE
    .\Deploy-CloudScope.ps1 -DeploymentType Local
    
.EXAMPLE
    .\Deploy-CloudScope.ps1 -DeploymentType AzureAutomation -ResourceGroup "rg-compliance" -AutomationAccount "CloudScope-Automation"
    
.NOTES
    File: Deploy-CloudScope.ps1
    Author: CloudScope Team
    Version: 1.0.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Local', 'AzureAutomation', 'PSGallery', 'All')]
    [string]$DeploymentType,
    
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroup,
    
    [Parameter(Mandatory = $false)]
    [string]$AutomationAccount,
    
    [Parameter(Mandatory = $false)]
    [string]$PSGalleryApiKey,
    
    [Parameter(Mandatory = $false)]
    [string]$ModulePath = (Join-Path $PSScriptRoot '..' '..' 'Modules'),
    
    [Parameter(Mandatory = $false)]
    [string]$ScriptsPath = (Join-Path $PSScriptRoot '..'),
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipDependencyCheck,
    
    [Parameter(Mandatory = $false)]
    [switch]$Force
)

# Script variables
$script:DeploymentLog = @()
$script:ErrorCount = 0
$script:SuccessCount = 0

# Required modules for deployment
$RequiredModules = @(
    @{ Name = 'Az.Accounts'; MinimumVersion = '2.10.0' }
    @{ Name = 'Az.Automation'; MinimumVersion = '1.7.0' }
    @{ Name = 'Az.Resources'; MinimumVersion = '5.0.0' }
    @{ Name = 'PowerShellGet'; MinimumVersion = '2.2.5' }
)

# CloudScope modules
$CloudScopeModules = @(
    'CloudScope.Compliance',
    'CloudScope.Graph',
    'CloudScope.Monitoring',
    'CloudScope.Reports'
)

#region Helper Functions

function Write-DeploymentLog {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Success', 'Warning', 'Error')]
        [string]$Level = 'Info'
    )
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logEntry = "$timestamp [$Level] $Message"
    $script:DeploymentLog += $logEntry
    
    switch ($Level) {
        'Success' {
            Write-Host $Message -ForegroundColor Green
            $script:SuccessCount++
        }
        'Warning' {
            Write-Warning $Message
        }
        'Error' {
            Write-Error $Message
            $script:ErrorCount++
        }
        default {
            Write-Host $Message -ForegroundColor Cyan
        }
    }
}

function Test-Prerequisites {
    Write-DeploymentLog "Checking prerequisites..."
    
    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        Write-DeploymentLog "PowerShell 7.0 or later is required. Current version: $($PSVersionTable.PSVersion)" -Level Error
        return $false
    }
    
    # Check required modules
    if (-not $SkipDependencyCheck) {
        foreach ($module in $RequiredModules) {
            Write-DeploymentLog "Checking module: $($module.Name)"
            
            $installed = Get-Module -Name $module.Name -ListAvailable | 
                Where-Object { $_.Version -ge [version]$module.MinimumVersion }
            
            if (-not $installed) {
                Write-DeploymentLog "Installing $($module.Name) v$($module.MinimumVersion)..." -Level Warning
                try {
                    Install-Module @module -Force -Scope CurrentUser -SkipPublisherCheck
                    Write-DeploymentLog "$($module.Name) installed successfully" -Level Success
                } catch {
                    Write-DeploymentLog "Failed to install $($module.Name): $_" -Level Error
                    return $false
                }
            }
        }
    }
    
    # Verify CloudScope modules exist
    foreach ($moduleName in $CloudScopeModules) {
        $modulePath = Join-Path $ModulePath $moduleName
        if (-not (Test-Path $modulePath)) {
            Write-DeploymentLog "CloudScope module not found: $modulePath" -Level Error
            return $false
        }
    }
    
    return $true
}

function Deploy-ToLocal {
    Write-DeploymentLog "`nDeploying CloudScope modules locally..."
    
    # Determine installation path
    $installPath = if ($IsWindows -or $PSVersionTable.PSVersion.Major -lt 6) {
        Join-Path $env:ProgramFiles 'WindowsPowerShell\Modules'
    } else {
        Join-Path $HOME '.local/share/powershell/Modules'
    }
    
    # Create installation directory if needed
    if (-not (Test-Path $installPath)) {
        New-Item -ItemType Directory -Path $installPath -Force | Out-Null
    }
    
    # Deploy each module
    foreach ($moduleName in $CloudScopeModules) {
        Write-DeploymentLog "Installing $moduleName..."
        
        $sourcePath = Join-Path $ModulePath $moduleName
        $destPath = Join-Path $installPath $moduleName
        
        try {
            # Remove existing version if Force is specified
            if ($Force -and (Test-Path $destPath)) {
                Remove-Item $destPath -Recurse -Force
            }
            
            # Copy module
            Copy-Item -Path $sourcePath -Destination $destPath -Recurse -Force
            
            # Import module to verify
            Import-Module $destPath -Force
            
            Write-DeploymentLog "$moduleName installed successfully to $destPath" -Level Success
        } catch {
            Write-DeploymentLog "Failed to install $moduleName`: $_" -Level Error
        }
    }
    
    # Deploy DSC configurations
    Write-DeploymentLog "Deploying DSC configurations..."
    
    $dscPath = Join-Path $env:ProgramFiles 'WindowsPowerShell\DscService\Configuration'
    if (-not (Test-Path $dscPath)) {
        New-Item -ItemType Directory -Path $dscPath -Force | Out-Null
    }
    
    $configPath = Join-Path $ScriptsPath 'Configuration'
    $configs = Get-ChildItem -Path $configPath -Filter '*.ps1'
    
    foreach ($config in $configs) {
        try {
            Copy-Item -Path $config.FullName -Destination $dscPath -Force
            Write-DeploymentLog "Deployed DSC configuration: $($config.Name)" -Level Success
        } catch {
            Write-DeploymentLog "Failed to deploy DSC configuration $($config.Name): $_" -Level Error
        }
    }
}

function Deploy-ToAzureAutomation {
    param(
        [string]$ResourceGroup,
        [string]$AutomationAccount
    )
    
    Write-DeploymentLog "`nDeploying CloudScope modules to Azure Automation..."
    
    # Connect to Azure
    try {
        $context = Get-AzContext
        if (-not $context) {
            Write-DeploymentLog "Connecting to Azure..."
            Connect-AzAccount
        }
        Write-DeploymentLog "Connected to Azure subscription: $($context.Subscription.Name)"
    } catch {
        Write-DeploymentLog "Failed to connect to Azure: $_" -Level Error
        return
    }
    
    # Verify automation account exists
    try {
        $automation = Get-AzAutomationAccount -ResourceGroupName $ResourceGroup -Name $AutomationAccount -ErrorAction Stop
        Write-DeploymentLog "Found automation account: $($automation.AutomationAccountName)"
    } catch {
        Write-DeploymentLog "Automation account not found: $AutomationAccount" -Level Error
        return
    }
    
    # Deploy modules
    foreach ($moduleName in $CloudScopeModules) {
        Write-DeploymentLog "Deploying $moduleName to Azure Automation..."
        
        $modulePath = Join-Path $ModulePath $moduleName
        $zipPath = "$env:TEMP\$moduleName.zip"
        
        try {
            # Create module package
            Compress-Archive -Path "$modulePath\*" -DestinationPath $zipPath -Force
            
            # Upload to storage account
            $storageAccount = Get-AzStorageAccount -ResourceGroupName $ResourceGroup | Select-Object -First 1
            if (-not $storageAccount) {
                Write-DeploymentLog "No storage account found in resource group" -Level Warning
                # Create temporary storage account
                $storageAccountName = "cloudscope$(Get-Random -Maximum 9999)"
                $storageAccount = New-AzStorageAccount -ResourceGroupName $ResourceGroup `
                    -Name $storageAccountName `
                    -Location 'eastus' `
                    -SkuName 'Standard_LRS'
            }
            
            $container = Get-AzStorageContainer -Name 'modules' -Context $storageAccount.Context -ErrorAction SilentlyContinue
            if (-not $container) {
                $container = New-AzStorageContainer -Name 'modules' -Context $storageAccount.Context -Permission Blob
            }
            
            # Upload module
            $blob = Set-AzStorageBlobContent -File $zipPath `
                -Container 'modules' `
                -Blob "$moduleName.zip" `
                -Context $storageAccount.Context `
                -Force
            
            # Import module to automation account
            $module = New-AzAutomationModule -ResourceGroupName $ResourceGroup `
                -AutomationAccountName $AutomationAccount `
                -Name $moduleName `
                -ContentLinkUri $blob.ICloudBlob.Uri.AbsoluteUri
            
            Write-DeploymentLog "$moduleName deployed successfully" -Level Success
            
            # Wait for import to complete
            $maxWait = 300 # 5 minutes
            $waited = 0
            while ($waited -lt $maxWait) {
                $moduleStatus = Get-AzAutomationModule -ResourceGroupName $ResourceGroup `
                    -AutomationAccountName $AutomationAccount `
                    -Name $moduleName
                
                if ($moduleStatus.ProvisioningState -eq 'Succeeded') {
                    break
                } elseif ($moduleStatus.ProvisioningState -eq 'Failed') {
                    Write-DeploymentLog "Module import failed: $moduleName" -Level Error
                    break
                }
                
                Start-Sleep -Seconds 10
                $waited += 10
            }
            
        } catch {
            Write-DeploymentLog "Failed to deploy $moduleName`: $_" -Level Error
        } finally {
            if (Test-Path $zipPath) {
                Remove-Item $zipPath -Force
            }
        }
    }
    
    # Deploy runbooks
    Write-DeploymentLog "Deploying runbooks..."
    
    $runbookPath = Join-Path $ScriptsPath 'Automation'
    $runbooks = Get-ChildItem -Path $runbookPath -Filter '*.ps1'
    
    foreach ($runbook in $runbooks) {
        try {
            $runbookName = [System.IO.Path]::GetFileNameWithoutExtension($runbook.Name)
            
            Import-AzAutomationRunbook -ResourceGroupName $ResourceGroup `
                -AutomationAccountName $AutomationAccount `
                -Path $runbook.FullName `
                -Name $runbookName `
                -Type PowerShell `
                -Force
            
            Publish-AzAutomationRunbook -ResourceGroupName $ResourceGroup `
                -AutomationAccountName $AutomationAccount `
                -Name $runbookName
            
            Write-DeploymentLog "Deployed runbook: $runbookName" -Level Success
        } catch {
            Write-DeploymentLog "Failed to deploy runbook $($runbook.Name): $_" -Level Error
        }
    }
}

function Deploy-ToPSGallery {
    param(
        [string]$ApiKey
    )
    
    Write-DeploymentLog "`nDeploying CloudScope modules to PowerShell Gallery..."
    
    if (-not $ApiKey) {
        Write-DeploymentLog "PowerShell Gallery API key is required" -Level Error
        return
    }
    
    # Set up NuGet provider
    if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
        Install-PackageProvider -Name NuGet -Force -Scope CurrentUser
    }
    
    # Register PSGallery if needed
    if (-not (Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue)) {
        Register-PSRepository -Default
    }
    
    # Deploy each module
    foreach ($moduleName in $CloudScopeModules) {
        Write-DeploymentLog "Publishing $moduleName to PowerShell Gallery..."
        
        $modulePath = Join-Path $ModulePath $moduleName
        
        try {
            # Test module manifest
            $manifestPath = Join-Path $modulePath "$moduleName.psd1"
            $manifest = Test-ModuleManifest -Path $manifestPath -ErrorAction Stop
            
            # Check if module already exists
            $existing = Find-Module -Name $moduleName -ErrorAction SilentlyContinue
            if ($existing -and $existing.Version -ge $manifest.Version) {
                if (-not $Force) {
                    Write-DeploymentLog "Module $moduleName v$($existing.Version) already exists. Use -Force to overwrite." -Level Warning
                    continue
                }
            }
            
            # Publish module
            Publish-Module -Path $modulePath `
                -NuGetApiKey $ApiKey `
                -Repository PSGallery `
                -Force:$Force
            
            Write-DeploymentLog "$moduleName v$($manifest.Version) published successfully" -Level Success
            
        } catch {
            Write-DeploymentLog "Failed to publish $moduleName`: $_" -Level Error
        }
    }
}

function New-DeploymentReport {
    $reportPath = Join-Path $PSScriptRoot "CloudScope-Deployment-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
    
    $report = @"
CloudScope PowerShell Deployment Report
=======================================
Deployment Date: $(Get-Date)
Deployment Type: $DeploymentType
Success Count: $script:SuccessCount
Error Count: $script:ErrorCount

Deployment Log:
--------------
$($script:DeploymentLog -join "`n")

Deployed Modules:
----------------
$($CloudScopeModules -join "`n")

"@
    
    if ($DeploymentType -eq 'AzureAutomation') {
        $report += @"
Azure Automation Details:
------------------------
Resource Group: $ResourceGroup
Automation Account: $AutomationAccount

"@
    }
    
    $report | Out-File -FilePath $reportPath -Encoding UTF8
    
    Write-DeploymentLog "`nDeployment report saved to: $reportPath" -Level Success
    
    return $reportPath
}

#endregion

# Main deployment logic

Write-Host @"
========================================
CloudScope PowerShell Deployment
========================================
Deployment Type: $DeploymentType
Module Path: $ModulePath
========================================
"@ -ForegroundColor Cyan

# Check prerequisites
if (-not (Test-Prerequisites)) {
    Write-DeploymentLog "Prerequisites check failed. Deployment aborted." -Level Error
    exit 1
}

# Execute deployment based on type
switch ($DeploymentType) {
    'Local' {
        Deploy-ToLocal
    }
    
    'AzureAutomation' {
        if (-not $ResourceGroup -or -not $AutomationAccount) {
            Write-DeploymentLog "ResourceGroup and AutomationAccount parameters are required for Azure deployment" -Level Error
            exit 1
        }
        Deploy-ToAzureAutomation -ResourceGroup $ResourceGroup -AutomationAccount $AutomationAccount
    }
    
    'PSGallery' {
        if (-not $PSGalleryApiKey) {
            Write-DeploymentLog "PSGalleryApiKey parameter is required for PowerShell Gallery deployment" -Level Error
            exit 1
        }
        Deploy-ToPSGallery -ApiKey $PSGalleryApiKey
    }
    
    'All' {
        # Deploy locally first
        Deploy-ToLocal
        
        # Deploy to Azure if parameters provided
        if ($ResourceGroup -and $AutomationAccount) {
            Deploy-ToAzureAutomation -ResourceGroup $ResourceGroup -AutomationAccount $AutomationAccount
        } else {
            Write-DeploymentLog "Skipping Azure deployment - missing parameters" -Level Warning
        }
        
        # Deploy to PS Gallery if API key provided
        if ($PSGalleryApiKey) {
            Deploy-ToPSGallery -ApiKey $PSGalleryApiKey
        } else {
            Write-DeploymentLog "Skipping PowerShell Gallery deployment - missing API key" -Level Warning
        }
    }
}

# Generate deployment report
$reportPath = New-DeploymentReport

# Display summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Deployment Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Total Operations: $($script:SuccessCount + $script:ErrorCount)" -ForegroundColor White
Write-Host "Successful: $script:SuccessCount" -ForegroundColor Green
Write-Host "Failed: $script:ErrorCount" -ForegroundColor Red
Write-Host "Report: $reportPath" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan

# Exit with appropriate code
if ($script:ErrorCount -gt 0) {
    exit 1
} else {
    Write-Host "`nDeployment completed successfully! ✅" -ForegroundColor Green
    exit 0
}
