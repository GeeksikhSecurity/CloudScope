#Requires -Module Pester

<#
.SYNOPSIS
    Pester tests for CloudScope.Graph module
    
.DESCRIPTION
    Unit tests for Microsoft Graph integration functionality
#>

BeforeAll {
    # Import the module
    $modulePath = Join-Path $PSScriptRoot '..' 'Modules' 'CloudScope.Graph'
    Import-Module $modulePath -Force
    
    # Mock Microsoft Graph cmdlets
    Mock Connect-MgGraph {}
    Mock Disconnect-MgGraph {}
    Mock Get-MgContext {
        @{
            Account = 'test@contoso.com'
            TenantId = '12345678-1234-1234-1234-123456789012'
            Scopes = @('User.Read.All', 'Group.Read.All')
            AppId = 'app123'
        }
    }
    Mock Get-MgUser {
        @{
            Id = 'user123'
            UserPrincipalName = 'test.user@contoso.com'
            DisplayName = 'Test User'
            Department = 'IT'
            JobTitle = 'Developer'
            AccountEnabled = $true
            UserType = 'Member'
            CreatedDateTime = Get-Date
            LastSignInDateTime = (Get-Date).AddDays(-1)
        }
    }
    Mock Get-MgUserMemberOf {
        @(
            @{ AdditionalProperties = @{ displayName = 'IT Team' } }
            @{ AdditionalProperties = @{ displayName = 'Developers' } }
        )
    }
    Mock Invoke-MgGraphRequest {
        @{
            value = @()
        }
    }
}

Describe 'CloudScope.Graph Module Tests' {
    
    Context 'Module Import' {
        It 'Should import successfully' {
            $module = Get-Module -Name 'CloudScope.Graph'
            $module | Should -Not -BeNullOrEmpty
        }
        
        It 'Should export expected functions' {
            $expectedFunctions = @(
                'Connect-CloudScopeGraph',
                'Disconnect-CloudScopeGraph',
                'Get-CloudScopeGraphContext',
                'Get-ComplianceUsers',
                'Get-UserComplianceData',
                'Get-SensitiveDataLocations',
                'Get-ComplianceAlerts',
                'Invoke-GraphAPIRequest'
            )
            
            $module = Get-Module -Name 'CloudScope.Graph'
            $exportedFunctions = $module.ExportedFunctions.Keys
            
            foreach ($function in $expectedFunctions) {
                $exportedFunctions | Should -Contain $function
            }
        }
    }
    
    Context 'Connect-CloudScopeGraph' {
        BeforeEach {
            InModuleScope 'CloudScope.Graph' {
                $script:GraphContext = @{
                    Connected = $false
                    Scopes = @()
                    TenantId = $null
                    Environment = $null
                    AppId = $null
                }
            }
        }
        
        It 'Should connect with default settings' {
            { Connect-CloudScopeGraph } | Should -Not -Throw
            
            InModuleScope 'CloudScope.Graph' {
                $script:GraphContext.Connected | Should -Be $true
                $script:GraphContext.TenantId | Should -Not -BeNullOrEmpty
                $script:GraphContext.Environment | Should -Be 'Production'
            }
            
            Assert-MockCalled -CommandName Connect-MgGraph -Times 1
        }
        
        It 'Should connect with specific tenant' {
            $tenantId = 'test-tenant-123'
            
            { Connect-CloudScopeGraph -TenantId $tenantId } | Should -Not -Throw
            
            Assert-MockCalled -CommandName Connect-MgGraph -ParameterFilter {
                $TenantId -eq $tenantId
            }
        }
        
        It 'Should support different environments' {
            $environments = @('Production', 'USGov', 'China', 'Germany')
            
            foreach ($env in $environments) {
                { Connect-CloudScopeGraph -Environment $env } | Should -Not -Throw
                
                InModuleScope 'CloudScope.Graph' -ArgumentList $env {
                    param($env)
                    $script:GraphContext.Environment | Should -Be $env
                }
            }
        }
        
        It 'Should include required compliance scopes' {
            Connect-CloudScopeGraph
            
            $expectedScopes = @(
                'User.Read.All',
                'Group.Read.All',
                'Directory.Read.All',
                'InformationProtectionPolicy.Read',
                'SecurityEvents.Read.All',
                'AuditLog.Read.All'
            )
            
            Assert-MockCalled -CommandName Connect-MgGraph -ParameterFilter {
                $allExpected = $true
                foreach ($scope in $expectedScopes) {
                    if ($Scopes -notcontains $scope) {
                        $allExpected = $false
                        break
                    }
                }
                $allExpected
            }
        }
        
        It 'Should merge additional scopes' {
            $additionalScopes = @('Mail.Read', 'Calendar.Read')
            
            Connect-CloudScopeGraph -Scopes $additionalScopes
            
            Assert-MockCalled -CommandName Connect-MgGraph -ParameterFilter {
                $Scopes -contains 'Mail.Read' -and $Scopes -contains 'Calendar.Read'
            }
        }
    }
    
    Context 'Disconnect-CloudScopeGraph' {
        BeforeAll {
            Connect-CloudScopeGraph
        }
        
        It 'Should disconnect successfully' {
            { Disconnect-CloudScopeGraph } | Should -Not -Throw
            
            InModuleScope 'CloudScope.Graph' {
                $script:GraphContext.Connected | Should -Be $false
                $script:GraphContext.Scopes | Should -BeNullOrEmpty
                $script:GraphContext.TenantId | Should -BeNullOrEmpty
            }
            
            Assert-MockCalled -CommandName Disconnect-MgGraph -Times 1
        }
        
        It 'Should clear cache on disconnect' {
            InModuleScope 'CloudScope.Graph' {
                # Add some cache data
                $script:GraphCache.Users['test'] = @{ Name = 'Test' }
                $script:GraphCache.Labels['label1'] = @{ Name = 'Label1' }
            }
            
            Disconnect-CloudScopeGraph
            
            InModuleScope 'CloudScope.Graph' {
                $script:GraphCache.Users.Count | Should -Be 0
                $script:GraphCache.Labels.Count | Should -Be 0
            }
        }
    }
    
    Context 'Get-CloudScopeGraphContext' {
        It 'Should return context when connected' {
            Connect-CloudScopeGraph
            
            $context = Get-CloudScopeGraphContext
            
            $context | Should -Not -BeNullOrEmpty
            $context.Connected | Should -Be $true
            $context.Environment | Should -Be 'Production'
        }
        
        It 'Should warn when not connected' {
            InModuleScope 'CloudScope.Graph' {
                $script:GraphContext.Connected = $false
            }
            
            $context = Get-CloudScopeGraphContext 3>&1
            
            $context | Should -BeNullOrEmpty
        }
    }
    
    Context 'Get-ComplianceUsers' {
        BeforeAll {
            Connect-CloudScopeGraph
            
            Mock Get-MgUserManager {
                @{ AdditionalProperties = @{ displayName = 'Manager Name' } }
            }
            Mock Get-UserRiskState {
                @{ RiskLevel = 'Low'; RiskState = 'None'; LastUpdated = Get-Date }
            } -ModuleName 'CloudScope.Graph'
            Mock Test-PrivilegedAccess { $false } -ModuleName 'CloudScope.Graph'
            Mock Test-SensitiveDataAccess { $true } -ModuleName 'CloudScope.Graph'
        }
        
        It 'Should get users with compliance properties' {
            $users = Get-ComplianceUsers
            
            $users | Should -Not -BeNullOrEmpty
            $users[0].UserPrincipalName | Should -Be 'test.user@contoso.com'
            $users[0].Groups | Should -Not -BeNullOrEmpty
            $users[0].HasPrivilegedAccess | Should -Be $false
            $users[0].HasSensitiveDataAccess | Should -Be $true
        }
        
        It 'Should apply filters correctly' {
            Get-ComplianceUsers -Filter "department eq 'IT'"
            
            Assert-MockCalled -CommandName Get-MgUser -ParameterFilter {
                $Filter -eq "department eq 'IT'"
            }
        }
        
        It 'Should include risk state when requested' {
            $users = Get-ComplianceUsers -IncludeRiskState
            
            $users[0].RiskState | Should -Not -BeNullOrEmpty
            $users[0].RiskState.RiskLevel | Should -Be 'Low'
        }
        
        It 'Should exclude guest users by default' {
            Get-ComplianceUsers
            
            Assert-MockCalled -CommandName Get-MgUser -ParameterFilter {
                $Filter -eq "userType eq 'Member'"
            }
        }
        
        It 'Should include guests when specified' {
            Get-ComplianceUsers -IncludeGuests
            
            Assert-MockCalled -CommandName Get-MgUser -ParameterFilter {
                $null -eq $Filter
            }
        }
        
        It 'Should respect Top parameter' {
            Get-ComplianceUsers -Top 50
            
            Assert-MockCalled -CommandName Get-MgUser -ParameterFilter {
                $Top -eq 50
            }
        }
    }
    
    Context 'Get-UserComplianceData' {
        BeforeAll {
            Connect-CloudScopeGraph
            
            Mock Get-MgUserRegisteredDevice {
                @(
                    @{ DisplayName = 'Device1'; OperatingSystem = 'Windows' }
                )
            }
            Mock Get-MgUserAppRoleAssignment {
                @(
                    @{ AppRoleId = 'role123'; PrincipalDisplayName = 'Test User' }
                )
            }
            Mock Get-MgRiskDetection { @() }
            Mock Get-DataAccessLogs { @() } -ModuleName 'CloudScope.Graph'
            Mock Get-UserComplianceViolations { @() } -ModuleName 'CloudScope.Graph'
        }
        
        It 'Should get comprehensive user compliance data' {
            $data = Get-UserComplianceData -UserId 'test@contoso.com'
            
            $data | Should -Not -BeNullOrEmpty
            $data.User | Should -Not -BeNullOrEmpty
            $data.Devices | Should -Not -BeNullOrEmpty
            $data.Applications | Should -Not -BeNullOrEmpty
            $data.Keys | Should -Contain 'SignInActivity'
            $data.Keys | Should -Contain 'ComplianceViolations'
        }
        
        It 'Should handle user ID or UPN' {
            Get-UserComplianceData -UserId 'user123'
            Assert-MockCalled -CommandName Get-MgUser -ParameterFilter { $UserId -eq 'user123' }
            
            Get-UserComplianceData -UserId 'test@contoso.com'
            Assert-MockCalled -CommandName Get-MgUser -ParameterFilter { $UserId -eq 'test@contoso.com' }
        }
        
        It 'Should include risk events when available' {
            Mock Get-MgRiskDetection {
                @(
                    @{ Id = 'risk123'; RiskLevel = 'Medium' }
                )
            }
            
            $data = Get-UserComplianceData -UserId 'test@contoso.com'
            
            $data.RiskEvents | Should -Not -BeNullOrEmpty
            $data.RiskEvents[0].RiskLevel | Should -Be 'Medium'
        }
    }
    
    Context 'Get-SensitiveDataLocations' {
        BeforeAll {
            Connect-CloudScopeGraph
            
            Mock Get-DataGovernanceLabels { @() } -ModuleName 'CloudScope.Graph'
            Mock Search-OneDriveContent {
                @(
                    @{ Path = '/personal/user/file1.xlsx'; RiskLevel = 'High' }
                )
            } -ModuleName 'CloudScope.Graph'
            Mock Search-SharePointContent {
                @(
                    @{ Path = '/sites/hr/docs/employees.csv'; RiskLevel = 'Medium' }
                )
            } -ModuleName 'CloudScope.Graph'
            Mock Search-ExchangeContent { @() } -ModuleName 'CloudScope.Graph'
            Mock Search-TeamsContent { @() } -ModuleName 'CloudScope.Graph'
        }
        
        It 'Should search for sensitive data across all scopes' {
            $locations = Get-SensitiveDataLocations -DataType 'Personal' -Scope 'All'
            
            $locations | Should -Not -BeNullOrEmpty
            $locations.DataType | Should -Be 'Personal'
            $locations.Scope | Should -Be 'All'
            $locations.TotalLocations | Should -Be 2
            $locations.HighRiskLocations.Count | Should -Be 1
        }
        
        It 'Should search specific scopes' {
            Get-SensitiveDataLocations -DataType 'CreditCard' -Scope 'OneDrive'
            
            Assert-MockCalled -CommandName Search-OneDriveContent -ModuleName 'CloudScope.Graph' -Times 1
            Assert-MockCalled -CommandName Search-SharePointContent -ModuleName 'CloudScope.Graph' -Times 0
        }
        
        It 'Should handle different data types' {
            $dataTypes = @('CreditCard', 'SSN', 'HealthRecord', 'Financial', 'Personal')
            
            foreach ($type in $dataTypes) {
                { Get-SensitiveDataLocations -DataType $type -Scope 'OneDrive' } | Should -Not -Throw
            }
        }
    }
    
    Context 'Get-ComplianceAlerts' {
        BeforeAll {
            Connect-CloudScopeGraph
            
            Mock Invoke-GraphAPIRequest {
                @{
                    value = @(
                        @{
                            id = 'alert1'
                            title = 'Suspicious Activity'
                            severity = 'high'
                            status = 'active'
                            createdDateTime = (Get-Date).AddHours(-2)
                        },
                        @{
                            id = 'alert2'
                            title = 'Policy Violation'
                            severity = 'medium'
                            status = 'active'
                            createdDateTime = (Get-Date).AddDays(-1)
                        }
                    )
                }
            } -ModuleName 'CloudScope.Graph'
            
            Mock Get-UnifiedAuditLogAlerts { @() } -ModuleName 'CloudScope.Graph'
        }
        
        It 'Should get compliance alerts' {
            $alerts = Get-ComplianceAlerts
            
            $alerts | Should -Not -BeNullOrEmpty
            $alerts.Count | Should -Be 2
            $alerts[0].Title | Should -Be 'Suspicious Activity'
        }
        
        It 'Should filter by severity' {
            Get-ComplianceAlerts -Severity 'High'
            
            Assert-MockCalled -CommandName Invoke-GraphAPIRequest -ModuleName 'CloudScope.Graph' -ParameterFilter {
                $Uri -match "severity eq 'high'"
            }
        }
        
        It 'Should filter by status' {
            Get-ComplianceAlerts -Status 'Active'
            
            Assert-MockCalled -CommandName Invoke-GraphAPIRequest -ModuleName 'CloudScope.Graph' -ParameterFilter {
                $Uri -match "status eq 'active'"
            }
        }
        
        It 'Should filter by date range' {
            Get-ComplianceAlerts -Days 30
            
            Assert-MockCalled -CommandName Invoke-GraphAPIRequest -ModuleName 'CloudScope.Graph' -ParameterFilter {
                $Uri -match "createdDateTime ge"
            }
        }
    }
    
    Context 'New-ComplianceAlert' {
        BeforeAll {
            Connect-CloudScopeGraph
            
            Mock Write-AuditLog {} -ModuleName 'CloudScope.Graph'
            Mock Test-AzureMonitorConnection { $false } -ModuleName 'CloudScope.Graph'
        }
        
        It 'Should create compliance alert' {
            $alert = New-ComplianceAlert -Title "Test Alert" -Description "Test description" -Severity "High"
            
            $alert | Should -Not -BeNullOrEmpty
            $alert.title | Should -Be "Test Alert"
            $alert.severity | Should -Be "high"
            $alert.status | Should -Be "active"
            $alert.id | Should -Not -BeNullOrEmpty
        }
        
        It 'Should include evidence when provided' {
            $evidence = @{ File = 'test.xlsx'; User = 'john@contoso.com' }
            
            $alert = New-ComplianceAlert -Title "Data Breach" -Description "Unauthorized access" -Severity "Critical" -Evidence $evidence
            
            $alert.evidence | Should -Not -BeNullOrEmpty
            $alert.evidence.File | Should -Be 'test.xlsx'
        }
        
        It 'Should log alert creation' {
            New-ComplianceAlert -Title "Test" -Description "Test" -Severity "Low"
            
            Assert-MockCalled -CommandName Write-AuditLog -ModuleName 'CloudScope.Graph' -ParameterFilter {
                $Operation -eq "ComplianceAlertCreated"
            }
        }
    }
    
    Context 'Invoke-GraphAPIRequest' {
        BeforeAll {
            Connect-CloudScopeGraph
            
            Mock Invoke-MgGraphRequest {
                @{ success = $true }
            }
        }
        
        It 'Should make Graph API request' {
            $result = Invoke-GraphAPIRequest -Uri "/users" -Method GET
            
            $result | Should -Not -BeNullOrEmpty
            $result.success | Should -Be $true
            
            Assert-MockCalled -CommandName Invoke-MgGraphRequest -ParameterFilter {
                $Uri -match "/v1.0/users" -and $Method -eq 'GET'
            }
        }
        
        It 'Should handle relative URIs' {
            Invoke-GraphAPIRequest -Uri "users/test@contoso.com"
            
            Assert-MockCalled -CommandName Invoke-MgGraphRequest -ParameterFilter {
                $Uri -match "/v1.0/users/test@contoso.com"
            }
        }
        
        It 'Should handle absolute URIs' {
            Invoke-GraphAPIRequest -Uri "https://graph.microsoft.com/v1.0/users"
            
            Assert-MockCalled -CommandName Invoke-MgGraphRequest -ParameterFilter {
                $Uri -eq "https://graph.microsoft.com/v1.0/users"
            }
        }
        
        It 'Should send body for POST requests' {
            $body = @{ displayName = "Test User" }
            
            Invoke-GraphAPIRequest -Uri "/users" -Method POST -Body $body
            
            Assert-MockCalled -CommandName Invoke-MgGraphRequest -ParameterFilter {
                $Method -eq 'POST' -and $Body -ne $null
            }
        }
        
        It 'Should throw when not connected' {
            InModuleScope 'CloudScope.Graph' {
                $script:GraphContext.Connected = $false
            }
            
            { Invoke-GraphAPIRequest -Uri "/users" } | Should -Throw "*Not connected*"
        }
    }
    
    Context 'Cache Management' {
        BeforeAll {
            Connect-CloudScopeGraph
        }
        
        It 'Should cache data governance labels' {
            Mock Invoke-GraphAPIRequest {
                @{
                    value = @(
                        @{ id = 'label1'; displayName = 'Confidential'; isEnabled = $true }
                    )
                }
            } -ModuleName 'CloudScope.Graph'
            
            # First call should hit the API
            $labels1 = Get-DataGovernanceLabels
            Assert-MockCalled -CommandName Invoke-GraphAPIRequest -ModuleName 'CloudScope.Graph' -Times 1
            
            # Second call within 30 minutes should use cache
            $labels2 = Get-DataGovernanceLabels
            Assert-MockCalled -CommandName Invoke-GraphAPIRequest -ModuleName 'CloudScope.Graph' -Times 1
            
            $labels1[0].displayName | Should -Be $labels2[0].displayName
        }
        
        It 'Should refresh cache after timeout' {
            InModuleScope 'CloudScope.Graph' {
                # Set cache time to past
                $script:GraphCache.LastRefresh = (Get-Date).AddHours(-1)
            }
            
            Mock Invoke-GraphAPIRequest {
                @{ value = @() }
            } -ModuleName 'CloudScope.Graph'
            
            Get-DataGovernanceLabels
            
            # Should make new API call
            Assert-MockCalled -CommandName Invoke-GraphAPIRequest -ModuleName 'CloudScope.Graph'
        }
    }
}

Describe 'Integration Tests' {
    
    Context 'Multi-Service Data Search' {
        BeforeAll {
            Connect-CloudScopeGraph
            
            Mock Get-DataGovernanceLabels { 
                @(
                    @{ id = 'label1'; displayName = 'Personal Data' }
                )
            } -ModuleName 'CloudScope.Graph'
            
            Mock Search-OneDriveContent {
                @(
                    @{ Path = '/personal/user1/data.xlsx'; RiskLevel = 'High'; Classification = $null }
                    @{ Path = '/personal/user2/info.docx'; RiskLevel = 'Medium'; Classification = 'Internal' }
                )
            } -ModuleName 'CloudScope.Graph'
            
            Mock Search-SharePointContent {
                @(
                    @{ Path = '/sites/hr/employees.xlsx'; RiskLevel = 'High'; Classification = $null }
                )
            } -ModuleName 'CloudScope.Graph'
            
            Mock Search-ExchangeContent { @() } -ModuleName 'CloudScope.Graph'
            Mock Search-TeamsContent { @() } -ModuleName 'CloudScope.Graph'
        }
        
        It 'Should aggregate results from multiple services' {
            $results = Get-SensitiveDataLocations -DataType 'Personal' -Scope 'All'
            
            $results.TotalLocations | Should -Be 3
            $results.HighRiskLocations.Count | Should -Be 2
            $results.Locations | Should -HaveCount 3
        }
        
        It 'Should identify unclassified data' {
            $results = Get-SensitiveDataLocations -DataType 'Personal' -Scope 'All'
            
            $unclassified = $results.Locations | Where-Object { -not $_.Classification }
            $unclassified.Count | Should -Be 2
        }
    }
    
    Context 'User Compliance Assessment' {
        BeforeAll {
            Connect-CloudScopeGraph
            
            Mock Get-MgUser {
                @(
                    @{
                        Id = 'user1'
                        UserPrincipalName = 'high.risk@contoso.com'
                        DisplayName = 'High Risk User'
                        LastSignInDateTime = (Get-Date).AddDays(-100)
                        UserType = 'Member'
                    },
                    @{
                        Id = 'user2'
                        UserPrincipalName = 'guest.user@external.com'
                        DisplayName = 'External Guest'
                        UserType = 'Guest'
                    }
                )
            }
            
            Mock Get-UserRiskState {
                param($UserId)
                if ($UserId -eq 'user1') {
                    @{ RiskLevel = 'High'; RiskState = 'AtRisk' }
                } else {
                    @{ RiskLevel = 'Low'; RiskState = 'None' }
                }
            } -ModuleName 'CloudScope.Graph'
            
            Mock Test-PrivilegedAccess {
                param($UserId)
                $UserId -eq 'user1'
            } -ModuleName 'CloudScope.Graph'
            
            Mock Test-SensitiveDataAccess {
                param($UserId)
                $true
            } -ModuleName 'CloudScope.Graph'
        }
        
        It 'Should identify high-risk users with privileged access' {
            $users = Get-ComplianceUsers -IncludeRiskState -IncludeGuests
            
            $highRiskPrivileged = $users | Where-Object { 
                $_.RiskState.RiskLevel -eq 'High' -and $_.HasPrivilegedAccess 
            }
            
            $highRiskPrivileged.Count | Should -Be 1
            $highRiskPrivileged[0].UserPrincipalName | Should -Be 'high.risk@contoso.com'
        }
        
        It 'Should identify guest users with sensitive data access' {
            $users = Get-ComplianceUsers -IncludeGuests
            
            $guestWithAccess = $users | Where-Object {
                $_.UserType -eq 'Guest' -and $_.HasSensitiveDataAccess
            }
            
            $guestWithAccess.Count | Should -Be 1
            $guestWithAccess[0].UserPrincipalName | Should -Be 'guest.user@external.com'
        }
        
        It 'Should identify dormant accounts' {
            $users = Get-ComplianceUsers -IncludeGuests
            
            $dormantUsers = $users | Where-Object {
                $_.LastSignInDateTime -lt (Get-Date).AddDays(-90)
            }
            
            $dormantUsers.Count | Should -BeGreaterThan 0
        }
    }
}
