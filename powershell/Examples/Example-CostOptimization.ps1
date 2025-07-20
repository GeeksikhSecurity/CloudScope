<#
.SYNOPSIS
    Example script for CloudScope FinOps integration
    
.DESCRIPTION
    This script demonstrates how to use CloudScope.FinOps module to optimize
    costs while maintaining compliance requirements.
    
.EXAMPLE
    .\Example-CostOptimization.ps1
    
    Analyzes compliance costs and provides optimization recommendations
    
.NOTES
    File: Example-CostOptimization.ps1
    Author: CloudScope Team
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Framework = "GDPR",
    
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroup,
    
    [Parameter(Mandatory = $false)]
    [switch]$ApplyRecommendations
)

# Import required modules
Import-Module CloudScope.Core
Import-Module CloudScope.Compliance
Import-Module CloudScope.FinOps

# Initialize CloudScope
Write-Host "🚀 Initializing CloudScope..." -ForegroundColor Cyan
Initialize-CloudScope

# Connect to Microsoft services
Write-Host "🔑 Connecting to Microsoft services..." -ForegroundColor Cyan
Connect-CloudScopeServices

# Analyze compliance cost impact
Write-Host "💰 Analyzing compliance cost impact for $Framework..." -ForegroundColor Cyan
$costImpact = Get-ComplianceCostImpact -Framework $Framework -ResourceGroup $ResourceGroup

# Display cost impact summary
Write-Host "`n📊 Compliance Cost Impact Summary:" -ForegroundColor Cyan
Write-Host "  Framework: $Framework" -ForegroundColor White
Write-Host "  Total Monthly Cost: $($costImpact.TotalMonthlyCost) USD" -ForegroundColor White
Write-Host "  Compliance-Related Cost: $($costImpact.ComplianceRelatedCost) USD ($($costImpact.CompliancePercentage)%)" -ForegroundColor White
Write-Host "  Optimization Potential: $($costImpact.OptimizationPotential) USD" -ForegroundColor Green

# Display cost breakdown by category
Write-Host "`n📊 Cost Breakdown by Category:" -ForegroundColor Cyan
foreach ($category in $costImpact.Categories) {
    Write-Host "  $($category.Name): $($category.Cost) USD ($($category.Percentage)%)" -ForegroundColor White
}

# Get optimization recommendations
Write-Host "`n💡 Getting optimization recommendations..." -ForegroundColor Cyan
$recommendations = Get-OptimizationRecommendations -IncludeComplianceImpact -ResourceGroup $ResourceGroup

# Display optimization recommendations
Write-Host "`n📋 Optimization Recommendations:" -ForegroundColor Cyan
foreach ($recommendation in $recommendations) {
    $impactColor = switch ($recommendation.ComplianceImpact) {
        'None' { 'Green' }
        'Low' { 'Green' }
        'Medium' { 'Yellow' }
        'High' { 'Red' }
        default { 'White' }
    }
    
    Write-Host "  $($recommendation.Name)" -ForegroundColor White
    Write-Host "    Potential Savings: $($recommendation.PotentialSavings) USD/month" -ForegroundColor Green
    Write-Host "    Compliance Impact: $($recommendation.ComplianceImpact)" -ForegroundColor $impactColor
    Write-Host "    Description: $($recommendation.Description)" -ForegroundColor Gray
}

# Create compliance budget
Write-Host "`n💰 Creating compliance budget..." -ForegroundColor Cyan
$budget = New-ComplianceBudget -Framework $Framework -Amount $costImpact.ComplianceRelatedCost -Period "Monthly"
Write-Host "  Budget created: $($budget.Name)" -ForegroundColor Green
Write-Host "  Amount: $($budget.Amount) USD/month" -ForegroundColor White
Write-Host "  Start Date: $($budget.StartDate)" -ForegroundColor White
Write-Host "  Alerts: $($budget.AlertThresholds -join ', ')% of budget" -ForegroundColor White

# Get compliance cost forecast
Write-Host "`n📈 Getting compliance cost forecast..." -ForegroundColor Cyan
$forecast = Get-ComplianceCostForecast -Framework $Framework -Months 6
Write-Host "  Current Month: $($forecast.CurrentMonth) USD" -ForegroundColor White
Write-Host "  6-Month Forecast: $($forecast.SixMonthTotal) USD" -ForegroundColor White
Write-Host "  Trend: $($forecast.Trend)" -ForegroundColor $(if ($forecast.Trend -eq 'Increasing') { 'Red' } elseif ($forecast.Trend -eq 'Decreasing') { 'Green' } else { 'Yellow' })

# Apply optimization recommendations if requested
if ($ApplyRecommendations) {
    Write-Host "`n🔧 Applying optimization recommendations..." -ForegroundColor Cyan
    
    # Filter recommendations with no or low compliance impact
    $safeRecommendations = $recommendations | Where-Object { $_.ComplianceImpact -in @('None', 'Low') }
    
    if ($safeRecommendations.Count -gt 0) {
        $result = Invoke-ResourceOptimization -Recommendations $safeRecommendations -ComplianceCheck
        
        Write-Host "  Applied $($result.SuccessCount) of $($safeRecommendations.Count) recommendations" -ForegroundColor Green
        Write-Host "  Estimated monthly savings: $($result.EstimatedSavings) USD" -ForegroundColor Green
        
        if ($result.FailedCount -gt 0) {
            Write-Host "  Failed to apply $($result.FailedCount) recommendations" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  No safe recommendations found to apply" -ForegroundColor Yellow
    }
}

Write-Host "`n✅ Cost optimization analysis completed!" -ForegroundColor Green