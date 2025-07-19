#!/bin/bash
# CloudScope Development Helper Script
# Common development tasks and utilities

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_task() { echo -e "${PURPLE}[TASK]${NC} $1"; }

# Check if virtual environment is active
check_venv() {
    if [[ -z "${VIRTUAL_ENV:-}" ]]; then
        log_warning "Virtual environment not active"
        if [[ -f "venv/bin/activate" ]]; then
            log_info "Activating virtual environment..."
            source venv/bin/activate
        else
            log_error "Virtual environment not found. Run: python -m venv venv"
            return 1
        fi
    fi
}

# Run tests
run_tests() {
    log_task "Running tests..."
    check_venv
    
    # Run pytest with coverage
    python -m pytest -v --cov=cloudscope --cov-report=html --cov-report=term
    
    log_success "Tests completed. Coverage report: htmlcov/index.html"
}

# Run specific test file or pattern
run_test_pattern() {
    local pattern=$1
    log_task "Running tests matching: $pattern"
    check_venv
    
    python -m pytest -v -k "$pattern" --cov=cloudscope --cov-report=term
}

# Run linting
run_lint() {
    log_task "Running linters..."
    check_venv
    
    # Run flake8
    log_info "Running flake8..."
    flake8 cloudscope tests
    
    # Run mypy
    log_info "Running mypy..."
    mypy cloudscope
    
    # Run black check
    log_info "Running black..."
    black --check cloudscope tests
    
    # Run isort check
    log_info "Running isort..."
    isort --check-only cloudscope tests
    
    log_success "Linting completed successfully"
}

# Format code
format_code() {
    log_task "Formatting code..."
    check_venv
    
    # Run black
    log_info "Running black formatter..."
    black cloudscope tests
    
    # Run isort
    log_info "Running isort..."
    isort cloudscope tests
    
    log_success "Code formatting completed"
}

# Generate documentation
generate_docs() {
    log_task "Generating documentation..."
    check_venv
    
    # Install doc dependencies if needed
    pip install -q sphinx sphinx-rtd-theme sphinx-autodoc-typehints
    
    # Create docs directory if it doesn't exist
    mkdir -p docs/source
    
    # Generate API documentation
    sphinx-apidoc -f -o docs/source cloudscope
    
    # Build HTML documentation
    cd docs && make html
    cd ..
    
    log_success "Documentation generated: docs/_build/html/index.html"
}

# Create new collector template
create_collector() {
    local name=$1
    local type=${2:-python}  # python or powershell
    
    log_task "Creating new $type collector: $name"
    
    if [[ "$type" == "python" ]]; then
        # Create Python collector
        mkdir -p cloudscope/adapters/collectors
        cat > "cloudscope/adapters/collectors/${name}_collector.py" << 'EOF'
#!/usr/bin/env python3
"""
NAME_PLACEHOLDER Collector for CloudScope.

This module implements the collector for NAME_PLACEHOLDER assets.
"""
import asyncio
import logging
from datetime import datetime
from typing import Dict, List, Optional, Any

from cloudscope.domain.models.asset import Asset
from cloudscope.ports.collectors import CollectorInterface


logger = logging.getLogger(__name__)


class NAME_PLACEHOLDERCollector(CollectorInterface):
    """Collector implementation for NAME_PLACEHOLDER."""
    
    def __init__(self, config: Dict[str, Any]):
        """
        Initialize the NAME_PLACEHOLDER collector.
        
        Args:
            config: Configuration dictionary
        """
        self.config = config
        self.name = "NAME_PLACEHOLDER_collector"
        self.enabled = config.get("enabled", True)
        
    async def collect(self) -> List[Asset]:
        """
        Collect assets from NAME_PLACEHOLDER.
        
        Returns:
            List of Asset objects
        """
        if not self.enabled:
            logger.info(f"{self.name} is disabled")
            return []
            
        logger.info(f"Starting {self.name} collection")
        assets = []
        
        try:
            # TODO: Implement collection logic here
            # Example:
            # client = self._create_client()
            # raw_assets = await client.list_assets()
            # 
            # for raw_asset in raw_assets:
            #     asset = self._transform_to_asset(raw_asset)
            #     assets.append(asset)
            
            logger.info(f"Collected {len(assets)} assets from {self.name}")
            
        except Exception as e:
            logger.error(f"Error in {self.name}: {str(e)}", exc_info=True)
            
        return assets
    
    def _create_client(self):
        """Create NAME_PLACEHOLDER API client."""
        # TODO: Implement client creation
        pass
    
    def _transform_to_asset(self, raw_data: Dict[str, Any]) -> Asset:
        """
        Transform raw NAME_PLACEHOLDER data to Asset object.
        
        Args:
            raw_data: Raw data from NAME_PLACEHOLDER API
            
        Returns:
            Asset object
        """
        # TODO: Implement transformation logic
        return Asset(
            id=raw_data.get("id"),
            name=raw_data.get("name", "Unknown"),
            asset_type="NAME_PLACEHOLDER_Asset",
            source=self.name,
            metadata=raw_data,
            risk_score=self._calculate_risk_score(raw_data)
        )
    
    def _calculate_risk_score(self, raw_data: Dict[str, Any]) -> int:
        """Calculate risk score for the asset."""
        # TODO: Implement risk scoring logic
        return 50


if __name__ == "__main__":
    # Test the collector
    import json
    
    config = {
        "enabled": True,
        # Add test configuration here
    }
    
    async def test():
        collector = NAME_PLACEHOLDERCollector(config)
        assets = await collector.collect()
        for asset in assets:
            print(json.dumps(asset.to_dict(), indent=2))
    
    asyncio.run(test())
EOF
        sed -i "" "s/NAME_PLACEHOLDER/${name}/g" "cloudscope/adapters/collectors/${name}_collector.py"
        
        # Create test file
        mkdir -p tests/adapters/collectors
        cat > "tests/adapters/collectors/test_${name}_collector.py" << 'EOF'
"""Tests for NAME_PLACEHOLDER collector."""
import pytest
from unittest.mock import Mock, patch

from cloudscope.adapters.collectors.NAME_PLACEHOLDER_collector import NAME_PLACEHOLDERCollector
from cloudscope.domain.models.asset import Asset


class TestNAME_PLACEHOLDERCollector:
    """Test cases for NAME_PLACEHOLDER collector."""
    
    @pytest.fixture
    def collector(self):
        """Create collector instance."""
        config = {
            "enabled": True,
        }
        return NAME_PLACEHOLDERCollector(config)
    
    @pytest.mark.asyncio
    async def test_collect_when_disabled(self):
        """Test collect when collector is disabled."""
        config = {"enabled": False}
        collector = NAME_PLACEHOLDERCollector(config)
        
        assets = await collector.collect()
        
        assert assets == []
    
    @pytest.mark.asyncio
    async def test_collect_success(self, collector):
        """Test successful collection."""
        # TODO: Add mock data and assertions
        assets = await collector.collect()
        
        assert isinstance(assets, list)
        # Add more specific assertions
    
    def test_transform_to_asset(self, collector):
        """Test transformation of raw data to Asset."""
        raw_data = {
            "id": "test-123",
            "name": "Test Asset",
            # Add more test data
        }
        
        asset = collector._transform_to_asset(raw_data)
        
        assert isinstance(asset, Asset)
        assert asset.id == "test-123"
        assert asset.name == "Test Asset"
        assert asset.asset_type == "NAME_PLACEHOLDER_Asset"
EOF
        sed -i "" "s/NAME_PLACEHOLDER/${name}/g" "tests/adapters/collectors/test_${name}_collector.py"
        
        log_success "Created Python collector: cloudscope/adapters/collectors/${name}_collector.py"
        
    elif [[ "$type" == "powershell" ]]; then
        # Create PowerShell collector
        mkdir -p "collectors/powershell/${name}"
        cat > "collectors/powershell/${name}/Get-${name}Assets.ps1" << 'EOF'
<#
.SYNOPSIS
    CloudScope NAME_PLACEHOLDER Asset Collector
    
.DESCRIPTION
    Collects asset information from NAME_PLACEHOLDER and exports to CloudScope
    
.PARAMETER OutputFormat
    Output format: JSON, CSV, or Database
    
.PARAMETER ConfigFile
    Path to CloudScope configuration file
    
.PARAMETER LogFile
    Path to log file
    
.EXAMPLE
    .\Get-NAME_PLACEHOLDERAssets.ps1 -OutputFormat Database
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('JSON', 'CSV', 'Database')]
    [string]$OutputFormat = 'Database',
    
    [Parameter()]
    [string]$ConfigFile = "../../../config/cloudscope-config.json",
    
    [Parameter()]
    [string]$LogFile = "../../../data/logs/NAME_PLACEHOLDER_collector_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
)

# Set strict mode
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Import required modules
Import-Module Microsoft.Graph -ErrorAction Stop

# Initialize logging
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # Write to console
    switch ($Level) {
        "ERROR" { Write-Host $logMessage -ForegroundColor Red }
        "WARN"  { Write-Host $logMessage -ForegroundColor Yellow }
        "INFO"  { Write-Host $logMessage -ForegroundColor Cyan }
        default { Write-Host $logMessage }
    }
    
    # Write to log file
    if ($LogFile) {
        $logMessage | Out-File -FilePath $LogFile -Append
    }
}

# Load configuration
function Get-Configuration {
    Write-Log "Loading configuration from: $ConfigFile"
    
    if (-not (Test-Path $ConfigFile)) {
        throw "Configuration file not found: $ConfigFile"
    }
    
    $config = Get-Content $ConfigFile | ConvertFrom-Json
    return $config
}

# Connect to NAME_PLACEHOLDER
function Connect-NAME_PLACEHOLDER {
    param($Config)
    
    Write-Log "Connecting to NAME_PLACEHOLDER..."
    
    try {
        # TODO: Implement connection logic
        # Example:
        # $credential = Get-Credential
        # Connect-Service -Credential $credential
        
        Write-Log "Successfully connected to NAME_PLACEHOLDER" -Level INFO
    }
    catch {
        Write-Log "Failed to connect to NAME_PLACEHOLDER: $_" -Level ERROR
        throw
    }
}

# Collect assets
function Get-Assets {
    Write-Log "Collecting NAME_PLACEHOLDER assets..."
    
    $assets = @()
    
    try {
        # TODO: Implement asset collection
        # Example:
        # $rawAssets = Get-NAME_PLACEHOLDERResource -All
        # 
        # foreach ($rawAsset in $rawAssets) {
        #     $asset = [PSCustomObject]@{
        #         id = $rawAsset.Id
        #         name = $rawAsset.Name
        #         asset_type = "NAME_PLACEHOLDER_Asset"
        #         source = "NAME_PLACEHOLDER_collector"
        #         metadata = @{
        #             # Add relevant metadata
        #         }
        #         risk_score = Get-RiskScore -Asset $rawAsset
        #         created_at = $rawAsset.CreatedDateTime
        #         updated_at = $rawAsset.LastModifiedDateTime
        #     }
        #     $assets += $asset
        # }
        
        Write-Log "Collected $($assets.Count) assets"
        
    }
    catch {
        Write-Log "Error collecting assets: $_" -Level ERROR
        throw
    }
    
    return $assets
}

# Calculate risk score
function Get-RiskScore {
    param($Asset)
    
    # TODO: Implement risk scoring logic
    return 50
}

# Export to database
function Export-ToDatabase {
    param($Assets, $Config)
    
    Write-Log "Exporting to Memgraph database..."
    
    # TODO: Implement database export
    # This would typically call a Python script or REST API
    
    $exportData = @{
        assets = $Assets
        timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        collector = "NAME_PLACEHOLDER_collector"
    }
    
    $jsonData = $exportData | ConvertTo-Json -Depth 10
    
    # Call Python script to insert into Memgraph
    $pythonScript = Join-Path $PSScriptRoot "../../../scripts/database/insert_assets.py"
    $jsonData | python $pythonScript
}

# Export to JSON
function Export-ToJSON {
    param($Assets, $OutputPath)
    
    Write-Log "Exporting to JSON: $OutputPath"
    
    $exportData = @{
        metadata = @{
            collector = "NAME_PLACEHOLDER_collector"
            timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            count = $Assets.Count
        }
        assets = $Assets
    }
    
    $exportData | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputPath
    Write-Log "Exported $($Assets.Count) assets to JSON"
}

# Export to CSV
function Export-ToCSV {
    param($Assets, $OutputPath)
    
    Write-Log "Exporting to CSV: $OutputPath"
    
    $csvData = $Assets | ForEach-Object {
        [PSCustomObject]@{
            Id = $_.id
            Name = $_.name
            Type = $_.asset_type
            Source = $_.source
            RiskScore = $_.risk_score
            CreatedAt = $_.created_at
            UpdatedAt = $_.updated_at
            # Flatten metadata as needed
        }
    }
    
    $csvData | Export-Csv -Path $OutputPath -NoTypeInformation
    Write-Log "Exported $($Assets.Count) assets to CSV"
}

# Main execution
try {
    Write-Log "Starting NAME_PLACEHOLDER asset collection"
    
    # Load configuration
    $config = Get-Configuration
    
    # Connect to service
    Connect-NAME_PLACEHOLDER -Config $config
    
    # Collect assets
    $assets = Get-Assets
    
    # Export based on format
    switch ($OutputFormat) {
        'Database' {
            Export-ToDatabase -Assets $assets -Config $config
        }
        'JSON' {
            $outputPath = Join-Path (Split-Path $LogFile) "NAME_PLACEHOLDER_assets_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
            Export-ToJSON -Assets $assets -OutputPath $outputPath
        }
        'CSV' {
            $outputPath = Join-Path (Split-Path $LogFile) "NAME_PLACEHOLDER_assets_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
            Export-ToCSV -Assets $assets -OutputPath $outputPath
        }
    }
    
    Write-Log "NAME_PLACEHOLDER asset collection completed successfully" -Level INFO
    
}
catch {
    Write-Log "Fatal error: $_" -Level ERROR
    exit 1
}
finally {
    # Disconnect if needed
    # Disconnect-NAME_PLACEHOLDER
}
EOF
        sed -i "" "s/NAME_PLACEHOLDER/${name}/g" "collectors/powershell/${name}/Get-${name}Assets.ps1"
        
        log_success "Created PowerShell collector: collectors/powershell/${name}/Get-${name}Assets.ps1"
    fi
}

# Database operations
db_shell() {
    log_task "Opening Memgraph shell..."
    
    docker exec -it cloudscope-memgraph mgconsole
}

db_query() {
    local query=$1
    log_task "Executing query..."
    
    echo "$query" | docker exec -i cloudscope-memgraph mgconsole
}

db_backup() {
    log_task "Creating database backup..."
    
    BACKUP_DIR="./backups"
    mkdir -p "$BACKUP_DIR"
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    
    # Export Memgraph data
    docker exec cloudscope-memgraph mgconsole --execute "DUMP DATABASE;" > "$BACKUP_DIR/memgraph_backup_${TIMESTAMP}.cypher"
    
    log_success "Backup saved to: $BACKUP_DIR/memgraph_backup_${TIMESTAMP}.cypher"
}

# Docker operations
docker_up() {
    log_task "Starting Docker services..."
    docker-compose up -d
    
    log_info "Waiting for services to be ready..."
    sleep 5
    
    docker-compose ps
}

docker_down() {
    log_task "Stopping Docker services..."
    docker-compose down
}

docker_logs() {
    local service=${1:-}
    
    if [[ -z "$service" ]]; then
        docker-compose logs -f
    else
        docker-compose logs -f "$service"
    fi
}

# Git operations
git_status() {
    log_task "Git repository status..."
    
    # Show branch
    echo -e "\n${BLUE}Current branch:${NC}"
    git branch --show-current
    
    # Show status
    echo -e "\n${BLUE}Git status:${NC}"
    git status -s
    
    # Show recent commits
    echo -e "\n${BLUE}Recent commits:${NC}"
    git log --oneline -5
}

# Show menu
show_menu() {
    echo -e "\n${PURPLE}CloudScope Development Helper${NC}"
    echo "=============================="
    echo ""
    echo "Testing & Quality:"
    echo "  1) Run all tests"
    echo "  2) Run specific test"
    echo "  3) Run linting"
    echo "  4) Format code"
    echo ""
    echo "Development:"
    echo "  5) Generate documentation"
    echo "  6) Create new collector"
    echo ""
    echo "Database:"
    echo "  7) Open database shell"
    echo "  8) Execute query"
    echo "  9) Backup database"
    echo ""
    echo "Docker:"
    echo "  10) Start services"
    echo "  11) Stop services"
    echo "  12) View logs"
    echo ""
    echo "Other:"
    echo "  13) Git status"
    echo "  14) Exit"
    echo ""
}

# Main interactive menu
interactive_mode() {
    while true; do
        show_menu
        read -p "Select option: " choice
        
        case $choice in
            1) run_tests ;;
            2) 
                read -p "Enter test pattern: " pattern
                run_test_pattern "$pattern"
                ;;
            3) run_lint ;;
            4) format_code ;;
            5) generate_docs ;;
            6) 
                read -p "Collector name: " name
                read -p "Type (python/powershell): " type
                create_collector "$name" "$type"
                ;;
            7) db_shell ;;
            8)
                read -p "Enter Cypher query: " query
                db_query "$query"
                ;;
            9) db_backup ;;
            10) docker_up ;;
            11) docker_down ;;
            12)
                read -p "Service name (empty for all): " service
                docker_logs "$service"
                ;;
            13) git_status ;;
            14) 
                log_info "Goodbye!"
                exit 0
                ;;
            *)
                log_error "Invalid option"
                ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
    done
}

# Parse command line arguments
if [[ $# -eq 0 ]]; then
    interactive_mode
else
    case $1 in
        test) run_tests ;;
        test-pattern) run_test_pattern "$2" ;;
        lint) run_lint ;;
        format) format_code ;;
        docs) generate_docs ;;
        collector) create_collector "$2" "${3:-python}" ;;
        db-shell) db_shell ;;
        db-query) db_query "$2" ;;
        db-backup) db_backup ;;
        docker-up) docker_up ;;
        docker-down) docker_down ;;
        docker-logs) docker_logs "$2" ;;
        git-status) git_status ;;
        *)
            log_error "Unknown command: $1"
            echo ""
            echo "Available commands:"
            echo "  test              Run all tests"
            echo "  test-pattern      Run tests matching pattern"
            echo "  lint              Run linting"
            echo "  format            Format code"
            echo "  docs              Generate documentation"
            echo "  collector         Create new collector"
            echo "  db-shell          Open database shell"
            echo "  db-query          Execute database query"
            echo "  db-backup         Backup database"
            echo "  docker-up         Start Docker services"
            echo "  docker-down       Stop Docker services"
            echo "  docker-logs       View Docker logs"
            echo "  git-status        Show git status"
            exit 1
            ;;
    esac
fi
