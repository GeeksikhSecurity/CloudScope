# CloudScope PowerShell Quick Start Guide

Get up and running with CloudScope compliance monitoring in under 10 minutes!

## 🚀 Quick Installation

```powershell
# Install CloudScope modules from PowerShell Gallery
Install-Module -Name CloudScope.Compliance, CloudScope.Graph, CloudScope.Monitoring, CloudScope.Reports -Force

# Import modules
Import-Module CloudScope.Compliance, CloudScope.Graph, CloudScope.Monitoring, CloudScope.Reports
```

## 🔧 Initial Setup

### Step 1: Initialize CloudScope

```powershell
# Initialize with your preferred compliance framework
Initialize-CloudScopeCompliance -Framework GDPR

# Connect to Microsoft Graph
Connect-CloudScopeGraph
```

### Step 2: Configure Your Environment

```powershell
# Set your Key Vault for encryption (optional but recommended)
$env:CLOUDSCOPE_KEYVAULT_NAME = "your-keyvault-name"

# Configure compliance settings for GDPR
Set-GDPRCompliance -LawfulBasis "Legitimate Interest" -RetentionDays 365
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
# Initialize monitoring (requires Azure subscription)
Initialize-ComplianceMonitoring -WorkspaceName "CloudScope-Monitoring" `
    -ResourceGroup "rg-compliance" `
    -CreateIfNotExists

# Configure alert rules
Set-AlertingRules -RuleName "ComplianceScore" -Threshold 80 -Operator "LessThan" -Severity "Warning"
Set-AlertingRules -RuleName "ViolationCount" -Threshold 5 -Operator "GreaterThan" -Severity "Error"

# Start monitoring
Start-RealtimeMonitoring -IntervalSeconds 300
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
Initialize-CloudScopeCompliance -Framework $Framework
Connect-CloudScopeGraph

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

# Generate report if issues found
if ($score -lt 80 -or $violations.Count -gt 0) {
    New-ComplianceReport -ReportName "Daily-Compliance-Alert" -Framework $Framework -Format HTML
}
```

### Automated Remediation

```powershell
# Auto-remediate common issues
.\Scripts\Automation\Invoke-ComplianceRemediation.ps1 -RemediationType All -WhatIf

# If results look good, run without WhatIf
.\Scripts\Automation\Invoke-ComplianceRemediation.ps1 -RemediationType All -Force
```

### Schedule Weekly Reports

```powershell
# Schedule automated weekly compliance report
Schedule-ComplianceReport -ReportName "Weekly Compliance Summary" `
    -Schedule Weekly `
    -Recipients @("compliance@company.com", "security@company.com") `
    -Frameworks @('GDPR', 'PCI_DSS') `
    -Format PDF
```

## 🎯 Framework-Specific Quick Starts

### GDPR Compliance

```powershell
# GDPR-specific setup
Set-GDPRCompliance -LawfulBasis "Consent" -RetentionDays 365 -EnablePseudonymization

# Check data subject rights
$assessment = Invoke-ComplianceAssessment -Framework GDPR
$dsrChecks = $assessment.Results | Where-Object { $_.Check -like "*Data Subject*" }
$dsrChecks | Format-Table Check, Status -AutoSize
```

### PCI DSS Compliance

```powershell
# PCI DSS setup
Set-PCICompliance -EnablePANMasking -EnableTokenization -KeyRotationDays 90

# Check payment data security
$paymentData = Get-SensitiveDataLocations -DataType Payment -Scope All
Write-Host "Payment data locations: $($paymentData.TotalLocations)"
```

### HIPAA Compliance

```powershell
# HIPAA setup
Set-HIPAACompliance -EnableMinimumNecessary -AuditRetentionYears 6

# Check PHI protection
$phiData = Get-SensitiveDataLocations -DataType Health -Scope All
$phiData.Locations | Where-Object { $_.RiskLevel -eq 'High' } | Format-Table Path, RiskLevel
```

## 💡 Tips and Best Practices

1. **Start with one framework** - Master one compliance framework before adding others
2. **Enable monitoring early** - Set up real-time monitoring to catch issues immediately
3. **Automate classifications** - Use bulk classification scripts for existing data
4. **Schedule regular assessments** - Daily quick checks, weekly detailed assessments
5. **Review high-risk items first** - Focus remediation efforts on critical issues

## 🆘 Getting Help

```powershell
# Get help for any command
Get-Help Initialize-CloudScopeCompliance -Full
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
4. **Automate**: Set up Azure Automation for continuous compliance
5. **Scale**: Deploy across your entire Microsoft 365 environment

## 🚨 Quick Troubleshooting

```powershell
# Connection issues?
Disconnect-MgGraph
Connect-CloudScopeGraph -UseDeviceCode

# Module not loading?
Import-Module CloudScope.Compliance -Force -Verbose

# Need to see what's happening?
$VerbosePreference = 'Continue'
Initialize-CloudScopeCompliance -Framework GDPR -Verbose
```

---

**Ready for more?** Check out our [example scripts](Scripts/Examples/) for advanced scenarios and automation patterns.
