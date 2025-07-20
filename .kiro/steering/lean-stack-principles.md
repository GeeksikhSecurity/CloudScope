---
title: Lean Stack Principles
description: Guidelines for implementing lean stack principles in CloudScope development
inclusion: always
priority: high
---

# Lean Stack Principles for CloudScope

## Core Philosophy

**"Build the minimum viable solution that delivers maximum value"**

When developing CloudScope components, follow these lean principles:

## 1. Minimize Dependencies

- Use built-in PowerShell capabilities whenever possible
- Only add external dependencies when absolutely necessary
- Prefer PowerShell Gallery modules with strong community support
- Document all dependencies with version requirements

```powershell
# GOOD: Using built-in capabilities
$data = Get-Content -Path $file | ConvertFrom-Json

# AVOID: Unnecessary dependencies
# Import-Module SomeJsonModule
# $data = ConvertFrom-JsonAdvanced -File $file
```

## 2. Simplify Configuration

- Use sensible defaults that work in most scenarios
- Implement progressive configuration (start simple, add complexity as needed)
- Store configuration in standard locations
- Validate configuration early

```powershell
function Initialize-CloudScopeConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ConfigPath = "~/.cloudscope/config.json",
        
        [Parameter(Mandatory = $false)]
        [switch]$Force
    )
    
    # Default configuration
    $defaultConfig = @{
        Version = "1.0"
        Environment = "Production"
        LogLevel = "Information"
        Monitoring = @{
            Enabled = $true
            IntervalSeconds = 300
        }
    }
    
    # Create directory if it doesn't exist
    $configDir = Split-Path -Parent $ConfigPath
    if (-not (Test-Path -Path $configDir)) {
        New-Item -Path $configDir -ItemType Directory -Force | Out-Null
    }
    
    # Create or update config file
    if ((Test-Path -Path $ConfigPath) -and -not $Force) {
        # Load existing config and merge with defaults
        $existingConfig = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
        $mergedConfig = Merge-Hashtables $defaultConfig ($existingConfig | ConvertTo-Hashtable)
        $mergedConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $ConfigPath
    } else {
        # Create new config with defaults
        $defaultConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $ConfigPath
    }
}
```

## 3. Modular Architecture

- Design small, focused modules with clear responsibilities
- Use interfaces to define module boundaries
- Implement loose coupling between components
- Enable selective module loading

```powershell
# Core module interface
function Get-ModuleInterface {
    @{
        Name = 'CloudScope.Core'
        Commands = @{
            'Initialize-CloudScope' = @{
                Parameters = @('ConfigPath', 'Force')
                Returns = 'Boolean'
            }
            'Get-CloudScopeConfig' = @{
                Parameters = @('Path')
                Returns = 'Hashtable'
            }
        }
    }
}

# Implementation that adheres to interface
function Initialize-CloudScope {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ConfigPath,
        
        [Parameter(Mandatory = $false)]
        [switch]$Force
    )
    
    # Implementation details
}
```

## 4. Progressive Enhancement

- Start with core functionality that delivers immediate value
- Add advanced features incrementally
- Allow users to opt-in to complexity
- Maintain backward compatibility

```powershell
function Invoke-ComplianceCheck {
    [CmdletBinding(DefaultParameterSetName = 'Simple')]
    param(
        # Core parameters (simple mode)
        [Parameter(Mandatory = $true, ParameterSetName = 'Simple')]
        [Parameter(Mandatory = $true, ParameterSetName = 'Advanced')]
        [string]$Target,
        
        # Advanced parameters
        [Parameter(Mandatory = $false, ParameterSetName = 'Advanced')]
        [hashtable]$CustomRules,
        
        [Parameter(Mandatory = $false, ParameterSetName = 'Advanced')]
        [string]$OutputFormat = 'Summary'
    )
    
    # Core functionality for all modes
    $results = @()
    
    # Add advanced functionality when in advanced mode
    if ($PSCmdlet.ParameterSetName -eq 'Advanced') {
        # Apply custom rules, format output, etc.
    }
    
    return $results
}
```

## 5. Fail Fast, Fail Safely

- Validate inputs early
- Provide clear error messages
- Implement graceful degradation
- Use try/catch blocks strategically

```powershell
function Get-ComplianceData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Source,
        
        [Parameter(Mandatory = $false)]
        [string]$Format = 'JSON'
    )
    
    # Validate early
    if (-not (Test-Path -Path $Source)) {
        Write-Error "Source not found: $Source"
        return $null
    }
    
    # Try primary approach
    try {
        $data = Get-Content -Path $Source -Raw | ConvertFrom-Json
        return $data
    }
    catch {
        # Graceful degradation
        Write-Warning "Could not parse $Source as JSON. Falling back to CSV import."
        try {
            $data = Import-Csv -Path $Source
            return $data
        }
        catch {
            Write-Error "Failed to import data: $_"
            return $null
        }
    }
}
```

## 6. Optimize for Maintenance

- Write self-documenting code
- Include inline documentation for complex logic
- Use consistent naming conventions
- Implement logging for troubleshooting

```powershell
function Update-ComplianceStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceId,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet('Compliant', 'NonCompliant', 'Unknown')]
        [string]$Status,
        
        [Parameter(Mandatory = $false)]
        [string]$Reason
    )
    
    # Log operation for troubleshooting
    Write-Verbose "Updating compliance status for $ResourceId to $Status"
    
    # Self-documenting variable names
    $timestamp = Get-Date
    $currentUser = $env:USERNAME
    
    # Document complex logic
    # This algorithm prioritizes the most severe status when multiple checks run
    $statusPriority = @{
        'NonCompliant' = 3
        'Unknown' = 2
        'Compliant' = 1
    }
    
    # Implementation
}
```

## 7. Design for Testability

- Use dependency injection
- Avoid hidden state
- Make side effects explicit
- Create testable interfaces

```powershell
# Hard to test
function Get-UserComplianceStatus {
    # Hidden dependency
    $graph = Connect-MgGraph
    $user = Get-MgUser -UserId 'current'
    # Implementation
}

# Easy to test
function Get-UserComplianceStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [object]$GraphClient = (Connect-MgGraph),
        
        [Parameter(Mandatory = $false)]
        [string]$UserId = 'current'
    )
    
    # Implementation using provided client
    $user = Get-MgUser -UserId $UserId -Graph $GraphClient
    # Rest of implementation
}
```

## 8. Measure and Optimize

- Include performance metrics
- Implement telemetry (opt-in)
- Focus optimization on critical paths
- Use benchmarking to guide improvements

```powershell
function Invoke-ComplianceAssessment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Target
    )
    
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    
    # Implementation
    
    $stopwatch.Stop()
    
    # Log performance metrics
    Write-Verbose "Assessment completed in $($stopwatch.ElapsedMilliseconds)ms"
    
    # Return results with performance data
    return @{
        Results = $results
        Performance = @{
            TotalTimeMs = $stopwatch.ElapsedMilliseconds
            ItemsProcessed = $itemCount
            ItemsPerSecond = $itemCount / ($stopwatch.ElapsedMilliseconds / 1000)
        }
    }
}
```

## 9. Progressive Disclosure

- Hide complexity by default
- Expose advanced options progressively
- Use parameter sets to organize functionality
- Provide sensible defaults

```powershell
function Get-ComplianceReport {
    [CmdletBinding(DefaultParameterSetName = 'Simple')]
    param(
        # Basic parameters
        [Parameter(Mandatory = $true, ParameterSetName = 'Simple')]
        [Parameter(Mandatory = $true, ParameterSetName = 'Advanced')]
        [string]$Framework,
        
        # Intermediate parameters
        [Parameter(Mandatory = $false, ParameterSetName = 'Simple')]
        [Parameter(Mandatory = $false, ParameterSetName = 'Advanced')]
        [string]$Format = 'HTML',
        
        # Advanced parameters
        [Parameter(Mandatory = $true, ParameterSetName = 'Advanced')]
        [hashtable]$CustomMetrics,
        
        [Parameter(Mandatory = $false, ParameterSetName = 'Advanced')]
        [string]$TemplatePath
    )
    
    # Implementation with progressive complexity
}
```

## 10. Documentation as Code

- Include documentation in code
- Generate help from code comments
- Keep examples up-to-date
- Document design decisions

```powershell
<#
.SYNOPSIS
    Performs a compliance assessment against specified framework.
    
.DESCRIPTION
    This function evaluates the target system against compliance requirements
    defined in the specified framework. It returns detailed findings and
    remediation steps.
    
.PARAMETER Framework
    The compliance framework to assess against (e.g., GDPR, HIPAA, PCI).
    
.PARAMETER Target
    The target system or resource to assess.
    
.EXAMPLE
    Invoke-ComplianceAssessment -Framework GDPR -Target "tenant.onmicrosoft.com"
    
    Performs a GDPR compliance assessment against the specified tenant.
    
.NOTES
    Design Decision: This function uses parallel processing for performance
    but limits concurrent operations to avoid throttling.
#>
function Invoke-ComplianceAssessment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Framework,
        
        [Parameter(Mandatory = $true)]
        [string]$Target
    )
    
    # Implementation
}
```