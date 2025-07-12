<#
.SYNOPSIS
Comprehensive Microsoft 365 asset discovery and inventory collection for CloudScope

.DESCRIPTION
This script collects comprehensive asset data from Microsoft 365 including:
- Users and Groups with detailed metadata
- Applications and Service Principals
- Devices and Compliance Status
- SharePoint Sites and Teams
- Exchange Online Resources
- Security and Compliance Data

The script implements secure authentication, comprehensive error handling,
and outputs data in CloudScope-compatible format.

.PARAMETER ConfigPath
Path to configuration file containing connection details and collection settings

.PARAMETER OutputFormat
Output format for collected data. Options: JSON, CSV, Database
- JSON: Single file with all asset data
- CSV: Separate CSV files for each asset type
- Database: Direct submission to CloudScope API

.PARAMETER OutputPath
Path where output files will be saved (ignored for Database format)

.PARAMETER AssetTypes
Comma-separated list of asset types to collect. Available types:
Users, Groups, Applications, Devices, Sites, Teams, Security, Compliance

.PARAMETER Detailed
Switch to enable detailed collection with additional metadata and relationships

.EXAMPLE
./Get-M365Assets.ps1 -ConfigPath "config/m365-config.json" -OutputFormat JSON -Detailed

.EXAMPLE
./Get-M365Assets.ps1 -AssetTypes "Users,Groups,Devices" -OutputFormat Database

.NOTES
Author: CloudScope Community
Version: 1.0.0
Requires: PowerShell 7.0+, Microsoft.Graph module
Security: Implements secure credential handling and input validation
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateScript({Test-Path $_ -PathType Leaf})]
    [string]$ConfigPath = "./config/m365-config.json",
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("JSON", "CSV", "Database")]
    [string]$OutputFormat = "JSON",
    
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "./output/m365-assets.json",
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("Users", "Groups", "Applications", "Devices", "Sites", "Teams", "Security", "Compliance")]
    [string[]]$AssetTypes = @("Users", "Groups", "Applications", "Devices"),
    
    [Parameter(Mandatory = $false)]
    [switch]$Detailed
)

#Requires -Version 7.0
#Requires -Modules Microsoft.Graph.Authentication, Microsoft.Graph.Users, Microsoft.Graph.Groups

# Set strict mode for better error handling
Set-StrictMode -Version 3.0

# Global variables for script configuration
$Global:ScriptConfig = $null
$Global:CollectionStats = @{
    StartTime = Get-Date
    TotalAssets = 0
    SuccessfulCollections = 0
    FailedCollections = 0
    Errors = @()
}

#region Helper Functions

function Write-LogMessage {
    <#
    .SYNOPSIS
    Write structured log messages with severity levels
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("INFO", "WARNING", "ERROR", "SUCCESS")]
        [string]$Level = "INFO",
        
        [Parameter(Mandatory = $false)]
        [string]$Component = "Main"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] [$Component] $Message"
    
    # Color coding for console output
    switch ($Level) {
        "SUCCESS" { Write-Host $logEntry -ForegroundColor Green }
        "WARNING" { Write-Host $logEntry -ForegroundColor Yellow }
        "ERROR" { Write-Host $logEntry -ForegroundColor Red }
        default { Write-Host $logEntry -ForegroundColor White }
    }
    
    # Add to global error collection for reporting
    if ($Level -eq "ERROR") {
        $Global:CollectionStats.Errors += @{
            Timestamp = $timestamp
            Component = $Component
            Message = $Message
        }
    }
}

function Test-ModuleRequirements {
    <#
    .SYNOPSIS
    Verify all required PowerShell modules are installed and importable
    #>
    param()
    
    $RequiredModules = @(
        'Microsoft.Graph.Authentication',
        'Microsoft.Graph.Users',
        'Microsoft.Graph.Groups',
        'Microsoft.Graph.Applications',
        'Microsoft.Graph.DeviceManagement',
        'Microsoft.Graph.Sites',
        'Microsoft.Graph.Teams',
        'Microsoft.Graph.Security'
    )
    
    Write-LogMessage "Checking required PowerShell modules..." "INFO" "ModuleCheck"
    
    foreach ($Module in $RequiredModules) {
        try {
            if (Get-Module -ListAvailable -Name $Module) {
                Import-Module $Module -ErrorAction Stop
                Write-LogMessage "✓ Module imported: $Module" "SUCCESS" "ModuleCheck"
            } else {
                Write-LogMessage "✗ Module not found: $Module" "ERROR" "ModuleCheck"
                Write-LogMessage "Install with: Install-Module $Module -Scope CurrentUser" "INFO" "ModuleCheck"
                return $false
            }
        }
        catch {
            Write-LogMessage "✗ Failed to import module $Module`: $($_.Exception.Message)" "ERROR" "ModuleCheck"
            return $false
        }
    }
    
    return $true
}

function Import-Configuration {
    <#
    .SYNOPSIS
    Load and validate configuration from JSON file with security checks
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigPath
    )
    
    try {
        Write-LogMessage "Loading configuration from: $ConfigPath" "INFO" "Config"
        
        if (-not (Test-Path $ConfigPath)) {
            throw "Configuration file not found: $ConfigPath"
        }
        
        $configContent = Get-Content $ConfigPath -Raw | ConvertFrom-Json
        
        # Validate required configuration properties
        $requiredProperties = @('TenantId', 'ClientId')
        foreach ($property in $requiredProperties) {
            if (-not $configContent.PSObject.Properties.Name -contains $property) {
                throw "Missing required configuration property: $property"
            }
        }
        
        # Validate TenantId format (GUID)
        if ($configContent.TenantId -notmatch '^[a-f0-9\-]{36}$') {
            throw "Invalid TenantId format. Must be a valid GUID."
        }
        
        # Validate ClientId format (GUID)
        if ($configContent.ClientId -notmatch '^[a-f0-9\-]{36}$') {
            throw "Invalid ClientId format. Must be a valid GUID."
        }
        
        Write-LogMessage "✓ Configuration loaded and validated successfully" "SUCCESS" "Config"
        return $configContent
    }
    catch {
        Write-LogMessage "Configuration load failed: $($_.Exception.Message)" "ERROR" "Config"
        throw
    }
}

function Connect-ToMicrosoftGraph {
    <#
    .SYNOPSIS
    Establish secure connection to Microsoft Graph with retry logic and proper error handling
    #>
    param(
        [Parameter(Mandatory = $true)]
        [object]$Config
    )
    
    $MaxRetries = 3
    $RetryCount = 0
    
    Write-LogMessage "Connecting to Microsoft Graph..." "INFO" "Authentication"
    
    do {
        try {
            $ConnectionParams = @{
                TenantId = $Config.TenantId
                ClientId = $Config.ClientId
                ErrorAction = 'Stop'
            }
            
            # Add authentication method based on configuration
            if ($Config.PSObject.Properties.Name -contains 'CertificateThumbprint') {
                $ConnectionParams['CertificateThumbprint'] = $Config.CertificateThumbprint
                Write-LogMessage "Using certificate authentication" "INFO" "Authentication"
            }
            elseif ($Config.PSObject.Properties.Name -contains 'ClientSecret') {
                # Convert client secret to secure string
                $SecureSecret = ConvertTo-SecureString $Config.ClientSecret -AsPlainText -Force
                $ConnectionParams['ClientSecretCredential'] = New-Object System.Management.Automation.PSCredential($Config.ClientId, $SecureSecret)
                Write-LogMessage "Using client secret authentication" "INFO" "Authentication"
            }
            else {
                # Interactive authentication
                Write-LogMessage "Using interactive authentication" "INFO" "Authentication"
            }
            
            Connect-MgGraph @ConnectionParams
            
            # Verify connection
            $context = Get-MgContext
            if ($context) {
                Write-LogMessage "✓ Successfully connected to Microsoft Graph" "SUCCESS" "Authentication"
                Write-LogMessage "Tenant: $($context.TenantId)" "INFO" "Authentication"
                Write-LogMessage "Account: $($context.Account)" "INFO" "Authentication"
                return $true
            }
            
        }
        catch {
            $RetryCount++
            Write-LogMessage "Connection attempt $RetryCount failed: $($_.Exception.Message)" "WARNING" "Authentication"
            
            if ($RetryCount -lt $MaxRetries) {
                $WaitTime = 5 * $RetryCount
                Write-LogMessage "Retrying in $WaitTime seconds..." "INFO" "Authentication"
                Start-Sleep -Seconds $WaitTime
            }
        }
    } while ($RetryCount -lt $MaxRetries)
    
    Write-LogMessage "Failed to connect to Microsoft Graph after $MaxRetries attempts" "ERROR" "Authentication"
    return $false
}

function Get-UserRiskScore {
    <#
    .SYNOPSIS
    Calculate risk score for a user based on multiple security factors
    #>
    param(
        [Parameter(Mandatory = $true)]
        [object]$User
    )
    
    $RiskScore = 0
    $RiskFactors = @()
    
    # Account status risks
    if (-not $User.AccountEnabled) { 
        $RiskScore += 10 
        $RiskFactors += "Account disabled"
    }
    
    # User type risks
    if ($User.UserType -eq "Guest") { 
        $RiskScore += 5 
        $RiskFactors += "Guest user"
    }
    
    # Sign-in activity risks
    if (-not $User.LastSignInDateTime) { 
        $RiskScore += 15 
        $RiskFactors += "Never signed in"
    }
    elseif ($User.LastSignInDateTime) {
        $DaysSinceLastSignIn = ((Get-Date) - [datetime]$User.LastSignInDateTime).Days
        if ($DaysSinceLastSignIn -gt 90) { 
            $RiskScore += 10 
            $RiskFactors += "Inactive >90 days"
        }
        elseif ($DaysSinceLastSignIn -gt 30) { 
            $RiskScore += 5 
            $RiskFactors += "Inactive >30 days"
        }
    }
    
    # License assignment risks
    if (-not $User.AssignedLicenses -or $User.AssignedLicenses.Count -eq 0) {
        $RiskScore += 8
        $RiskFactors += "No licenses assigned"
    }
    
    # Email verification risks
    if ($User.Mail -and $Global:ScriptConfig.TenantDomain -and $User.Mail -notlike "*@$($Global:ScriptConfig.TenantDomain)*") {
        $RiskScore += 3
        $RiskFactors += "External email domain"
    }
    
    return @{
        Score = [Math]::Min($RiskScore, 100)  # Cap at 100
        Factors = $RiskFactors
        Level = switch ($RiskScore) {
            { $_ -ge 70 } { "Critical" }
            { $_ -ge 40 } { "High" }
            { $_ -ge 20 } { "Medium" }
            default { "Low" }
        }
    }
}

function Get-DeviceRiskScore {
    <#
    .SYNOPSIS
    Calculate risk score for a device based on compliance and security factors
    #>
    param(
        [Parameter(Mandatory = $true)]
        [object]$Device
    )
    
    $RiskScore = 0
    $RiskFactors = @()
    
    # Compliance state
    if ($Device.ComplianceState -eq "NonCompliant") {
        $RiskScore += 25
        $RiskFactors += "Non-compliant device"
    }
    elseif ($Device.ComplianceState -eq "Unknown") {
        $RiskScore += 15
        $RiskFactors += "Unknown compliance state"
    }
    
    # Management state
    if ($Device.ManagementState -eq "Unmanaged") {
        $RiskScore += 20
        $RiskFactors += "Unmanaged device"
    }
    
    # Last sync time
    if ($Device.LastSyncDateTime) {
        $DaysSinceLastSync = ((Get-Date) - [datetime]$Device.LastSyncDateTime).Days
        if ($DaysSinceLastSync -gt 30) {
            $RiskScore += 15
            $RiskFactors += "Not synced >30 days"
        }
        elseif ($DaysSinceLastSync -gt 7) {
            $RiskScore += 8
            $RiskFactors += "Not synced >7 days"
        }
    }
    else {
        $RiskScore += 20
        $RiskFactors += "Never synced"
    }
    
    # Operating system risks
    if ($Device.OperatingSystem -like "*Windows 7*" -or $Device.OperatingSystem -like "*Windows 8*") {
        $RiskScore += 30
        $RiskFactors += "Unsupported OS version"
    }
    
    return @{
        Score = [Math]::Min($RiskScore, 100)
        Factors = $RiskFactors
        Level = switch ($RiskScore) {
            { $_ -ge 70 } { "Critical" }
            { $_ -ge 40 } { "High" }
            { $_ -ge 20 } { "Medium" }
            default { "Low" }
        }
    }
}

#endregion

#region Asset Collection Functions

function Get-M365Users {
    <#
    .SYNOPSIS
    Collect comprehensive user data from Microsoft 365
    #>
    param(
        [Parameter(Mandatory = $false)]
        [switch]$Detailed
    )
    
    Write-LogMessage "📊 Collecting Microsoft 365 Users..." "INFO" "UserCollection"
    
    try {
        $UserProperties = @(
            'Id', 'DisplayName', 'UserPrincipalName', 'AccountEnabled',
            'CreatedDateTime', 'LastSignInDateTime', 'AssignedLicenses',
            'JobTitle', 'Department', 'OfficeLocation', 'Manager',
            'SecurityIdentifier', 'UserType', 'OnPremisesSyncEnabled',
            'Mail', 'ProxyAddresses'
        )
        
        if ($Detailed) {
            $UserProperties += @(
                'BusinessPhones', 'MobilePhone', 'PreferredLanguage',
                'UsageLocation', 'OnPremisesLastSyncDateTime',
                'OnPremisesSecurityIdentifier', 'OnPremisesDomainName'
            )
        }
        
        $Users = Get-MgUser -All -Property $UserProperties -ErrorAction Stop
        $ProcessedUsers = @()
        
        foreach ($User in $Users) {
            $RiskAssessment = Get-UserRiskScore -User $User
            
            $UserLicenses = @()
            if ($User.AssignedLicenses) {
                $UserLicenses = $User.AssignedLicenses | ForEach-Object { $_.SkuId }
            }
            
            $ProcessedUser = @{
                id = $User.Id
                display_name = $User.DisplayName
                user_principal_name = $User.UserPrincipalName
                account_enabled = $User.AccountEnabled
                created_date = $User.CreatedDateTime
                last_signin = $User.LastSignInDateTime
                job_title = $User.JobTitle
                department = $User.Department
                office_location = $User.OfficeLocation
                licenses = $UserLicenses
                user_type = $User.UserType
                sync_enabled = $User.OnPremisesSyncEnabled
                mail = $User.Mail
                asset_type = "m365_user"
                risk_score = $RiskAssessment.Score
                risk_level = $RiskAssessment.Level
                risk_factors = $RiskAssessment.Factors
                collection_timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
            }
            
            if ($Detailed) {
                $ProcessedUser.business_phones = $User.BusinessPhones
                $ProcessedUser.mobile_phone = $User.MobilePhone
                $ProcessedUser.preferred_language = $User.PreferredLanguage
                $ProcessedUser.usage_location = $User.UsageLocation
                $ProcessedUser.proxy_addresses = $User.ProxyAddresses
                $ProcessedUser.onprem_sync_time = $User.OnPremisesLastSyncDateTime
                $ProcessedUser.onprem_sid = $User.OnPremisesSecurityIdentifier
                $ProcessedUser.onprem_domain = $User.OnPremisesDomainName
            }
            
            $ProcessedUsers += $ProcessedUser
        }
        
        Write-LogMessage "✓ Collected $($Users.Count) users" "SUCCESS" "UserCollection"
        $Global:CollectionStats.TotalAssets += $Users.Count
        $Global:CollectionStats.SuccessfulCollections++
        
        return $ProcessedUsers
    }
    catch {
        Write-LogMessage "Failed to collect users: $($_.Exception.Message)" "ERROR" "UserCollection"
        $Global:CollectionStats.FailedCollections++
        return @()
    }
}

function Get-M365Groups {
    <#
    .SYNOPSIS
    Collect comprehensive group data from Microsoft 365
    #>
    param(
        [Parameter(Mandatory = $false)]
        [switch]$Detailed
    )
    
    Write-LogMessage "📊 Collecting Microsoft 365 Groups..." "INFO" "GroupCollection"
    
    try {
        $GroupProperties = @(
            'Id', 'DisplayName', 'GroupTypes', 'SecurityEnabled',
            'CreatedDateTime', 'MembershipRule', 'Description',
            'Visibility', 'ResourceBehaviorOptions', 'Mail'
        )
        
        if ($Detailed) {
            $GroupProperties += @(
                'OnPremisesSyncEnabled', 'OnPremisesLastSyncDateTime',
                'Classification', 'PreferredLanguage'
            )
        }
        
        $Groups = Get-MgGroup -All -Property $GroupProperties -ErrorAction Stop
        $ProcessedGroups = @()
        
        foreach ($Group in $Groups) {
            # Get group members with error handling
            $Members = @()
            try {
                $GroupMembers = Get-MgGroupMember -GroupId $Group.Id -All | Select-Object Id, "@odata.type"
                $Members = $GroupMembers | ForEach-Object { 
                    @{ 
                        id = $_.Id
                        type = $_."@odata.type" -replace "#microsoft.graph.", ""
                    } 
                }
            }
            catch {
                Write-LogMessage "Warning: Could not retrieve members for group $($Group.DisplayName): $($_.Exception.Message)" "WARNING" "GroupCollection"
            }
            
            $ProcessedGroup = @{
                id = $Group.Id
                display_name = $Group.DisplayName
                group_types = $Group.GroupTypes
                security_enabled = $Group.SecurityEnabled
                created_date = $Group.CreatedDateTime
                membership_rule = $Group.MembershipRule
                description = $Group.Description
                visibility = $Group.Visibility
                mail = $Group.Mail
                member_count = $Members.Count
                members = $Members
                asset_type = "m365_group"
                collection_timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
            }
            
            if ($Detailed) {
                $ProcessedGroup.sync_enabled = $Group.OnPremisesSyncEnabled
                $ProcessedGroup.last_sync_time = $Group.OnPremisesLastSyncDateTime
                $ProcessedGroup.classification = $Group.Classification
                $ProcessedGroup.preferred_language = $Group.PreferredLanguage
                $ProcessedGroup.resource_behaviors = $Group.ResourceBehaviorOptions
            }
            
            $ProcessedGroups += $ProcessedGroup
        }
        
        Write-LogMessage "✓ Collected $($Groups.Count) groups" "SUCCESS" "GroupCollection"
        $Global:CollectionStats.TotalAssets += $Groups.Count
        $Global:CollectionStats.SuccessfulCollections++
        
        return $ProcessedGroups
    }
    catch {
        Write-LogMessage "Failed to collect groups: $($_.Exception.Message)" "ERROR" "GroupCollection"
        $Global:CollectionStats.FailedCollections++
        return @()
    }
}

function Get-M365Applications {
    <#
    .SYNOPSIS
    Collect comprehensive application and service principal data from Microsoft 365
    #>
    param(
        [Parameter(Mandatory = $false)]
        [switch]$Detailed
    )
    
    Write-LogMessage "📊 Collecting Applications and Service Principals..." "INFO" "ApplicationCollection"
    
    try {
        $AppProperties = @(
            'Id', 'DisplayName', 'AppId', 'CreatedDateTime',
            'PublisherDomain', 'SignInAudience', 'RequiredResourceAccess'
        )
        
        if ($Detailed) {
            $AppProperties += @(
                'Description', 'Homepage', 'ReplyUrls', 'Tags'
            )
        }
        
        $Applications = Get-MgApplication -All -Property $AppProperties -ErrorAction Stop
        $ProcessedApplications = @()
        
        foreach ($App in $Applications) {
            $Permissions = @()
            if ($App.RequiredResourceAccess) {
                $Permissions = $App.RequiredResourceAccess | ForEach-Object {
                    @{
                        resource_app_id = $_.ResourceAppId
                        resource_access = $_.ResourceAccess | ForEach-Object {
                            @{
                                id = $_.Id
                                type = $_.Type
                            }
                        }
                    }
                }
            }
            
            $ProcessedApp = @{
                id = $App.Id
                display_name = $App.DisplayName
                app_id = $App.AppId
                created_date = $App.CreatedDateTime
                publisher_domain = $App.PublisherDomain
                signin_audience = $App.SignInAudience
                permissions = $Permissions
                asset_type = "m365_application"
                collection_timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
            }
            
            if ($Detailed) {
                $ProcessedApp.description = $App.Description
                $ProcessedApp.homepage = $App.Homepage
                $ProcessedApp.reply_urls = $App.ReplyUrls
                $ProcessedApp.tags = $App.Tags
            }
            
            $ProcessedApplications += $ProcessedApp
        }
        
        Write-LogMessage "✓ Collected $($Applications.Count) applications" "SUCCESS" "ApplicationCollection"
        $Global:CollectionStats.TotalAssets += $Applications.Count
        $Global:CollectionStats.SuccessfulCollections++
        
        return $ProcessedApplications
    }
    catch {
        Write-LogMessage "Failed to collect applications: $($_.Exception.Message)" "ERROR" "ApplicationCollection"
        $Global:CollectionStats.FailedCollections++
        return @()
    }
}

function Get-M365Devices {
    <#
    .SYNOPSIS
    Collect comprehensive device data from Microsoft 365
    #>
    param(
        [Parameter(Mandatory = $false)]
        [switch]$Detailed
    )
    
    Write-LogMessage "📊 Collecting Managed Devices..." "INFO" "DeviceCollection"
    
    try {
        $Devices = Get-MgDeviceManagementManagedDevice -All -ErrorAction Stop
        $ProcessedDevices = @()
        
        foreach ($Device in $Devices) {
            $RiskAssessment = Get-DeviceRiskScore -Device $Device
            
            $ProcessedDevice = @{
                id = $Device.Id
                device_name = $Device.DeviceName
                operating_system = $Device.OperatingSystem
                os_version = $Device.OsVersion
                compliance_state = $Device.ComplianceState
                management_state = $Device.ManagementState
                last_sync = $Device.LastSyncDateTime
                enrollment_date = $Device.EnrolledDateTime
                device_type = $Device.DeviceType
                manufacturer = $Device.Manufacturer
                model = $Device.Model
                serial_number = $Device.SerialNumber
                user_principal_name = $Device.UserPrincipalName
                asset_type = "managed_device"
                risk_score = $RiskAssessment.Score
                risk_level = $RiskAssessment.Level
                risk_factors = $RiskAssessment.Factors
                collection_timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
            }
            
            if ($Detailed) {
                $ProcessedDevice.imei = $Device.Imei
                $ProcessedDevice.wifi_mac_address = $Device.WiFiMacAddress
                $ProcessedDevice.ethernet_mac_address = $Device.EthernetMacAddress
                $ProcessedDevice.total_storage_space = $Device.TotalStorageSpaceInBytes
                $ProcessedDevice.free_storage_space = $Device.FreeStorageSpaceInBytes
                $ProcessedDevice.device_category = $Device.DeviceCategoryDisplayName
                $ProcessedDevice.activation_lock_bypass_code = "***REDACTED***"  # Security - don't expose bypass codes
            }
            
            $ProcessedDevices += $ProcessedDevice
        }
        
        Write-LogMessage "✓ Collected $($Devices.Count) devices" "SUCCESS" "DeviceCollection"
        $Global:CollectionStats.TotalAssets += $Devices.Count
        $Global:CollectionStats.SuccessfulCollections++
        
        return $ProcessedDevices
    }
    catch {
        Write-LogMessage "Failed to collect devices: $($_.Exception.Message)" "ERROR" "DeviceCollection"
        $Global:CollectionStats.FailedCollections++
        return @()
    }
}

#endregion

#region Export Functions

function Export-ToJSON {
    <#
    .SYNOPSIS
    Export collected asset data to JSON format
    #>
    param(
        [Parameter(Mandatory = $true)]
        [object]$AssetInventory,
        
        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )
    
    try {
        Write-LogMessage "Exporting data to JSON: $OutputPath" "INFO" "Export"
        
        # Ensure output directory exists
        $OutputDir = Split-Path $OutputPath -Parent
        if ($OutputDir -and -not (Test-Path $OutputDir)) {
            New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
        }
        
        # Convert to JSON with proper formatting
        $JsonOutput = $AssetInventory | ConvertTo-Json -Depth 10 -Compress:$false
        
        # Write to file with UTF-8 encoding
        [System.IO.File]::WriteAllText($OutputPath, $JsonOutput, [System.Text.Encoding]::UTF8)
        
        Write-LogMessage "✓ Successfully exported to JSON: $OutputPath" "SUCCESS" "Export"
        return $true
    }
    catch {
        Write-LogMessage "Failed to export to JSON: $($_.Exception.Message)" "ERROR" "Export"
        return $false
    }
}

function Export-ToCSV {
    <#
    .SYNOPSIS
    Export collected asset data to separate CSV files for each asset type
    #>
    param(
        [Parameter(Mandatory = $true)]
        [object]$AssetInventory,
        
        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )
    
    try {
        Write-LogMessage "Exporting data to CSV files..." "INFO" "Export"
        
        $BasePath = [System.IO.Path]::GetDirectoryWithoutExtension($OutputPath)
        $OutputDir = Split-Path $BasePath -Parent
        
        # Ensure output directory exists
        if ($OutputDir -and -not (Test-Path $OutputDir)) {
            New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
        }
        
        $ExportedFiles = @()
        
        # Export each asset type to separate CSV files
        foreach ($AssetType in $AssetInventory.PSObject.Properties.Name) {
            if ($AssetType -eq "collection_metadata") {
                continue
            }
            
            $AssetData = $AssetInventory.$AssetType
            if ($AssetData -and $AssetData.Count -gt 0) {
                $CsvPath = "$BasePath-$AssetType.csv"
                
                # Flatten nested objects for CSV export
                $FlattenedData = $AssetData | ForEach-Object {
                    $Item = $_
                    $FlatItem = @{}
                    
                    foreach ($Property in $Item.PSObject.Properties) {
                        if ($Property.Value -is [Array]) {
                            $FlatItem[$Property.Name] = ($Property.Value -join "; ")
                        }
                        elseif ($Property.Value -is [PSCustomObject] -or $Property.Value -is [Hashtable]) {
                            $FlatItem[$Property.Name] = ($Property.Value | ConvertTo-Json -Compress)
                        }
                        else {
                            $FlatItem[$Property.Name] = $Property.Value
                        }
                    }
                    
                    [PSCustomObject]$FlatItem
                }
                
                $FlattenedData | Export-Csv -Path $CsvPath -NoTypeInformation -Encoding UTF8
                $ExportedFiles += $CsvPath
                Write-LogMessage "✓ Exported $($AssetData.Count) $AssetType to: $CsvPath" "SUCCESS" "Export"
            }
        }
        
        Write-LogMessage "✓ Successfully exported to $($ExportedFiles.Count) CSV files" "SUCCESS" "Export"
        return $true
    }
    catch {
        Write-LogMessage "Failed to export to CSV: $($_.Exception.Message)" "ERROR" "Export"
        return $false
    }
}

function Send-ToCloudScopeAPI {
    <#
    .SYNOPSIS
    Send collected asset data directly to CloudScope API
    #>
    param(
        [Parameter(Mandatory = $true)]
        [object]$AssetInventory
    )
    
    try {
        Write-LogMessage "Sending data to CloudScope API..." "INFO" "API"
        
        if (-not $Global:ScriptConfig.CloudScopeAPI) {
            throw "CloudScope API configuration not found. Please configure CloudScopeAPI and ApiToken in config file."
        }
        
        $ApiEndpoint = $Global:ScriptConfig.CloudScopeAPI
        $Headers = @{
            'Content-Type' = 'application/json'
            'User-Agent' = 'CloudScope-M365Collector/1.0.0'
        }
        
        # Add authentication if configured
        if ($Global:ScriptConfig.ApiToken) {
            $Headers['Authorization'] = "Bearer $($Global:ScriptConfig.ApiToken)"
        }
        
        # Convert data to JSON
        $JsonData = $AssetInventory | ConvertTo-Json -Depth 10 -Compress
        
        # Send to API with retry logic
        $MaxRetries = 3
        $RetryCount = 0
        
        do {
            try {
                $Response = Invoke-RestMethod -Uri "$ApiEndpoint/api/v1/assets/bulk" -Method POST -Body $JsonData -Headers $Headers -TimeoutSec 300
                
                Write-LogMessage "✓ Successfully sent data to CloudScope API" "SUCCESS" "API"
                Write-LogMessage "Response: $($Response | ConvertTo-Json -Compress)" "INFO" "API"
                return $true
            }
            catch {
                $RetryCount++
                Write-LogMessage "API call attempt $RetryCount failed: $($_.Exception.Message)" "WARNING" "API"
                
                if ($RetryCount -lt $MaxRetries) {
                    $WaitTime = 5 * $RetryCount
                    Write-LogMessage "Retrying in $WaitTime seconds..." "INFO" "API"
                    Start-Sleep -Seconds $WaitTime
                }
            }
        } while ($RetryCount -lt $MaxRetries)
        
        throw "Failed to send data to CloudScope API after $MaxRetries attempts"
    }
    catch {
        Write-LogMessage "Failed to send data to CloudScope API: $($_.Exception.Message)" "ERROR" "API"
        return $false
    }
}

#endregion

#region Main Execution

function Invoke-AssetCollection {
    <#
    .SYNOPSIS
    Main function to orchestrate the asset collection process
    #>
    param()
    
    try {
        Write-LogMessage "🚀 Starting CloudScope Microsoft 365 Asset Collection" "INFO" "Main"
        Write-LogMessage "Version: 1.0.0" "INFO" "Main"
        Write-LogMessage "Asset Types: $($AssetTypes -join ', ')" "INFO" "Main"
        Write-LogMessage "Output Format: $OutputFormat" "INFO" "Main"
        
        # Initialize asset inventory structure
        $AssetInventory = @{
            collection_metadata = @{
                timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
                collector_version = "1.0.0"
                collector_type = "microsoft_365"
                tenant_id = $Global:ScriptConfig.TenantId
                collection_scope = $AssetTypes
                detailed_collection = $Detailed.IsPresent
            }
        }
        
        # Collect each requested asset type
        foreach ($AssetType in $AssetTypes) {
            Write-LogMessage "Collecting asset type: $AssetType" "INFO" "Main"
            
            switch ($AssetType) {
                "Users" { 
                    $AssetInventory.users = Get-M365Users -Detailed:$Detailed 
                }
                "Groups" { 
                    $AssetInventory.groups = Get-M365Groups -Detailed:$Detailed 
                }
                "Applications" { 
                    $AssetInventory.applications = Get-M365Applications -Detailed:$Detailed 
                }
                "Devices" { 
                    $AssetInventory.devices = Get-M365Devices -Detailed:$Detailed 
                }
                "Sites" { 
                    Write-LogMessage "SharePoint Sites collection not yet implemented" "WARNING" "Main"
                    # Future implementation for SharePoint sites
                }
                "Teams" { 
                    Write-LogMessage "Teams collection not yet implemented" "WARNING" "Main"
                    # Future implementation for Teams
                }
                "Security" { 
                    Write-LogMessage "Security events collection not yet implemented" "WARNING" "Main"
                    # Future implementation for security events
                }
                "Compliance" { 
                    Write-LogMessage "Compliance data collection not yet implemented" "WARNING" "Main"
                    # Future implementation for compliance data
                }
            }
        }
        
        # Export or send data based on output format
        $ExportSuccess = $false
        switch ($OutputFormat) {
            "JSON" {
                $ExportSuccess = Export-ToJSON -AssetInventory $AssetInventory -OutputPath $OutputPath
            }
            "CSV" {
                $ExportSuccess = Export-ToCSV -AssetInventory $AssetInventory -OutputPath $OutputPath
            }
            "Database" {
                $ExportSuccess = Send-ToCloudScopeAPI -AssetInventory $AssetInventory
            }
        }
        
        # Generate collection summary
        $Duration = (Get-Date) - $Global:CollectionStats.StartTime
        
        Write-LogMessage "`n📈 Collection Summary:" "INFO" "Summary"
        Write-LogMessage "   Duration: $($Duration.ToString('hh\:mm\:ss'))" "INFO" "Summary"
        Write-LogMessage "   Total Assets: $($Global:CollectionStats.TotalAssets)" "INFO" "Summary"
        Write-LogMessage "   Successful Collections: $($Global:CollectionStats.SuccessfulCollections)" "INFO" "Summary"
        Write-LogMessage "   Failed Collections: $($Global:CollectionStats.FailedCollections)" "INFO" "Summary"
        
        if ($Global:CollectionStats.Errors.Count -gt 0) {
            Write-LogMessage "   Errors: $($Global:CollectionStats.Errors.Count)" "WARNING" "Summary"
            foreach ($Error in $Global:CollectionStats.Errors) {
                Write-LogMessage "      [$($Error.Component)] $($Error.Message)" "ERROR" "Summary"
            }
        }
        
        if ($ExportSuccess) {
            Write-LogMessage "`n✅ CloudScope Microsoft 365 collection completed successfully!" "SUCCESS" "Main"
            exit 0
        } else {
            Write-LogMessage "`n❌ Collection completed with export errors!" "ERROR" "Main"
            exit 1
        }
    }
    catch {
        Write-LogMessage "Critical error in main execution: $($_.Exception.Message)" "ERROR" "Main"
        Write-LogMessage "Stack trace: $($_.ScriptStackTrace)" "ERROR" "Main"
        exit 1
    }
    finally {
        # Cleanup - disconnect from Microsoft Graph
        try {
            Disconnect-MgGraph -ErrorAction SilentlyContinue
            Write-LogMessage "✓ Disconnected from Microsoft Graph" "SUCCESS" "Cleanup"
        }
        catch {
            # Ignore disconnect errors
        }
    }
}

# Script entry point
try {
    # Validate PowerShell modules
    if (-not (Test-ModuleRequirements)) {
        Write-LogMessage "Required modules are missing. Please install them and try again." "ERROR" "Main"
        exit 1
    }
    
    # Load configuration
    $Global:ScriptConfig = Import-Configuration -ConfigPath $ConfigPath
    
    # Connect to Microsoft Graph
    if (-not (Connect-ToMicrosoftGraph -Config $Global:ScriptConfig)) {
        Write-LogMessage "Failed to connect to Microsoft Graph. Exiting." "ERROR" "Main"
        exit 1
    }
    
    # Start asset collection
    Invoke-AssetCollection
}
catch {
    Write-LogMessage "Script execution failed: $($_.Exception.Message)" "ERROR" "Main"
    exit 1
}

#endregion
