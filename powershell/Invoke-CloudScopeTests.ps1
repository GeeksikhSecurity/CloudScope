<#
.SYNOPSIS
    CloudScope Test Runner
    
.DESCRIPTION
    Runs Pester tests for CloudScope PowerShell modules with code coverage.
    
.PARAMETER Module
    Specific module to test. If not specified, tests all modules.
    
.PARAMETER OutputFormat
    Output format for test results (NUnitXml, JUnitXml, or HTML)
    
.PARAMETER CodeCoverage
    Enable code coverage analysis
    
.PARAMETER PassThru
    Return test results object
    
.EXAMPLE
    .\Invoke-CloudScopeTests.ps1
    
.EXAMPLE
    .\Invoke-CloudScopeTests.ps1 -Module CloudScope.Compliance -CodeCoverage
    
.NOTES
    File: Invoke-CloudScopeTests.ps1
    Author: CloudScope Team
    Version: 1.0.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet('CloudScope.Compliance', 'CloudScope.Graph', 'CloudScope.Monitoring', 'CloudScope.Reports', 'All')]
    [string]$Module = 'All',
    
    [Parameter(Mandatory = $false)]
    [ValidateSet('NUnitXml', 'JUnitXml', 'HTML')]
    [string]$OutputFormat = 'NUnitXml',
    
    [Parameter(Mandatory = $false)]
    [switch]$CodeCoverage = $true,
    
    [Parameter(Mandatory = $false)]
    [switch]$PassThru,
    
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = (Join-Path $PSScriptRoot 'TestResults'),
    
    [Parameter(Mandatory = $false)]
    [switch]$Detailed
)

# Ensure we have Pester
if (-not (Get-Module -ListAvailable -Name Pester | Where-Object { $_.Version -ge '5.0.0' })) {
    Write-Error "Pester 5.0 or higher is required. Install with: Install-Module -Name Pester -Force -SkipPublisherCheck"
    exit 1
}

Import-Module Pester -MinimumVersion 5.0

# Create output directory
if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
}

# Test paths
$modulePath = Join-Path $PSScriptRoot 'Modules'
$testsPath = Join-Path $PSScriptRoot 'Tests'

Write-Host @"
================================================
     CloudScope PowerShell Test Runner
================================================
"@ -ForegroundColor Cyan

Write-Host "Module: $Module" -ForegroundColor Yellow
Write-Host "Output Format: $OutputFormat" -ForegroundColor Yellow
Write-Host "Code Coverage: $CodeCoverage" -ForegroundColor Yellow
Write-Host "Output Path: $OutputPath" -ForegroundColor Yellow
Write-Host "================================================`n" -ForegroundColor Cyan

# Determine which tests to run
$testFiles = if ($Module -eq 'All') {
    Get-ChildItem -Path $testsPath -Filter '*.Tests.ps1' -File
} else {
    Get-ChildItem -Path $testsPath -Filter "$Module.Tests.ps1" -File
}

if ($testFiles.Count -eq 0) {
    Write-Error "No test files found for module: $Module"
    exit 1
}

Write-Host "Found $($testFiles.Count) test file(s)" -ForegroundColor Green

# Configure Pester
$pesterConfig = New-PesterConfiguration

# Run settings
$pesterConfig.Run.Path = $testFiles.FullName
$pesterConfig.Run.PassThru = $true

# Output settings
$pesterConfig.Output.Verbosity = if ($Detailed) { 'Detailed' } else { 'Normal' }

# Test result settings
$pesterConfig.TestResult.Enabled = $true
$pesterConfig.TestResult.OutputPath = Join-Path $OutputPath "TestResults-$(Get-Date -Format 'yyyyMMdd-HHmmss').$($OutputFormat.ToLower())"
$pesterConfig.TestResult.OutputFormat = $OutputFormat

# Code coverage settings
if ($CodeCoverage) {
    $coverageFiles = if ($Module -eq 'All') {
        Get-ChildItem -Path $modulePath -Include '*.psm1', '*.ps1' -Recurse | 
            Where-Object { $_.FullName -notmatch '\.Tests\.ps1$' }
    } else {
        Get-ChildItem -Path (Join-Path $modulePath $Module) -Include '*.psm1', '*.ps1' -Recurse |
            Where-Object { $_.FullName -notmatch '\.Tests\.ps1$' }
    }
    
    $pesterConfig.CodeCoverage.Enabled = $true
    $pesterConfig.CodeCoverage.Path = $coverageFiles.FullName
    $pesterConfig.CodeCoverage.OutputPath = Join-Path $OutputPath "Coverage-$(Get-Date -Format 'yyyyMMdd-HHmmss').xml"
    $pesterConfig.CodeCoverage.OutputFormat = 'JaCoCo'
}

# Run tests
Write-Host "`nRunning tests..." -ForegroundColor Yellow
$testResults = Invoke-Pester -Configuration $pesterConfig

# Display results
Write-Host "`n================================================" -ForegroundColor Cyan
Write-Host "Test Results Summary" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Cyan

Write-Host "Total Tests: $($testResults.TotalCount)" -ForegroundColor White
Write-Host "Passed: $($testResults.PassedCount)" -ForegroundColor Green
Write-Host "Failed: $($testResults.FailedCount)" -ForegroundColor $(if ($testResults.FailedCount -eq 0) { 'Green' } else { 'Red' })
Write-Host "Skipped: $($testResults.SkippedCount)" -ForegroundColor $(if ($testResults.SkippedCount -eq 0) { 'Green' } else { 'Yellow' })
Write-Host "Not Run: $($testResults.NotRunCount)" -ForegroundColor Gray

if ($CodeCoverage -and $testResults.CodeCoverage) {
    Write-Host "`nCode Coverage: $($testResults.CodeCoverage.CoveragePercent)%" -ForegroundColor $(
        if ($testResults.CodeCoverage.CoveragePercent -ge 80) { 'Green' }
        elseif ($testResults.CodeCoverage.CoveragePercent -ge 60) { 'Yellow' }
        else { 'Red' }
    )
    Write-Host "Covered Commands: $($testResults.CodeCoverage.CommandsExecutedCount) / $($testResults.CodeCoverage.CommandsAnalyzedCount)" -ForegroundColor White
}

Write-Host "`nDuration: $($testResults.Duration)" -ForegroundColor White
Write-Host "================================================" -ForegroundColor Cyan

# Show failed tests if any
if ($testResults.FailedCount -gt 0) {
    Write-Host "`nFailed Tests:" -ForegroundColor Red
    Write-Host "=============" -ForegroundColor Red
    
    $testResults.Failed | ForEach-Object {
        Write-Host "`n$($_.ExpandedPath)" -ForegroundColor Red
        Write-Host "Error: $($_.ErrorRecord.Exception.Message)" -ForegroundColor Red
        if ($Detailed) {
            Write-Host "Stack Trace:" -ForegroundColor Yellow
            Write-Host $_.ErrorRecord.ScriptStackTrace -ForegroundColor Gray
        }
    }
}

# Generate HTML report if requested
if ($OutputFormat -eq 'HTML' -or $Detailed) {
    $htmlPath = Join-Path $OutputPath "TestReport-$(Get-Date -Format 'yyyyMMdd-HHmmss').html"
    
    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>CloudScope Test Results</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .summary { background: #f0f0f0; padding: 15px; border-radius: 5px; }
        .passed { color: green; }
        .failed { color: red; }
        .skipped { color: orange; }
        table { border-collapse: collapse; width: 100%; margin-top: 20px; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #4CAF50; color: white; }
        tr:nth-child(even) { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <h1>CloudScope PowerShell Test Results</h1>
    <div class="summary">
        <h2>Summary</h2>
        <p>Date: $(Get-Date)</p>
        <p>Total Tests: $($testResults.TotalCount)</p>
        <p class="passed">Passed: $($testResults.PassedCount)</p>
        <p class="failed">Failed: $($testResults.FailedCount)</p>
        <p class="skipped">Skipped: $($testResults.SkippedCount)</p>
        <p>Duration: $($testResults.Duration)</p>
"@
    
    if ($CodeCoverage -and $testResults.CodeCoverage) {
        $html += "<p>Code Coverage: $($testResults.CodeCoverage.CoveragePercent)%</p>"
    }
    
    $html += @"
    </div>
    
    <h2>Test Details</h2>
    <table>
        <tr>
            <th>Test</th>
            <th>Result</th>
            <th>Duration</th>
            <th>Error</th>
        </tr>
"@
    
    foreach ($test in $testResults.Tests) {
        $resultClass = switch ($test.Result) {
            'Passed' { 'passed' }
            'Failed' { 'failed' }
            'Skipped' { 'skipped' }
            default { '' }
        }
        
        $html += @"
        <tr>
            <td>$($test.ExpandedPath)</td>
            <td class="$resultClass">$($test.Result)</td>
            <td>$($test.Duration)</td>
            <td>$(if ($test.ErrorRecord) { $test.ErrorRecord.Exception.Message } else { '-' })</td>
        </tr>
"@
    }
    
    $html += @"
    </table>
</body>
</html>
"@
    
    $html | Out-File -FilePath $htmlPath -Encoding UTF8
    Write-Host "`nHTML report generated: $htmlPath" -ForegroundColor Green
    
    if ($Detailed) {
        Start-Process $htmlPath
    }
}

# Save results summary
$summaryPath = Join-Path $OutputPath 'TestSummary.json'
@{
    Date = Get-Date
    Module = $Module
    TotalTests = $testResults.TotalCount
    Passed = $testResults.PassedCount
    Failed = $testResults.FailedCount
    Skipped = $testResults.SkippedCount
    Duration = $testResults.Duration.ToString()
    CodeCoverage = if ($testResults.CodeCoverage) { $testResults.CodeCoverage.CoveragePercent } else { 0 }
} | ConvertTo-Json | Out-File -FilePath $summaryPath -Encoding UTF8

Write-Host "`nTest files saved to: $OutputPath" -ForegroundColor Gray

# Return results if requested
if ($PassThru) {
    return $testResults
}

# Exit with appropriate code
exit $(if ($testResults.FailedCount -eq 0) { 0 } else { 1 })
