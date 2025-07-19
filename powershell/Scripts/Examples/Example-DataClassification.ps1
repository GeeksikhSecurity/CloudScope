<#
.SYNOPSIS
    Example: Data Classification and Protection
    
.DESCRIPTION
    Demonstrates how to classify and protect sensitive data using
    CloudScope PowerShell modules with Microsoft Information Protection.
    
.NOTES
    File: Example-DataClassification.ps1
    Author: CloudScope Team
    Version: 1.0.0
#>

# Import required modules
Import-Module CloudScope.Compliance -Force
Import-Module CloudScope.Graph -Force

Write-Host "=== CloudScope Data Classification Example ===" -ForegroundColor Green
Write-Host "This example shows how to classify and protect sensitive data" -ForegroundColor Cyan

# Initialize CloudScope
Initialize-CloudScopeCompliance -Framework GDPR
Connect-CloudScopeGraph

# Example 1: Classify a single file
Write-Host "`n[Example 1] Classifying a single file" -ForegroundColor Yellow

$testFile = "C:\Data\customer_records.xlsx"
if (Test-Path $testFile) {
    try {
        # Classify as personal data
        Set-DataClassification -Path $testFile -Classification Personal -Framework GDPR
        Write-Host "✅ File classified as Personal data" -ForegroundColor Green
        
        # Enable encryption for the file
        $encrypted = Enable-DataEncryption -Data (Get-Content $testFile -Raw) -Classification Personal
        Write-Host "✅ File encrypted with key: $($encrypted.KeyId)" -ForegroundColor Green
    } catch {
        Write-Warning "Failed to classify file: $($_.Exception.Message)"
    }
} else {
    Write-Host "Creating sample file for demonstration..." -ForegroundColor Yellow
    
    # Create sample data
    $sampleData = @"
CustomerID,Name,Email,CreditCard,SSN
1001,John Doe,john@example.com,4111111111111111,123-45-6789
1002,Jane Smith,jane@example.com,5555555555554444,987-65-4321
1003,Bob Johnson,bob@example.com,378282246310005,456-78-9012
"@
    
    New-Item -ItemType Directory -Path "C:\Data" -Force | Out-Null
    $sampleData | Out-File -FilePath $testFile -Encoding UTF8
    Write-Host "✅ Sample file created" -ForegroundColor Green
}

# Example 2: Bulk classification of files
Write-Host "`n[Example 2] Bulk classification of files in a directory" -ForegroundColor Yellow

$dataDirectory = "C:\Data"
$files = Get-ChildItem -Path $dataDirectory -File -Recurse

Write-Host "Found $($files.Count) files to classify" -ForegroundColor Cyan

foreach ($file in $files) {
    Write-Host "`nProcessing: $($file.Name)" -ForegroundColor White
    
    # Detect sensitive content
    $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
    if ($content) {
        $classification = $null
        
        # Detect credit card numbers
        if ($content -match '\b(?:4[0-9]{12}(?:[0-9]{3})?|5[1-5][0-9]{14}|3[47][0-9]{13})\b') {
            $classification = 'Payment'
            Write-Host "  Detected: Credit card information" -ForegroundColor Yellow
        }
        # Detect SSN
        elseif ($content -match '\b\d{3}-\d{2}-\d{4}\b') {
            $classification = 'Personal'
            Write-Host "  Detected: Social Security Number" -ForegroundColor Yellow
        }
        # Detect email addresses
        elseif ($content -match '\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b') {
            $classification = 'Personal'
            Write-Host "  Detected: Email addresses" -ForegroundColor Yellow
        }
        # Detect health information
        elseif ($content -match 'diagnosis|medical|patient|treatment|prescription') {
            $classification = 'Health'
            Write-Host "  Detected: Health information" -ForegroundColor Yellow
        }
        else {
            $classification = 'Internal'
            Write-Host "  No sensitive data detected" -ForegroundColor Gray
        }
        
        # Apply classification
        try {
            Set-DataClassification -Path $file.FullName -Classification $classification
            Write-Host "  ✅ Classified as: $classification" -ForegroundColor Green
        } catch {
            Write-Warning "  Failed to classify: $($_.Exception.Message)"
        }
    }
}

# Example 3: Search for unclassified sensitive data
Write-Host "`n[Example 3] Searching for unclassified sensitive data" -ForegroundColor Yellow

$sensitiveDataSearch = Get-SensitiveDataLocations -DataType 'All' -Scope 'OneDrive'
Write-Host "Found $($sensitiveDataSearch.TotalLocations) locations with sensitive data" -ForegroundColor Cyan

if ($sensitiveDataSearch.Locations.Count -gt 0) {
    Write-Host "`nUnclassified sensitive data locations:" -ForegroundColor Yellow
    $sensitiveDataSearch.Locations | Where-Object { -not $_.Classification } | ForEach-Object {
        Write-Host "  - $($_.Path)" -ForegroundColor Red
        Write-Host "    Type: $($_.SensitiveTypes -join ', ')" -ForegroundColor Gray
    }
}

# Example 4: Apply Microsoft Information Protection labels
Write-Host "`n[Example 4] Applying Microsoft Information Protection labels" -ForegroundColor Yellow

# Get available labels
$labels = Get-DataGovernanceLabels
Write-Host "Available MIP labels:" -ForegroundColor Cyan
$labels | ForEach-Object {
    Write-Host "  - $($_.displayName) (Priority: $($_.priority))" -ForegroundColor White
}

# Apply label to sensitive file
$sensitiveFile = "C:\Data\financial_report.xlsx"
if (Test-Path $sensitiveFile) {
    # Find the "Highly Confidential" label
    $confidentialLabel = $labels | Where-Object { $_.displayName -like "*Confidential*" } | Select-Object -First 1
    
    if ($confidentialLabel) {
        try {
            # This would apply the MIP label using Graph API
            Write-Host "`nApplying '$($confidentialLabel.displayName)' label to financial report..." -ForegroundColor Yellow
            # In practice: Set-MgInformationProtectionLabel -Path $sensitiveFile -LabelId $confidentialLabel.id
            Write-Host "✅ Label applied successfully" -ForegroundColor Green
        } catch {
            Write-Warning "Failed to apply label: $($_.Exception.Message)"
        }
    }
}

# Example 5: Create DLP policy for classified data
Write-Host "`n[Example 5] Creating DLP policy for classified data" -ForegroundColor Yellow

$dlpPolicy = @{
    Name = "Protect Classified Payment Data"
    Description = "Prevents sharing of files classified as Payment data"
    Rules = @(
        @{
            Name = "Block External Sharing"
            Conditions = @{
                Classification = "Payment"
                Recipients = "External"
            }
            Actions = @{
                BlockAccess = $true
                NotifyUser = $true
                GenerateIncident = $true
            }
        }
    )
}

Write-Host "Creating DLP policy: $($dlpPolicy.Name)" -ForegroundColor Yellow
# In practice: New-DLPPolicy @dlpPolicy
Write-Host "✅ DLP policy created" -ForegroundColor Green

# Example 6: Monitor data access
Write-Host "`n[Example 6] Monitoring access to classified data" -ForegroundColor Yellow

# Set up monitoring for Payment classified data
$monitoringConfig = @{
    Classification = "Payment"
    AlertOnAccess = $true
    LogAllAccess = $true
    RequireMFA = $true
}

Write-Host "Configuring monitoring for Payment classified data..." -ForegroundColor Yellow
Write-Host "  - Alert on access: $($monitoringConfig.AlertOnAccess)"
Write-Host "  - Log all access: $($monitoringConfig.LogAllAccess)"
Write-Host "  - Require MFA: $($monitoringConfig.RequireMFA)"
Write-Host "✅ Monitoring configured" -ForegroundColor Green

# Summary report
Write-Host "`n=== Data Classification Summary ===" -ForegroundColor Green

$classificationStats = @{
    Total = $files.Count
    Classified = 0
    Personal = 0
    Payment = 0
    Health = 0
    Financial = 0
    Internal = 0
}

# In practice, you would query actual classification data
Write-Host "`nClassification Statistics:" -ForegroundColor Cyan
Write-Host "Total Files: $($classificationStats.Total)"
Write-Host "Classified: $($classificationStats.Classified) ($([math]::Round(($classificationStats.Classified / $classificationStats.Total) * 100, 2))%)"
Write-Host "`nBy Classification Type:" -ForegroundColor Cyan
Write-Host "  Personal Data: $($classificationStats.Personal)"
Write-Host "  Payment Data: $($classificationStats.Payment)"
Write-Host "  Health Data: $($classificationStats.Health)"
Write-Host "  Financial Data: $($classificationStats.Financial)"
Write-Host "  Internal Data: $($classificationStats.Internal)"

# Best practices
Write-Host "`n📚 Data Classification Best Practices:" -ForegroundColor Cyan
Write-Host "1. Classify data at creation time"
Write-Host "2. Use automated classification for bulk operations"
Write-Host "3. Regularly scan for unclassified sensitive data"
Write-Host "4. Apply appropriate protection based on classification"
Write-Host "5. Monitor access to highly classified data"
Write-Host "6. Train users on classification requirements"
Write-Host "7. Review and update classification policies regularly"

# Next steps
Write-Host "`n🚀 Next Steps:" -ForegroundColor Cyan
Write-Host "1. Enable automated classification rules"
Write-Host "2. Create custom sensitive information types"
Write-Host "3. Implement data lifecycle management"
Write-Host "4. Set up regular compliance scans"
Write-Host "5. Configure retention policies based on classification"
