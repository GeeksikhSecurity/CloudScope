<#
.SYNOPSIS
    Example script for CloudScope visualizations
    
.DESCRIPTION
    This script demonstrates how to use CloudScope.Visualization module to create
    interactive visualizations for compliance data without third-party dependencies.
    
.EXAMPLE
    .\Example-Visualizations.ps1
    
    Creates various visualizations for compliance data
    
.NOTES
    File: Example-Visualizations.ps1
    Author: CloudScope Team
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "./visualizations",
    
    [Parameter(Mandatory = $false)]
    [switch]$OpenInBrowser
)

# Import required modules
Import-Module CloudScope.Core
Import-Module CloudScope.Compliance
Import-Module CloudScope.Visualization

# Initialize CloudScope
Write-Host "🚀 Initializing CloudScope..." -ForegroundColor Cyan
Initialize-CloudScope

# Create output directory if it doesn't exist
if (-not (Test-Path -Path $OutputPath)) {
    New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
}

# Sample compliance data (normally this would come from an assessment)
$complianceData = @{
    Framework = "GDPR"
    ComplianceScore = 78.5
    Categories = @(
        @{
            Name = "Data Protection"
            Score = 85
            Findings = @(
                @{ Check = "Encryption at Rest"; Status = "Pass"; Severity = "High" }
                @{ Check = "Encryption in Transit"; Status = "Pass"; Severity = "High" }
                @{ Check = "Data Minimization"; Status = "Fail"; Severity = "Medium" }
            )
        },
        @{
            Name = "Data Subject Rights"
            Score = 70
            Findings = @(
                @{ Check = "Right to Access"; Status = "Pass"; Severity = "High" }
                @{ Check = "Right to Erasure"; Status = "Fail"; Severity = "High" }
                @{ Check = "Right to Portability"; Status = "Fail"; Severity = "Medium" }
            )
        },
        @{
            Name = "Consent Management"
            Score = 90
            Findings = @(
                @{ Check = "Consent Records"; Status = "Pass"; Severity = "High" }
                @{ Check = "Consent Withdrawal"; Status = "Pass"; Severity = "Medium" }
                @{ Check = "Child Consent"; Status = "Pass"; Severity = "High" }
            )
        },
        @{
            Name = "Breach Notification"
            Score = 65
            Findings = @(
                @{ Check = "Breach Detection"; Status = "Pass"; Severity = "High" }
                @{ Check = "Breach Response Plan"; Status = "Fail"; Severity = "High" }
                @{ Check = "72-Hour Notification"; Status = "Fail"; Severity = "High" }
            )
        }
    )
}

# 1. Create a compliance mindmap
Write-Host "📊 Creating compliance mindmap..." -ForegroundColor Cyan
$mindmapPath = Join-Path $OutputPath "compliance-mindmap.html"
New-ComplianceVisualization -Data $complianceData -Type MindMap -Path $mindmapPath
Write-Host "  Mindmap saved to: $mindmapPath" -ForegroundColor Green

# 2. Create a compliance dashboard
Write-Host "📊 Creating compliance dashboard..." -ForegroundColor Cyan
$dashboardPath = Join-Path $OutputPath "compliance-dashboard.html"
New-ComplianceDashboard -Data $complianceData -Path $dashboardPath -Interactive
Write-Host "  Dashboard saved to: $dashboardPath" -ForegroundColor Green

# 3. Create a compliance heatmap
Write-Host "📊 Creating compliance heatmap..." -ForegroundColor Cyan
$heatmapPath = Join-Path $OutputPath "compliance-heatmap.html"
New-ComplianceVisualization -Data $complianceData -Type Heatmap -Path $heatmapPath
Write-Host "  Heatmap saved to: $heatmapPath" -ForegroundColor Green

# 4. Create a findings tree
Write-Host "📊 Creating findings tree..." -ForegroundColor Cyan
$treePath = Join-Path $OutputPath "findings-tree.html"
New-ComplianceVisualization -Data $complianceData.Categories -Type Tree -Path $treePath
Write-Host "  Tree visualization saved to: $treePath" -ForegroundColor Green

# 5. Create a CSV file and visualize it
Write-Host "📊 Creating CSV visualization..." -ForegroundColor Cyan
$csvPath = Join-Path $OutputPath "compliance-data.csv"

# Create CSV file
"Category,Score,Status" | Out-File -FilePath $csvPath
foreach ($category in $complianceData.Categories) {
    "$($category.Name),$($category.Score),$([Math]::Round($category.Score / 100 * $category.Findings.Count))" | Add-Content -Path $csvPath
}

# Visualize CSV
$csvVisualizationPath = Join-Path $OutputPath "csv-visualization.html"
Show-CSVVisualization -Path $csvPath -VisualizationType "BarChart" -OutputPath $csvVisualizationPath
Write-Host "  CSV visualization saved to: $csvVisualizationPath" -ForegroundColor Green

# 6. Create a JSON file and visualize it
Write-Host "📊 Creating JSON visualization..." -ForegroundColor Cyan
$jsonPath = Join-Path $OutputPath "compliance-data.json"

# Create JSON file
$complianceData | ConvertTo-Json -Depth 5 | Out-File -FilePath $jsonPath

# Visualize JSON
$jsonVisualizationPath = Join-Path $OutputPath "json-visualization.html"
Show-JSONVisualization -Path $jsonPath -VisualizationType "TreeMap" -OutputPath $jsonVisualizationPath
Write-Host "  JSON visualization saved to: $jsonVisualizationPath" -ForegroundColor Green

# 7. Create an interactive report
Write-Host "📊 Creating interactive report..." -ForegroundColor Cyan
$reportPath = Join-Path $OutputPath "interactive-report.html"
ConvertTo-InteractiveReport -Data $complianceData -OutputPath $reportPath
Write-Host "  Interactive report saved to: $reportPath" -ForegroundColor Green

# Open visualizations in browser if requested
if ($OpenInBrowser) {
    Write-Host "`n🌐 Opening visualizations in browser..." -ForegroundColor Cyan
    Start-Process $mindmapPath
    Start-Process $dashboardPath
    Start-Process $reportPath
}

Write-Host "`n✅ All visualizations created successfully!" -ForegroundColor Green
Write-Host "  Output directory: $OutputPath" -ForegroundColor Green