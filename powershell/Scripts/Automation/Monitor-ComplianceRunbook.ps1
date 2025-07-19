<#
.SYNOPSIS
    Azure Automation Runbook for Continuous Compliance Monitoring
    
.DESCRIPTION
    This runbook performs automated compliance checks across Microsoft 365
    and Azure environments, generating alerts for violations.
    
.NOTES
    File: Monitor-ComplianceRunbook.ps1
    Author: CloudScope Team
    Version: 1.0.0
    
    Required Azure Automation Assets:
    - Modules: CloudScope.Compliance, CloudScope.Graph, Az.Accounts
    - Credentials: AutomationCredential
    - Variables: TenantId, SubscriptionId, ComplianceOfficerEmail
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$Framework = "All",
    
    [Parameter(Mandatory = $false)]
    [int]$ThresholdScore = 80,
    
    [Parameter(Mandatory = $false)]
    [switch]$SendAlerts = $true
)

# Import required modules
Import-Module CloudScope.Compliance -Force
Import-Module CloudScope.Graph -Force
Import-Module CloudScope.Monitoring -Force

# Authenticate using Automation RunAs account
try {
    Write-Output "Authenticating to Azure..."
    
    $connection = Get-AutomationConnection -Name AzureRunAsConnection
    $certificateThumbprint = $connection.CertificateThumbprint
    $tenantId = $connection.TenantId
    $applicationId = $connection.ApplicationId
    $subscriptionId = $connection.SubscriptionId
    
    # Connect to Azure
    Connect-AzAccount -ServicePrincipal `
        -TenantId $tenantId `
        -ApplicationId $applicationId `
        -CertificateThumbprint $certificateThumbprint
    
    Set-AzContext -SubscriptionId $subscriptionId
    
    Write-Output "Successfully authenticated to Azure"
}
catch {
    Write-Error "Failed to authenticate: $($_.Exception.Message)"
    throw
}

# Initialize CloudScope
try {
    Write-Output "Initializing CloudScope Compliance Framework..."
    
    Initialize-CloudScopeCompliance -TenantId $tenantId -Framework GDPR -EnableMonitoring
    Connect-CloudScopeGraph -TenantId $tenantId -UseDeviceCode:$false
    
    Write-Output "CloudScope initialized successfully"
}
catch {
    Write-Error "Failed to initialize CloudScope: $($_.Exception.Message)"
    throw
}

# Function to perform compliance checks
function Invoke-ComplianceChecks {
    param(
        [string]$Framework
    )
    
    $results = @{
        Timestamp = Get-Date
        Framework = $Framework
        Passed = @()
        Failed = @()
        Score = 0
        Violations = @()
    }
    
    Write-Output "Running compliance checks for: $Framework"
    
    try {
        # Run assessment
        if ($Framework -eq "All") {
            $frameworks = @('GDPR', 'PCI_DSS', 'HIPAA', 'SOC2')
            $overallScore = 0
            
            foreach ($fw in $frameworks) {
                $assessment = Invoke-ComplianceAssessment -Framework $fw
                $results.Passed += $assessment.Results | Where-Object { $_.Status -eq 'Pass' }
                $results.Failed += $assessment.Results | Where-Object { $_.Status -eq 'Fail' }
                $overallScore += $assessment.ComplianceScore
            }
            
            $results.Score = [math]::Round($overallScore / $frameworks.Count, 2)
        }
        else {
            $assessment = Invoke-ComplianceAssessment -Framework $Framework
            $results.Passed = $assessment.Results | Where-Object { $_.Status -eq 'Pass' }
            $results.Failed = $assessment.Results | Where-Object { $_.Status -eq 'Fail' }
            $results.Score = $assessment.ComplianceScore
        }
        
        # Get recent violations
        $results.Violations = Get-ComplianceViolations -Recent -Hours 24
        
        return $results
    }
    catch {
        Write-Error "Compliance check failed: $($_.Exception.Message)"
        throw
    }
}

# Function to check specific compliance areas
function Test-ComplianceAreas {
    $areas = @()
    
    # Check user compliance
    Write-Output "Checking user compliance..."
    $users = Get-ComplianceUsers -IncludeRiskState
    $highRiskUsers = $users | Where-Object { $_.RiskState.RiskLevel -eq 'High' }
    
    if ($highRiskUsers.Count -gt 0) {
        $areas += @{
            Area = "User Risk"
            Status = "Failed"
            Message = "$($highRiskUsers.Count) high-risk users detected"
            Details = $highRiskUsers | Select-Object UserPrincipalName, RiskState
        }
    }
    
    # Check data classification
    Write-Output "Checking data classification..."
    $dataLocations = Get-SensitiveDataLocations -DataType 'Personal' -Scope 'All'
    $unclassifiedCount = $dataLocations.Locations | Where-Object { -not $_.Classification }
    
    if ($unclassifiedCount.Count -gt 0) {
        $areas += @{
            Area = "Data Classification"
            Status = "Failed"
            Message = "$($unclassifiedCount.Count) locations with unclassified personal data"
            Details = $unclassifiedCount | Select-Object -First 10
        }
    }
    
    # Check DLP policies
    Write-Output "Checking DLP policies..."
    $dlpPolicies = Get-DLPPolicies
    $disabledPolicies = $dlpPolicies | Where-Object { $_.Enabled -eq $false }
    
    if ($disabledPolicies.Count -gt 0) {
        $areas += @{
            Area = "DLP Policies"
            Status = "Warning"
            Message = "$($disabledPolicies.Count) DLP policies are disabled"
            Details = $disabledPolicies | Select-Object Name, Workload
        }
    }
    
    # Check security alerts
    Write-Output "Checking security alerts..."
    $alerts = Get-ComplianceAlerts -Severity 'Critical' -Status 'Active'
    
    if ($alerts.Count -gt 0) {
        $areas += @{
            Area = "Security Alerts"
            Status = "Critical"
            Message = "$($alerts.Count) critical security alerts active"
            Details = $alerts | Select-Object Title, CreatedDateTime
        }
    }
    
    return $areas
}

# Main execution
try {
    Write-Output "Starting compliance monitoring run at $(Get-Date)"
    
    # Perform compliance checks
    $complianceResults = Invoke-ComplianceChecks -Framework $Framework
    
    # Check specific areas
    $areaResults = Test-ComplianceAreas
    
    # Create metrics
    $metrics = @{
        ComplianceScore = $complianceResults.Score
        TotalChecks = $complianceResults.Passed.Count + $complianceResults.Failed.Count
        PassedChecks = $complianceResults.Passed.Count
        FailedChecks = $complianceResults.Failed.Count
        ViolationCount = $complianceResults.Violations.Count
        CriticalIssues = ($areaResults | Where-Object { $_.Status -eq 'Critical' }).Count
    }
    
    # Send metrics to Azure Monitor
    foreach ($metric in $metrics.GetEnumerator()) {
        $complianceMetric = New-ComplianceMetric -Name $metric.Key -Value $metric.Value -Category "Automated Monitoring"
        Send-ComplianceMetric -Metric $complianceMetric
    }
    
    # Check thresholds and create alerts
    if ($complianceResults.Score -lt $ThresholdScore) {
        $alertMessage = "Compliance score below threshold: $($complianceResults.Score)% (Threshold: $ThresholdScore%)"
        
        if ($SendAlerts) {
            New-ComplianceAlert -Title "Low Compliance Score Alert" `
                -Description $alertMessage `
                -Severity "Warning" `
                -Properties @{
                    Score = $complianceResults.Score
                    Threshold = $ThresholdScore
                    Framework = $Framework
                }
        }
    }
    
    # Create alerts for critical issues
    foreach ($area in $areaResults | Where-Object { $_.Status -in @('Critical', 'Failed') }) {
        if ($SendAlerts) {
            New-ComplianceAlert -Title "Compliance Issue: $($area.Area)" `
                -Description $area.Message `
                -Severity $area.Status `
                -Properties @{
                    Area = $area.Area
                    Details = $area.Details | ConvertTo-Json -Compress
                }
        }
    }
    
    # Generate summary output
    $summary = @"
Compliance Monitoring Summary
============================
Timestamp: $(Get-Date)
Framework: $Framework
Overall Score: $($complianceResults.Score)%
Status: $(if ($complianceResults.Score -ge $ThresholdScore) { "COMPLIANT" } else { "NON-COMPLIANT" })

Metrics:
- Total Checks: $($metrics.TotalChecks)
- Passed: $($metrics.PassedChecks)
- Failed: $($metrics.FailedChecks)
- Active Violations: $($metrics.ViolationCount)
- Critical Issues: $($metrics.CriticalIssues)

Failed Checks:
$($complianceResults.Failed | ForEach-Object { "- $($_.Check): $($_.Description)" } | Out-String)

Critical Areas:
$($areaResults | Where-Object { $_.Status -in @('Critical', 'Failed') } | ForEach-Object { "- $($_.Area): $($_.Message)" } | Out-String)
"@
    
    Write-Output $summary
    
    # Store results in Azure Storage for historical tracking
    $resultsJson = @{
        Summary = $summary
        Results = $complianceResults
        AreaChecks = $areaResults
        Metrics = $metrics
    } | ConvertTo-Json -Depth 10
    
    # Save to storage account (if configured)
    $storageAccount = Get-AutomationVariable -Name 'ComplianceStorageAccount' -ErrorAction SilentlyContinue
    if ($storageAccount) {
        $containerName = "compliance-results"
        $blobName = "monitoring-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
        
        $storageContext = New-AzStorageContext -StorageAccountName $storageAccount -UseConnectedAccount
        $blob = Set-AzStorageBlobContent -Container $containerName `
            -Blob $blobName `
            -BlobType Block `
            -Context $storageContext `
            -Force
    }
    
    Write-Output "Compliance monitoring completed successfully"
}
catch {
    Write-Error "Compliance monitoring failed: $($_.Exception.Message)"
    
    # Send critical alert
    if ($SendAlerts) {
        New-ComplianceAlert -Title "Compliance Monitoring Failure" `
            -Description "The automated compliance monitoring runbook failed: $($_.Exception.Message)" `
            -Severity "Critical"
    }
    
    throw
}
finally {
    # Cleanup
    Disconnect-AzAccount -ErrorAction SilentlyContinue
    Disconnect-CloudScopeGraph -ErrorAction SilentlyContinue
}
