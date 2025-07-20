#Requires -Version 7.0
#Requires -Modules Microsoft.Graph

<#
.SYNOPSIS
    CloudScope Core Module
    
.DESCRIPTION
    Core functionality for CloudScope compliance monitoring framework.
    Provides authentication, configuration, and logging capabilities.
    
.NOTES
    Module: CloudScope.Core
    Author: CloudScope Team
    Version: 1.0.0
#>

# Module variables
$script:CloudScopeContext = @{
    Initialized = $false
    ConfigPath = Join-Path $HOME '.cloudscope' 'config.json'
    LogPath = Join-Path $HOME '.cloudscope' 'logs'
    TenantId = $null
    SubscriptionId = $null
    AuthenticationStatus = @{
        Graph = $false
        Azure = $false
    }
}

#region Public Functions

<#
.SYNOPSIS
    Initializes the CloudScope environment
    
.DESCRIPTION
    Sets up the CloudScope environment, including configuration, logging,
    and authentication with Microsoft services.
    
.PARAMETER ConfigPath
    Path to configuration file (defaults to ~/.cloudscope/config.json)
    
.PARAMETER Force
    Force reinitialization even if already initialized
    
.EXAMPLE
    Initialize-CloudScope
    
    Initializes CloudScope with default configuration
    
.EXAMPLE
    Initialize-CloudScope -ConfigPath "./myconfig.json" -Force
    
    Initializes CloudScope with custom configuration, forcing reinitialization
#>
function Initialize-CloudScope {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ConfigPath = $script:CloudScopeContext.ConfigPath,
        
        [Parameter(Mandatory = $false)]
        [switch]$Force
    )
    
    # Check if already initialized
    if ($script:CloudScopeContext.Initialized -and -not $Force) {
        Write-Verbose "CloudScope already initialized. Use -Force to reinitialize."
        return $true
    }
    
    Write-Host "🚀 Initializing CloudScope..." -ForegroundColor Green
    
    try {
        # Run environment check
        $envCheck = Test-CloudScopeEnvironment
        if (-not $envCheck.Ready) {
            Write-Error "Environment check failed. Run ./Test-Environment.ps1 -Fix to resolve issues."
            return $false
        }
        
        # Initialize configuration
        $config = Initialize-CloudScopeConfig -ConfigPath $ConfigPath
        if (-not $config) {
            Write-Error "Failed to initialize configuration."
            return $false
        }
        
        # Initialize logging
        Initialize-CloudScopeLogging
        
        # Set context
        $script:CloudScopeContext.Initialized = $true
        $script:CloudScopeContext.ConfigPath = $ConfigPath
        $script:CloudScopeContext.TenantId = $config.TenantId
        $script:CloudScopeContext.SubscriptionId = $config.SubscriptionId
        
        Write-CloudScopeLog -Message "CloudScope initialized successfully" -Level Information
        Write-Host "✅ CloudScope initialized successfully" -ForegroundColor Green
        
        return $true
    }
    catch {
        Write-Error "Failed to initialize CloudScope: $_"
        return $false
    }
}

<#
.SYNOPSIS
    Connects to Microsoft cloud services
    
.DESCRIPTION
    Establishes connections to Microsoft Graph and Azure services
    using existing authentication tokens when available.
    
.PARAMETER TenantId
    Azure AD tenant ID
    
.PARAMETER Interactive
    Use interactive authentication
    
.PARAMETER DeviceCode
    Use device code authentication
    
.PARAMETER ManagedIdentity
    Use managed identity authentication
    
.EXAMPLE
    Connect-CloudScopeServices
    
    Connects to Microsoft services using default authentication
    
.EXAMPLE
    Connect-CloudScopeServices -TenantId "contoso.onmicrosoft.com" -Interactive
    
    Connects to Microsoft services for specific tenant using interactive auth
#>
function Connect-CloudScopeServices {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$TenantId = $script:CloudScopeContext.TenantId,
        
        [Parameter(Mandatory = $false)]
        [switch]$Interactive,
        
        [Parameter(Mandatory = $false)]
        [switch]$DeviceCode,
        
        [Parameter(Mandatory = $false)]
        [switch]$ManagedIdentity
    )
    
    Write-Host "🔑 Connecting to Microsoft services..." -ForegroundColor Green
    
    try {
        # Connect to Microsoft Graph
        $graphParams = @{}
        if ($TenantId) { $graphParams.TenantId = $TenantId }
        if ($Interactive) { $graphParams.Interactive = $true }
        if ($DeviceCode) { $graphParams.DeviceCode = $true }
        if ($ManagedIdentity) { $graphParams.ManagedIdentity = $true }
        
        # Check if already connected to Graph
        $graphContext = Get-MgContext -ErrorAction SilentlyContinue
        if (-not $graphContext) {
            Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Yellow
            Connect-MgGraph @graphParams
            $graphContext = Get-MgContext
        }
        
        if ($graphContext) {
            $script:CloudScopeContext.AuthenticationStatus.Graph = $true
            Write-Host "✅ Connected to Microsoft Graph" -ForegroundColor Green
            Write-Host "   Tenant: $($graphContext.TenantId)" -ForegroundColor Cyan
        }
        
        # Connect to Azure if Az module is available
        if (Get-Module -Name Az.Accounts -ListAvailable) {
            $azContext = Get-AzContext -ErrorAction SilentlyContinue
            if (-not $azContext) {
                Write-Host "Connecting to Azure..." -ForegroundColor Yellow
                $azParams = @{}
                if ($TenantId) { $azParams.TenantId = $TenantId }
                if ($DeviceCode) { $azParams.UseDeviceAuthentication = $true }
                if ($ManagedIdentity) { $azParams.Identity = $true }
                
                Connect-AzAccount @azParams
                $azContext = Get-AzContext
            }
            
            if ($azContext) {
                $script:CloudScopeContext.AuthenticationStatus.Azure = $true
                Write-Host "✅ Connected to Azure" -ForegroundColor Green
                Write-Host "   Subscription: $($azContext.Subscription.Name)" -ForegroundColor Cyan
            }
        }
        
        return $true
    }
    catch {
        Write-Error "Failed to connect to Microsoft services: $_"
        return $false
    }
}

<#
.SYNOPSIS
    Gets CloudScope configuration
    
.DESCRIPTION
    Retrieves the current CloudScope configuration from the config file.
    
.PARAMETER Path
    Path to configuration file (defaults to ~/.cloudscope/config.json)
    
.EXAMPLE
    Get-CloudScopeConfig
    
    Gets the current CloudScope configuration
#>
function Get-CloudScopeConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Path = $script:CloudScopeContext.ConfigPath
    )
    
    try {
        # Check if config file exists
        if (-not (Test-Path -Path $Path)) {
            Write-Error "Configuration file not found: $Path"
            return $null
        }
        
        # Read and parse config
        $configJson = Get-Content -Path $Path -Raw
        $config = $configJson | ConvertFrom-Json -AsHashtable
        
        return $config
    }
    catch {
        Write-Error "Failed to get configuration: $_"
        return $null
    }
}

<#
.SYNOPSIS
    Sets CloudScope configuration
    
.DESCRIPTION
    Updates the CloudScope configuration with the specified setting.
    
.PARAMETER Setting
    Configuration setting to update (dot notation supported)
    
.PARAMETER Value
    Value to set
    
.PARAMETER Path
    Path to configuration file (defaults to ~/.cloudscope/config.json)
    
.EXAMPLE
    Set-CloudScopeConfig -Setting "Monitoring.Enabled" -Value $true
    
    Enables monitoring in the configuration
#>
function Set-CloudScopeConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Setting,
        
        [Parameter(Mandatory = $true)]
        [object]$Value,
        
        [Parameter(Mandatory = $false)]
        [string]$Path = $script:CloudScopeContext.ConfigPath
    )
    
    try {
        # Get current config
        $config = Get-CloudScopeConfig -Path $Path
        if (-not $config) {
            $config = @{}
        }
        
        # Update setting using dot notation
        $current = $config
        $parts = $Setting -split '\.'
        
        # Navigate to the correct level
        for ($i = 0; $i -lt $parts.Count - 1; $i++) {
            $part = $parts[$i]
            if (-not $current.ContainsKey($part)) {
                $current[$part] = @{}
            }
            $current = $current[$part]
        }
        
        # Set the value
        $current[$parts[-1]] = $Value
        
        # Save config
        $config | ConvertTo-Json -Depth 10 | Set-Content -Path $Path
        
        Write-CloudScopeLog -Message "Updated configuration setting: $Setting" -Level Information
        return $true
    }
    catch {
        Write-Error "Failed to set configuration: $_"
        return $false
    }
}

<#
.SYNOPSIS
    Imports CloudScope configuration
    
.DESCRIPTION
    Imports CloudScope configuration from a JSON file.
    
.PARAMETER Path
    Path to configuration file to import
    
.PARAMETER Destination
    Destination path for the imported configuration
    
.EXAMPLE
    Import-CloudScopeConfig -Path "./myconfig.json"
    
    Imports configuration from the specified file
#>
function Import-CloudScopeConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        
        [Parameter(Mandatory = $false)]
        [string]$Destination = $script:CloudScopeContext.ConfigPath
    )
    
    try {
        # Check if source file exists
        if (-not (Test-Path -Path $Path)) {
            Write-Error "Source configuration file not found: $Path"
            return $false
        }
        
        # Create destination directory if it doesn't exist
        $destDir = Split-Path -Parent $Destination
        if (-not (Test-Path -Path $destDir)) {
            New-Item -Path $destDir -ItemType Directory -Force | Out-Null
        }
        
        # Validate JSON
        $configJson = Get-Content -Path $Path -Raw
        $null = $configJson | ConvertFrom-Json
        
        # Copy file
        Copy-Item -Path $Path -Destination $Destination -Force
        
        Write-CloudScopeLog -Message "Imported configuration from: $Path" -Level Information
        return $true
    }
    catch {
        Write-Error "Failed to import configuration: $_"
        return $false
    }
}

<#
.SYNOPSIS
    Exports CloudScope configuration
    
.DESCRIPTION
    Exports CloudScope configuration to a JSON file.
    
.PARAMETER Path
    Destination path for the exported configuration
    
.PARAMETER Source
    Source path for the configuration to export
    
.EXAMPLE
    Export-CloudScopeConfig -Path "./myconfig.json"
    
    Exports configuration to the specified file
#>
function Export-CloudScopeConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        
        [Parameter(Mandatory = $false)]
        [string]$Source = $script:CloudScopeContext.ConfigPath
    )
    
    try {
        # Check if source file exists
        if (-not (Test-Path -Path $Source)) {
            Write-Error "Source configuration file not found: $Source"
            return $false
        }
        
        # Create destination directory if it doesn't exist
        $destDir = Split-Path -Parent $Path
        if (-not (Test-Path -Path $destDir)) {
            New-Item -Path $destDir -ItemType Directory -Force | Out-Null
        }
        
        # Copy file
        Copy-Item -Path $Source -Destination $Path -Force
        
        Write-CloudScopeLog -Message "Exported configuration to: $Path" -Level Information
        return $true
    }
    catch {
        Write-Error "Failed to export configuration: $_"
        return $false
    }
}

<#
.SYNOPSIS
    Writes a log message to the CloudScope log
    
.DESCRIPTION
    Writes a log message to the CloudScope log file and console.
    
.PARAMETER Message
    Log message
    
.PARAMETER Level
    Log level (Information, Warning, Error, Debug)
    
.PARAMETER Tags
    Tags for categorizing log messages
    
.EXAMPLE
    Write-CloudScopeLog -Message "Operation completed" -Level Information
    
    Writes an information message to the log
#>
function Write-CloudScopeLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('Information', 'Warning', 'Error', 'Debug')]
        [string]$Level = 'Information',
        
        [Parameter(Mandatory = $false)]
        [string[]]$Tags = @()
    )
    
    try {
        # Create log entry
        $logEntry = @{
            Timestamp = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ'
            Level = $Level
            Message = $Message
            Tags = $Tags
            Source = "CloudScope.Core"
            User = $env:USERNAME
            Computer = $env:COMPUTERNAME
        }
        
        # Write to console with appropriate color
        $color = switch ($Level) {
            'Information' { 'White' }
            'Warning' { 'Yellow' }
            'Error' { 'Red' }
            'Debug' { 'Gray' }
            default { 'White' }
        }
        
        if ($Level -ne 'Debug' -or $VerbosePreference -eq 'Continue') {
            Write-Host "[$($logEntry.Timestamp)] [$Level] $Message" -ForegroundColor $color
        }
        
        # Write to log file
        $logDir = $script:CloudScopeContext.LogPath
        if (-not (Test-Path -Path $logDir)) {
            New-Item -Path $logDir -ItemType Directory -Force | Out-Null
        }
        
        $logFile = Join-Path $logDir "CloudScope_$(Get-Date -Format 'yyyyMMdd').log"
        $logLine = "[$($logEntry.Timestamp)] [$Level] $Message"
        if ($Tags.Count -gt 0) {
            $logLine += " [Tags: $($Tags -join ', ')]"
        }
        
        Add-Content -Path $logFile -Value $logLine
        
        return $true
    }
    catch {
        # Don't use Write-Error here to avoid infinite recursion
        Write-Host "Failed to write log: $_" -ForegroundColor Red
        return $false
    }
}

#endregion

#region Private Functions

function Initialize-CloudScopeConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ConfigPath = $script:CloudScopeContext.ConfigPath
    )
    
    try {
        # Default configuration
        $defaultConfig = @{
            Version = "1.0.0"
            Environment = "Production"
            TenantId = $null
            SubscriptionId = $null
            LogLevel = "Information"
            Monitoring = @{
                Enabled = $true
                IntervalSeconds = 300
            }
            Compliance = @{
                DefaultFramework = "GDPR"
                EnableAutomaticRemediation = $false
            }
            FinOps = @{
                Enabled = $true
                BudgetAlerts = $true
            }
            Visualization = @{
                DefaultFormat = "HTML"
                EnableInteractive = $true
            }
        }
        
        # Create directory if it doesn't exist
        $configDir = Split-Path -Parent $ConfigPath
        if (-not (Test-Path -Path $configDir)) {
            New-Item -Path $configDir -ItemType Directory -Force | Out-Null
        }
        
        # Create or update config file
        if (Test-Path -Path $ConfigPath) {
            # Load existing config and merge with defaults
            $existingConfig = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json -AsHashtable
            $mergedConfig = Merge-Hashtables -Base $defaultConfig -Overlay $existingConfig
            $mergedConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $ConfigPath
            return $mergedConfig
        } else {
            # Create new config with defaults
            $defaultConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $ConfigPath
            return $defaultConfig
        }
    }
    catch {
        Write-Error "Failed to initialize configuration: $_"
        return $null
    }
}

function Initialize-CloudScopeLogging {
    [CmdletBinding()]
    param()
    
    try {
        # Create log directory if it doesn't exist
        $logDir = $script:CloudScopeContext.LogPath
        if (-not (Test-Path -Path $logDir)) {
            New-Item -Path $logDir -ItemType Directory -Force | Out-Null
        }
        
        return $true
    }
    catch {
        Write-Error "Failed to initialize logging: $_"
        return $false
    }
}

function Merge-Hashtables {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Base,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$Overlay
    )
    
    $result = $Base.Clone()
    
    foreach ($key in $Overlay.Keys) {
        if ($result.ContainsKey($key) -and $result[$key] -is [hashtable] -and $Overlay[$key] -is [hashtable]) {
            $result[$key] = Merge-Hashtables -Base $result[$key] -Overlay $Overlay[$key]
        } else {
            $result[$key] = $Overlay[$key]
        }
    }
    
    return $result
}

function Test-CloudScopeEnvironment {
    [CmdletBinding()]
    param()
    
    $issues = 0
    
    # Check PowerShell version
    $requiredVersion = [version]'7.0.0'
    $currentVersion = $PSVersionTable.PSVersion
    if ($currentVersion -lt $requiredVersion) {
        Write-Verbose "PowerShell $requiredVersion or higher required. Current: $currentVersion"
        $issues++
    }
    
    # Check required modules
    $requiredModules = @('Microsoft.Graph')
    foreach ($module in $requiredModules) {
        if (-not (Get-Module -ListAvailable -Name $module)) {
            Write-Verbose "Required module not found: $module"
            $issues++
        }
    }
    
    return @{
        Ready = ($issues -eq 0)
        Issues = $issues
    }
}

#endregion

# Export public functions
Export-ModuleMember -Function @(
    'Initialize-CloudScope',
    'Connect-CloudScopeServices',
    'Get-CloudScopeConfig',
    'Set-CloudScopeConfig',
    'Import-CloudScopeConfig',
    'Export-CloudScopeConfig',
    'Write-CloudScopeLog'
)