#Requires -Module Pester

<#
.SYNOPSIS
    Pester tests for CloudScope.Compliance module
    
.DESCRIPTION
    Unit tests for the core compliance module functionality
#>

BeforeAll {
    # Import the module
    $modulePath = Join-Path $PSScriptRoot '..' 'Modules' 'CloudScope.Compliance'
    Import-Module $modulePath -Force
    
    # Mock external dependencies
    Mock Connect-MgGraph {}
    Mock Get-MgContext { 
        @{ Account = 'test@contoso.com'; TenantId = '12345678-1234-1234-1234-123456789012' }
    }
    Mock Get-MgUser {
        @{
            Id = 'user123'
            UserPrincipalName = 'test.user@contoso.com'
            DisplayName = 'Test User'
        }
    }
    Mock Set-MgInformationProtectionLabel { @{ Success = $true } }
    Mock Get-MgInformationProtectionLabel {
        @(
            @{ Id = 'label123'; DisplayName = 'Confidential' }
        )
    }
}

Describe 'CloudScope.Compliance Module Tests' {
    
    Context 'Module Import' {
        It 'Should import successfully' {
            $module = Get-Module -Name 'CloudScope.Compliance'
            $module | Should -Not -BeNullOrEmpty
        }
        
        It 'Should export expected functions' {
            $expectedFunctions = @(
                'Initialize-CloudScopeCompliance',
                'Set-DataClassification',
                'Enable-DataEncryption',
                'Add-AuditLog',
                'Test-AccessControl',
                'Invoke-ComplianceAssessment'
            )
            
            $module = Get-Module -Name 'CloudScope.Compliance'
            $exportedFunctions = $module.ExportedFunctions.Keys
            
            foreach ($function in $expectedFunctions) {
                $exportedFunctions | Should -Contain $function
            }
        }
    }
    
    Context 'Initialize-CloudScopeCompliance' {
        BeforeEach {
            # Reset module variables
            InModuleScope 'CloudScope.Compliance' {
                $script:ComplianceContext = @{
                    CurrentUser = $null
                    Framework = $null
                }
            }
        }
        
        It 'Should initialize with default GDPR framework' {
            { Initialize-CloudScopeCompliance } | Should -Not -Throw
            
            InModuleScope 'CloudScope.Compliance' {
                $script:ComplianceContext.Framework | Should -Be 'GDPR'
                $script:ComplianceContext.CurrentUser | Should -Be 'test@contoso.com'
            }
        }
        
        It 'Should accept different compliance frameworks' {
            $frameworks = @('GDPR', 'PCI_DSS', 'HIPAA', 'SOC2')
            
            foreach ($framework in $frameworks) {
                { Initialize-CloudScopeCompliance -Framework $framework } | Should -Not -Throw
                
                InModuleScope 'CloudScope.Compliance' -ArgumentList $framework {
                    param($framework)
                    $script:ComplianceContext.Framework | Should -Be $framework
                }
            }
        }
        
        It 'Should enable monitoring when specified' {
            Mock Start-ComplianceMonitoring {} -ModuleName 'CloudScope.Compliance'
            
            Initialize-CloudScopeCompliance -EnableMonitoring
            
            Assert-MockCalled -CommandName Start-ComplianceMonitoring -ModuleName 'CloudScope.Compliance' -Times 1
        }
    }
    
    Context 'Set-DataClassification' {
        BeforeAll {
            Initialize-CloudScopeCompliance -Framework GDPR
            
            # Create test file
            $testFile = Join-Path $TestDrive 'test-data.txt'
            'Test content' | Out-File $testFile
        }
        
        It 'Should classify existing file' {
            Mock Test-Path { $true } -ModuleName 'CloudScope.Compliance'
            
            { Set-DataClassification -Path $testFile -Classification 'Personal' } | Should -Not -Throw
            
            Assert-MockCalled -CommandName Set-MgInformationProtectionLabel -Times 1
        }
        
        It 'Should throw error for non-existent file' {
            $fakePath = 'C:\fake\path\file.txt'
            
            { Set-DataClassification -Path $fakePath -Classification 'Personal' } | Should -Throw
        }
        
        It 'Should record violations on failure' {
            Mock Set-MgInformationProtectionLabel { throw "API Error" } -ModuleName 'CloudScope.Compliance'
            
            { Set-DataClassification -Path $testFile -Classification 'Personal' } | Should -Throw
            
            InModuleScope 'CloudScope.Compliance' {
                $script:ComplianceViolations.Count | Should -BeGreaterThan 0
                $script:ComplianceMetrics.ViolationCount | Should -BeGreaterThan 0
            }
        }
        
        It 'Should support all classification types' {
            $classifications = @('Public', 'Internal', 'Confidential', 'Personal', 'Health', 'Financial', 'Payment')
            
            foreach ($classification in $classifications) {
                { Set-DataClassification -Path $testFile -Classification $classification } | Should -Not -Throw
            }
        }
    }
    
    Context 'Enable-DataEncryption' {
        BeforeAll {
            Initialize-CloudScopeCompliance
            $env:CLOUDSCOPE_KEYVAULT_NAME = 'TestKeyVault'
            
            Mock Get-AzKeyVaultKey { 
                @{ Id = 'https://vault/keys/key123'; Name = 'cloudscope-encryption-key' }
            } -ModuleName 'CloudScope.Compliance'
            
            Mock Invoke-AzKeyVaultKeyOperation { 
                @{ Result = [byte[]]@(1,2,3,4,5) }
            } -ModuleName 'CloudScope.Compliance'
        }
        
        AfterAll {
            Remove-Item env:CLOUDSCOPE_KEYVAULT_NAME -ErrorAction SilentlyContinue
        }
        
        It 'Should encrypt string data' {
            $testData = "Sensitive information"
            
            $result = Enable-DataEncryption -Data $testData -Classification 'Personal'
            
            $result | Should -Not -BeNullOrEmpty
            $result.Data | Should -Not -BeNullOrEmpty
            $result.KeyId | Should -Match 'vault/keys'
            $result.Classification | Should -Be 'Personal'
        }
        
        It 'Should encrypt object data' {
            $testObject = @{
                Name = "John Doe"
                SSN = "123-45-6789"
            }
            
            $result = Enable-DataEncryption -Data $testObject -Classification 'Personal'
            
            $result | Should -Not -BeNullOrEmpty
            $result.Data | Should -Not -BeNullOrEmpty
        }
        
        It 'Should require KeyVault name' {
            Remove-Item env:CLOUDSCOPE_KEYVAULT_NAME -ErrorAction SilentlyContinue
            
            { Enable-DataEncryption -Data "test" -Classification 'Personal' } | Should -Throw "*KeyVaultName is required*"
        }
        
        It 'Should update compliance metrics' {
            InModuleScope 'CloudScope.Compliance' {
                $initialOperations = $script:ComplianceMetrics.TotalOperations
            }
            
            Enable-DataEncryption -Data "test" -Classification 'Personal'
            
            InModuleScope 'CloudScope.Compliance' {
                $script:ComplianceMetrics.TotalOperations | Should -BeGreaterThan $initialOperations
                $script:ComplianceMetrics.CompliantOperations | Should -BeGreaterThan 0
            }
        }
    }
    
    Context 'Test-AccessControl' {
        BeforeAll {
            Initialize-CloudScopeCompliance -Framework GDPR
            
            Mock Test-UserPermission { $true } -ModuleName 'CloudScope.Compliance'
            Mock Get-MgUserMemberOf { @() } -ModuleName 'CloudScope.Compliance'
            Mock Get-MgUserAppRoleAssignment { @() } -ModuleName 'CloudScope.Compliance'
        }
        
        It 'Should validate user access' {
            $result = Test-AccessControl -User 'test@contoso.com' -Resource 'PersonalData' -Permission 'Read'
            
            $result | Should -Be $true
            Assert-MockCalled -CommandName Get-MgUser -Times 1
        }
        
        It 'Should return false for non-existent user' {
            Mock Get-MgUser { $null } -ModuleName 'CloudScope.Compliance'
            
            $result = Test-AccessControl -User 'fake@contoso.com' -Resource 'PersonalData' -Permission 'Read'
            
            $result | Should -Be $false
        }
        
        It 'Should apply GDPR lawful basis check' {
            InModuleScope 'CloudScope.Compliance' {
                $script:ComplianceContext.LawfulBasis = $null
            }
            
            $result = Test-AccessControl -User 'test@contoso.com' -Resource 'PersonalData' -Permission 'Read' -Framework 'GDPR'
            
            $result | Should -Be $false
            
            InModuleScope 'CloudScope.Compliance' {
                $violation = $script:ComplianceViolations | Where-Object { $_.Type -eq 'MissingLawfulBasis' }
                $violation | Should -Not -BeNullOrEmpty
            }
        }
        
        It 'Should apply HIPAA minimum necessary check' {
            InModuleScope 'CloudScope.Compliance' {
                $script:ComplianceContext.MinimumNecessary = $false
            }
            
            $result = Test-AccessControl -User 'test@contoso.com' -Resource 'HealthData' -Permission 'Write' -Framework 'HIPAA'
            
            $result | Should -Be $false
        }
        
        It 'Should log access attempts' {
            Mock Add-AuditLog {} -ModuleName 'CloudScope.Compliance'
            
            Test-AccessControl -User 'test@contoso.com' -Resource 'PersonalData' -Permission 'Read'
            
            Assert-MockCalled -CommandName Add-AuditLog -ModuleName 'CloudScope.Compliance' -Times 1 -ParameterFilter {
                $Operation -eq 'AccessControl'
            }
        }
    }
    
    Context 'Invoke-ComplianceAssessment' {
        BeforeAll {
            Initialize-CloudScopeCompliance
            
            Mock Test-GDPRCompliance {
                @(
                    @{ Check = 'User Consent'; Status = 'Pass' }
                    @{ Check = 'Data Retention'; Status = 'Fail' }
                )
            } -ModuleName 'CloudScope.Compliance'
            
            Mock Test-PCICompliance {
                @(
                    @{ Check = 'Encryption'; Status = 'Pass' }
                    @{ Check = 'Access Control'; Status = 'Pass' }
                )
            } -ModuleName 'CloudScope.Compliance'
        }
        
        It 'Should run framework assessment' {
            $result = Invoke-ComplianceAssessment -Framework 'GDPR'
            
            $result | Should -Not -BeNullOrEmpty
            $result.Framework | Should -Be 'GDPR'
            $result.TotalChecks | Should -Be 2
            $result.PassedChecks | Should -Be 1
            $result.FailedChecks | Should -Be 1
            $result.ComplianceScore | Should -Be 50
        }
        
        It 'Should calculate compliance score correctly' {
            $result = Invoke-ComplianceAssessment -Framework 'PCI_DSS'
            
            $result.ComplianceScore | Should -Be 100
            $result.PassedChecks | Should -Be 2
            $result.FailedChecks | Should -Be 0
        }
        
        It 'Should generate report when requested' {
            Mock New-ComplianceReport {} -ModuleName 'CloudScope.Compliance'
            
            Invoke-ComplianceAssessment -Framework 'GDPR' -GenerateReport
            
            Assert-MockCalled -CommandName New-ComplianceReport -ModuleName 'CloudScope.Compliance' -Times 1
        }
        
        It 'Should throw for unsupported framework' {
            { Invoke-ComplianceAssessment -Framework 'ISO27001' } | Should -Throw "*not implemented*"
        }
    }
    
    Context 'Compliance Metrics' {
        BeforeAll {
            Initialize-CloudScopeCompliance
        }
        
        It 'Should track compliance metrics' {
            InModuleScope 'CloudScope.Compliance' {
                # Reset metrics
                $script:ComplianceMetrics = @{
                    TotalOperations = 0
                    CompliantOperations = 0
                    ViolationCount = 0
                    ComplianceRate = 100.0
                }
                
                # Simulate operations
                $script:ComplianceMetrics.TotalOperations = 10
                $script:ComplianceMetrics.CompliantOperations = 8
                $script:ComplianceMetrics.ViolationCount = 2
                
                # Update rate
                Update-ComplianceRate
                
                $script:ComplianceMetrics.ComplianceRate | Should -Be 80.0
            }
        }
        
        It 'Should get compliance violations' {
            InModuleScope 'CloudScope.Compliance' {
                # Add test violations
                $script:ComplianceViolations.Clear()
                
                Add-ComplianceViolation -Type 'TestViolation' -Description 'Test violation 1'
                Add-ComplianceViolation -Type 'TestViolation' -Description 'Test violation 2'
                
                $violations = Get-ComplianceViolations
                $violations.Count | Should -Be 2
                $violations[0].Type | Should -Be 'TestViolation'
            }
        }
        
        It 'Should filter recent violations' {
            InModuleScope 'CloudScope.Compliance' {
                # Add old and new violations
                $script:ComplianceViolations.Clear()
                
                $oldViolation = @{
                    Id = [guid]::NewGuid().ToString()
                    Timestamp = (Get-Date).AddDays(-2)
                    Type = 'OldViolation'
                }
                $script:ComplianceViolations.Add($oldViolation)
                
                Add-ComplianceViolation -Type 'RecentViolation' -Description 'Recent'
                
                $recent = Get-ComplianceViolations -Recent -Hours 24
                $recent.Count | Should -Be 1
                $recent[0].Type | Should -Be 'RecentViolation'
            }
        }
    }
}

Describe 'Framework-Specific Tests' {
    
    Context 'GDPR Compliance' {
        BeforeAll {
            Mock Enable-InformationProtectionLabels {} -ModuleName 'CloudScope.Compliance'
            Mock New-DLPPolicy {} -ModuleName 'CloudScope.Compliance'
            Mock Enable-PersonalDataAuditing {} -ModuleName 'CloudScope.Compliance'
            Mock Enable-DataPseudonymization {} -ModuleName 'CloudScope.Compliance'
        }
        
        It 'Should configure GDPR settings' {
            { Set-GDPRCompliance -LawfulBasis "Consent" -RetentionDays 730 } | Should -Not -Throw
            
            InModuleScope 'CloudScope.Compliance' {
                $script:ComplianceContext.Framework | Should -Be 'GDPR'
                $script:ComplianceContext.LawfulBasis | Should -Be 'Consent'
            }
        }
        
        It 'Should enable pseudonymization when requested' {
            Set-GDPRCompliance -EnablePseudonymization
            
            Assert-MockCalled -CommandName Enable-DataPseudonymization -ModuleName 'CloudScope.Compliance' -Times 1
        }
    }
    
    Context 'PCI DSS Compliance' {
        BeforeAll {
            Mock Set-KeyVaultConfiguration {} -ModuleName 'CloudScope.Compliance'
            Mock Enable-PANMaskingPolicy {} -ModuleName 'CloudScope.Compliance'
            Mock Enable-PaymentTokenization {} -ModuleName 'CloudScope.Compliance'
            Mock Set-NetworkSecurityGroups {} -ModuleName 'CloudScope.Compliance'
            Mock Enable-SecurityLogging {} -ModuleName 'CloudScope.Compliance'
        }
        
        It 'Should configure PCI settings' {
            { Set-PCICompliance -EnablePANMasking -KeyRotationDays 30 } | Should -Not -Throw
            
            Assert-MockCalled -CommandName Enable-PANMaskingPolicy -ModuleName 'CloudScope.Compliance' -Times 1
            Assert-MockCalled -CommandName Set-KeyVaultConfiguration -ModuleName 'CloudScope.Compliance' -ParameterFilter {
                $KeyRotationDays -eq 30
            }
        }
        
        It 'Should enable tokenization when requested' {
            Set-PCICompliance -EnableTokenization
            
            Assert-MockCalled -CommandName Enable-PaymentTokenization -ModuleName 'CloudScope.Compliance' -Times 1
        }
    }
}

Describe 'Integration Tests' {
    
    Context 'End-to-End Compliance Workflow' {
        BeforeAll {
            Initialize-CloudScopeCompliance -Framework GDPR
            
            # Create test data
            $testDir = Join-Path $TestDrive 'ComplianceTest'
            New-Item -ItemType Directory -Path $testDir -Force | Out-Null
            
            $personalData = @"
Name,Email,Phone
John Doe,john@example.com,555-1234
Jane Smith,jane@example.com,555-5678
"@
            $personalData | Out-File (Join-Path $testDir 'personal.csv')
            
            $paymentData = @"
CardNumber,CardHolder,Amount
4111111111111111,John Doe,100.00
5555555555554444,Jane Smith,200.00
"@
            $paymentData | Out-File (Join-Path $testDir 'payment.csv')
        }
        
        It 'Should complete full compliance workflow' {
            # 1. Initialize
            { Initialize-CloudScopeCompliance -Framework GDPR } | Should -Not -Throw
            
            # 2. Classify data
            $files = Get-ChildItem $testDir -File
            foreach ($file in $files) {
                $classification = if ($file.Name -match 'payment') { 'Payment' } else { 'Personal' }
                { Set-DataClassification -Path $file.FullName -Classification $classification } | Should -Not -Throw
            }
            
            # 3. Test access control
            $hasAccess = Test-AccessControl -User 'admin@contoso.com' -Resource 'PersonalData' -Permission 'Read'
            $hasAccess | Should -BeOfType [bool]
            
            # 4. Run assessment
            $assessment = Invoke-ComplianceAssessment -Framework GDPR
            $assessment | Should -Not -BeNullOrEmpty
            $assessment.Framework | Should -Be 'GDPR'
            
            # 5. Check metrics
            InModuleScope 'CloudScope.Compliance' {
                $metrics = Get-ComplianceMetrics
                $metrics.TotalOperations | Should -BeGreaterThan 0
            }
        }
    }
}
