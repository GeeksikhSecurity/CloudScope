#!/bin/bash
# CloudScope Utility Script
# Common operations and shortcuts for CloudScope management

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Configuration
export CLOUDSCOPE_HOME="${CLOUDSCOPE_HOME:-$PROJECT_ROOT}"
export CLOUDSCOPE_CONFIG="${CLOUDSCOPE_CONFIG:-$CLOUDSCOPE_HOME/config/cloudscope-config.json}"
export CLOUDSCOPE_DATA="${CLOUDSCOPE_DATA:-$CLOUDSCOPE_HOME/data}"
export CLOUDSCOPE_LOGS="${CLOUDSCOPE_LOGS:-$CLOUDSCOPE_DATA/logs}"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }
log_cmd() { echo -e "${PURPLE}[CMD]${NC} $1"; }

# Banner
show_banner() {
    echo -e "${CYAN}"
    echo "   ____ _                 _ ____                       "
    echo "  / ___| | ___  _   _  __| / ___|  ___ ___  _ __   ___ "
    echo " | |   | |/ _ \| | | |/ _\` \___ \ / __/ _ \| '_ \ / _ \\"
    echo " | |___| | (_) | |_| | (_| |___) | (_| (_) | |_) |  __/"
    echo "  \____|_|\___/ \__,_|\__,_|____/ \___\___/| .__/ \___|"
    echo "                                            |_|         "
    echo -e "${NC}"
    echo "CloudScope Utility Tool v1.0"
    echo ""
}

# Change to project directory
cd "$CLOUDSCOPE_HOME"

# Quick status check
quick_status() {
    log_info "CloudScope Quick Status"
    echo "======================="
    
    # Check services
    echo -e "\n${BLUE}Services:${NC}"
    if docker-compose ps 2>/dev/null | grep -q "Up"; then
        docker-compose ps --services | while read -r service; do
            if docker-compose ps "$service" 2>/dev/null | grep -q "Up"; then
                echo -e "  ${GREEN}●${NC} $service"
            else
                echo -e "  ${RED}●${NC} $service"
            fi
        done
    else
        log_warning "No services running"
    fi
    
    # Check API
    echo -e "\n${BLUE}API:${NC}"
    if curl -s -f http://localhost:8000/health &> /dev/null; then
        echo -e "  ${GREEN}●${NC} API is healthy"
    else
        echo -e "  ${RED}●${NC} API is not responding"
    fi
    
    # Asset count
    echo -e "\n${BLUE}Assets:${NC}"
    local asset_count=$(docker exec cloudscope-memgraph mgconsole --execute "MATCH (a:Asset) RETURN count(a)" 2>/dev/null | grep -oE '[0-9]+' | tail -1 || echo "0")
    echo "  Total: $asset_count"
    
    # Recent activity
    echo -e "\n${BLUE}Recent Activity:${NC}"
    local recent_logs=$(find "$CLOUDSCOPE_LOGS" -name "*.log" -mtime -1 2>/dev/null | wc -l)
    echo "  Log files (24h): $recent_logs"
}

# Start all services
start_all() {
    log_info "Starting CloudScope services..."
    
    # Start Docker services
    log_cmd "docker-compose up -d"
    docker-compose up -d
    
    # Wait for services
    log_info "Waiting for services to be ready..."
    sleep 10
    
    # Start API
    if [[ -f "$CLOUDSCOPE_HOME/scripts/api/manage-api.sh" ]]; then
        log_cmd "Starting API..."
        bash "$CLOUDSCOPE_HOME/scripts/api/manage-api.sh" start
    fi
    
    log_success "All services started"
}

# Stop all services
stop_all() {
    log_info "Stopping CloudScope services..."
    
    # Stop API
    if [[ -f "$CLOUDSCOPE_HOME/scripts/api/manage-api.sh" ]]; then
        bash "$CLOUDSCOPE_HOME/scripts/api/manage-api.sh" stop 2>/dev/null || true
    fi
    
    # Stop Docker services
    log_cmd "docker-compose down"
    docker-compose down
    
    log_success "All services stopped"
}

# Restart all services
restart_all() {
    stop_all
    sleep 2
    start_all
}

# Run collectors
run_collectors() {
    log_info "Running asset collectors..."
    
    if [[ -f "$CLOUDSCOPE_HOME/scripts/collectors/run-all-collectors.sh" ]]; then
        bash "$CLOUDSCOPE_HOME/scripts/collectors/run-all-collectors.sh" "$@"
    else
        log_error "Collector script not found"
    fi
}

# Database operations
db_shell() {
    log_info "Opening Memgraph shell..."
    docker exec -it cloudscope-memgraph mgconsole
}

db_query() {
    local query=$1
    log_info "Executing query..."
    docker exec cloudscope-memgraph mgconsole --execute "$query"
}

db_backup() {
    log_info "Creating database backup..."
    
    if [[ -f "$CLOUDSCOPE_HOME/scripts/backup/backup-restore.sh" ]]; then
        bash "$CLOUDSCOPE_HOME/scripts/backup/backup-restore.sh" backup all
    else
        # Simple backup
        local backup_file="$CLOUDSCOPE_DATA/backups/memgraph_backup_$(date +%Y%m%d_%H%M%S).cypher"
        mkdir -p "$(dirname "$backup_file")"
        docker exec cloudscope-memgraph mgconsole --execute "DUMP DATABASE;" > "$backup_file"
        log_success "Backup saved to: $backup_file"
    fi
}

# Log operations
view_logs() {
    local service=${1:-all}
    
    if [[ "$service" == "all" ]]; then
        log_info "Viewing all logs..."
        docker-compose logs -f
    else
        log_info "Viewing logs for: $service"
        docker-compose logs -f "$service"
    fi
}

tail_logs() {
    local pattern=${1:-"*.log"}
    log_info "Tailing log files matching: $pattern"
    
    tail -f "$CLOUDSCOPE_LOGS"/$pattern
}

# Search operations
search_assets() {
    local query=$1
    log_info "Searching for assets: $query"
    
    docker exec cloudscope-memgraph mgconsole --execute "
        MATCH (a:Asset)
        WHERE a.name =~ '.*$query.*' OR a.id =~ '.*$query.*'
        RETURN a.id AS ID, a.name AS Name, a.asset_type AS Type, a.risk_score AS Risk
        LIMIT 20
    "
}

find_high_risk() {
    local threshold=${1:-80}
    log_info "Finding assets with risk score >= $threshold"
    
    docker exec cloudscope-memgraph mgconsole --execute "
        MATCH (a:Asset)
        WHERE a.risk_score >= $threshold
        RETURN a.name AS Name, a.risk_score AS Risk, a.asset_type AS Type
        ORDER BY a.risk_score DESC
    "
}

# Report operations
generate_report() {
    local report_type=${1:-inventory}
    log_info "Generating $report_type report..."
    
    if [[ -f "$CLOUDSCOPE_HOME/scripts/reports/generate-reports.sh" ]]; then
        bash "$CLOUDSCOPE_HOME/scripts/reports/generate-reports.sh" generate "$report_type"
    else
        log_error "Report generator not found"
    fi
}

# Configuration operations
edit_config() {
    local editor=${EDITOR:-nano}
    log_info "Opening configuration in $editor..."
    "$editor" "$CLOUDSCOPE_CONFIG"
}

show_config() {
    log_info "Current configuration:"
    if command -v jq &> /dev/null; then
        jq . "$CLOUDSCOPE_CONFIG"
    else
        cat "$CLOUDSCOPE_CONFIG"
    fi
}

# Development operations
run_tests() {
    log_info "Running tests..."
    
    if [[ -f "$CLOUDSCOPE_HOME/scripts/testing/run-tests.sh" ]]; then
        bash "$CLOUDSCOPE_HOME/scripts/testing/run-tests.sh" "$@"
    else
        # Simple test run
        source venv/bin/activate 2>/dev/null || true
        python -m pytest tests/
    fi
}

lint_code() {
    log_info "Running code linters..."
    
    source venv/bin/activate 2>/dev/null || true
    
    # Python linting
    log_cmd "Running flake8..."
    flake8 cloudscope/ || true
    
    log_cmd "Running mypy..."
    mypy cloudscope/ || true
    
    # Shell script linting
    if command -v shellcheck &> /dev/null; then
        log_cmd "Running shellcheck..."
        find scripts -name "*.sh" -type f -exec shellcheck {} \; || true
    fi
}

# Quick actions menu
quick_menu() {
    while true; do
        echo ""
        echo "Quick Actions:"
        echo "============="
        echo "1) Status check"
        echo "2) Start all services"
        echo "3) Stop all services"
        echo "4) Run collectors"
        echo "5) View logs"
        echo "6) Database shell"
        echo "7) Search assets"
        echo "8) Generate report"
        echo "9) Backup database"
        echo "0) Exit"
        echo ""
        read -p "Select action (0-9): " choice
        
        case $choice in
            1) quick_status ;;
            2) start_all ;;
            3) stop_all ;;
            4) run_collectors ;;
            5) view_logs ;;
            6) db_shell ;;
            7) 
                read -p "Search query: " query
                search_assets "$query"
                ;;
            8) 
                echo "Report types: inventory, risk, security, executive"
                read -p "Report type: " rtype
                generate_report "$rtype"
                ;;
            9) db_backup ;;
            0) exit 0 ;;
            *) log_error "Invalid selection" ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
    done
}

# Environment setup
setup_env() {
    log_info "Setting up CloudScope environment..."
    
    # Export environment variables
    export CLOUDSCOPE_HOME
    export CLOUDSCOPE_CONFIG
    export CLOUDSCOPE_DATA
    export CLOUDSCOPE_LOGS
    
    # Add scripts to PATH
    export PATH="$CLOUDSCOPE_HOME/scripts:$PATH"
    
    # Activate Python virtual environment
    if [[ -f "$CLOUDSCOPE_HOME/venv/bin/activate" ]]; then
        source "$CLOUDSCOPE_HOME/venv/bin/activate"
    fi
    
    # Create aliases
    alias cs="cd $CLOUDSCOPE_HOME"
    alias csutil="$CLOUDSCOPE_HOME/scripts/utils/cloudscope-util.sh"
    alias csstatus="csutil status"
    alias csstart="csutil start"
    alias csstop="csutil stop"
    alias cslogs="csutil logs"
    alias csdb="csutil db"
    
    log_success "Environment configured"
    echo ""
    echo "Aliases created:"
    echo "  cs       - Change to CloudScope directory"
    echo "  csutil   - CloudScope utility"
    echo "  csstatus - Quick status check"
    echo "  csstart  - Start all services"
    echo "  csstop   - Stop all services"
    echo "  cslogs   - View logs"
    echo "  csdb     - Database shell"
    echo ""
    echo "Add this to your shell profile to make permanent:"
    echo "  source $CLOUDSCOPE_HOME/scripts/utils/cloudscope-util.sh setup-env"
}

# Main command handling
case ${1:-} in
    status)
        quick_status
        ;;
    start)
        start_all
        ;;
    stop)
        stop_all
        ;;
    restart)
        restart_all
        ;;
    collect|collectors)
        shift
        run_collectors "$@"
        ;;
    logs)
        shift
        view_logs "$@"
        ;;
    tail)
        shift
        tail_logs "$@"
        ;;
    db|database)
        case ${2:-shell} in
            shell) db_shell ;;
            query) db_query "${3:-}" ;;
            backup) db_backup ;;
            *) log_error "Unknown database command: ${2:-}" ;;
        esac
        ;;
    search)
        search_assets "${2:-}"
        ;;
    risk)
        find_high_risk "${2:-80}"
        ;;
    report)
        generate_report "${2:-inventory}"
        ;;
    config)
        case ${2:-show} in
            edit) edit_config ;;
            show) show_config ;;
            *) log_error "Unknown config command: ${2:-}" ;;
        esac
        ;;
    test)
        shift
        run_tests "$@"
        ;;
    lint)
        lint_code
        ;;
    backup)
        db_backup
        ;;
    menu)
        quick_menu
        ;;
    setup-env)
        setup_env
        ;;
    help|--help|-h)
        show_banner
        cat << EOF
Usage: $0 [COMMAND] [OPTIONS]

Service Management:
    status              Quick status check
    start               Start all services
    stop                Stop all services
    restart             Restart all services

Data Operations:
    collect             Run asset collectors
    search QUERY        Search for assets
    risk [THRESHOLD]    Find high-risk assets (default: 80)

Database:
    db shell            Open database shell
    db query "SQL"      Execute query
    db backup           Backup database

Logs & Monitoring:
    logs [SERVICE]      View service logs
    tail [PATTERN]      Tail log files

Reports:
    report [TYPE]       Generate report (inventory|risk|security|executive)

Configuration:
    config show         Display configuration
    config edit         Edit configuration

Development:
    test                Run tests
    lint                Run code linters

Other:
    backup              Create full backup
    menu                Interactive menu
    setup-env           Setup environment and aliases
    help                Show this help

Examples:
    # Quick status check
    $0 status

    # Search for assets
    $0 search "web-server"

    # Find critical risk assets
    $0 risk 90

    # View API logs
    $0 logs api

    # Generate risk report
    $0 report risk
EOF
        ;;
    *)
        if [[ -n "${1:-}" ]]; then
            log_error "Unknown command: $1"
            echo "Use '$0 help' for usage information"
            exit 1
        else
            show_banner
            quick_menu
        fi
        ;;
esac
