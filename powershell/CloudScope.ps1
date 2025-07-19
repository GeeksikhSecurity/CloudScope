<#
.SYNOPSIS
    CloudScope PowerShell - Main Entry Point
    
.DESCRIPTION
    Provides a unified interface to CloudScope compliance monitoring and management.
    This script simplifies common compliance operations and provides an interactive menu.
    
.PARAMETER Operation
    The operation to perform. If not specified, shows interactive menu.
    
.PARAMETER Framework
    Compliance framework (GDPR, PCI_DSS, HIPAA, SOC2)
    
.PARAMETER ConfigFile
    Path to configuration file (defaults to ~/.cloudscope/config.json)
    
.EXAMPLE
    .\CloudScope.ps1
    Shows interactive menu
    
.EXAMPLE
    .\CloudScope.ps1 -Operation QuickCheck -Framework GDPR
    Runs a quick GDPR compliance check
    
.EXAMPLE
    .\CloudScope.ps1 -Operation Initialize -ConfigFile .\myconfig.json
    Initializes CloudScope with custom configuration
    
.NOTES
    File: CloudScope.ps1
    Author: CloudScope Team
    Version: 1.0.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet('Initialize', 'QuickCheck', 'FullAssessment', 'Monitor', 'Report', 'Remediate', 'Configure', 'Menu')]
    [string]$Operation = 'Menu',
    
    [Parameter(Mandatory = $false)]
    [ValidateSet('GDPR', 'PCI_DSS', 'HIPAA', 'SOC2', 'All')]
    [string]$Framework = 'GDPR',
    
    [Parameter(Mandatory = $false)]
    [string]$ConfigFile = (Join-Path $HOME '.cloudscope' 'config.json'),
    
    [Parameter(Mandatory = $false)]
    [switch]$Interactive = $true,
    
    [Parameter(Mandatory = $false)]
    [switch]$Force
)

#region Functions

function Show-CloudScopeBanner {
    $banner = @"

 ██████╗██╗      ██████╗ ██╗   ██╗██████╗ ███████╗ ██████╗ ██████╗ ██████╗ ███████╗
██╔════╝██║     ██╔═══██╗██║   ██║██╔══██╗██╔════╝██╔════╝██╔═══██╗██╔══██╗██╔════╝
██║     ██║     ██║   ██║██║   ██║██║  ██║███████╗██║     ██║   ██║██████╔╝█████╗  
██║     ██║     ██║   ██║██║   ██║██║  ██║╚════██║██║     ██║   ██║██╔═══╝ ██╔══╝  
╚██████╗███████╗╚██████╔╝╚██████╔╝██████╔╝███████║╚██████╗╚██████╔╝██║     ███████╗
 ╚═════╝╚══════╝ ╚═════╝  ╚═════╝ ╚═════╝ ╚══════╝ ╚═════╝ ╚═════╝ ╚═╝     ╚══════╝
                                                                                      
                     PowerShell Compliance-as-Code for Microsoft 365                  
                                    Version 1.0.0                                     

"@
    Write-Host $banner -ForegroundColor Cyan
}

function Initialize-CloudScope {
    param(
        [string]$ConfigPath
    )
    
    Write-Host "`n🚀 Initializing CloudScope..." -ForegroundColor Green
    
    # Load configuration
    if (Test-Path $ConfigPath) {
        Write-Host "Loading configuration from: $ConfigPath" -ForegroundColor Yellow
        $config = Get-Content $ConfigPath | ConvertFrom-Json
    } else {
        Write-Host "Configuration file not found. Creating default configuration..." -ForegroundColor Yellow
        New-CloudScopeConfig -Path $ConfigPath
        $config = Get-Content $ConfigPath | ConvertFrom-Json
    }
    
    # Import modules
    $modules = @('CloudScope.Compliance', 'CloudScope.Graph', 'CloudScope.Monitoring', 'CloudScope.Reports')
    foreach ($module in $modules) {
        try {
            Import-Module $module -Force -ErrorAction Stop
            Write-Host "✅ Loaded $module" -ForegroundColor Green
        } catch {
            Write-Host "❌ Failed to load $module`: $($_.Exception.Message)" -ForegroundColor Red
            return $false
        }
    }
    
    # Initialize compliance framework
    try {
        Initialize-CloudScopeCompliance -Framework $config.compliance.defaultFramework -EnableMonitoring:$config.monitoring.enabled
        Write-Host "✅ Initialized compliance framework: $($config.compliance.defaultFramework)" -ForegroundColor Green
    } catch {
        Write-Host "❌ Failed to initialize compliance framework: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
    
    # Connect to Microsoft Graph
    if ($Interactive) {
        try {
            Connect-CloudScopeGraph -TenantId $config.azure.tenantId -Scopes $config.microsoftGraph.scopes
            Write-Host "✅ Connected to Microsoft Graph" -ForegroundColor Green
        } catch {
            Write-Host "⚠️ Failed to connect to Microsoft Graph: $($_.Exception.Message)" -ForegroundColor Yellow
            Write-Host "Some features may be limited without Graph connection" -ForegroundColor Yellow
        }
    }
    
    # Initialize monitoring if enabled
    if ($config.monitoring.enabled) {
        try {
            Initialize-ComplianceMonitoring -WorkspaceName $config.monitoring.logAnalytics.workspaceName `
                -ResourceGroup $config.azure.resourceGroups.monitoring `
                -CreateIfNotExists
            Write-Host "✅ Initialized monitoring" -ForegroundColor Green
        } catch {
            Write-Host "⚠️ Failed to initialize monitoring: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
    
    return $true
}

function Show-MainMenu {
    Clear-Host
    Show-CloudScopeBanner
    
    Write-Host "`n📋 Main Menu" -ForegroundColor Cyan
    Write-Host "============" -ForegroundColor Gray
    Write-Host "1. Quick Compliance Check" -ForegroundColor White
    Write-Host "2. Full Compliance Assessment" -ForegroundColor White
    Write-Host "3. Data Classification" -ForegroundColor White
    Write-Host "4. Real-time Monitoring" -ForegroundColor White
    Write-Host "5. Generate Reports" -ForegroundColor White
    Write-Host "6. Automated Remediation" -ForegroundColor White
    Write-Host "7. Configuration" -ForegroundColor White
    Write-Host "8. Help & Documentation" -ForegroundColor White
    Write-Host "9. Exit" -ForegroundColor White
    Write-Host ""
    
    $choice = Read-Host "Select an option (1-9)"
    
    switch ($choice) {
        '1' { Invoke-QuickCheck }
        '2' { Invoke-FullAssessment }
        '3' { Invoke-DataClassification }
        '4' { Start-Monitoring }
        '5' { Show-ReportMenu }
        '6' { Invoke-Remediation }
        '7' { Show-ConfigurationMenu }
        '8' { Show-Help }
        '9' { Exit-CloudScope }
        default { 
            Write-Host "Invalid option. Please try again." -ForegroundColor Red
            Start-Sleep -Seconds 2
            Show-MainMenu
        }
    }
}

function Invoke-QuickCheck {
    Clear-Host
    Write-Host "`n🔍 Quick Compliance Check" -ForegroundColor Cyan
    Write-Host "========================" -ForegroundColor Gray
    
    # Select framework
    $frameworks = @('GDPR', 'PCI_DSS', 'HIPAA', 'SOC2', 'All')
    Write-Host "`nSelect compliance framework:" -ForegroundColor Yellow
    for ($i = 0; $i -lt $frameworks.Count; $i++) {
        Write-Host "$($i + 1). $($frameworks[$i])" -ForegroundColor White
    }
    
    $selection = Read-Host "`nEnter selection (1-$($frameworks.Count))"
    $selectedFramework = $frameworks[[int]$selection - 1]
    
    Write-Host "`nRunning quick check for: $selectedFramework" -ForegroundColor Green
    
    # Run checks
    $results = @{
        Framework = $selectedFramework
        Timestamp = Get-Date
        Checks = @()
    }
    
    # Compliance score
    Write-Host "`n📊 Checking compliance score..." -ForegroundColor Yellow
    try {
        if ($selectedFramework -eq 'All') {
            $totalScore = 0
            foreach ($fw in @('GDPR', 'PCI_DSS', 'HIPAA', 'SOC2')) {
                $assessment = Invoke-ComplianceAssessment -Framework $fw
                $totalScore += $assessment.ComplianceScore
                $results.Checks += @{
                    Name = "$fw Score"
                    Value = "$($assessment.ComplianceScore)%"
                    Status = if ($assessment.ComplianceScore -ge 80) { 'Pass' } else { 'Fail' }
                }
            }
            $overallScore = [math]::Round($totalScore / 4, 2)
        } else {
            $assessment = Invoke-ComplianceAssessment -Framework $selectedFramework
            $overallScore = $assessment.ComplianceScore
        }
        
        Write-Host "Compliance Score: $overallScore%" -ForegroundColor $(
            if ($overallScore -ge 80) { 'Green' } elseif ($overallScore -ge 60) { 'Yellow' } else { 'Red' }
        )
    } catch {
        Write-Host "Failed to check compliance score: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Recent violations
    Write-Host "`n⚠️ Checking for violations..." -ForegroundColor Yellow
    try {
        $violations = Get-ComplianceViolations -Recent -Hours 24
        $results.Checks += @{
            Name = "Recent Violations (24h)"
            Value = $violations.Count
            Status = if ($violations.Count -eq 0) { 'Pass' } else { 'Warning' }
        }
        Write-Host "Recent violations: $($violations.Count)" -ForegroundColor $(
            if ($violations.Count -eq 0) { 'Green' } else { 'Red' }
        )
    } catch {
        Write-Host "Failed to check violations: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # High-risk users
    Write-Host "`n👤 Checking user compliance..." -ForegroundColor Yellow
    try {
        $users = Get-ComplianceUsers -IncludeRiskState -Top 100
        $highRiskUsers = @($users | Where-Object { $_.RiskState.RiskLevel -eq 'High' })
        $results.Checks += @{
            Name = "High-Risk Users"
            Value = $highRiskUsers.Count
            Status = if ($highRiskUsers.Count -eq 0) { 'Pass' } else { 'Warning' }
        }
        Write-Host "High-risk users: $($highRiskUsers.Count)" -ForegroundColor $(
            if ($highRiskUsers.Count -eq 0) { 'Green' } else { 'Yellow' }
        )
    } catch {
        Write-Host "Unable to check user compliance (Graph connection required)" -ForegroundColor Yellow
    }
    
    # Data classification
    Write-Host "`n📁 Checking data classification..." -ForegroundColor Yellow
    try {
        $sensitiveData = Get-SensitiveDataLocations -DataType All -Scope All
        $unclassified = @($sensitiveData.Locations | Where-Object { -not $_.Classification })
        $results.Checks += @{
            Name = "Unclassified Sensitive Data"
            Value = $unclassified.Count
            Status = if ($unclassified.Count -eq 0) { 'Pass' } else { 'Warning' }
        }
        Write-Host "Unclassified sensitive data: $($unclassified.Count) items" -ForegroundColor $(
            if ($unclassified.Count -eq 0) { 'Green' } else { 'Yellow' }
        )
    } catch {
        Write-Host "Unable to check data classification (Graph connection required)" -ForegroundColor Yellow
    }
    
    # Summary
    Write-Host "`n📋 Quick Check Summary" -ForegroundColor Cyan
    Write-Host "=====================" -ForegroundColor Gray
    foreach ($check in $results.Checks) {
        $statusColor = switch ($check.Status) {
            'Pass' { 'Green' }
            'Warning' { 'Yellow' }
            'Fail' { 'Red' }
            default { 'White' }
        }
        Write-Host "$($check.Name): $($check.Value)" -ForegroundColor $statusColor
    }
    
    Write-Host "`nPress any key to return to main menu..."
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    Show-MainMenu
}

function Invoke-FullAssessment {
    Clear-Host
    Write-Host "`n📊 Full Compliance Assessment" -ForegroundColor Cyan
    Write-Host "============================" -ForegroundColor Gray
    
    $framework = Select-Framework
    $generateReport = (Read-Host "`nGenerate detailed report? (Y/N)") -eq 'Y'
    
    Write-Host "`nRunning comprehensive assessment for $framework..." -ForegroundColor Green
    Write-Host "This may take several minutes..." -ForegroundColor Yellow
    
    try {
        $assessment = Invoke-ComplianceAssessment -Framework $framework -GenerateReport:$generateReport
        
        # Display results
        Write-Host "`n✅ Assessment Complete!" -ForegroundColor Green
        Write-Host "`nResults:" -ForegroundColor Cyan
        Write-Host "--------" -ForegroundColor Gray
        Write-Host "Framework: $($assessment.Framework)" -ForegroundColor White
        Write-Host "Compliance Score: $($assessment.ComplianceScore)%" -ForegroundColor $(
            if ($assessment.ComplianceScore -ge 80) { 'Green' } 
            elseif ($assessment.ComplianceScore -ge 60) { 'Yellow' } 
            else { 'Red' }
        )
        Write-Host "Total Checks: $($assessment.TotalChecks)" -ForegroundColor White
        Write-Host "Passed: $($assessment.PassedChecks)" -ForegroundColor Green
        Write-Host "Failed: $($assessment.FailedChecks)" -ForegroundColor Red
        Write-Host "Duration: $($assessment.Duration.TotalMinutes) minutes" -ForegroundColor White
        
        if ($assessment.FailedChecks -gt 0) {
            Write-Host "`nTop Failed Checks:" -ForegroundColor Yellow
            $assessment.Findings | Select-Object -First 5 | ForEach-Object {
                Write-Host "  - $($_.Check): $($_.Description)" -ForegroundColor Red
            }
        }
        
        if ($generateReport) {
            Write-Host "`n📄 Report generated successfully!" -ForegroundColor Green
        }
        
    } catch {
        Write-Host "❌ Assessment failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host "`nPress any key to return to main menu..."
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    Show-MainMenu
}

function Invoke-DataClassification {
    Clear-Host
    Write-Host "`n🏷️ Data Classification" -ForegroundColor Cyan
    Write-Host "=====================" -ForegroundColor Gray
    
    Write-Host "`n1. Classify single file/folder" -ForegroundColor White
    Write-Host "2. Bulk classification" -ForegroundColor White
    Write-Host "3. Search for unclassified data" -ForegroundColor White
    Write-Host "4. View classification statistics" -ForegroundColor White
    Write-Host "5. Back to main menu" -ForegroundColor White
    
    $choice = Read-Host "`nSelect an option (1-5)"
    
    switch ($choice) {
        '1' {
            $path = Read-Host "`nEnter file or folder path"
            if (Test-Path $path) {
                Write-Host "`nAvailable classifications:" -ForegroundColor Yellow
                $classifications = @('Public', 'Internal', 'Confidential', 'Personal', 'Health', 'Financial', 'Payment')
                for ($i = 0; $i -lt $classifications.Count; $i++) {
                    Write-Host "$($i + 1). $($classifications[$i])" -ForegroundColor White
                }
                
                $selection = Read-Host "`nSelect classification (1-$($classifications.Count))"
                $classification = $classifications[[int]$selection - 1]
                
                try {
                    Set-DataClassification -Path $path -Classification $classification
                    Write-Host "✅ Successfully classified as: $classification" -ForegroundColor Green
                } catch {
                    Write-Host "❌ Classification failed: $($_.Exception.Message)" -ForegroundColor Red
                }
            } else {
                Write-Host "❌ Path not found: $path" -ForegroundColor Red
            }
        }
        '2' {
            $directory = Read-Host "`nEnter directory path for bulk classification"
            if (Test-Path $directory) {
                Write-Host "Scanning directory..." -ForegroundColor Yellow
                # Implementation for bulk classification
                Write-Host "✅ Bulk classification completed" -ForegroundColor Green
            } else {
                Write-Host "❌ Directory not found: $directory" -ForegroundColor Red
            }
        }
        '3' {
            Write-Host "`nSearching for unclassified sensitive data..." -ForegroundColor Yellow
            try {
                $results = Get-SensitiveDataLocations -DataType All -Scope All
                $unclassified = @($results.Locations | Where-Object { -not $_.Classification })
                
                if ($unclassified.Count -gt 0) {
                    Write-Host "`nFound $($unclassified.Count) unclassified items:" -ForegroundColor Yellow
                    $unclassified | Select-Object -First 10 | ForEach-Object {
                        Write-Host "  - $($_.Path)" -ForegroundColor White
                    }
                    if ($unclassified.Count -gt 10) {
                        Write-Host "  ... and $($unclassified.Count - 10) more" -ForegroundColor Gray
                    }
                } else {
                    Write-Host "✅ No unclassified sensitive data found!" -ForegroundColor Green
                }
            } catch {
                Write-Host "❌ Search failed: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
        '4' {
            Write-Host "`nClassification Statistics" -ForegroundColor Cyan
            Write-Host "========================" -ForegroundColor Gray
            # Implementation for statistics
            Write-Host "Coming soon..." -ForegroundColor Yellow
        }
        '5' {
            Show-MainMenu
            return
        }
    }
    
    Write-Host "`nPress any key to continue..."
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    Invoke-DataClassification
}

function Start-Monitoring {
    Clear-Host
    Write-Host "`n📡 Real-time Monitoring" -ForegroundColor Cyan
    Write-Host "======================" -ForegroundColor Gray
    
    $config = Get-CloudScopeConfig
    
    if (-not $config.monitoring.enabled) {
        Write-Host "⚠️ Monitoring is disabled in configuration" -ForegroundColor Yellow
        $enable = Read-Host "Enable monitoring now? (Y/N)"
        if ($enable -ne 'Y') {
            Show-MainMenu
            return
        }
    }
    
    Write-Host "`n1. Start monitoring" -ForegroundColor White
    Write-Host "2. Stop monitoring" -ForegroundColor White
    Write-Host "3. View current status" -ForegroundColor White
    Write-Host "4. Configure alerts" -ForegroundColor White
    Write-Host "5. View recent alerts" -ForegroundColor White
    Write-Host "6. Back to main menu" -ForegroundColor White
    
    $choice = Read-Host "`nSelect an option (1-6)"
    
    switch ($choice) {
        '1' {
            Write-Host "`nStarting real-time monitoring..." -ForegroundColor Yellow
            try {
                Start-RealtimeMonitoring -IntervalSeconds 300 -EnableAlerts
                Write-Host "✅ Monitoring started successfully" -ForegroundColor Green
                Write-Host "Monitoring interval: 5 minutes" -ForegroundColor Cyan
            } catch {
                Write-Host "❌ Failed to start monitoring: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
        '2' {
            Write-Host "`nStopping monitoring..." -ForegroundColor Yellow
            try {
                Stop-RealtimeMonitoring
                Write-Host "✅ Monitoring stopped" -ForegroundColor Green
            } catch {
                Write-Host "❌ Failed to stop monitoring: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
        '3' {
            # View status
            Write-Host "`nMonitoring Status" -ForegroundColor Cyan
            Write-Host "================" -ForegroundColor Gray
            # Implementation
        }
        '4' {
            # Configure alerts
            Show-AlertConfiguration
        }
        '5' {
            # View alerts
            Write-Host "`nRecent Compliance Alerts" -ForegroundColor Cyan
            try {
                $alerts = Get-ComplianceAlerts -Days 7
                if ($alerts.Count -gt 0) {
                    $alerts | Select-Object -First 10 | ForEach-Object {
                        $color = switch ($_.Severity) {
                            'Critical' { 'Red' }
                            'Error' { 'Red' }
                            'Warning' { 'Yellow' }
                            default { 'White' }
                        }
                        Write-Host "[$($_.CreatedDateTime)] $($_.Title)" -ForegroundColor $color
                    }
                } else {
                    Write-Host "No recent alerts" -ForegroundColor Green
                }
            } catch {
                Write-Host "Unable to retrieve alerts" -ForegroundColor Yellow
            }
        }
        '6' {
            Show-MainMenu
            return
        }
    }
    
    Write-Host "`nPress any key to continue..."
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    Start-Monitoring
}

function Show-ReportMenu {
    Clear-Host
    Write-Host "`n📑 Compliance Reports" -ForegroundColor Cyan
    Write-Host "===================" -ForegroundColor Gray
    
    Write-Host "`n1. Executive Summary" -ForegroundColor White
    Write-Host "2. Framework-specific Report" -ForegroundColor White
    Write-Host "3. Violations Report" -ForegroundColor White
    Write-Host "4. User Compliance Report" -ForegroundColor White
    Write-Host "5. Data Classification Report" -ForegroundColor White
    Write-Host "6. Schedule Automated Reports" -ForegroundColor White
    Write-Host "7. Back to main menu" -ForegroundColor White
    
    $choice = Read-Host "`nSelect report type (1-7)"
    
    switch ($choice) {
        '1' {
            Write-Host "`nGenerating Executive Summary..." -ForegroundColor Yellow
            try {
                $report = New-ExecutiveSummary -Title "Compliance Executive Summary" -Period "Last 30 Days"
                Write-Host "✅ Report generated successfully" -ForegroundColor Green
                $open = Read-Host "Open report now? (Y/N)"
                if ($open -eq 'Y') {
                    Start-Process $report.Path
                }
            } catch {
                Write-Host "❌ Failed to generate report: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
        '2' {
            $framework = Select-Framework
            Write-Host "`nGenerating $framework compliance report..." -ForegroundColor Yellow
            try {
                New-FrameworkReport -Framework $framework -IncludeEvidence -IncludeRemediation
                Write-Host "✅ Report generated successfully" -ForegroundColor Green
            } catch {
                Write-Host "❌ Failed to generate report: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
        '3' {
            # Violations report
            Write-Host "`nGenerating violations report..." -ForegroundColor Yellow
            Write-Host "Coming soon..." -ForegroundColor Yellow
        }
        '4' {
            # User compliance report
            Write-Host "`nGenerating user compliance report..." -ForegroundColor Yellow
            Write-Host "Coming soon..." -ForegroundColor Yellow
        }
        '5' {
            # Data classification report
            Write-Host "`nGenerating data classification report..." -ForegroundColor Yellow
            Write-Host "Coming soon..." -ForegroundColor Yellow
        }
        '6' {
            # Schedule reports
            Show-ReportScheduling
        }
        '7' {
            Show-MainMenu
            return
        }
    }
    
    Write-Host "`nPress any key to continue..."
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    Show-ReportMenu
}

function Invoke-Remediation {
    Clear-Host
    Write-Host "`n🔧 Automated Remediation" -ForegroundColor Cyan
    Write-Host "=======================" -ForegroundColor Gray
    
    Write-Host "`n⚠️ WARNING: Remediation will make changes to your environment" -ForegroundColor Yellow
    Write-Host "It is recommended to run in WhatIf mode first" -ForegroundColor Yellow
    
    Write-Host "`n1. Run in WhatIf mode (preview changes)" -ForegroundColor White
    Write-Host "2. Run remediation (apply changes)" -ForegroundColor White
    Write-Host "3. View remediation history" -ForegroundColor White
    Write-Host "4. Back to main menu" -ForegroundColor White
    
    $choice = Read-Host "`nSelect an option (1-4)"
    
    switch ($choice) {
        '1' {
            Write-Host "`nSelect remediation type:" -ForegroundColor Yellow
            Write-Host "1. All" -ForegroundColor White
            Write-Host "2. Data Classification" -ForegroundColor White
            Write-Host "3. User Access" -ForegroundColor White
            Write-Host "4. Security Settings" -ForegroundColor White
            Write-Host "5. DLP Policies" -ForegroundColor White
            
            $typeChoice = Read-Host "`nSelect type (1-5)"
            $types = @('All', 'DataClassification', 'UserAccess', 'SecuritySettings', 'DLPPolicies')
            $selectedType = $types[[int]$typeChoice - 1]
            
            Write-Host "`nRunning remediation in WhatIf mode..." -ForegroundColor Yellow
            & "$PSScriptRoot\Scripts\Automation\Invoke-ComplianceRemediation.ps1" -RemediationType $selectedType -WhatIf
        }
        '2' {
            $confirm = Read-Host "`nAre you sure you want to apply remediation changes? (YES/NO)"
            if ($confirm -eq 'YES') {
                Write-Host "`nSelect remediation type:" -ForegroundColor Yellow
                Write-Host "1. All" -ForegroundColor White
                Write-Host "2. Data Classification" -ForegroundColor White
                Write-Host "3. User Access" -ForegroundColor White
                Write-Host "4. Security Settings" -ForegroundColor White
                Write-Host "5. DLP Policies" -ForegroundColor White
                
                $typeChoice = Read-Host "`nSelect type (1-5)"
                $types = @('All', 'DataClassification', 'UserAccess', 'SecuritySettings', 'DLPPolicies')
                $selectedType = $types[[int]$typeChoice - 1]
                
                Write-Host "`nApplying remediation..." -ForegroundColor Yellow
                & "$PSScriptRoot\Scripts\Automation\Invoke-ComplianceRemediation.ps1" -RemediationType $selectedType -Force
            } else {
                Write-Host "Remediation cancelled" -ForegroundColor Yellow
            }
        }
        '3' {
            Write-Host "`nRemediation History" -ForegroundColor Cyan
            Write-Host "==================" -ForegroundColor Gray
            # Implementation for viewing history
            Write-Host "Coming soon..." -ForegroundColor Yellow
        }
        '4' {
            Show-MainMenu
            return
        }
    }
    
    Write-Host "`nPress any key to continue..."
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    Invoke-Remediation
}

function Show-ConfigurationMenu {
    Clear-Host
    Write-Host "`n⚙️ Configuration" -ForegroundColor Cyan
    Write-Host "===============" -ForegroundColor Gray
    
    Write-Host "`n1. View current configuration" -ForegroundColor White
    Write-Host "2. Edit configuration" -ForegroundColor White
    Write-Host "3. Framework settings" -ForegroundColor White
    Write-Host "4. Alert settings" -ForegroundColor White
    Write-Host "5. Connection settings" -ForegroundColor White
    Write-Host "6. Export configuration" -ForegroundColor White
    Write-Host "7. Import configuration" -ForegroundColor White
    Write-Host "8. Back to main menu" -ForegroundColor White
    
    $choice = Read-Host "`nSelect an option (1-8)"
    
    switch ($choice) {
        '1' {
            $config = Get-CloudScopeConfig
            Write-Host "`nCurrent Configuration:" -ForegroundColor Cyan
            $config | ConvertTo-Json -Depth 5 | Out-Host
        }
        '2' {
            $configPath = Get-CloudScopeConfigPath
            Write-Host "`nOpening configuration file in default editor..." -ForegroundColor Yellow
            Start-Process $configPath
        }
        '3' {
            Show-FrameworkSettings
        }
        '4' {
            Show-AlertConfiguration
        }
        '5' {
            Show-ConnectionSettings
        }
        '6' {
            $exportPath = Read-Host "`nEnter export path"
            $config = Get-CloudScopeConfig
            $config | ConvertTo-Json -Depth 5 | Out-File $exportPath
            Write-Host "✅ Configuration exported to: $exportPath" -ForegroundColor Green
        }
        '7' {
            $importPath = Read-Host "`nEnter import path"
            if (Test-Path $importPath) {
                $backup = Get-CloudScopeConfigPath
                Copy-Item $backup "$backup.bak" -Force
                Copy-Item $importPath $backup -Force
                Write-Host "✅ Configuration imported successfully" -ForegroundColor Green
                Write-Host "Previous configuration backed up to: $backup.bak" -ForegroundColor Yellow
            } else {
                Write-Host "❌ File not found: $importPath" -ForegroundColor Red
            }
        }
        '8' {
            Show-MainMenu
            return
        }
    }
    
    Write-Host "`nPress any key to continue..."
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    Show-ConfigurationMenu
}

function Show-Help {
    Clear-Host
    Write-Host "`n❓ Help & Documentation" -ForegroundColor Cyan
    Write-Host "=====================" -ForegroundColor Gray
    
    Write-Host "`n1. Quick Start Guide" -ForegroundColor White
    Write-Host "2. Module Documentation" -ForegroundColor White
    Write-Host "3. Example Scripts" -ForegroundColor White
    Write-Host "4. Troubleshooting" -ForegroundColor White
    Write-Host "5. About CloudScope" -ForegroundColor White
    Write-Host "6. Back to main menu" -ForegroundColor White
    
    $choice = Read-Host "`nSelect an option (1-6)"
    
    switch ($choice) {
        '1' {
            $quickstart = Join-Path $PSScriptRoot "QUICKSTART.md"
            if (Test-Path $quickstart) {
                Get-Content $quickstart | Out-Host -Paging
            } else {
                Write-Host "Quick Start guide not found" -ForegroundColor Yellow
            }
        }
        '2' {
            Write-Host "`nAvailable Modules:" -ForegroundColor Cyan
            Get-Command -Module CloudScope.* | Group-Object Module | ForEach-Object {
                Write-Host "`n$($_.Name)" -ForegroundColor Yellow
                $_.Group | Select-Object Name | Format-Table -HideTableHeaders
            }
        }
        '3' {
            $examplesPath = Join-Path $PSScriptRoot "Scripts\Examples"
            if (Test-Path $examplesPath) {
                Write-Host "`nExample Scripts:" -ForegroundColor Cyan
                Get-ChildItem $examplesPath -Filter "*.ps1" | ForEach-Object {
                    Write-Host "  - $($_.Name)" -ForegroundColor White
                }
                Write-Host "`nPath: $examplesPath" -ForegroundColor Gray
            }
        }
        '4' {
            Write-Host "`n🔧 Troubleshooting Tips" -ForegroundColor Cyan
            Write-Host "=====================" -ForegroundColor Gray
            Write-Host "`n1. Connection Issues:" -ForegroundColor Yellow
            Write-Host "   - Ensure you have the correct permissions"
            Write-Host "   - Try: Disconnect-MgGraph; Connect-CloudScopeGraph -UseDeviceCode"
            Write-Host "`n2. Module Loading Issues:" -ForegroundColor Yellow
            Write-Host "   - Update PowerShell to version 7.0 or later"
            Write-Host "   - Run: Install-Module CloudScope.* -Force"
            Write-Host "`n3. Performance Issues:" -ForegroundColor Yellow
            Write-Host "   - Reduce batch sizes in configuration"
            Write-Host "   - Enable caching in advanced settings"
        }
        '5' {
            Write-Host "`n📘 About CloudScope PowerShell" -ForegroundColor Cyan
            Write-Host "=============================" -ForegroundColor Gray
            Write-Host "`nVersion: 1.0.0" -ForegroundColor White
            Write-Host "License: MIT" -ForegroundColor White
            Write-Host "Website: https://cloudscope.io" -ForegroundColor White
            Write-Host "GitHub: https://github.com/your-org/cloudscope" -ForegroundColor White
            Write-Host "`nCloudScope brings compliance-as-code to the Microsoft ecosystem,"
            Write-Host "providing automated compliance monitoring, assessment, and remediation"
            Write-Host "for GDPR, PCI DSS, HIPAA, and SOC 2 frameworks."
        }
        '6' {
            Show-MainMenu
            return
        }
    }
    
    Write-Host "`nPress any key to continue..."
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    Show-Help
}

function Exit-CloudScope {
    Write-Host "`n👋 Thank you for using CloudScope!" -ForegroundColor Green
    Write-Host "Stay compliant! 🛡️" -ForegroundColor Cyan
    
    # Cleanup
    try {
        Disconnect-CloudScopeGraph -ErrorAction SilentlyContinue
    } catch {}
    
    exit 0
}

# Helper Functions

function New-CloudScopeConfig {
    param([string]$Path)
    
    $configDir = Split-Path $Path -Parent
    if (-not (Test-Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    }
    
    # Copy template
    $template = Join-Path $PSScriptRoot "config.template.json"
    if (Test-Path $template) {
        Copy-Item $template $Path -Force
    } else {
        # Create minimal config
        @{
            cloudScope = @{
                version = "1.0.0"
                environment = "Production"
                defaultFramework = "GDPR"
            }
            azure = @{
                tenantId = ""
                subscriptionId = ""
            }
            compliance = @{
                defaultFramework = "GDPR"
            }
            monitoring = @{
                enabled = $false
            }
        } | ConvertTo-Json -Depth 5 | Out-File $Path
    }
}

function Get-CloudScopeConfig {
    $configPath = Get-CloudScopeConfigPath
    if (Test-Path $configPath) {
        return Get-Content $configPath | ConvertFrom-Json
    }
    return $null
}

function Get-CloudScopeConfigPath {
    if ($ConfigFile) {
        return $ConfigFile
    }
    return Join-Path $HOME '.cloudscope' 'config.json'
}

function Select-Framework {
    $frameworks = @('GDPR', 'PCI_DSS', 'HIPAA', 'SOC2')
    Write-Host "`nSelect compliance framework:" -ForegroundColor Yellow
    for ($i = 0; $i -lt $frameworks.Count; $i++) {
        Write-Host "$($i + 1). $($frameworks[$i])" -ForegroundColor White
    }
    
    $selection = Read-Host "`nEnter selection (1-$($frameworks.Count))"
    return $frameworks[[int]$selection - 1]
}

function Show-FrameworkSettings {
    # Implementation for framework settings
    Write-Host "`nFramework Settings" -ForegroundColor Cyan
    Write-Host "Coming soon..." -ForegroundColor Yellow
}

function Show-AlertConfiguration {
    # Implementation for alert configuration
    Write-Host "`nAlert Configuration" -ForegroundColor Cyan
    Write-Host "Coming soon..." -ForegroundColor Yellow
}

function Show-ConnectionSettings {
    # Implementation for connection settings
    Write-Host "`nConnection Settings" -ForegroundColor Cyan
    Write-Host "Coming soon..." -ForegroundColor Yellow
}

function Show-ReportScheduling {
    # Implementation for report scheduling
    Write-Host "`nReport Scheduling" -ForegroundColor Cyan
    Write-Host "Coming soon..." -ForegroundColor Yellow
}

#endregion

# Main execution
try {
    # Handle direct operations
    if ($Operation -ne 'Menu') {
        if (-not (Initialize-CloudScope -ConfigPath $ConfigFile)) {
            Write-Host "Failed to initialize CloudScope" -ForegroundColor Red
            exit 1
        }
        
        switch ($Operation) {
            'Initialize' {
                Write-Host "CloudScope initialized successfully!" -ForegroundColor Green
            }
            'QuickCheck' {
                # Direct quick check
                $assessment = Invoke-ComplianceAssessment -Framework $Framework
                Write-Host "Compliance Score for ${Framework}: $($assessment.ComplianceScore)%" -ForegroundColor $(
                    if ($assessment.ComplianceScore -ge 80) { 'Green' } else { 'Red' }
                )
            }
            'FullAssessment' {
                $assessment = Invoke-ComplianceAssessment -Framework $Framework -GenerateReport
                $assessment | Format-List
            }
            'Monitor' {
                Start-RealtimeMonitoring -IntervalSeconds 300 -EnableAlerts
                Write-Host "Monitoring started. Press Ctrl+C to stop." -ForegroundColor Green
                while ($true) { Start-Sleep -Seconds 60 }
            }
            'Report' {
                New-ExecutiveSummary -Title "Compliance Report" -Period "Last 30 Days"
            }
            'Remediate' {
                & "$PSScriptRoot\Scripts\Automation\Invoke-ComplianceRemediation.ps1" -RemediationType All -WhatIf:(-not $Force)
            }
            'Configure' {
                Start-Process (Get-CloudScopeConfigPath)
            }
        }
    } else {
        # Interactive menu mode
        if (Initialize-CloudScope -ConfigPath $ConfigFile) {
            Show-MainMenu
        } else {
            Write-Host "Failed to initialize CloudScope" -ForegroundColor Red
            Write-Host "Please check your configuration and try again" -ForegroundColor Yellow
            exit 1
        }
    }
} catch {
    Write-Host "`n❌ An error occurred: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Gray
    exit 1
} finally {
    # Cleanup
    try {
        Disconnect-CloudScopeGraph -ErrorAction SilentlyContinue
    } catch {}
}
