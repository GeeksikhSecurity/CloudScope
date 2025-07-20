<#
.SYNOPSIS
    Pre-flight check script for CloudScope environment validation
    
.DESCRIPTION
    This script validates that the current environment meets all requirements
    for running CloudScope PowerShell modules. It checks PowerShell version,
    required modules, and configuration.
    
.EXAMPLE
    ./Test-Environment.ps1
    
    Runs all environment checks and reports issues
    
.NOTES
    File: Test-Environment.ps1
    Author: CloudScope Team
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$Quiet,
    
    [Parameter(Mandatory = $false)]
    [switch]$Fix
)

function Test-CloudScopeEnvironment {
    [CmdletBinding()]
    param()
    
    $issues = 0
    $warnings = 0
    
    Write-Host "🔍 CloudScope Environment Check" -ForegroundColor Cyan
    Write-Host "=============================" -ForegroundColor Cyan
    
    # Check PowerShell version
    $requiredVersion = [version]'7.0.0'
    $currentVersion = $PSVersionTable.PSVersion
    if ($currentVersion -lt $requiredVersion) {
        Write-Host "❌ PowerShell version: $currentVersion (Required: $requiredVersion or higher)" -ForegroundColor Red
        $issues++
    } else {
        Write-Host "✅ PowerShell version: $currentVersion" -ForegroundColor Green
    }
    
    # Check required modules
    $requiredModules = @(
        @{ Name = 'Microsoft.Graph'; MinimumVersion = '2.0.0' },
        @{ Name = 'Az.Accounts'; MinimumVersion = '2.10.0' }
    )
    
    Write-Host "`nChecking required modules:" -ForegroundColor Cyan
    foreach ($module in $requiredModules) {
        $installed = Get-Module -Name $module.Name -ListAvailable | 
            Where-Object { $_.Version -ge [version]$module.MinimumVersion }
        
        if (-not $installed) {
            Write-Host "❌ $($module.Name) v$($module.MinimumVersion) or higher not found" -ForegroundColor Red
            $issues++
            
            if ($Fix) {
                try {
                    Write-Host "   Installing $($module.Name)..." -ForegroundColor Yellow
                    Install-Module -Name $module.Name -MinimumVersion $module.MinimumVersion -Force -Scope CurrentUser
                    Write-Host "   ✅ Installed successfully" -ForegroundColor Green
                    $issues--
                } catch {
                    Write-Host "   ❌ Installation failed: $($_.Exception.Message)" -ForegroundColor Red
                }
            }
        } else {
            Write-Host "✅ $($module.Name) v$($installed.Version)" -ForegroundColor Green
        }
    }
    
    # Check configuration directory
    $configDir = Join-Path $HOME '.cloudscope'
    if (-not (Test-Path -Path $configDir)) {
        Write-Host "`n⚠️ Configuration directory not found: $configDir" -ForegroundColor Yellow
        $warnings++
        
        if ($Fix) {
            try {
                New-Item -Path $configDir -ItemType Directory -Force | Out-Null
                Write-Host "   ✅ Created configuration directory" -ForegroundColor Green
                $warnings--
            } catch {
                Write-Host "   ❌ Failed to create directory: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    } else {
        Write-Host "`n✅ Configuration directory exists: $configDir" -ForegroundColor Green
    }
    
    # Check for Docker (which we want to avoid)
    if (Get-Command docker -ErrorAction SilentlyContinue) {
        Write-Host "`nℹ️ Docker is installed, but CloudScope is designed to work without Docker" -ForegroundColor Blue
    } else {
        Write-Host "`n✅ Docker not found (CloudScope works without Docker)" -ForegroundColor Green
    }
    
    # Summary
    Write-Host "`n📋 Environment Check Summary" -ForegroundColor Cyan
    Write-Host "=========================" -ForegroundColor Cyan
    Write-Host "Issues found: $issues" -ForegroundColor $(if ($issues -eq 0) { 'Green' } else { 'Red' })
    Write-Host "Warnings: $warnings" -ForegroundColor $(if ($warnings -eq 0) { 'Green' } else { 'Yellow' })
    
    if ($issues -eq 0 -and $warnings -eq 0) {
        Write-Host "`n✅ Environment is ready for CloudScope!" -ForegroundColor Green
    } elseif ($issues -eq 0) {
        Write-Host "`n⚠️ Environment has warnings but should work for CloudScope" -ForegroundColor Yellow
    } else {
        Write-Host "`n❌ Environment has issues that need to be resolved" -ForegroundColor Red
        if (-not $Fix) {
            Write-Host "   Run with -Fix parameter to attempt automatic resolution" -ForegroundColor Yellow
        }
    }
    
    return @{
        Ready = ($issues -eq 0)
        Issues = $issues
        Warnings = $warnings
    }
}

# Run the check
$result = Test-CloudScopeEnvironment
exit $(if ($result.Ready) { 0 } else { 1 })