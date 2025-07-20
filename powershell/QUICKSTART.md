# CloudScope PowerShell Quick Start Guide

Get up and running with CloudScope compliance monitoring in under 10 minutes!

## 🚀 Quick Installation

```powershell
# Clone the repository
git clone https://github.com/your-org/cloudscope.git
cd cloudscope/powershell

# Run the setup script
./Setup-CloudScope.ps1
```

## 🔧 Initial Setup

### Step 1: Initialize CloudScope

```powershell
# Import the core module
Import-Module CloudScope.Core

# Initialize CloudScope
Initialize-CloudScope

# Connect to Microsoft services
Connect-CloudScopeServices
```

### Step 2: Configure Your Environment

```powershell
# Set your preferred compliance framework
Set-CloudScopeConfig -Setting "Compliance.DefaultFramework" -Value "GDPR"

# Enable monitoring
Set-CloudScopeConfig -Setting "Monitoring.Enabled" -Value $true
```

## 📊 Basic Compliance Check

### Run Your First Assessment

```powershell
# Quick compliance assessment
$assessment = Invoke-ComplianceAssessment -Framework GDPR

# View results
Write-Host "Compliance Score: $($assessment.ComplianceScore)%" -ForegroundColor $(
    if ($assessment.ComplianceScore -ge 80) { 'Green' } 
    elseif ($assessment.ComplianceScore -ge 60) { 'Yellow' } 
    else { 'Red' }
)
```

### Check for Compliance Violations

```powershell
# Get recent violations
$violations = Get-ComplianceViolations -Recent

if ($violations.Count -gt 0) {
    Write-Host "⚠️ Found $($violations.Count) compliance violations:" -ForegroundColor Yellow
    $violations | Format-Table Type, Description, Severity -AutoSize
} else {
    Write-Host "✅ No recent compliance violations!" -ForegroundColor Green
}
```

## 🏷️ Data Classification Example

```powershell
# Classify a sensitive file
$file = "C:\Data\customer_records.xlsx"
Set-DataClassification -Path $file -Classification Personal -Framework GDPR

# Search for unclassified sensitive data
$sensitiveData = Get-SensitiveDataLocations -DataType Personal -Scope OneDrive
Write-Host "Found $($sensitiveData.TotalLocations) locations with personal data"
```

## 📈 Real-time Monitoring

### Set Up Basic Monitoring

```powershell
# Initialize monitoring
Initialize-ComplianceMonitoring

# Configure alert rules
Set-AlertingRules -RuleName "ComplianceScore" -Threshold 80 -Operator "LessThan" -Severity "Warning"
Set-AlertingRules -RuleName "ViolationCount" -Threshold 5 -Operator "GreaterThan" -Severity "Error"

# Start monitoring
Start-RealtimeMonitoring -IntervalSeconds 300
```

## 💰 Cost Optimization

### Analyze Cost Impact

```powershell
# Get compliance cost impact
$costImpact = Get-ComplianceCostImpact -Framework GDPR

# Get optimization recommendations
$recommendations = Get-OptimizationRecommendations -IncludeComplianceImpact

# View recommendations
$recommendations | Format-Table Name, PotentialSavings, ComplianceImpact -AutoSize
```

## 📊 Visualization

### Create Interactive Visualizations

```powershell
# Generate compliance mindmap
New-ComplianceVisualization -Data $assessment -Type MindMap -Path "./compliance-map.html"

# Create interactive dashboard
New-ComplianceDashboard -Framework GDPR -Interactive

# Visualize CSV data
$csvPath = "./compliance-data.csv"
Show-CSVVisualization -Path $csvPath -VisualizationType "BarChart"
```

## 📑 Generate Reports

### Create an Executive Summary

```powershell
# Generate executive compliance report
$report = New-ExecutiveSummary -Title "Monthly Compliance Status" -Period "Last 30 Days" -OpenAfterCreation

# Generate detailed framework report
New-FrameworkReport -Framework GDPR -IncludeEvidence -IncludeRemediation
```

## 🔄 Common Workflows

### Daily Compliance Check

```powershell
# Save as DailyComplianceCheck.ps1
param(
    [string]$Framework = "GDPR"
)

# Initialize
Import-Module CloudScope.Core
Initialize-CloudScope
Connect-CloudScopeServices

# Run checks
Write-Host "`n🔍 Running daily compliance check for $Framework..." -ForegroundColor Cyan

# 1. Check compliance score
$assessment = Invoke-ComplianceAssessment -Framework $Framework
$score = $assessment.ComplianceScore

# 2. Check for new violations
$violations = Get-ComplianceViolations -Recent -Hours 24

# 3. Check high-risk users
$users = Get-ComplianceUsers -IncludeRiskState
$highRiskUsers = $users | Where-Object { $_.RiskState.RiskLevel -eq 'High' }

# 4. Check unclassified data
$unclassifiedData = Get-SensitiveDataLocations -DataType All -Scope All
$unclassifiedCount = ($unclassifiedData.Locations | Where-Object { -not $_.Classification }).Count

# Report results
Write-Host "`n📊 Daily Compliance Summary" -ForegroundColor Green
Write-Host "=========================" -ForegroundColor Gray
Write-Host "Compliance Score: $score%" -ForegroundColor $(if ($score -ge 80) { 'Green' } else { 'Red' })
Write-Host "New Violations: $($violations.Count)" -ForegroundColor $(if ($violations.Count -eq 0) { 'Green' } else { 'Red' })
Write-Host "High Risk Users: $($highRiskUsers.Count)" -ForegroundColor $(if ($highRiskUsers.Count -eq 0) { 'Green' } else { 'Yellow' })
Write-Host "Unclassified Data: $unclassifiedCount items" -ForegroundColor $(if ($unclassifiedCount -eq 0) { 'Green' } else { 'Yellow' })

# Generate visualization if issues found
if ($score -lt 80 -or $violations.Count -gt 0) {
    New-ComplianceVisualization -Data $assessment -Type "Dashboard" -Path "./compliance-alert.html"
}
```

## 💡 Tips and Best Practices

1. **Start with one framework** - Master one compliance framework before adding others
2. **Enable monitoring early** - Set up real-time monitoring to catch issues immediately
3. **Automate classifications** - Use bulk classification scripts for existing data
4. **Schedule regular assessments** - Daily quick checks, weekly detailed assessments
5. **Review high-risk items first** - Focus remediation efforts on critical issues
6. **Optimize costs** - Use FinOps recommendations to reduce cloud spending while maintaining compliance
7. **Visualize findings** - Use interactive visualizations to communicate compliance status effectively

## 🆘 Getting Help

```powershell
# Get help for any command
Get-Help Initialize-CloudScope -Full
Get-Help Set-DataClassification -Examples

# List all CloudScope commands
Get-Command -Module CloudScope.*

# Check module versions
Get-Module CloudScope.* -ListAvailable | Format-Table Name, Version
```

## 📚 Next Steps

1. **Deep Dive**: Review the [full documentation](../README.md)
2. **Customize**: Create custom compliance policies for your organization
3. **Integrate**: Connect CloudScope with your existing security tools
4. **Automate**: Set up scheduled tasks for continuous compliance
5. **Visualize**: Create custom dashboards for your compliance needs

## 🚨 Quick Troubleshooting

```powershell
# Connection issues?
Disconnect-MgGraph
Connect-CloudScopeServices -DeviceCode

# Module not loading?
Import-Module CloudScope.Core -Force -Verbose

# Need to see what's happening?
$VerbosePreference = 'Continue'
Initialize-CloudScope -Verbose
```

---

**Ready for more?** Check out our [example scripts](Examples/) for advanced scenarios and automation patterns.