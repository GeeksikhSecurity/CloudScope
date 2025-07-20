<#
.SYNOPSIS
    Pester tests for Test-Environment.ps1
    
.DESCRIPTION
    Unit tests for the CloudScope environment validation script
#>

BeforeAll {
    # Import the script
    . "$PSScriptRoot/../Tools/Test-Environment.ps1"
    
    # Mock external commands
    Mock Get-Module {
        @(
            @{
                Name = 'Microsoft.Graph'
                Version = [version]'2.5.0'
            }
        )
    } -ParameterFilter { $Name -eq 'Microsoft.Graph' -and $ListAvailable }
    
    Mock Get-Module {
        @(
            @{
                Name = 'Az.Accounts'
                Version = [version]'2.12.0'
            }
        )
    } -ParameterFilter { $Name -eq 'Az.Accounts' -and $ListAvailable }
    
    Mock Test-Path { $true } -ParameterFilter { $Path -like '*/.cloudscope' }
    
    Mock Install-Module { $true }
    
    Mock New-Item { $true }
}

Describe 'Test-CloudScopeEnvironment' {
    Context 'When environment meets all requirements' {
        It 'Should report no issues' {
            # Arrange
            $PSVersionTable = @{
                PSVersion = [version]'7.2.0'
            }
            
            # Act
            $result = Test-CloudScopeEnvironment
            
            # Assert
            $result.Ready | Should -Be $true
            $result.Issues | Should -Be 0
        }
    }
    
    Context 'When PowerShell version is too low' {
        It 'Should report an issue' {
            # Arrange
            $global:PSVersionTable = @{
                PSVersion = [version]'6.0.0'
            }
            
            # Act
            $result = Test-CloudScopeEnvironment
            
            # Assert
            $result.Ready | Should -Be $false
            $result.Issues | Should -BeGreaterThan 0
        }
    }
    
    Context 'When required modules are missing' {
        BeforeAll {
            Mock Get-Module { $null } -ParameterFilter { $Name -eq 'Microsoft.Graph' -and $ListAvailable }
        }
        
        It 'Should report an issue' {
            # Act
            $result = Test-CloudScopeEnvironment
            
            # Assert
            $result.Ready | Should -Be $false
            $result.Issues | Should -BeGreaterThan 0
        }
        
        It 'Should attempt to install missing modules with -Fix parameter' {
            # Act
            $result = Test-CloudScopeEnvironment -Fix
            
            # Assert
            Assert-MockCalled Install-Module -Times 1 -Exactly
        }
    }
    
    Context 'When configuration directory is missing' {
        BeforeAll {
            Mock Test-Path { $false } -ParameterFilter { $Path -like '*/.cloudscope' }
        }
        
        It 'Should report a warning' {
            # Act
            $result = Test-CloudScopeEnvironment
            
            # Assert
            $result.Warnings | Should -BeGreaterThan 0
        }
        
        It 'Should create the directory with -Fix parameter' {
            # Act
            $result = Test-CloudScopeEnvironment -Fix
            
            # Assert
            Assert-MockCalled New-Item -Times 1 -Exactly
        }
    }
}