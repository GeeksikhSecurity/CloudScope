<#
.SYNOPSIS
    Pester tests for CloudScope.Core module
    
.DESCRIPTION
    Unit tests for the core functionality of CloudScope
#>

BeforeAll {
    # Import the module
    Import-Module "$PSScriptRoot/../CloudScope.Core.psd1" -Force
    
    # Mock external commands
    Mock Get-MgContext {
        @{
            TenantId = '12345678-1234-1234-1234-123456789012'
            Account = 'test@contoso.com'
        }
    }
    
    Mock Connect-MgGraph { $true }
    
    Mock Get-AzContext {
        @{
            Subscription = @{
                Id = '87654321-4321-4321-4321-210987654321'
                Name = 'Test Subscription'
            }
            Tenant = @{
                Id = '12345678-1234-1234-1234-123456789012'
            }
        }
    }
    
    Mock Connect-AzAccount { $true }
    
    # Create test config file
    $testConfigDir = Join-Path $TestDrive 'cloudscope'
    $testConfigPath = Join-Path $testConfigDir 'config.json'
    $testLogPath = Join-Path $testConfigDir 'logs'
    
    New-Item -Path $testConfigDir -ItemType Directory -Force | Out-Null
    
    $testConfig = @{
        Version = "1.0.0"
        TenantId = "test-tenant-id"
        SubscriptionId = "test-subscription-id"
        Environment = "Test"
    }
    
    $testConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $testConfigPath
    
    # Set module variables for testing
    InModuleScope 'CloudScope.Core' {
        $script:CloudScopeContext.ConfigPath = $using:testConfigPath
        $script:CloudScopeContext.LogPath = $using:testLogPath
    }
}

Describe 'CloudScope.Core Module' {
    Context 'Module Import' {
        It 'Should import successfully' {
            Get-Module 'CloudScope.Core' | Should -Not -BeNullOrEmpty
        }
        
        It 'Should export required functions' {
            $module = Get-Module 'CloudScope.Core'
            $module.ExportedFunctions.Keys | Should -Contain 'Initialize-CloudScope'
            $module.ExportedFunctions.Keys | Should -Contain 'Connect-CloudScopeServices'
            $module.ExportedFunctions.Keys | Should -Contain 'Get-CloudScopeConfig'
            $module.ExportedFunctions.Keys | Should -Contain 'Set-CloudScopeConfig'
        }
    }
    
    Context 'Initialize-CloudScope' {
        It 'Should initialize successfully' {
            $result = Initialize-CloudScope
            $result | Should -BeTrue
            
            InModuleScope 'CloudScope.Core' {
                $script:CloudScopeContext.Initialized | Should -BeTrue
            }
        }
        
        It 'Should use custom config path when specified' {
            $customPath = Join-Path $TestDrive 'custom-config.json'
            $result = Initialize-CloudScope -ConfigPath $customPath -Force
            $result | Should -BeTrue
            
            InModuleScope 'CloudScope.Core' {
                $script:CloudScopeContext.ConfigPath | Should -Be $using:customPath
            }
        }
    }
    
    Context 'Connect-CloudScopeServices' {
        It 'Should connect to Microsoft Graph' {
            $result = Connect-CloudScopeServices
            $result | Should -BeTrue
            
            Assert-MockCalled Connect-MgGraph -Times 1 -Exactly
            
            InModuleScope 'CloudScope.Core' {
                $script:CloudScopeContext.AuthenticationStatus.Graph | Should -BeTrue
            }
        }
        
        It 'Should connect to Azure if available' {
            # Mock Get-Module to indicate Az.Accounts is available
            Mock Get-Module { $true } -ParameterFilter { $Name -eq 'Az.Accounts' -and $ListAvailable }
            
            $result = Connect-CloudScopeServices
            $result | Should -BeTrue
            
            Assert-MockCalled Connect-AzAccount -Times 1 -Exactly
            
            InModuleScope 'CloudScope.Core' {
                $script:CloudScopeContext.AuthenticationStatus.Azure | Should -BeTrue
            }
        }
        
        It 'Should use specified tenant ID' {
            $tenantId = 'custom-tenant-id'
            Connect-CloudScopeServices -TenantId $tenantId
            
            Assert-MockCalled Connect-MgGraph -ParameterFilter { $TenantId -eq $tenantId }
        }
        
        It 'Should support interactive authentication' {
            Connect-CloudScopeServices -Interactive
            
            Assert-MockCalled Connect-MgGraph -ParameterFilter { $Interactive -eq $true }
        }
    }
    
    Context 'Configuration Management' {
        It 'Should get configuration' {
            $config = Get-CloudScopeConfig
            $config | Should -Not -BeNullOrEmpty
            $config.TenantId | Should -Be 'test-tenant-id'
            $config.Environment | Should -Be 'Test'
        }
        
        It 'Should set configuration value' {
            $result = Set-CloudScopeConfig -Setting 'TestSetting' -Value 'TestValue'
            $result | Should -BeTrue
            
            $config = Get-CloudScopeConfig
            $config.TestSetting | Should -Be 'TestValue'
        }
        
        It 'Should set nested configuration value' {
            $result = Set-CloudScopeConfig -Setting 'Nested.Setting' -Value 'NestedValue'
            $result | Should -BeTrue
            
            $config = Get-CloudScopeConfig
            $config.Nested.Setting | Should -Be 'NestedValue'
        }
        
        It 'Should import configuration' {
            $importPath = Join-Path $TestDrive 'import-config.json'
            $importConfig = @{
                ImportTest = 'ImportValue'
            }
            $importConfig | ConvertTo-Json | Set-Content -Path $importPath
            
            $result = Import-CloudScopeConfig -Path $importPath
            $result | Should -BeTrue
            
            $config = Get-CloudScopeConfig
            $config.ImportTest | Should -Be 'ImportValue'
        }
        
        It 'Should export configuration' {
            $exportPath = Join-Path $TestDrive 'export-config.json'
            
            $result = Export-CloudScopeConfig -Path $exportPath
            $result | Should -BeTrue
            
            Test-Path -Path $exportPath | Should -BeTrue
            $exportedConfig = Get-Content -Path $exportPath -Raw | ConvertFrom-Json
            $exportedConfig.TenantId | Should -Be 'test-tenant-id'
        }
    }
    
    Context 'Logging' {
        It 'Should write log messages' {
            $result = Write-CloudScopeLog -Message 'Test log message' -Level Information
            $result | Should -BeTrue
            
            $logFile = Join-Path $testLogPath "CloudScope_$(Get-Date -Format 'yyyyMMdd').log"
            Test-Path -Path $logFile | Should -BeTrue
            $logContent = Get-Content -Path $logFile -Raw
            $logContent | Should -Match 'Test log message'
        }
        
        It 'Should include tags in log messages' {
            $result = Write-CloudScopeLog -Message 'Tagged message' -Level Information -Tags @('Test', 'Unit')
            $result | Should -BeTrue
            
            $logFile = Join-Path $testLogPath "CloudScope_$(Get-Date -Format 'yyyyMMdd').log"
            $logContent = Get-Content -Path $logFile -Raw
            $logContent | Should -Match 'Tagged message'
            $logContent | Should -Match '\[Tags: Test, Unit\]'
        }
    }
}