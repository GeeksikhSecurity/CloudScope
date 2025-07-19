<#
.SYNOPSIS
    Example: Complete GDPR Compliance Check
    
.DESCRIPTION
    Demonstrates how to perform a comprehensive GDPR compliance check
    using CloudScope PowerShell modules.
    
.NOTES
    File: Example-GDPRComplianceCheck.ps1
    Author: CloudScope Team
    Version: 1.0.0
#>

# Import CloudScope modules
Import-Module CloudScope.Compliance -Force
Import-Module CloudScope.Graph -Force
Import-Module CloudScope.Reports -Force

Write-Host "=== CloudScope GDPR Compliance Check Example ===" -ForegroundColor Green
Write-Host "This example demonstrates a complete GDPR compliance assessment" -ForegroundColor Cyan

# Step 1: Initialize CloudScope with GDPR framework
Write-Host "`n[Step 1] Initializing CloudScope for GDPR..." -ForegroundColor Yellow
try {
    Initialize-CloudScopeCompliance -Framework GDPR -EnableMonitoring
    Connect-CloudScopeGraph
    Write-Host "✅ Initialization complete" -ForegroundColor Green
} catch {
    Write-Error "Failed to initialize: $($_.Exception.Message)"
    exit 1
}

# Step 2: Configure GDPR-specific settings
Write-Host "`n[Step 2] Configuring GDPR compliance settings..." -ForegroundColor Yellow
Set-GDPRCompliance -LawfulBasis "Legitimate Interest" -RetentionDays 365 -EnablePseudonymization
Write-Host "✅ GDPR settings configured" -ForegroundColor Green

# Step 3: Check personal data inventory
Write-Host "`n[Step 3] Checking personal data inventory..." -ForegroundColor Yellow
$personalData = Get-SensitiveDataLocations -DataType 'Personal' -Scope 'All'
Write-Host "Found $($personalData.TotalLocations) locations with personal data" -ForegroundColor Cyan
Write-Host "High-risk locations: $($personalData.HighRiskLocations.Count)" -ForegroundColor $(if ($personalData.HighRiskLocations.Count -gt 0) { 'Red' } else { 'Green' })

# Step 4: Verify data subject rights implementation
Write-Host "`n[Step 4] Verifying data subject rights..." -ForegroundColor Yellow
$dsrChecks = @{
    AccessRights = Test-DataSubjectAccessRights
    RectificationRights = Test-DataRectificationRights
    ErasureRights = Test-DataErasureRights
    PortabilityRights = Test-DataPortabilityRights
}

foreach ($right in $dsrChecks.GetEnumerator()) {
    $status = if ($right.Value) { "✅ Implemented" } else { "❌ Not Implemented" }
    $color = if ($right.Value) { 'Green' } else { 'Red' }
    Write-Host "$($right.Key): $status" -ForegroundColor $color
}

# Step 5: Check consent management
Write-Host "`n[Step 5] Checking consent management..." -ForegroundColor Yellow
$consentStatus = Get-ConsentManagementStatus
Write-Host "Active consents: $($consentStatus.ActiveConsents)" -ForegroundColor Cyan
Write-Host "Expired consents: $($consentStatus.ExpiredConsents)" -ForegroundColor $(if ($consentStatus.ExpiredConsents -gt 0) { 'Yellow' } else { 'Green' })

# Step 6: Validate data encryption
Write-Host "`n[Step 6] Validating data encryption..." -ForegroundColor Yellow
$encryptionStatus = Get-DataEncryptionStatus
$encryptionPercentage = [math]::Round(($encryptionStatus.EncryptedData / $encryptionStatus.TotalData) * 100, 2)
Write-Host "Data encryption: $encryptionPercentage%" -ForegroundColor $(if ($encryptionPercentage -ge 95) { 'Green' } elseif ($encryptionPercentage -ge 80) { 'Yellow' } else { 'Red' })

# Step 7: Review access controls
Write-Host "`n[Step 7] Reviewing access controls..." -ForegroundColor Yellow
$users = Get-ComplianceUsers -Filter "department eq 'HR' or department eq 'Finance'"
$privilegedUsers = $users | Where-Object { $_.HasPrivilegedAccess }
Write-Host "Users with access to personal data: $($users.Count)" -ForegroundColor Cyan
Write-Host "Privileged users: $($privilegedUsers.Count)" -ForegroundColor Yellow

# Test access control for a sample user
if ($users.Count -gt 0) {
    $testUser = $users[0]
    $accessTest = Test-AccessControl -User $testUser.UserPrincipalName -Resource "PersonalData" -Permission "Read"
    Write-Host "Access control test for $($testUser.DisplayName): $(if ($accessTest) { '✅ Pass' } else { '❌ Fail' })" -ForegroundColor $(if ($accessTest) { 'Green' } else { 'Red' })
}

# Step 8: Check breach notification procedures
Write-Host "`n[Step 8] Checking breach notification procedures..." -ForegroundColor Yellow
$breachProcedures = Test-BreachNotificationProcedures
if ($breachProcedures.HasProcedures) {
    Write-Host "✅ Breach notification procedures in place" -ForegroundColor Green
    Write-Host "  - 72-hour notification: $(if ($breachProcedures.MeetsTimeRequirement) { 'Yes' } else { 'No' })"
    Write-Host "  - Contact list updated: $(if ($breachProcedures.ContactListCurrent) { 'Yes' } else { 'No' })"
} else {
    Write-Host "❌ Breach notification procedures not found" -ForegroundColor Red
}

# Step 9: Run full GDPR assessment
Write-Host "`n[Step 9] Running comprehensive GDPR assessment..." -ForegroundColor Yellow
$assessment = Invoke-ComplianceAssessment -Framework GDPR -GenerateReport:$false

Write-Host "`n📊 GDPR Compliance Assessment Results" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Gray
Write-Host "Overall Score: $($assessment.ComplianceScore)%" -ForegroundColor $(if ($assessment.ComplianceScore -ge 80) { 'Green' } elseif ($assessment.ComplianceScore -ge 60) { 'Yellow' } else { 'Red' })
Write-Host "Total Checks: $($assessment.TotalChecks)"
Write-Host "Passed: $($assessment.PassedChecks)" -ForegroundColor Green
Write-Host "Failed: $($assessment.FailedChecks)" -ForegroundColor Red

# Display top failures
if ($assessment.FailedChecks -gt 0) {
    Write-Host "`nTop Compliance Gaps:" -ForegroundColor Yellow
    $assessment.Findings | Select-Object -First 5 | ForEach-Object {
        Write-Host "  - $($_.Check): $($_.Description)" -ForegroundColor Red
    }
}

# Step 10: Generate compliance report
Write-Host "`n[Step 10] Generating GDPR compliance report..." -ForegroundColor Yellow
$report = New-FrameworkReport -Framework GDPR -IncludeEvidence -IncludeRemediation
Write-Host "✅ Report generated: $($report.Path)" -ForegroundColor Green

# Step 11: Create executive summary
Write-Host "`n[Step 11] Creating executive summary..." -ForegroundColor Yellow
$summary = New-ExecutiveSummary -Title "GDPR Compliance Status" -Period "Q1 2025" -OpenAfterCreation
Write-Host "✅ Executive summary created" -ForegroundColor Green

# Step 12: Check for violations
Write-Host "`n[Step 12] Checking for recent violations..." -ForegroundColor Yellow
$violations = Get-ComplianceViolations -Recent -Hours 168 # Last 7 days
if ($violations.Count -gt 0) {
    Write-Host "⚠️ Found $($violations.Count) violations in the last 7 days" -ForegroundColor Red
    $violations | Group-Object Type | ForEach-Object {
        Write-Host "  - $($_.Name): $($_.Count) violations" -ForegroundColor Yellow
    }
} else {
    Write-Host "✅ No violations in the last 7 days" -ForegroundColor Green
}

# Summary and recommendations
Write-Host "`n=== GDPR Compliance Check Complete ===" -ForegroundColor Green
Write-Host "`nSummary:" -ForegroundColor Cyan
Write-Host "- Compliance Score: $($assessment.ComplianceScore)%"
Write-Host "- Personal Data Locations: $($personalData.TotalLocations)"
Write-Host "- Data Encryption: $encryptionPercentage%"
Write-Host "- Recent Violations: $($violations.Count)"

Write-Host "`nRecommendations:" -ForegroundColor Cyan
if ($assessment.ComplianceScore -lt 80) {
    Write-Host "1. Review and address failed compliance checks" -ForegroundColor Yellow
}
if ($personalData.HighRiskLocations.Count -gt 0) {
    Write-Host "2. Secure high-risk personal data locations" -ForegroundColor Yellow
}
if ($encryptionPercentage -lt 100) {
    Write-Host "3. Encrypt remaining unencrypted personal data" -ForegroundColor Yellow
}
if ($consentStatus.ExpiredConsents -gt 0) {
    Write-Host "4. Review and renew expired consents" -ForegroundColor Yellow
}

Write-Host "`nNext Steps:" -ForegroundColor Cyan
Write-Host "1. Review the detailed report at: $($report.Path)"
Write-Host "2. Implement remediation plan for failed checks"
Write-Host "3. Schedule regular compliance assessments"
Write-Host "4. Enable continuous monitoring for real-time compliance"

# Example helper functions (these would be implemented in the actual module)
function Test-DataSubjectAccessRights { return $true }
function Test-DataRectificationRights { return $true }
function Test-DataErasureRights { return $false }
function Test-DataPortabilityRights { return $true }
function Get-ConsentManagementStatus { return @{ ActiveConsents = 1523; ExpiredConsents = 47 } }
function Get-DataEncryptionStatus { return @{ EncryptedData = 8750; TotalData = 10000 } }
function Test-BreachNotificationProcedures { 
    return @{ 
        HasProcedures = $true
        MeetsTimeRequirement = $true
        ContactListCurrent = $false
    }
}
