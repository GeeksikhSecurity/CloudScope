<#
.SYNOPSIS
    Example script for GDPR compliance assessment
    
.DESCRIPTION
    This script demonstrates how to use CloudScope to perform a GDPR compliance
    assessment, identify issues, and generate reports.
    
.EXAMPLE
    .\Example-GDPRComplianceCheck.ps1
    
    Runs a GDPR compliance assessment and generates a report
    
.NOTES
    File: Example-GDPRComplianceCheck.ps1
    Author: CloudScope Team
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$GenerateReport,
    
    [Parameter(Mandatory = $false)]
    [switch]$IncludeVisualization
)

# Import required modules
Import-Module CloudScope.Core
Import-Module CloudScope.Compliance
Import-Module CloudScope.Graph
Import-Module CloudScope.Reports
if ($IncludeVisualization) {
    Import-Module CloudScope.Visualization
}

# Initialize CloudScope
Write-Host "🚀 Initializing CloudScope..." -ForegroundColor Cyan
Initialize-CloudScope

# Connect to Microsoft services
Write-Host "🔑 Connecting to Microsoft services..." -ForegroundColor Cyan
Connect-CloudScopeServices

# Set GDPR-specific configuration
Write-Host "⚙️ Configuring GDPR settings..." -ForegroundColor Cyan
Set-GDPRCompliance -LawfulBasis "Consent" -RetentionDays 365 -EnablePseudonymization

# Run GDPR compliance assessment
Write-Host "🔍 Running GDPR compliance assessment..." -ForegroundColor Cyan
$assessment = Invoke-ComplianceAssessment -Framework GDPR

# Display compliance score
$scoreColor = if ($assessment.ComplianceScore -ge 80) { 'Green' } 
              elseif ($assessment.ComplianceScore -ge 60) { 'Yellow' } 
              else { 'Red' }
Write-Host "`n📊 GDPR Compliance Score: $($assessment.ComplianceScore)%" -ForegroundColor $scoreColor

# Display findings by category
$categories = $assessment.Findings | Group-Object -Property Category

Write-Host "`n📋 Findings by Category:" -ForegroundColor Cyan
foreach ($category in $categories) {
    $categoryColor = if ($category.Group.Count -gt 5) { 'Red' } 
                    elseif ($category.Group.Count -gt 2) { 'Yellow' } 
                    else { 'Green' }
    Write-Host "  $($category.Name): $($category.Group.Count) findings" -ForegroundColor $categoryColor
}

# Display top critical findings
$criticalFindings = $assessment.Findings | Where-Object { $_.Severity -eq 'Critical' }
if ($criticalFindings.Count -gt 0) {
    Write-Host "`n⚠️ Critical Findings:" -ForegroundColor Red
    $criticalFindings | Select-Object -First 5 | ForEach-Object {
        Write-Host "  - $($_.Check): $($_.Description)" -ForegroundColor Red
    }
    
    if ($criticalFindings.Count -gt 5) {
        Write-Host "  ... and $($criticalFindings.Count - 5) more" -ForegroundColor Red
    }
}

# Check for data subject rights implementation
Write-Host "`n👤 Data Subject Rights:" -ForegroundColor Cyan
$dsrChecks = $assessment.Results | Where-Object { $_.Check -like "*Data Subject*" }
$dsrChecks | ForEach-Object {
    $statusColor = if ($_.Status -eq 'Pass') { 'Green' } else { 'Red' }
    Write-Host "  - $($_.Check): $($_.Status)" -ForegroundColor $statusColor
}

# Check for personal data inventory
Write-Host "`n📁 Personal Data Inventory:" -ForegroundColor Cyan
$dataInventory = Get-SensitiveDataLocations -DataType Personal -Scope All
Write-Host "  Found $($dataInventory.TotalLocations) locations with personal data" -ForegroundColor Yellow
Write-Host "  High-risk locations: $($dataInventory.HighRiskLocations.Count)" -ForegroundColor $(if ($dataInventory.HighRiskLocations.Count -gt 0) { 'Red' } else { 'Green' })

# Generate report if requested
if ($GenerateReport) {
    Write-Host "`n📄 Generating GDPR compliance report..." -ForegroundColor Cyan
    $reportPath = New-FrameworkReport -Framework GDPR -Assessment $assessment -IncludeEvidence -IncludeRemediation
    Write-Host "  Report saved to: $reportPath" -ForegroundColor Green
}

# Generate visualization if requested
if ($IncludeVisualization) {
    Write-Host "`n📊 Generating compliance visualization..." -ForegroundColor Cyan
    $visualizationPath = New-ComplianceVisualization -Data $assessment -Type MindMap -Path "./GDPR-Compliance-Map.html"
    Write-Host "  Visualization saved to: $visualizationPath" -ForegroundColor Green
    
    # Open visualization in browser
    if (Test-Path $visualizationPath) {
        Start-Process $visualizationPath
    }
}

# Provide remediation guidance
Write-Host "`n🔧 Remediation Guidance:" -ForegroundColor Cyan
Write-Host "  1. Address critical findings first" -ForegroundColor White
Write-Host "  2. Implement missing data subject rights processes" -ForegroundColor White
Write-Host "  3. Classify and protect high-risk personal data" -ForegroundColor White
Write-Host "  4. Document lawful basis for processing" -ForegroundColor White
Write-Host "  5. Implement data retention policies" -ForegroundColor White

Write-Host "`n✅ GDPR compliance assessment completed!" -ForegroundColor Green