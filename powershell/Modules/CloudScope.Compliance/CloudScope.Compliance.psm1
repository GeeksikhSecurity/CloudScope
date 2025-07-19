#Requires -Version 7.0
#Requires -Modules Microsoft.Graph.Authentication, Microsoft.Graph.Users, Microsoft.Graph.InformationProtection

<#
.SYNOPSIS
    CloudScope Compliance PowerShell Module
    
.DESCRIPTION
    Provides compliance-as-code functionality for Microsoft ecosystem using
    PowerShell, Microsoft Graph, and Azure services.
    
.NOTES
    Module: CloudScope.Compliance
    Author: CloudScope Team
    Version: 1.0.0
#>

# Import framework-specific functions
. $PSScriptRoot\ComplianceFrameworks.psm1

# Module-level variables
$script:ComplianceContext = @{
    CurrentUser = $null
    Framework = $null
    LawfulBasis = $null
    MinimumNecessary = $false
    AuthorizedAccess = $false
    AuditEnabled = $true
    EncryptionEnabled = $true
}

$script:ComplianceViolations = [System.Collections.ArrayList]::new()
$script:ComplianceMetrics = @{
    TotalOperations = 0
    CompliantOperations = 0
    ViolationCount = 0
    ComplianceRate = 100.0
}

# Compliance frameworks enum
enum ComplianceFramework {
    GDPR
    PCI_DSS
    HIPAA
    SOC2
    ISO27001
    NIST
}

# Data classification enum
enum DataClassification {
    Public
    Internal
    Confidential
    Personal
    Health
    Financial
    Payment
}

# Severity enum
enum Severity {
    Info
    Warning
    Error
    Critical
}

<#
.SYNOPSIS
    Initializes the CloudScope compliance framework
    
.DESCRIPTION
    Sets up the compliance context, connects to required services,
    and initializes monitoring.
    
.PARAMETER TenantId
    Azure Active Directory tenant ID
    
.PARAMETER Framework
    Primary compliance framework to use
    
.EXAMPLE
    Initialize-CloudScopeCompliance -TenantId "your-tenant-id" -Framework GDPR
#>
function Initialize-CloudScopeCompliance {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$TenantId,
        
        [Parameter(Mandatory = $false)]
        [ComplianceFramework]$Framework = [ComplianceFramework]::GDPR,
        
        [Parameter(Mandatory = $false)]
        [switch]$EnableMonitoring
    )
    
    Write-Host "🔒 Initializing CloudScope Compliance Framework" -ForegroundColor Green
    
    try {
        # Initialize compliance context
        $script:ComplianceContext.Framework = $Framework
        $script:ComplianceContext.CurrentUser = Get-MgContext | Select-Object -ExpandProperty Account
        
        # Connect to Microsoft Graph if not already connected
        if (-not (Get-MgContext)) {
            Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Yellow
            Connect-MgGraph -Scopes @(
                "User.Read.All",
                "InformationProtectionPolicy.Read",
                "InformationProtectionContent.Write",
                "AuditLog.Read.All",
                "Directory.Read.All"
            )
        }
        
        # Initialize Azure Monitor if monitoring is enabled
        if ($EnableMonitoring) {
            Start-ComplianceMonitoring
        }
        
        Write-Host "✅ CloudScope Compliance initialized successfully" -ForegroundColor Green
        Write-Host "Framework: $Framework" -ForegroundColor Cyan
        Write-Host "User: $($script:ComplianceContext.CurrentUser)" -ForegroundColor Cyan
        
    } catch {
        Write-Error "Failed to initialize CloudScope Compliance: $($_.Exception.Message)"
        throw
    }
}

<#
.SYNOPSIS
    Sets data classification on files or content
    
.DESCRIPTION
    Applies Microsoft Information Protection labels to classify data
    according to compliance requirements.
    
.PARAMETER Path
    Path to file or folder to classify
    
.PARAMETER Classification
    Data classification level
    
.PARAMETER Framework
    Compliance framework context
    
.EXAMPLE
    Set-DataClassification -Path ".\sensitive-data.xlsx" -Classification Personal -Framework GDPR
#>
function Set-DataClassification {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$Path,
        
        [Parameter(Mandatory = $true)]
        [DataClassification]$Classification,
        
        [Parameter(Mandatory = $false)]
        [ComplianceFramework]$Framework = $script:ComplianceContext.Framework,
        
        [Parameter(Mandatory = $false)]
        [string]$Justification = "Compliance classification"
    )
    
    begin {
        Write-Verbose "Starting data classification process"
        $operationId = [guid]::NewGuid().ToString()
    }
    
    process {
        try {
            # Increment operation counter
            $script:ComplianceMetrics.TotalOperations++
            
            # Validate path exists
            if (-not (Test-Path $Path)) {
                throw "Path not found: $Path"
            }
            
            # Get appropriate Microsoft Information Protection label
            $labelId = Get-InformationProtectionLabel -Classification $Classification -Framework $Framework
            
            if ($labelId) {
                # Apply the label using Microsoft Graph
                $result = Set-MgInformationProtectionLabel -Path $Path -LabelId $labelId -Justification $Justification
                
                # Log the classification operation
                Add-AuditLog -Operation "DataClassification" -Details @{
                    Path = $Path
                    Classification = $Classification.ToString()
                    Framework = $Framework.ToString()
                    LabelId = $labelId
                    User = $script:ComplianceContext.CurrentUser
                    OperationId = $operationId
                } -Severity Info
                
                $script:ComplianceMetrics.CompliantOperations++
                
                Write-Host "✅ Applied $Classification classification to: $Path" -ForegroundColor Green
                return $result
            } else {
                throw "No appropriate label found for classification: $Classification"
            }
            
        } catch {
            # Record compliance violation
            $violation = @{
                Id = [guid]::NewGuid().ToString()
                Timestamp = Get-Date
                Type = "DataClassificationFailure"
                Description = "Failed to classify data: $($_.Exception.Message)"
                Path = $Path
                Classification = $Classification.ToString()
                Framework = $Framework.ToString()
                Severity = [Severity]::Error
                User = $script:ComplianceContext.CurrentUser
            }
            
            $script:ComplianceViolations.Add($violation) | Out-Null
            $script:ComplianceMetrics.ViolationCount++
            
            Write-Error "Failed to classify $Path: $($_.Exception.Message)"
            throw
        }
    }
    
    end {
        # Update compliance rate
        Update-ComplianceRate
        Write-Verbose "Data classification process completed"
    }
}

<#
.SYNOPSIS
    Enables data encryption for sensitive content
    
.DESCRIPTION
    Encrypts data using Azure Key Vault and applies appropriate
    protection policies based on compliance requirements.
    
.PARAMETER Data
    Data to encrypt (string or object)
    
.PARAMETER KeyVaultName
    Azure Key Vault name for encryption keys
    
.PARAMETER Classification
    Data classification level
    
.EXAMPLE
    $encrypted = Enable-DataEncryption -Data "4111111111111111" -Classification Payment -KeyVaultName "MyKeyVault"
#>
function Enable-DataEncryption {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [object]$Data,
        
        [Parameter(Mandatory = $true)]
        [DataClassification]$Classification,
        
        [Parameter(Mandatory = $false)]
        [string]$KeyVaultName = $env:CLOUDSCOPE_KEYVAULT_NAME,
        
        [Parameter(Mandatory = $false)]
        [string]$KeyName = "cloudscope-encryption-key"
    )
    
    begin {
        Write-Verbose "Starting data encryption process"
        
        if (-not $KeyVaultName) {
            throw "KeyVaultName is required. Set CLOUDSCOPE_KEYVAULT_NAME environment variable or provide parameter."
        }
    }
    
    process {
        try {
            $script:ComplianceMetrics.TotalOperations++
            
            # Convert data to string if needed
            $dataString = if ($Data -is [string]) { $Data } else { $Data | ConvertTo-Json -Compress }
            
            # Get encryption key from Azure Key Vault
            $key = Get-AzKeyVaultKey -VaultName $KeyVaultName -Name $KeyName
            if (-not $key) {
                # Create key if it doesn't exist
                $key = Add-AzKeyVaultKey -VaultName $KeyVaultName -Name $KeyName -Destination 'Software' -KeyOps @('encrypt', 'decrypt')
            }
            
            # Encrypt the data
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($dataString)
            $encrypted = Invoke-AzKeyVaultKeyOperation -Operation Encrypt -Algorithm RSA-OAEP-256 -VaultName $KeyVaultName -Name $KeyName -ByteArrayValue $bytes
            
            # Create encrypted data object
            $encryptedData = @{
                Data = [System.Convert]::ToBase64String($encrypted.Result)
                KeyId = $key.Id
                Algorithm = 'RSA-OAEP-256'
                Classification = $Classification.ToString()
                EncryptedAt = Get-Date
                EncryptedBy = $script:ComplianceContext.CurrentUser
            }
            
            # Log encryption operation
            Add-AuditLog -Operation "DataEncryption" -Details @{
                Classification = $Classification.ToString()
                KeyVault = $KeyVaultName
                KeyName = $KeyName
                DataSize = $bytes.Length
            } -Severity Info
            
            $script:ComplianceMetrics.CompliantOperations++
            Write-Verbose "Data encrypted successfully"
            
            return $encryptedData
            
        } catch {
            $script:ComplianceMetrics.ViolationCount++
            Write-Error "Encryption failed: $($_.Exception.Message)"
            throw
        }
    }
    
    end {
        Update-ComplianceRate
    }
}

<#
.SYNOPSIS
    Adds an entry to the compliance audit log
    
.DESCRIPTION
    Records compliance-related operations for audit trail and monitoring.
    
.PARAMETER Operation
    Type of operation performed
    
.PARAMETER Details
    Hashtable of operation details
    
.PARAMETER Severity
    Severity level of the log entry
#>
function Add-AuditLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Operation,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$Details,
        
        [Parameter(Mandatory = $false)]
        [Severity]$Severity = [Severity]::Info,
        
        [Parameter(Mandatory = $false)]
        [switch]$SendToAzureMonitor
    )
    
    try {
        $logEntry = @{
            Id = [guid]::NewGuid().ToString()
            Timestamp = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ'
            Operation = $Operation
            Details = $Details
            Severity = $Severity.ToString()
            User = $script:ComplianceContext.CurrentUser
            Framework = $script:ComplianceContext.Framework.ToString()
            MachineName = $env:COMPUTERNAME
            ProcessId = $PID
        }
        
        # Write to local log
        $logPath = Join-Path $env:TEMP "CloudScope_Audit_$(Get-Date -Format 'yyyyMMdd').log"
        $logEntry | ConvertTo-Json -Compress | Add-Content -Path $logPath
        
        # Send to Azure Monitor if enabled
        if ($SendToAzureMonitor -or $script:ComplianceContext.AuditEnabled) {
            Send-AzureMonitorLog -LogEntry $logEntry
        }
        
        Write-Verbose "Audit log entry added: $Operation"
        
    } catch {
        Write-Warning "Failed to write audit log: $($_.Exception.Message)"
    }
}

<#
.SYNOPSIS
    Tests access control compliance
    
.DESCRIPTION
    Validates that proper access controls are in place for sensitive operations.
    
.PARAMETER User
    User to validate access for
    
.PARAMETER Resource
    Resource being accessed
    
.PARAMETER Permission
    Required permission level
#>
function Test-AccessControl {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$User,
        
        [Parameter(Mandatory = $true)]
        [string]$Resource,
        
        [Parameter(Mandatory = $true)]
        [string]$Permission,
        
        [Parameter(Mandatory = $false)]
        [ComplianceFramework]$Framework = $script:ComplianceContext.Framework
    )
    
    try {
        $script:ComplianceMetrics.TotalOperations++
        
        # Get user from Microsoft Graph
        $graphUser = Get-MgUser -UserId $User -ErrorAction SilentlyContinue
        if (-not $graphUser) {
            throw "User not found: $User"
        }
        
        # Check user permissions
        $hasAccess = Test-UserPermission -User $graphUser -Resource $Resource -Permission $Permission
        
        # Apply framework-specific rules
        switch ($Framework) {
            'GDPR' {
                # Check for lawful basis
                if (-not $script:ComplianceContext.LawfulBasis) {
                    $hasAccess = $false
                    Add-ComplianceViolation -Type "MissingLawfulBasis" -Description "No lawful basis established for data access"
                }
            }
            'HIPAA' {
                # Check minimum necessary principle
                if (-not $script:ComplianceContext.MinimumNecessary) {
                    $hasAccess = $false
                    Add-ComplianceViolation -Type "MinimumNecessaryViolation" -Description "Access exceeds minimum necessary requirement"
                }
            }
            'PCI_DSS' {
                # Check for authorized access
                if (-not $script:ComplianceContext.AuthorizedAccess) {
                    $hasAccess = $false
                    Add-ComplianceViolation -Type "UnauthorizedAccess" -Description "User not authorized for payment data access"
                }
            }
        }
        
        # Log access attempt
        Add-AuditLog -Operation "AccessControl" -Details @{
            User = $User
            Resource = $Resource
            Permission = $Permission
            AccessGranted = $hasAccess
            Framework = $Framework.ToString()
        } -Severity $(if ($hasAccess) { [Severity]::Info } else { [Severity]::Warning })
        
        if ($hasAccess) {
            $script:ComplianceMetrics.CompliantOperations++
        }
        
        return $hasAccess
        
    } catch {
        $script:ComplianceMetrics.ViolationCount++
        Write-Error "Access control test failed: $($_.Exception.Message)"
        return $false
    } finally {
        Update-ComplianceRate
    }
}

<#
.SYNOPSIS
    Invokes a compliance assessment
    
.DESCRIPTION
    Runs a comprehensive compliance assessment for the specified framework.
    
.PARAMETER Framework
    Compliance framework to assess against
    
.PARAMETER Scope
    Scope of assessment (Users, Data, Systems, All)
#>
function Invoke-ComplianceAssessment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ComplianceFramework]$Framework,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('Users', 'Data', 'Systems', 'All')]
        [string]$Scope = 'All',
        
        [Parameter(Mandatory = $false)]
        [switch]$GenerateReport
    )
    
    Write-Host "🔍 Starting Compliance Assessment for $Framework" -ForegroundColor Cyan
    
    $assessment = @{
        Framework = $Framework.ToString()
        StartTime = Get-Date
        Scope = $Scope
        Results = @()
        ComplianceScore = 0
        TotalChecks = 0
        PassedChecks = 0
        FailedChecks = 0
        Findings = @()
    }
    
    try {
        # Run framework-specific checks
        switch ($Framework) {
            'GDPR' {
                $assessment.Results += Test-GDPRCompliance -Scope $Scope
            }
            'PCI_DSS' {
                $assessment.Results += Test-PCICompliance -Scope $Scope
            }
            'HIPAA' {
                $assessment.Results += Test-HIPAACompliance -Scope $Scope
            }
            'SOC2' {
                $assessment.Results += Test-SOC2Compliance -Scope $Scope
            }
            default {
                throw "Framework not implemented: $Framework"
            }
        }
        
        # Calculate compliance score
        foreach ($result in $assessment.Results) {
            $assessment.TotalChecks++
            if ($result.Status -eq 'Pass') {
                $assessment.PassedChecks++
            } else {
                $assessment.FailedChecks++
                $assessment.Findings += $result
            }
        }
        
        $assessment.ComplianceScore = if ($assessment.TotalChecks -gt 0) {
            [math]::Round(($assessment.PassedChecks / $assessment.TotalChecks) * 100, 2)
        } else { 0 }
        
        $assessment.EndTime = Get-Date
        $assessment.Duration = $assessment.EndTime - $assessment.StartTime
        
        # Display results
        Write-Host "`n📊 Compliance Assessment Results" -ForegroundColor Green
        Write-Host "Framework: $($assessment.Framework)" -ForegroundColor White
        Write-Host "Compliance Score: $($assessment.ComplianceScore)%" -ForegroundColor $(if ($assessment.ComplianceScore -ge 80) { 'Green' } elseif ($assessment.ComplianceScore -ge 60) { 'Yellow' } else { 'Red' })
        Write-Host "Total Checks: $($assessment.TotalChecks)"
        Write-Host "Passed: $($assessment.PassedChecks)" -ForegroundColor Green
        Write-Host "Failed: $($assessment.FailedChecks)" -ForegroundColor Red
        
        # Generate report if requested
        if ($GenerateReport) {
            New-ComplianceReport -Assessment $assessment
        }
        
        # Log assessment
        Add-AuditLog -Operation "ComplianceAssessment" -Details @{
            Framework = $Framework.ToString()
            Score = $assessment.ComplianceScore
            TotalChecks = $assessment.TotalChecks
            PassedChecks = $assessment.PassedChecks
            FailedChecks = $assessment.FailedChecks
        } -Severity Info
        
        return $assessment
        
    } catch {
        Write-Error "Compliance assessment failed: $($_.Exception.Message)"
        throw
    }
}

# Helper Functions

function Get-InformationProtectionLabel {
    param(
        [DataClassification]$Classification,
        [ComplianceFramework]$Framework
    )
    
    # Map classification to Microsoft Information Protection labels
    $labelMap = @{
        'Public' = 'Public'
        'Internal' = 'General'
        'Confidential' = 'Confidential'
        'Personal' = 'Highly Confidential - GDPR'
        'Health' = 'Highly Confidential - HIPAA'
        'Financial' = 'Highly Confidential - Financial'
        'Payment' = 'Highly Confidential - PCI'
    }
    
    $labelName = $labelMap[$Classification.ToString()]
    
    try {
        # Get label from Microsoft Graph
        $labels = Get-MgInformationProtectionLabel
        $label = $labels | Where-Object { $_.DisplayName -eq $labelName } | Select-Object -First 1
        
        return $label.Id
    } catch {
        Write-Warning "Failed to get Information Protection label: $($_.Exception.Message)"
        return $null
    }
}

function Update-ComplianceRate {
    if ($script:ComplianceMetrics.TotalOperations -gt 0) {
        $script:ComplianceMetrics.ComplianceRate = [math]::Round(
            ($script:ComplianceMetrics.CompliantOperations / $script:ComplianceMetrics.TotalOperations) * 100, 
            2
        )
    }
}

function Add-ComplianceViolation {
    param(
        [string]$Type,
        [string]$Description,
        [Severity]$Severity = [Severity]::Warning
    )
    
    $violation = @{
        Id = [guid]::NewGuid().ToString()
        Timestamp = Get-Date
        Type = $Type
        Description = $Description
        Severity = $Severity.ToString()
        User = $script:ComplianceContext.CurrentUser
        Framework = $script:ComplianceContext.Framework.ToString()
    }
    
    $script:ComplianceViolations.Add($violation) | Out-Null
    $script:ComplianceMetrics.ViolationCount++
}

function Test-UserPermission {
    param(
        [object]$User,
        [string]$Resource,
        [string]$Permission
    )
    
    # Check user's group memberships and roles
    try {
        $memberOf = Get-MgUserMemberOf -UserId $User.Id
        $roles = Get-MgUserAppRoleAssignment -UserId $User.Id
        
        # Check if user has required permission
        # This is a simplified check - in production, you'd implement more sophisticated logic
        $hasPermission = $roles | Where-Object { $_.AppRoleId -match $Permission }
        
        return [bool]$hasPermission
    } catch {
        Write-Warning "Failed to check user permissions: $($_.Exception.Message)"
        return $false
    }
}

function Send-AzureMonitorLog {
    param(
        [hashtable]$LogEntry
    )
    
    # Implementation would send logs to Azure Monitor
    # This is a placeholder for the actual implementation
    Write-Verbose "Sending log to Azure Monitor: $($LogEntry.Operation)"
}

# Mock functions for testing (replace with actual implementations)
function Test-ConsentManagementSystem { $true }
function Test-DSRImplementation { $true }
function Get-PersonalDataInventory { $true }
function Test-MFAEnforcement { $true }
function Test-CHDEncryption { $true }
function Test-HealthDataEncryption { $true }
function Test-ChangeControlProcess { $true }
function Send-ComplianceAlert { param($Violations) }
function Enable-InformationProtectionLabels { param($Framework) }
function New-DLPPolicy { param($Name, $Template) }
function Enable-PersonalDataAuditing { }
function Enable-DataPseudonymization { }
function Set-DataGovernanceSettings { param($RetentionDays) }
function Set-KeyVaultConfiguration { param($KeyRotationDays) }
function Enable-PANMaskingPolicy { }
function Enable-PaymentTokenization { }
function Set-NetworkSecurityGroups { param($Framework) }
function Enable-SecurityLogging { param($Level) }
function Set-HealthcareAPIConfiguration { param($ComplianceMode) }
function Set-AuditRetention { param($Years) }
function Enable-PHIDeIdentification { }
function Set-PHIEncryption { param($Algorithm) }
function Set-AzSecurityCenter { param($ComplianceStandard) }
function Enable-ContinuousComplianceMonitoring { }
function New-AccessReviewPolicy { param($ReviewCycleDays) }
function Enable-ChangeManagement { param($ApprovalRequired) }
function New-IncidentResponsePlan { param($Framework) }
function Set-MgInformationProtectionLabel { param($Path, $LabelId, $Justification) @{} }
function Get-MgInformationProtectionLabel { @(@{Id = '12345'; DisplayName = 'Confidential'}) }

# Export module members
Export-ModuleMember -Function @(
    'Initialize-CloudScopeCompliance',
    'Set-DataClassification',
    'Enable-DataEncryption',
    'Add-AuditLog',
    'Test-AccessControl',
    'Invoke-ComplianceAssessment',
    'Get-ComplianceViolations',
    'New-ComplianceReport',
    'Set-GDPRCompliance',
    'Set-PCICompliance',
    'Set-HIPAACompliance',
    'Set-SOC2Compliance',
    'Get-ComplianceMetrics',
    'Start-ComplianceMonitoring',
    'Stop-ComplianceMonitoring'
) -Variable @() -Alias @()
