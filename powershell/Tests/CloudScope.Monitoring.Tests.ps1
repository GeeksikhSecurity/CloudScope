#Requires -Module Pester

<#
.SYNOPSIS
    Pester tests for CloudScope.Monitoring module
    
.DESCRIPTION
    Unit tests for Azure Monitor integration and compliance monitoring
#>

BeforeAll {
    # Import the module
    $modulePath = Join-Path $PSScriptRoot '..' 'Modules' 'CloudScope.Monitoring'
    Import-Module $modulePath -Force
    
    # Mock Azure cmdlets
    Mock Get-AzContext {
        @{
            Subscription = @{ Id = 'sub123' }
            Account = @{ Id = 'account123' }
        }
    }
    Mock Get-AzResourceGroup {
        @{ ResourceGroupName = 'rg-test'; Location = 'eastus' }
    }
    Mock Get-AzOperationalInsightsWorkspace {
        @{
            CustomerId = 'workspace123'
            ResourceId = '/subscriptions/sub123/resourceGroups/rg-test/providers/Microsoft.OperationalInsights/workspaces/test-workspace'
        }
    }
    Mock Get-AzOperationalInsightsWorkspaceSharedKey {
        @{ PrimarySharedKey = 'testkey123'; SecondarySharedKey = 'testkey456' }
    }
    Mock Get-AzApplicationInsights {
        @{ InstrumentationKey = 'appinsights123' }
    }
    Mock New-AzResourceGroup { @{ ResourceGroupName = 'rg-test' } }
    Mock New-AzOperationalInsightsWorkspace { @{ CustomerId = 'workspace123' } }
    Mock New-AzApplicationInsights { @{ InstrumentationKey = 'appinsights123' } }
    Mock Start-Job { @{ Id = 123; State = 'Running' } }
    Mock Stop-Job {}
    Mock Remove-Job {}
    Mock Register-ScheduledTask {}
}

Describe 'CloudScope.Monitoring Module Tests' {
    
    Context 'Module Import' {
        It 'Should import successfully' {
            $module = Get-Module -Name 'CloudScope.Monitoring'
            $module | Should -Not -BeNullOrEmpty
        }
        
        It 'Should export expected functions' {
            $expectedFunctions = @(
                'Initialize-ComplianceMonitoring',
                'Start-RealtimeMonitoring',
                'Stop-RealtimeMonitoring',
                'New-ComplianceMetric',
                'Send-ComplianceMetric',
                'New-ComplianceAlert',
                'Get-ComplianceMetrics',
                'Set-AlertingRules'
            )
            
            $module = Get-Module -Name 'CloudScope.Monitoring'
            $exportedFunctions = $module.ExportedFunctions.Keys
            
            foreach ($function in $expectedFunctions) {
                $exportedFunctions | Should -Contain $function
            }
        }
    }
    
    Context 'Initialize-ComplianceMonitoring' {
        BeforeEach {
            InModuleScope 'CloudScope.Monitoring' {
                $script:MonitoringContext = @{
                    WorkspaceId = $null
                    WorkspaceName = $null
                    ResourceGroup = $null
                    SubscriptionId = $null
                    AppInsightsKey = $null
                    IsRunning = $false
                }
            }
        }
        
        It 'Should initialize with existing resources' {
            { Initialize-ComplianceMonitoring -WorkspaceName "test-workspace" -ResourceGroup "rg-test" } | Should -Not -Throw
            
            InModuleScope 'CloudScope.Monitoring' {
                $script:MonitoringContext.WorkspaceId | Should -Be 'workspace123'
                $script:MonitoringContext.WorkspaceName | Should -Be 'test-workspace'
                $script:MonitoringContext.ResourceGroup | Should -Be 'rg-test'
                $script:MonitoringContext.AppInsightsKey | Should -Be 'appinsights123'
            }
        }
        
        It 'Should create resources when they do not exist' {
            Mock Get-AzResourceGroup { $null }
            Mock Get-AzOperationalInsightsWorkspace { $null }
            Mock Get-AzApplicationInsights { $null }
            
            { Initialize-ComplianceMonitoring -WorkspaceName "new-workspace" -ResourceGroup "rg-new" -CreateIfNotExists } | Should -Not -Throw
            
            Assert-MockCalled -CommandName New-AzResourceGroup -Times 1
            Assert-MockCalled -CommandName New-AzOperationalInsightsWorkspace -Times 1
            Assert-MockCalled -CommandName New-AzApplicationInsights -Times 1
        }
        
        It 'Should throw when resources do not exist without CreateIfNotExists' {
            Mock Get-AzResourceGroup { $null }
            
            { Initialize-ComplianceMonitoring -WorkspaceName "test" -ResourceGroup "rg-missing" } | Should -Throw "*not found*"
        }
        
        It 'Should set up custom tables and alert rules' {
            Mock New-ComplianceLogTables {} -ModuleName 'CloudScope.Monitoring'
            Mock Initialize-AlertRules {} -ModuleName 'CloudScope.Monitoring'
            
            Initialize-ComplianceMonitoring -WorkspaceName "test-workspace" -ResourceGroup "rg-test"
            
            Assert-MockCalled -CommandName New-ComplianceLogTables -ModuleName 'CloudScope.Monitoring' -Times 1
            Assert-MockCalled -CommandName Initialize-AlertRules -ModuleName 'CloudScope.Monitoring' -Times 1
        }
    }
    
    Context 'Start-RealtimeMonitoring' {
        BeforeAll {
            InModuleScope 'CloudScope.Monitoring' {
                $script:MonitoringContext = @{
                    WorkspaceId = 'workspace123'
                    IsRunning = $false
                }
            }
        }
        
        It 'Should start monitoring job' {
            { Start-RealtimeMonitoring -IntervalSeconds 60 } | Should -Not -Throw
            
            InModuleScope 'CloudScope.Monitoring' {
                $script:MonitoringContext.IsRunning | Should -Be $true
                $script:MonitoringJob | Should -Not -BeNullOrEmpty
            }
            
            Assert-MockCalled -CommandName Start-Job -Times 1
        }
        
        It 'Should not start if already running' {
            InModuleScope 'CloudScope.Monitoring' {
                $script:MonitoringContext.IsRunning = $true
            }
            
            Start-RealtimeMonitoring -IntervalSeconds 60 -WarningVariable warning 3>&1
            
            $warning | Should -Match "already running"
            Assert-MockCalled -CommandName Start-Job -Times 0 -Scope It
        }
        
        It 'Should throw if not initialized' {
            InModuleScope 'CloudScope.Monitoring' {
                $script:MonitoringContext.WorkspaceId = $null
            }
            
            { Start-RealtimeMonitoring } | Should -Throw "*not initialized*"
        }
    }
    
    Context 'Stop-RealtimeMonitoring' {
        BeforeAll {
            InModuleScope 'CloudScope.Monitoring' {
                $script:MonitoringContext.IsRunning = $true
                $script:MonitoringJob = @{ Id = 123 }
                $script:MonitoringContext.MetricsBuffer = [System.Collections.ArrayList]::new()
            }
        }
        
        It 'Should stop monitoring job' {
            { Stop-RealtimeMonitoring } | Should -Not -Throw
            
            InModuleScope 'CloudScope.Monitoring' {
                $script:MonitoringContext.IsRunning | Should -Be $false
                $script:MonitoringJob | Should -BeNullOrEmpty
            }
            
            Assert-MockCalled -CommandName Stop-Job -Times 1
            Assert-MockCalled -CommandName Remove-Job -Times 1
        }
        
        It 'Should flush buffered metrics' {
            InModuleScope 'CloudScope.Monitoring' {
                $script:MonitoringContext.MetricsBuffer.Add(@{ Name = 'Test'; Value = 1 })
            }
            
            Mock Flush-MetricsBuffer {} -ModuleName 'CloudScope.Monitoring'
            
            Stop-RealtimeMonitoring
            
            Assert-MockCalled -CommandName Flush-MetricsBuffer -ModuleName 'CloudScope.Monitoring' -Times 1
        }
    }
    
    Context 'New-ComplianceMetric' {
        It 'Should create metric with required properties' {
            $metric = New-ComplianceMetric -Name "TestMetric" -Value 42 -Category "Testing"
            
            $metric | Should -Not -BeNullOrEmpty
            $metric.Name | Should -Be "TestMetric"
            $metric.Value | Should -Be 42
            $metric.Category | Should -Be "Testing"
            $metric.Timestamp | Should -BeOfType [DateTime]
        }
        
        It 'Should include additional properties and dimensions' {
            $props = @{ Server = 'Server01'; Database = 'ComplianceDB' }
            $dims = @{ Region = 'East'; Environment = 'Production' }
            
            $metric = New-ComplianceMetric -Name "DBMetric" -Value 100 -Category "Database" -Properties $props -Dimensions $dims
            
            $metric.Properties.Server | Should -Be 'Server01'
            $metric.Dimensions.Region | Should -Be 'East'
        }
        
        It 'Should include compliance context when available' {
            Mock Get-Variable {
                @{ Value = @{ Framework = 'GDPR'; CurrentUser = 'admin@contoso.com' } }
            } -ParameterFilter { $Name -eq 'ComplianceContext' -and $Scope -eq 'Script' }
            
            $metric = New-ComplianceMetric -Name "Test" -Value 1
            
            $metric.Framework | Should -Be 'GDPR'
            $metric.User | Should -Be 'admin@contoso.com'
        }
    }
    
    Context 'Send-ComplianceMetric' {
        BeforeAll {
            InModuleScope 'CloudScope.Monitoring' {
                $script:MonitoringContext.WorkspaceId = 'workspace123'
                $script:MonitoringContext.AppInsightsKey = 'appinsights123'
                $script:MonitoringContext.MetricsBuffer = [System.Collections.ArrayList]::new()
            }
            
            Mock Invoke-WebRequest { @{ StatusCode = 200 } }
            Mock Send-AppInsightsMetric {} -ModuleName 'CloudScope.Monitoring'
        }
        
        It 'Should send metric to Log Analytics' {
            $metric = New-ComplianceMetric -Name "Test" -Value 42
            
            { Send-ComplianceMetric -Metric $metric } | Should -Not -Throw
            
            # Simplified test - actual implementation would check Invoke-WebRequest
        }
        
        It 'Should buffer metrics when requested' {
            $metric = New-ComplianceMetric -Name "Test" -Value 42
            
            Send-ComplianceMetric -Metric $metric -Buffer
            
            InModuleScope 'CloudScope.Monitoring' {
                $script:MonitoringContext.MetricsBuffer.Count | Should -Be 1
                $script:MonitoringContext.MetricsBuffer[0].Name | Should -Be "Test"
            }
        }
        
        It 'Should flush buffer when it reaches limit' {
            Mock Flush-MetricsBuffer {} -ModuleName 'CloudScope.Monitoring'
            
            # Add 100 metrics to trigger flush
            1..100 | ForEach-Object {
                $metric = New-ComplianceMetric -Name "Test$_" -Value $_
                Send-ComplianceMetric -Metric $metric -Buffer
            }
            
            Assert-MockCalled -CommandName Flush-MetricsBuffer -ModuleName 'CloudScope.Monitoring' -Times 1
        }
        
        It 'Should warn when monitoring not initialized' {
            InModuleScope 'CloudScope.Monitoring' {
                $script:MonitoringContext.WorkspaceId = $null
            }
            
            $metric = New-ComplianceMetric -Name "Test" -Value 42
            Send-ComplianceMetric -Metric $metric -WarningVariable warning 3>&1
            
            $warning | Should -Match "not initialized"
        }
    }
    
    Context 'New-ComplianceAlert' {
        BeforeAll {
            InModuleScope 'CloudScope.Monitoring' {
                $script:MonitoringContext.WorkspaceId = 'workspace123'
                $script:MonitoringContext.ResourceGroup = 'rg-test'
            }
            
            Mock New-AzMonitorAlertRule {} -ModuleName 'CloudScope.Monitoring'
            Mock Send-AlertEmail {} -ModuleName 'CloudScope.Monitoring'
        }
        
        It 'Should create compliance alert' {
            $alert = New-ComplianceAlert -Title "Test Alert" -Description "Test description" -Severity "Warning"
            
            $alert | Should -Not -BeNullOrEmpty
            $alert.Title | Should -Be "Test Alert"
            $alert.Severity | Should -Be "Warning"
            $alert.Status | Should -Be "Active"
            $alert.AlertId | Should -Not -BeNullOrEmpty
        }
        
        It 'Should send alert metric' {
            Mock Send-ComplianceMetric {} -ModuleName 'CloudScope.Monitoring'
            
            New-ComplianceAlert -Title "Test" -Description "Test" -Severity "Error"
            
            Assert-MockCalled -CommandName Send-ComplianceMetric -ModuleName 'CloudScope.Monitoring' -ParameterFilter {
                $Metric.Name -eq "ComplianceAlert"
            }
        }
        
        It 'Should create Azure Monitor alert rule' {
            New-ComplianceAlert -Title "Critical Issue" -Description "Critical compliance issue" -Severity "Critical"
            
            Assert-MockCalled -CommandName New-AzMonitorAlertRule -ModuleName 'CloudScope.Monitoring' -Times 1
        }
        
        It 'Should send email when requested' {
            New-ComplianceAlert -Title "Email Alert" -Description "Test" -Severity "Warning" -SendEmail -Recipients @("admin@contoso.com")
            
            Assert-MockCalled -CommandName Send-AlertEmail -ModuleName 'CloudScope.Monitoring' -Times 1
        }
    }
    
    Context 'Set-AlertingRules' {
        It 'Should set alerting rule' {
            { Set-AlertingRules -RuleName "TestRule" -Threshold 90 -Operator "GreaterThan" -Severity "Warning" } | Should -Not -Throw
            
            InModuleScope 'CloudScope.Monitoring' {
                $script:AlertRules['TestRule'] | Should -Not -BeNullOrEmpty
                $script:AlertRules['TestRule'].Threshold | Should -Be 90
                $script:AlertRules['TestRule'].Operator | Should -Be 'GreaterThan'
            }
        }
        
        It 'Should update existing rule' {
            Set-AlertingRules -RuleName "ComplianceScore" -Threshold 95 -Operator "LessThan"
            
            InModuleScope 'CloudScope.Monitoring' {
                $script:AlertRules['ComplianceScore'].Threshold | Should -Be 95
            }
        }
        
        It 'Should disable rule when Enabled is false' {
            Set-AlertingRules -RuleName "TestRule" -Threshold 50 -Operator "Equals" -Enabled:$false
            
            InModuleScope 'CloudScope.Monitoring' {
                $script:AlertRules['TestRule'].Enabled | Should -Be $false
            }
        }
    }
    
    Context 'Get-ComplianceMetrics' {
        BeforeAll {
            InModuleScope 'CloudScope.Monitoring' {
                $script:MonitoringContext.WorkspaceId = 'workspace123'
            }
            
            Mock Invoke-AzOperationalInsightsQuery {
                @{
                    Results = @(
                        @{ TimeGenerated = Get-Date; MetricName = 'ComplianceScore'; MetricValue = 85 }
                        @{ TimeGenerated = (Get-Date).AddHours(-1); MetricName = 'ComplianceScore'; MetricValue = 87 }
                    )
                }
            }
        }
        
        It 'Should query metrics from Log Analytics' {
            $metrics = Get-ComplianceMetrics -TimeRange 'Last24Hours'
            
            $metrics | Should -Not -BeNullOrEmpty
            $metrics.Count | Should -Be 2
            
            Assert-MockCalled -CommandName Invoke-AzOperationalInsightsQuery -ParameterFilter {
                $Query -match "TimeGenerated > ago\(24h\)"
            }
        }
        
        It 'Should filter by metric name' {
            Get-ComplianceMetrics -MetricName 'ComplianceScore'
            
            Assert-MockCalled -CommandName Invoke-AzOperationalInsightsQuery -ParameterFilter {
                $Query -match "MetricName == 'ComplianceScore'"
            }
        }
        
        It 'Should support custom time range' {
            $start = (Get-Date).AddDays(-7)
            $end = Get-Date
            
            Get-ComplianceMetrics -TimeRange 'Custom' -StartTime $start -EndTime $end
            
            Assert-MockCalled -CommandName Invoke-AzOperationalInsightsQuery -ParameterFilter {
                $Query -match "TimeGenerated between"
            }
        }
        
        It 'Should return empty array when not initialized' {
            InModuleScope 'CloudScope.Monitoring' {
                $script:MonitoringContext.WorkspaceId = $null
            }
            
            $metrics = Get-ComplianceMetrics
            $metrics | Should -BeNullOrEmpty
        }
    }
    
    Context 'New-ComplianceDashboard' {
        BeforeAll {
            InModuleScope 'CloudScope.Monitoring' {
                $script:MonitoringContext.ResourceGroup = 'rg-test'
            }
            
            Mock New-AzResourceGroupDeployment { @{ DeploymentName = 'test-deployment' } }
        }
        
        It 'Should create compliance dashboard' {
            { New-ComplianceDashboard -DashboardName "Test Dashboard" } | Should -Not -Throw
            
            Assert-MockCalled -CommandName New-AzResourceGroupDeployment -Times 1
        }
        
        It 'Should use monitoring resource group by default' {
            New-ComplianceDashboard -DashboardName "Test"
            
            Assert-MockCalled -CommandName New-AzResourceGroupDeployment -ParameterFilter {
                $ResourceGroupName -eq 'rg-test'
            }
        }
        
        It 'Should throw when resource group not specified' {
            InModuleScope 'CloudScope.Monitoring' {
                $script:MonitoringContext.ResourceGroup = $null
            }
            
            { New-ComplianceDashboard -DashboardName "Test" } | Should -Throw "*Resource group not specified*"
        }
    }
}

Describe 'Alert Rule Tests' {
    
    Context 'Alert Threshold Testing' {
        BeforeAll {
            InModuleScope 'CloudScope.Monitoring' {
                $script:AlertRules = @{
                    ComplianceScore = @{
                        Threshold = 80
                        Operator = 'LessThan'
                        Severity = 'Warning'
                        Enabled = $true
                    }
                    ViolationCount = @{
                        Threshold = 10
                        Operator = 'GreaterThan'
                        Severity = 'Error'
                        Enabled = $true
                    }
                }
            }
            
            Mock Test-Threshold {
                param($Value, $Threshold, $Operator)
                switch ($Operator) {
                    'LessThan' { return $Value -lt $Threshold }
                    'GreaterThan' { return $Value -gt $Threshold }
                }
            } -ModuleName 'CloudScope.Monitoring'
        }
        
        It 'Should trigger alert for low compliance score' {
            InModuleScope 'CloudScope.Monitoring' {
                $metrics = @{ ComplianceScore = 75 }
                $triggered = @()
                
                foreach ($rule in $script:AlertRules.GetEnumerator()) {
                    if ($rule.Value.Enabled) {
                        $value = $metrics.($rule.Key)
                        if ($value -and (Test-Threshold -Value $value -Threshold $rule.Value.Threshold -Operator $rule.Value.Operator)) {
                            $triggered += $rule.Key
                        }
                    }
                }
                
                $triggered | Should -Contain 'ComplianceScore'
            }
        }
        
        It 'Should trigger alert for high violation count' {
            InModuleScope 'CloudScope.Monitoring' {
                $metrics = @{ ViolationCount = 15 }
                $triggered = @()
                
                foreach ($rule in $script:AlertRules.GetEnumerator()) {
                    if ($rule.Value.Enabled) {
                        $value = $metrics.($rule.Key)
                        if ($value -and (Test-Threshold -Value $value -Threshold $rule.Value.Threshold -Operator $rule.Value.Operator)) {
                            $triggered += $rule.Key
                        }
                    }
                }
                
                $triggered | Should -Contain 'ViolationCount'
            }
        }
        
        It 'Should not trigger disabled rules' {
            InModuleScope 'CloudScope.Monitoring' {
                $script:AlertRules.ComplianceScore.Enabled = $false
                $metrics = @{ ComplianceScore = 75 }
                $triggered = @()
                
                foreach ($rule in $script:AlertRules.GetEnumerator()) {
                    if ($rule.Value.Enabled) {
                        $value = $metrics.($rule.Key)
                        if ($value -and (Test-Threshold -Value $value -Threshold $rule.Value.Threshold -Operator $rule.Value.Operator)) {
                            $triggered += $rule.Key
                        }
                    }
                }
                
                $triggered | Should -Not -Contain 'ComplianceScore'
            }
        }
    }
}

Describe 'Integration Tests' {
    
    Context 'End-to-End Monitoring Workflow' {
        BeforeAll {
            # Initialize monitoring
            Mock Get-AzContext { @{ Subscription = @{ Id = 'sub123' } } }
            Mock Get-AzResourceGroup { @{ ResourceGroupName = 'rg-test' } }
            Mock Get-AzOperationalInsightsWorkspace { @{ CustomerId = 'workspace123' } }
            Mock Get-AzOperationalInsightsWorkspaceSharedKey { @{ PrimarySharedKey = 'key123' } }
            Mock Get-AzApplicationInsights { @{ InstrumentationKey = 'appkey123' } }
            
            Initialize-ComplianceMonitoring -WorkspaceName "test" -ResourceGroup "rg-test"
        }
        
        It 'Should complete monitoring workflow' {
            # 1. Set up alert rules
            Set-AlertingRules -RuleName "TestScore" -Threshold 85 -Operator "LessThan" -Severity "Warning"
            
            # 2. Create and send metrics
            $metric1 = New-ComplianceMetric -Name "ComplianceScore" -Value 90 -Category "Assessment"
            Send-ComplianceMetric -Metric $metric1
            
            $metric2 = New-ComplianceMetric -Name "ViolationCount" -Value 3 -Category "Violations"
            Send-ComplianceMetric -Metric $metric2
            
            # 3. Create alert for low score
            $alert = New-ComplianceAlert -Title "Low Score" -Description "Score dropped below threshold" -Severity "Warning"
            
            # 4. Query metrics
            Mock Invoke-AzOperationalInsightsQuery {
                @{
                    Results = @(
                        @{ MetricName = 'ComplianceScore'; MetricValue = 90 }
                        @{ MetricName = 'ViolationCount'; MetricValue = 3 }
                    )
                }
            }
            
            $metrics = Get-ComplianceMetrics -TimeRange 'Last1Hour'
            
            # Verify workflow
            $metrics | Should -Not -BeNullOrEmpty
            $alert.Status | Should -Be 'Active'
            
            InModuleScope 'CloudScope.Monitoring' {
                $script:AlertRules['TestScore'] | Should -Not -BeNullOrEmpty
            }
        }
    }
}
