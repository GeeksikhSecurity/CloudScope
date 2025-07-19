<#
.SYNOPSIS
    Example: Real-time Compliance Monitoring and Alerting
    
.DESCRIPTION
    Demonstrates how to set up real-time compliance monitoring with
    Azure Monitor integration and automated alerting.
    
.NOTES
    File: Example-RealtimeMonitoring.ps1
    Author: CloudScope Team
    Version: 1.0.0
#>

# Import required modules
Import-Module CloudScope.Compliance -Force
Import-Module CloudScope.Graph -Force
Import-Module CloudScope.Monitoring -Force
Import-Module CloudScope.Reports -Force

Write-Host "=== CloudScope Real-time Monitoring Example ===" -ForegroundColor Green
Write-Host "This example demonstrates setting up continuous compliance monitoring" -ForegroundColor Cyan

# Prerequisites check
Write-Host "`n[Prerequisites Check]" -ForegroundColor Yellow
$azContext = Get-AzContext -ErrorAction SilentlyContinue
if (-not $azContext) {
    Write-Host "Connecting to Azure..." -ForegroundColor Yellow
    Connect-AzAccount
}

# Step 1: Initialize monitoring infrastructure
Write-Host "`n[Step 1] Initializing monitoring infrastructure" -ForegroundColor Yellow

$monitoringParams = @{
    WorkspaceName = "CloudScopeCompliance"
    ResourceGroup = "rg-compliance-monitoring"
    Location = "eastus"
    AppInsightsName = "CloudScope-AppInsights"
    CreateIfNotExists = $true
}

try {
    Initialize-ComplianceMonitoring @monitoringParams
    Write-Host "✅ Monitoring infrastructure initialized" -ForegroundColor Green
} catch {
    Write-Warning "Failed to initialize monitoring: $($_.Exception.Message)"
}

# Step 2: Configure alert rules
Write-Host "`n[Step 2] Configuring alert rules" -ForegroundColor Yellow

# Compliance score threshold
Set-AlertingRules -RuleName "ComplianceScore" `
    -Threshold 85 `
    -Operator "LessThan" `
    -Severity "Warning" `
    -Enabled
Write-Host "✅ Alert rule: Compliance score < 85%" -ForegroundColor Green

# Violation count threshold
Set-AlertingRules -RuleName "ViolationCount" `
    -Threshold 5 `
    -Operator "GreaterThan" `
    -Severity "Error" `
    -Enabled
Write-Host "✅ Alert rule: Violations > 5" -ForegroundColor Green

# Failed operations threshold
Set-AlertingRules -RuleName "FailedOperations" `
    -Threshold 3 `
    -Operator "GreaterThan" `
    -Severity "Critical" `
    -Enabled
Write-Host "✅ Alert rule: Failed operations > 3" -ForegroundColor Green

# Data access anomaly
Set-AlertingRules -RuleName "DataAccessAnomaly" `
    -Threshold 100 `
    -Operator "GreaterThan" `
    -Severity "Warning" `
    -Enabled
Write-Host "✅ Alert rule: Unusual data access patterns" -ForegroundColor Green

# Step 3: Define custom metrics
Write-Host "`n[Step 3] Defining custom compliance metrics" -ForegroundColor Yellow

# Create custom metrics for tracking
$metrics = @(
    @{
        Name = "UserComplianceScore"
        Description = "Average compliance score across all users"
        Category = "Users"
    },
    @{
        Name = "DataClassificationCoverage"
        Description = "Percentage of data that is classified"
        Category = "Data"
    },
    @{
        Name = "PolicyViolationsPerHour"
        Description = "Number of policy violations per hour"
        Category = "Violations"
    },
    @{
        Name = "SensitiveDataAccess"
        Description = "Number of sensitive data access events"
        Category = "Security"
    }
)

foreach ($metric in $metrics) {
    Write-Host "  - $($metric.Name): $($metric.Description)" -ForegroundColor White
}

# Step 4: Start real-time monitoring
Write-Host "`n[Step 4] Starting real-time monitoring" -ForegroundColor Yellow

Start-RealtimeMonitoring -IntervalSeconds 300 -EnableAlerts
Write-Host "✅ Real-time monitoring started (5-minute intervals)" -ForegroundColor Green

# Step 5: Simulate compliance events for demonstration
Write-Host "`n[Step 5] Simulating compliance events" -ForegroundColor Yellow

# Initialize compliance framework
Initialize-CloudScopeCompliance -Framework GDPR
Connect-CloudScopeGraph

# Simulate various compliance events
$simulatedEvents = @(
    @{
        Type = "DataAccess"
        Description = "User accessed sensitive personal data"
        Severity = "Info"
        User = "john.doe@contoso.com"
        Resource = "CustomerDatabase"
    },
    @{
        Type = "PolicyViolation"
        Description = "Attempted to share payment data externally"
        Severity = "Warning"
        User = "jane.smith@contoso.com"
        Resource = "FinancialReports"
    },
    @{
        Type = "UnauthorizedAccess"
        Description = "Access denied to classified data"
        Severity = "Error"
        User = "external.user@partner.com"
        Resource = "ConfidentialDocs"
    }
)

foreach ($event in $simulatedEvents) {
    Write-Host "`n  Event: $($event.Type)" -ForegroundColor White
    Write-Host "  Description: $($event.Description)" -ForegroundColor Gray
    
    # Log the event
    Add-AuditLog -Operation $event.Type -Details $event -Severity $event.Severity
    
    # Create metric
    $metric = New-ComplianceMetric -Name $event.Type `
        -Value 1 `
        -Category "SimulatedEvents" `
        -Properties $event
    
    # Send to monitoring
    Send-ComplianceMetric -Metric $metric
    
    Start-Sleep -Seconds 2
}

# Step 6: Check monitoring status
Write-Host "`n[Step 6] Checking monitoring status" -ForegroundColor Yellow

$status = Get-MonitoringStatus
if ($status) {
    Write-Host "Monitoring Status: Active" -ForegroundColor Green
    Write-Host "  Metrics collected: $($status.MetricsCount)"
    Write-Host "  Alerts triggered: $($status.AlertsCount)"
    Write-Host "  Last update: $($status.LastUpdate)"
}

# Step 7: Query recent metrics
Write-Host "`n[Step 7] Querying recent compliance metrics" -ForegroundColor Yellow

$recentMetrics = Get-ComplianceMetrics -TimeRange 'Last1Hour' -Aggregation 'Average'
if ($recentMetrics) {
    Write-Host "Recent metrics (last hour):" -ForegroundColor Cyan
    $recentMetrics | Format-Table -Property TimeGenerated, MetricName, MetricValue -AutoSize
}

# Step 8: Create monitoring dashboard
Write-Host "`n[Step 8] Creating monitoring dashboard" -ForegroundColor Yellow

try {
    New-ComplianceDashboard -DashboardName "CloudScope Real-time Compliance" `
        -ResourceGroup "rg-compliance-monitoring"
    Write-Host "✅ Dashboard created in Azure Portal" -ForegroundColor Green
} catch {
    Write-Warning "Dashboard creation skipped: $($_.Exception.Message)"
}

# Step 9: Set up automated responses
Write-Host "`n[Step 9] Configuring automated responses" -ForegroundColor Yellow

# Define automated response actions
$automationRules = @(
    @{
        Trigger = "ComplianceScoreLow"
        Action = {
            # Generate immediate compliance report
            New-ExecutiveSummary -Title "Low Compliance Score Alert" -Period "Current"
            
            # Send notification
            Send-ComplianceNotification -Recipients @("compliance@contoso.com") `
                -Subject "Urgent: Compliance Score Below Threshold" `
                -Priority "High"
        }
    },
    @{
        Trigger = "DataBreachDetected"
        Action = {
            # Initiate breach response protocol
            Invoke-BreachResponseProtocol
            
            # Lock down affected resources
            Set-EmergencyAccessControls -LockdownMode $true
            
            # Generate incident report
            New-IncidentReport -Type "DataBreach" -Severity "Critical"
        }
    },
    @{
        Trigger = "UnauthorizedAccessPattern"
        Action = {
            # Disable suspicious user accounts
            Disable-SuspiciousAccounts -Pattern "Multiple failed access attempts"
            
            # Increase monitoring sensitivity
            Set-MonitoringSensitivity -Level "High"
        }
    }
)

foreach ($rule in $automationRules) {
    Write-Host "  ✅ Automation rule: $($rule.Trigger)" -ForegroundColor Green
}

# Step 10: Generate monitoring report
Write-Host "`n[Step 10] Generating monitoring report" -ForegroundColor Yellow

$monitoringReport = @{
    Title = "Real-time Compliance Monitoring Report"
    Period = "Last 24 Hours"
    Metrics = @{
        AverageComplianceScore = 87.5
        TotalEvents = 1247
        Violations = 23
        CriticalAlerts = 2
        WarningAlerts = 15
    }
    TopIssues = @(
        "Unclassified personal data in SharePoint"
        "Expired access reviews for privileged users"
        "DLP policy violations in email"
    )
    Recommendations = @(
        "Enable automated data classification"
        "Implement quarterly access reviews"
        "Strengthen DLP policies for external sharing"
    )
}

Write-Host "`n📊 Monitoring Summary (Last 24 Hours)" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Gray
Write-Host "Average Compliance Score: $($monitoringReport.Metrics.AverageComplianceScore)%" -ForegroundColor Cyan
Write-Host "Total Events Monitored: $($monitoringReport.Metrics.TotalEvents)" -ForegroundColor White
Write-Host "Policy Violations: $($monitoringReport.Metrics.Violations)" -ForegroundColor Yellow
Write-Host "Critical Alerts: $($monitoringReport.Metrics.CriticalAlerts)" -ForegroundColor Red
Write-Host "Warning Alerts: $($monitoringReport.Metrics.WarningAlerts)" -ForegroundColor Yellow

Write-Host "`nTop Issues Detected:" -ForegroundColor Yellow
$monitoringReport.TopIssues | ForEach-Object {
    Write-Host "  - $_" -ForegroundColor Red
}

Write-Host "`nRecommendations:" -ForegroundColor Cyan
$monitoringReport.Recommendations | ForEach-Object {
    Write-Host "  • $_" -ForegroundColor White
}

# Step 11: Schedule regular monitoring reports
Write-Host "`n[Step 11] Scheduling automated reports" -ForegroundColor Yellow

Schedule-ComplianceReport -ReportName "Weekly Compliance Monitoring" `
    -Schedule "Weekly" `
    -Recipients @("compliance@contoso.com", "security@contoso.com") `
    -Frameworks @('GDPR', 'PCI_DSS', 'HIPAA') `
    -Format "PDF" `
    -Enabled

Write-Host "✅ Weekly monitoring report scheduled" -ForegroundColor Green

# Best practices for monitoring
Write-Host "`n📚 Monitoring Best Practices:" -ForegroundColor Cyan
Write-Host "1. Set realistic thresholds to avoid alert fatigue"
Write-Host "2. Implement automated responses for common issues"
Write-Host "3. Regular review and tuning of alert rules"
Write-Host "4. Correlate metrics across different data sources"
Write-Host "5. Maintain historical data for trend analysis"
Write-Host "6. Test incident response procedures regularly"
Write-Host "7. Document all automated actions for audit trails"

# Cleanup option
Write-Host "`n[Cleanup]" -ForegroundColor Yellow
$cleanup = Read-Host "Stop monitoring and cleanup? (Y/N)"
if ($cleanup -eq 'Y') {
    Stop-RealtimeMonitoring
    Write-Host "✅ Monitoring stopped" -ForegroundColor Green
}

# Helper functions for demonstration
function Get-MonitoringStatus { 
    return @{ 
        MetricsCount = 1247
        AlertsCount = 17
        LastUpdate = Get-Date
    } 
}

function Send-ComplianceNotification {
    param($Recipients, $Subject, $Priority)
    Write-Host "  📧 Notification sent to: $($Recipients -join ', ')" -ForegroundColor Gray
}

function Invoke-BreachResponseProtocol {
    Write-Host "  🚨 Breach response protocol initiated" -ForegroundColor Red
}

function Set-EmergencyAccessControls {
    param($LockdownMode)
    Write-Host "  🔒 Emergency access controls activated" -ForegroundColor Red
}

function New-IncidentReport {
    param($Type, $Severity)
    Write-Host "  📋 Incident report generated: $Type ($Severity)" -ForegroundColor Yellow
}

function Disable-SuspiciousAccounts {
    param($Pattern)
    Write-Host "  🚫 Suspicious accounts disabled based on: $Pattern" -ForegroundColor Yellow
}

function Set-MonitoringSensitivity {
    param($Level)
    Write-Host "  📡 Monitoring sensitivity set to: $Level" -ForegroundColor Yellow
}
