#Requires -Version 5.0

<#
.SYNOPSIS
    PowerShell DSC Configuration for PCI DSS Compliance
    
.DESCRIPTION
    Desired State Configuration for implementing PCI DSS compliance
    settings for systems handling payment card data.
    
.NOTES
    File: PCIDSSCompliance.ps1
    Author: CloudScope Team
    Version: 1.0.0
#>

Configuration PCIDSSCompliance {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$ComputerName,
        
        [Parameter(Mandatory = $false)]
        [string]$NetworkSegment = 'CDE', # Cardholder Data Environment
        
        [Parameter(Mandatory = $false)]
        [int]$KeyRotationDays = 90,
        
        [Parameter(Mandatory = $false)]
        [string]$LogServerPath = '\\logserver\PCILogs'
    )
    
    Import-DscResource -ModuleName 'PSDesiredStateConfiguration'
    Import-DscResource -ModuleName 'SecurityPolicyDsc'
    Import-DscResource -ModuleName 'NetworkingDsc'
    Import-DscResource -ModuleName 'xWebAdministration'
    
    Node $ComputerName {
        
        # Windows Features for PCI DSS
        WindowsFeature IIS {
            Name = 'Web-Server'
            Ensure = 'Present'
        }
        
        WindowsFeature IISSecurityFeatures {
            Name = @(
                'Web-Security',
                'Web-Filtering',
                'Web-IP-Security',
                'Web-Url-Auth',
                'Web-Windows-Auth'
            )
            Ensure = 'Present'
            DependsOn = '[WindowsFeature]IIS'
        }
        
        # Disable unnecessary services (PCI DSS Requirement 2.1)
        Service DisableTelnet {
            Name = 'TlntSvr'
            State = 'Stopped'
            StartupType = 'Disabled'
        }
        
        Service DisableSMBv1 {
            Name = 'mrxsmb10'
            State = 'Stopped'
            StartupType = 'Disabled'
        }
        
        # Registry Settings for PCI DSS
        
        # Enable TLS 1.2 only (PCI DSS Requirement 4.1)
        Registry EnableTLS12 {
            Key = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server'
            ValueName = 'Enabled'
            ValueData = '1'
            ValueType = 'DWord'
            Ensure = 'Present'
        }
        
        Registry DisableTLS10 {
            Key = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server'
            ValueName = 'Enabled'
            ValueData = '0'
            ValueType = 'DWord'
            Ensure = 'Present'
        }
        
        Registry DisableTLS11 {
            Key = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Server'
            ValueName = 'Enabled'
            ValueData = '0'
            ValueType = 'DWord'
            Ensure = 'Present'
        }
        
        Registry DisableSSL2 {
            Key = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0\Server'
            ValueName = 'Enabled'
            ValueData = '0'
            ValueType = 'DWord'
            Ensure = 'Present'
        }
        
        Registry DisableSSL3 {
            Key = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Server'
            ValueName = 'Enabled'
            ValueData = '0'
            ValueType = 'DWord'
            Ensure = 'Present'
        }
        
        # Security Policies for PCI DSS
        
        # Strong Password Policy (PCI DSS Requirement 8.2)
        AccountPolicy StrongPasswordPolicy {
            Name = 'PasswordPolicy'
            Enforce_password_history = 4
            Maximum_password_age = 90
            Minimum_password_age = 1
            Minimum_password_length = 8
            Password_must_meet_complexity_requirements = 'Enabled'
        }
        
        # Account Lockout (PCI DSS Requirement 8.1.6)
        AccountPolicy AccountLockout {
            Name = 'AccountLockoutPolicy'
            Account_lockout_duration = 30
            Account_lockout_threshold = 6
            Reset_account_lockout_counter_after = 30
        }
        
        # Audit Policies for PCI DSS Requirement 10
        
        AuditPolicySubcategory LogonEvents {
            Name = 'Logon'
            AuditFlag = 'SuccessAndFailure'
            Ensure = 'Present'
        }
        
        AuditPolicySubcategory ObjectAccess {
            Name = 'File System'
            AuditFlag = 'SuccessAndFailure'
            Ensure = 'Present'
        }
        
        AuditPolicySubcategory PrivilegeUse {
            Name = 'Sensitive Privilege Use'
            AuditFlag = 'SuccessAndFailure'
            Ensure = 'Present'
        }
        
        # Firewall Configuration (PCI DSS Requirement 1)
        Firewall EnableFirewall {
            Name = 'Domain'
            Enabled = 'True'
            DefaultInboundAction = 'Block'
            DefaultOutboundAction = 'Allow'
        }
        
        FirewallRule AllowHTTPS {
            Name = 'PCI-HTTPS-Inbound'
            DisplayName = 'PCI DSS - Allow HTTPS'
            Direction = 'Inbound'
            LocalPort = '443'
            Protocol = 'TCP'
            Action = 'Allow'
            Enabled = 'True'
        }
        
        FirewallRule BlockHTTP {
            Name = 'PCI-HTTP-Block'
            DisplayName = 'PCI DSS - Block HTTP'
            Direction = 'Inbound'
            LocalPort = '80'
            Protocol = 'TCP'
            Action = 'Block'
            Enabled = 'True'
        }
        
        # IIS Configuration for PCI DSS
        xWebsite DefaultWebSite {
            Name = 'Default Web Site'
            State = 'Stopped'
            Ensure = 'Present'
        }
        
        xWebAppPool PCIAppPool {
            Name = 'PCICompliantAppPool'
            Ensure = 'Present'
            State = 'Started'
            identityType = 'ApplicationPoolIdentity'
            recycling = @{
                periodicRestart = @{
                    time = '00:00:00'
                }
            }
        }
        
        # File System Security
        File CardholderDataFolder {
            DestinationPath = 'C:\PCIData'
            Type = 'Directory'
            Ensure = 'Present'
        }
        
        # Script for PCI-specific configurations
        Script ConfigurePCISettings {
            SetScript = {
                # Configure NTP for time synchronization (PCI DSS 10.4)
                w32tm /config /manualpeerlist:"time.windows.com" /syncfromflags:manual
                Stop-Service w32time
                Start-Service w32time
                
                # Enable Windows Event Log settings
                wevtutil set-log Application /retention:true /maxsize:104857600
                wevtutil set-log Security /retention:true /maxsize:524288000
                wevtutil set-log System /retention:true /maxsize:104857600
                
                # Configure cipher suites for PCI compliance
                $cipherOrder = @(
                    'TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384',
                    'TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256',
                    'TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384',
                    'TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256'
                )
                
                $cipherString = $cipherOrder -join ','
                
                New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Cryptography\Configuration\SSL\00010002' `
                    -Name 'Functions' -Value $cipherString -PropertyType String -Force
                
                # Set file permissions on cardholder data folder
                $acl = Get-Acl 'C:\PCIData'
                $acl.SetAccessRuleProtection($true, $false)
                
                # Remove all inherited permissions
                $acl.Access | ForEach-Object { $acl.RemoveAccessRule($_) }
                
                # Add only necessary permissions
                $permission = 'SYSTEM', 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow'
                $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule $permission
                $acl.SetAccessRule($accessRule)
                
                $permission = 'Administrators', 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow'
                $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule $permission
                $acl.SetAccessRule($accessRule)
                
                Set-Acl 'C:\PCIData' $acl
                
                # Enable file integrity monitoring
                New-ItemProperty -Path "HKLM:\SOFTWARE\CloudScope\PCI" `
                    -Name "EnableFIM" -Value 1 -PropertyType DWord -Force
            }
            
            TestScript = {
                # Check if PCI settings are configured
                $ntpConfig = w32tm /query /configuration
                $eventLogSize = (Get-WinEvent -ListLog Security).MaximumSizeInBytes
                
                $isConfigured = $true
                
                if ($eventLogSize -lt 524288000) {
                    $isConfigured = $false
                }
                
                if (-not (Test-Path 'C:\PCIData')) {
                    $isConfigured = $false
                }
                
                return $isConfigured
            }
            
            GetScript = {
                @{
                    Result = "PCI DSS Settings Configuration"
                    NTPServer = (w32tm /query /configuration | Select-String "NtpServer").ToString()
                    SecurityLogSize = (Get-WinEvent -ListLog Security).MaximumSizeInBytes
                    CardholderDataFolder = Test-Path 'C:\PCIData'
                }
            }
        }
        
        # Scheduled Task for Daily Security Scans
        ScheduledTask DailySecurityScan {
            TaskName = 'PCI DSS Daily Security Scan'
            TaskPath = '\CloudScope\PCI\'
            ActionExecutable = 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'
            ActionArguments = '-NoProfile -ExecutionPolicy Bypass -File C:\CloudScope\Scripts\Invoke-PCISecurityScan.ps1'
            ScheduleType = 'Daily'
            StartTime = '23:00:00'
            Enable = $true
        }
        
        # Log Forwarding Configuration
        Registry LogForwarding {
            Key = 'HKLM:\SOFTWARE\CloudScope\PCI'
            ValueName = 'LogServerPath'
            ValueData = $LogServerPath
            ValueType = 'String'
            Ensure = 'Present'
        }
        
        # Anti-virus Configuration (PCI DSS Requirement 5)
        Script ConfigureAntivirus {
            SetScript = {
                # Configure Windows Defender for PCI compliance
                Set-MpPreference -DisableRealtimeMonitoring $false
                Set-MpPreference -DisableBehaviorMonitoring $false
                Set-MpPreference -DisableBlockAtFirstSeen $false
                Set-MpPreference -DisableIOAVProtection $false
                Set-MpPreference -DisablePrivacyMode $false
                Set-MpPreference -SignatureUpdateInterval 1
                Set-MpPreference -ScanScheduleDay Everyday
                Set-MpPreference -ScanScheduleTime 120
                
                # Add exclusions for legitimate PCI processing applications
                Add-MpPreference -ExclusionPath "C:\PCIApps\PaymentProcessor.exe"
            }
            
            TestScript = {
                $mpPreference = Get-MpPreference
                return (-not $mpPreference.DisableRealtimeMonitoring)
            }
            
            GetScript = {
                @{
                    Result = Get-MpPreference
                }
            }
        }
    }
}

# Generate MOF files
PCIDSSCompliance -ComputerName 'localhost' -OutputPath 'C:\CloudScope\DSC\PCI'

# Apply configuration
# Start-DscConfiguration -Path 'C:\CloudScope\DSC\PCI' -Wait -Verbose -Force
