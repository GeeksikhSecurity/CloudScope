#!/bin/bash
# CloudScope Run All Collectors Script
# This script runs all configured collectors in sequence or parallel

set -euo pipefail

# Configuration
CONFIG_FILE="${CONFIG_FILE:-./config/cloudscope-config.json}"
LOG_DIR="${LOG_DIR:-./data/logs}"
PARALLEL="${PARALLEL:-false}"
DRY_RUN="${DRY_RUN:-false}"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Create log directory
mkdir -p "$LOG_DIR"

# Get timestamp for log files
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if config file exists
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Configuration file not found: $CONFIG_FILE"
        exit 1
    fi
    
    # Check if Python environment is activated
    if [[ -z "${VIRTUAL_ENV:-}" ]]; then
        log_warning "Python virtual environment not activated"
        log_info "Activating virtual environment..."
        source venv/bin/activate
    fi
    
    # Check if PowerShell is installed
    if ! command -v pwsh &> /dev/null; then
        log_error "PowerShell not found. Please install PowerShell Core."
        exit 1
    fi
    
    # Check if Docker is running (for database)
    if ! docker ps &> /dev/null; then
        log_error "Docker is not running or not accessible"
        exit 1
    fi
}

# Run PowerShell collectors
run_powershell_collectors() {
    log_info "Running PowerShell collectors..."
    
    # Microsoft 365 Collector
    if [[ -f "./collectors/powershell/microsoft-365/Get-M365Assets.ps1" ]]; then
        log_info "Running Microsoft 365 collector..."
        
        if [[ "$DRY_RUN" == "true" ]]; then
            log_warning "DRY RUN: Would run Microsoft 365 collector"
        else
            pwsh -File ./collectors/powershell/microsoft-365/Get-M365Assets.ps1 \
                -OutputFormat Database \
                -ConfigFile "$CONFIG_FILE" \
                -LogFile "$LOG_DIR/m365_collector_${TIMESTAMP}.log" \
                2>&1 | tee -a "$LOG_DIR/m365_collector_${TIMESTAMP}.log"
                
            if [ ${PIPESTATUS[0]} -eq 0 ]; then
                log_success "Microsoft 365 collector completed"
            else
                log_error "Microsoft 365 collector failed"
                return 1
            fi
        fi
    fi
    
    # Azure Collector (if exists)
    if [[ -f "./collectors/powershell/azure/Get-AzureAssets.ps1" ]]; then
        log_info "Running Azure collector..."
        
        if [[ "$DRY_RUN" == "true" ]]; then
            log_warning "DRY RUN: Would run Azure collector"
        else
            pwsh -File ./collectors/powershell/azure/Get-AzureAssets.ps1 \
                -OutputFormat Database \
                -ConfigFile "$CONFIG_FILE" \
                -LogFile "$LOG_DIR/azure_collector_${TIMESTAMP}.log" \
                2>&1 | tee -a "$LOG_DIR/azure_collector_${TIMESTAMP}.log"
                
            if [ ${PIPESTATUS[0]} -eq 0 ]; then
                log_success "Azure collector completed"
            else
                log_error "Azure collector failed"
                return 1
            fi
        fi
    fi
}

# Run Python collectors
run_python_collectors() {
    log_info "Running Python collectors..."
    
    # AWS Collector
    if [[ -f "./cloudscope/adapters/collectors/aws_collector.py" ]]; then
        log_info "Running AWS collector..."
        
        if [[ "$DRY_RUN" == "true" ]]; then
            log_warning "DRY RUN: Would run AWS collector"
        else
            python -m cloudscope.adapters.collectors.aws_collector \
                --config "$CONFIG_FILE" \
                --log-file "$LOG_DIR/aws_collector_${TIMESTAMP}.log" \
                2>&1 | tee -a "$LOG_DIR/aws_collector_${TIMESTAMP}.log"
                
            if [ ${PIPESTATUS[0]} -eq 0 ]; then
                log_success "AWS collector completed"
            else
                log_error "AWS collector failed"
                return 1
            fi
        fi
    fi
    
    # GCP Collector
    if [[ -f "./cloudscope/adapters/collectors/gcp_collector.py" ]]; then
        log_info "Running GCP collector..."
        
        if [[ "$DRY_RUN" == "true" ]]; then
            log_warning "DRY RUN: Would run GCP collector"
        else
            python -m cloudscope.adapters.collectors.gcp_collector \
                --config "$CONFIG_FILE" \
                --log-file "$LOG_DIR/gcp_collector_${TIMESTAMP}.log" \
                2>&1 | tee -a "$LOG_DIR/gcp_collector_${TIMESTAMP}.log"
                
            if [ ${PIPESTATUS[0]} -eq 0 ]; then
                log_success "GCP collector completed"
            else
                log_error "GCP collector failed"
                return 1
            fi
        fi
    fi
    
    # On-Premises Collector
    if [[ -f "./cloudscope/adapters/collectors/onprem_collector.py" ]]; then
        log_info "Running On-Premises collector..."
        
        if [[ "$DRY_RUN" == "true" ]]; then
            log_warning "DRY RUN: Would run On-Premises collector"
        else
            python -m cloudscope.adapters.collectors.onprem_collector \
                --config "$CONFIG_FILE" \
                --log-file "$LOG_DIR/onprem_collector_${TIMESTAMP}.log" \
                2>&1 | tee -a "$LOG_DIR/onprem_collector_${TIMESTAMP}.log"
                
            if [ ${PIPESTATUS[0]} -eq 0 ]; then
                log_success "On-Premises collector completed"
            else
                log_error "On-Premises collector failed"
                return 1
            fi
        fi
    fi
}

# Run collectors in parallel
run_parallel() {
    log_info "Running collectors in parallel..."
    
    # Create a temporary directory for PID files
    PID_DIR=$(mktemp -d)
    
    # Start PowerShell collectors in background
    (run_powershell_collectors) &
    echo $! > "$PID_DIR/powershell.pid"
    
    # Start Python collectors in background
    (run_python_collectors) &
    echo $! > "$PID_DIR/python.pid"
    
    # Wait for all collectors to complete
    log_info "Waiting for all collectors to complete..."
    
    FAILED=0
    for pid_file in "$PID_DIR"/*.pid; do
        PID=$(cat "$pid_file")
        wait $PID
        if [ $? -ne 0 ]; then
            FAILED=$((FAILED + 1))
        fi
    done
    
    # Clean up
    rm -rf "$PID_DIR"
    
    if [ $FAILED -gt 0 ]; then
        log_error "$FAILED collector(s) failed"
        return 1
    else
        log_success "All collectors completed successfully"
    fi
}

# Generate collection summary
generate_summary() {
    log_info "Generating collection summary..."
    
    SUMMARY_FILE="$LOG_DIR/collection_summary_${TIMESTAMP}.txt"
    
    cat > "$SUMMARY_FILE" << EOF
CloudScope Collection Summary
============================
Timestamp: $(date)
Configuration: $CONFIG_FILE
Log Directory: $LOG_DIR

Collectors Run:
EOF
    
    # List all log files created during this run
    find "$LOG_DIR" -name "*_${TIMESTAMP}.log" -type f | while read -r logfile; do
        collector_name=$(basename "$logfile" | sed "s/_${TIMESTAMP}.log//")
        line_count=$(wc -l < "$logfile")
        echo "- $collector_name: $line_count lines" >> "$SUMMARY_FILE"
    done
    
    # Add asset count from database
    if command -v mgconsole &> /dev/null; then
        asset_count=$(docker exec cloudscope-memgraph echo "MATCH (a:Asset) RETURN count(a) AS count;" | mgconsole | grep -oE '[0-9]+' | tail -1)
        echo -e "\nTotal Assets in Database: $asset_count" >> "$SUMMARY_FILE"
    fi
    
    log_success "Summary written to: $SUMMARY_FILE"
    cat "$SUMMARY_FILE"
}

# Print usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Run all CloudScope collectors

Options:
    -c, --config FILE       Configuration file (default: ./config/cloudscope-config.json)
    -l, --log-dir DIR      Log directory (default: ./data/logs)
    -p, --parallel         Run collectors in parallel
    -d, --dry-run          Show what would be run without executing
    -h, --help             Show this help message

Examples:
    # Run all collectors sequentially
    $0

    # Run collectors in parallel
    $0 --parallel

    # Dry run to see what would be executed
    $0 --dry-run

    # Use custom config file
    $0 --config /path/to/config.json
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        -l|--log-dir)
            LOG_DIR="$2"
            shift 2
            ;;
        -p|--parallel)
            PARALLEL="true"
            shift
            ;;
        -d|--dry-run)
            DRY_RUN="true"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Main execution
main() {
    log_info "CloudScope Collector Runner"
    log_info "==========================="
    
    # Check prerequisites
    check_prerequisites
    
    # Show configuration
    log_info "Configuration:"
    echo "  Config File: $CONFIG_FILE"
    echo "  Log Directory: $LOG_DIR"
    echo "  Parallel Mode: $PARALLEL"
    echo "  Dry Run: $DRY_RUN"
    echo ""
    
    # Run collectors
    if [[ "$PARALLEL" == "true" ]]; then
        run_parallel
    else
        run_powershell_collectors
        run_python_collectors
    fi
    
    # Generate summary
    if [[ "$DRY_RUN" != "true" ]]; then
        generate_summary
    fi
    
    log_success "Collection process complete!"
}

# Run main function
main
