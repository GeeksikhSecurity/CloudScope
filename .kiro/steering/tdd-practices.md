---
title: Test-Driven Development Practices
description: Guidelines for implementing TDD practices in CloudScope development
inclusion: fileMatch
fileMatchPattern: '**/*.ps1'
priority: high
---

# Test-Driven Development Practices for CloudScope

## Core TDD Philosophy

**"Write tests that fail for the right reasons, then make them pass"**

When developing PowerShell modules for CloudScope, always follow these TDD principles:

1. **Write the test first** - Define expected behavior before implementation
2. **Run the test to see it fail** - Confirm the test works correctly
3. **Write minimal code to make the test pass** - Focus on simplicity
4. **Refactor while keeping tests passing** - Improve code quality
5. **Repeat for each feature** - Build incrementally

## Pre-flight Checks

Always include pre-flight checks in your PowerShell modules:

```powershell
function Test-CloudScopeEnvironment {
    [CmdletBinding()]
    param()
    
    $issues = 0
    
    # Check PowerShell version
    $requiredVersion = [version]'7.0.0'
    $currentVersion = $PSVersionTable.PSVersion
    if ($currentVersion -lt $requiredVersion) {
        Write-Error "PowerShell $requiredVersion or higher required. Current: $currentVersion"
        $issues++
    }
    
    # Check required modules
    $requiredModules = @('Microsoft.Graph', 'Az.Accounts')
    foreach ($module in $requiredModules) {
        if (-not (Get-Module -ListAvailable -Name $module)) {
            Write-Error "Required module not found: $module"
            $issues++
        }
    }
    
    return $issues -eq 0
}
```

## Defensive Coding Patterns

Implement these defensive coding patterns in all PowerShell modules:

### Input Validation

```powershell
function Invoke-SafeOperation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Parameter1,
        
        [Parameter(Mandatory = $true)]
        [ValidateScript({Test-Path $_})]
        [string]$FilePath
    )
    
    # Additional validation
    if ($Parameter1 -match '[<>|&;]') {
        throw "Parameter contains invalid characters"
    }
    
    # Proceed with operation
}
```

### Error Handling

```powershell
function Get-DataSafely {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri
    )
    
    try {
        $response = Invoke-RestMethod -Uri $Uri -ErrorAction Stop
        return @{
            Success = $true
            Data = $response
        }
    }
    catch [System.Net.WebException] {
        return @{
            Success = $false
            Error = "Network error: $($_.Exception.Message)"
            StatusCode = $_.Exception.Response.StatusCode
        }
    }
    catch {
        return @{
            Success = $false
            Error = "Unexpected error: $($_.Exception.Message)"
        }
    }
}
```

### Circuit Breaker Pattern

```powershell
class CircuitBreaker {
    [string]$Name
    [int]$FailureThreshold
    [int]$CurrentFailures
    [datetime]$NextRetry
    [int]$RetryIntervalSeconds
    [string]$State
    
    CircuitBreaker([string]$name, [int]$threshold = 3, [int]$retryInterval = 60) {
        $this.Name = $name
        $this.FailureThreshold = $threshold
        $this.RetryIntervalSeconds = $retryInterval
        $this.CurrentFailures = 0
        $this.State = 'CLOSED'
    }
    
    [bool] CanExecute() {
        if ($this.State -eq 'OPEN') {
            if ((Get-Date) -ge $this.NextRetry) {
                $this.State = 'HALF-OPEN'
                return $true
            }
            return $false
        }
        return $true
    }
    
    [void] RecordSuccess() {
        $this.CurrentFailures = 0
        $this.State = 'CLOSED'
    }
    
    [void] RecordFailure() {
        $this.CurrentFailures++
        if ($this.CurrentFailures -ge $this.FailureThreshold) {
            $this.State = 'OPEN'
            $this.NextRetry = (Get-Date).AddSeconds($this.RetryIntervalSeconds)
        }
    }
}
```

## JSON Validation

Always validate JSON files before using them:

```powershell
function Test-JsonFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    
    try {
        if (-not (Test-Path -Path $Path)) {
            return @{
                Valid = $false
                Error = "File not found: $Path"
            }
        }
        
        $content = Get-Content -Path $Path -Raw
        $null = $content | ConvertFrom-Json
        
        return @{
            Valid = $true
        }
    }
    catch {
        return @{
            Valid = $false
            Error = $_.Exception.Message
            Line = ($_.ErrorDetails.Message | Select-String -Pattern 'line (\d+)').Matches.Groups[1].Value
        }
    }
}
```

## Test Structure

Structure your Pester tests following this pattern:

```powershell
Describe 'Module-Function' {
    BeforeAll {
        # Setup test environment
        $testData = @{
            Input = 'test'
            Expected = 'result'
        }
        
        # Mock dependencies
        Mock Invoke-RestMethod { return @{ success = $true } }
    }
    
    Context 'When provided valid input' {
        It 'Should return expected result' {
            # Arrange
            $input = $testData.Input
            
            # Act
            $result = Function-Under-Test -Parameter $input
            
            # Assert
            $result | Should -Be $testData.Expected
        }
    }
    
    Context 'When handling errors' {
        It 'Should handle network errors gracefully' {
            # Arrange
            Mock Invoke-RestMethod { throw [System.Net.WebException]::new('Network error') }
            
            # Act
            $result = Function-Under-Test -Parameter 'test'
            
            # Assert
            $result.Success | Should -Be $false
            $result.Error | Should -Match 'Network error'
        }
    }
    
    AfterAll {
        # Cleanup test environment
    }
}
```

## Troubleshooting Workflow

When troubleshooting issues, follow this workflow:

1. **Identify the problem with tests**
   - Write a test that reproduces the issue
   - Verify the test fails for the expected reason

2. **Isolate the root cause**
   - Use binary search to narrow down the problem
   - Create minimal reproduction case

3. **Fix systematically**
   - Modify code to address root cause
   - Ensure test now passes
   - Add regression test to prevent recurrence

4. **Document the solution**
   - Update comments with explanation
   - Add to troubleshooting guide if applicable

## Pre-Commit Validation

Before committing code, run these validations:

```powershell
# Validate PowerShell scripts
Get-ChildItem -Path . -Filter *.ps1 -Recurse | ForEach-Object {
    $result = Invoke-ScriptAnalyzer -Path $_.FullName
    if ($result) {
        Write-Warning "Issues found in $($_.Name):"
        $result | Format-Table -AutoSize
    }
}

# Run tests
Invoke-Pester -Path ./tests

# Validate module manifests
Get-ChildItem -Path . -Filter *.psd1 -Recurse | ForEach-Object {
    try {
        $null = Test-ModuleManifest -Path $_.FullName -ErrorAction Stop
        Write-Host "✓ $($_.Name) is valid" -ForegroundColor Green
    } catch {
        Write-Error "× $($_.Name) has issues: $($_.Exception.Message)"
    }
}
```