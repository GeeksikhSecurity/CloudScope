#!/bin/bash
# CloudScope Troubleshooting and Diagnostics Tool
# Diagnose and fix common issues with CloudScope installation

set -euo pipefail

# Configuration
LOG_DIR="${LOG_DIR:-./data/logs}"
DIAG_DIR="${DIAG_DIR:-./data/diagnostics}"
CONFIG_FILE="${CONFIG_FILE:-./config/cloudscope-config.json}"
SUPPORT_BUNDLE="${SUPPORT_BUNDLE:-cloudscope-support-bundle}"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Diagnostic status
ISSUES_FOUND=0
WARNINGS_FOUND=0

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[⚠]${NC} $1"; WARNINGS_FOUND=$((WARNINGS_FOUND + 1)); }
log_error() { echo -e "${RED}[✗]${NC} $1"; ISSUES_FOUND=$((ISSUES_FOUND + 1)); }
log_check() { echo -e "${CYAN}[CHECK]${NC} $1"; }
log_fix() { echo -e "${PURPLE}[FIX]${NC} $1"; }

# Create diagnostics directory
mkdir -p "$DIAG_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# System information
get_system_info() {
    log_check "Gathering system information..."
    
    cat > "$DIAG_DIR/system_info_${TIMESTAMP}.txt" << EOF
CloudScope System Information
=============================
Date: $(date)
Hostname: $(hostname)
OS: $(uname -a)
Python: $(python3 --version 2>&1)
Docker: $(docker --version 2>&1 || echo "Not installed")
Docker Compose: $(docker-compose --version 2>&1 || echo "Not installed")
PowerShell: $(pwsh --version 2>&1 | head -1 || echo "Not installed")

Environment Variables:
$(env | grep -E "CLOUDSCOPE|MEMGRAPH|POSTGRES|ELASTIC" | sort || echo "None set")

Disk Usage:
$(df -h .)

Memory Usage:
$(free -h 2>/dev/null || vm_stat 2>/dev/null || echo "Unable to determine")

CPU Info:
$(grep -E "^processor|^model name" /proc/cpuinfo 2>/dev/null | head -10 || sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "Unable to determine")
EOF
    
    log_success "System information collected"
}

# Check prerequisites
check_prerequisites() {
    log_check "Checking prerequisites..."
    
    local all_good=true
    
    # Check Python
    if command -v python3 &> /dev/null; then
        local py_version=$(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:2])))')
        if [[ $(echo "$py_version >= 3.8" | bc) -eq 1 ]]; then
            log_success "Python $py_version"
        else
            log_error "Python version too old: $py_version (need >= 3.8)"
            all_good=false
        fi
    else
        log_error "Python 3 not found"
        all_good=false
    fi
    
    # Check Docker
    if command -v docker &> /dev/null; then
        if docker ps &> /dev/null; then
            log_success "Docker is running"
        else
            log_error "Docker is installed but not running or not accessible"
            log_fix "Try: sudo systemctl start docker (Linux) or start Docker Desktop (macOS/Windows)"
            all_good=false
        fi
    else
        log_error "Docker not found"
        all_good=false
    fi
    
    # Check Docker Compose
    if command -v docker-compose &> /dev/null; then
        log_success "Docker Compose installed"
    else
        log_error "Docker Compose not found"
        all_good=false
    fi
    
    # Check PowerShell (optional)
    if command -v pwsh &> /dev/null; then
        log_success "PowerShell Core installed"
    else
        log_warning "PowerShell Core not found (required for Microsoft collectors)"
    fi
    
    # Check network connectivity
    if ping -c 1 google.com &> /dev/null; then
        log_success "Internet connectivity OK"
    else
        log_warning "No internet connectivity detected"
    fi
    
    return $([ "$all_good" = true ])
}

# Check Python environment
check_python_env() {
    log_check "Checking Python environment..."
    
    # Check virtual environment
    if [[ -n "${VIRTUAL_ENV:-}" ]]; then
        log_success "Virtual environment active: $VIRTUAL_ENV"
    else
        if [[ -d "venv" ]]; then
            log_warning "Virtual environment exists but not activated"
            log_fix "Run: source venv/bin/activate"
        else
            log_error "No virtual environment found"
            log_fix "Run: python3 -m venv venv && source venv/bin/activate"
        fi
    fi
    
    # Check required packages
    if [[ -f "requirements.txt" ]]; then
        log_info "Checking Python packages..."
        
        # Get installed packages
        pip list --format=freeze > "$DIAG_DIR/installed_packages_${TIMESTAMP}.txt"
        
        # Check for missing packages
        local missing_packages=()
        while IFS= read -r requirement; do
            # Skip empty lines and comments
            [[ -z "$requirement" || "$requirement" =~ ^# ]] && continue
            
            # Extract package name
            local package_name=$(echo "$requirement" | sed -E 's/[<>=!].*//')
            
            if ! pip show "$package_name" &> /dev/null; then
                missing_packages+=("$package_name")
            fi
        done < requirements.txt
        
        if [[ ${#missing_packages[@]} -eq 0 ]]; then
            log_success "All required Python packages installed"
        else
            log_error "Missing Python packages: ${missing_packages[*]}"
            log_fix "Run: pip install -r requirements.txt"
        fi
    fi
}

# Check configuration
check_configuration() {
    log_check "Checking configuration..."
    
    # Check if config file exists
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Configuration file not found: $CONFIG_FILE"
        log_fix "Run: cp config/cloudscope-config.example.json $CONFIG_FILE"
        return 1
    fi
    
    # Validate JSON syntax
    if python3 -m json.tool "$CONFIG_FILE" > /dev/null 2>&1; then
        log_success "Configuration file syntax is valid"
    else
        log_error "Configuration file has invalid JSON syntax"
        log_fix "Check $CONFIG_FILE for syntax errors"
        python3 -m json.tool "$CONFIG_FILE" 2>&1 | head -10
        return 1
    fi
    
    # Check required fields
    python3 << EOF
import json
import sys

try:
    with open('$CONFIG_FILE', 'r') as f:
        config = json.load(f)
    
    # Check required fields
    issues = []
    
    if 'database' not in config:
        issues.append("Missing 'database' section")
    elif 'memgraph' not in config['database']:
        issues.append("Missing Memgraph configuration")
    
    if 'api' not in config:
        issues.append("Missing 'api' section")
    
    if issues:
        print("Configuration issues found:")
        for issue in issues:
            print(f"  - {issue}")
        sys.exit(1)
    else:
        print("Configuration structure looks good")
        
except Exception as e:
    print(f"Error reading configuration: {e}")
    sys.exit(1)
EOF
    
    if [[ $? -eq 0 ]]; then
        log_success "Configuration validation passed"
    else
        log_error "Configuration validation failed"
    fi
}

# Check Docker services
check_docker_services() {
    log_check "Checking Docker services..."
    
    # List all containers
    docker-compose ps > "$DIAG_DIR/docker_services_${TIMESTAMP}.txt" 2>&1
    
    # Check specific services
    local services=("memgraph" "postgres" "elasticsearch")
    local all_running=true
    
    for service in "${services[@]}"; do
        local container_name="cloudscope-$service"
        
        if docker ps --format "{{.Names}}" | grep -q "^${container_name}"; then
            # Get container status
            local status=$(docker inspect -f '{{.State.Status}}' "$container_name" 2>/dev/null)
            
            if [[ "$status" == "running" ]]; then
                # Check health if available
                local health=$(docker inspect -f '{{.State.Health.Status}}' "$container_name" 2>/dev/null || echo "none")
                
                if [[ "$health" == "healthy" || "$health" == "none" ]]; then
                    log_success "$service is running"
                else
                    log_warning "$service is running but unhealthy: $health"
                    all_running=false
                fi
            else
                log_error "$service container exists but not running: $status"
                all_running=false
            fi
        else
            log_error "$service container not found"
            all_running=false
        fi
    done
    
    if [[ "$all_running" == "false" ]]; then
        log_fix "Run: docker-compose up -d"
    fi
}

# Check database connectivity
check_database_connectivity() {
    log_check "Checking database connectivity..."
    
    # Check Memgraph
    if docker exec cloudscope-memgraph echo "RETURN 1;" | mgconsole &> /dev/null; then
        log_success "Memgraph connection OK"
        
        # Get node count
        local node_count=$(docker exec cloudscope-memgraph mgconsole --execute "MATCH (n) RETURN count(n) AS count;" 2>/dev/null | grep -oE '[0-9]+' | tail -1 || echo "0")
        log_info "Memgraph nodes: $node_count"
    else
        log_error "Cannot connect to Memgraph"
        log_fix "Check if Memgraph container is running and healthy"
    fi
    
    # Check PostgreSQL
    if docker exec cloudscope-postgres pg_isready &> /dev/null; then
        log_success "PostgreSQL connection OK"
    else
        log_warning "Cannot connect to PostgreSQL"
    fi
    
    # Check Elasticsearch
    if curl -s http://localhost:9200/_cluster/health &> /dev/null; then
        log_success "Elasticsearch connection OK"
    else
        log_warning "Cannot connect to Elasticsearch"
    fi
}

# Check API health
check_api_health() {
    log_check "Checking API health..."
    
    # Check if API is running
    if curl -s -f http://localhost:8000/health &> /dev/null; then
        log_success "API is responding"
        
        # Get API info
        local api_info=$(curl -s http://localhost:8000/api/v1/info 2>/dev/null || echo "{}")
        echo "$api_info" > "$DIAG_DIR/api_info_${TIMESTAMP}.json"
        
        # Check response time
        local response_time=$(curl -s -w "%{time_total}" -o /dev/null http://localhost:8000/health)
        if (( $(echo "$response_time < 2" | bc -l) )); then
            log_success "API response time: ${response_time}s"
        else
            log_warning "API response time slow: ${response_time}s"
        fi
    else
        log_error "API is not responding"
        log_fix "Run: ./scripts/api/manage-api.sh start"
    fi
}

# Check logs for errors
check_logs() {
    log_check "Checking logs for errors..."
    
    local error_count=0
    local warning_count=0
    
    # Check various log files
    for log_file in "$LOG_DIR"/*.log; do
        [[ -f "$log_file" ]] || continue
        
        local file_errors=$(grep -i "error\|exception\|failed" "$log_file" 2>/dev/null | wc -l)
        local file_warnings=$(grep -i "warning\|warn" "$log_file" 2>/dev/null | wc -l)
        
        error_count=$((error_count + file_errors))
        warning_count=$((warning_count + file_warnings))
        
        if [[ $file_errors -gt 0 ]]; then
            log_warning "Found $file_errors errors in $(basename "$log_file")"
            # Save recent errors
            grep -i "error\|exception\|failed" "$log_file" | tail -20 > "$DIAG_DIR/errors_$(basename "$log_file")_${TIMESTAMP}"
        fi
    done
    
    if [[ $error_count -eq 0 ]]; then
        log_success "No errors found in logs"
    else
        log_warning "Total errors found in logs: $error_count"
        log_info "Error samples saved to $DIAG_DIR"
    fi
}

# Check disk space
check_disk_space() {
    log_check "Checking disk space..."
    
    local usage=$(df -h . | awk 'NR==2 {print $5}' | sed 's/%//')
    
    if [[ $usage -lt 80 ]]; then
        log_success "Disk usage: ${usage}%"
    elif [[ $usage -lt 90 ]]; then
        log_warning "Disk usage high: ${usage}%"
    else
        log_error "Disk usage critical: ${usage}%"
        log_fix "Free up disk space or expand storage"
    fi
    
    # Check specific directories
    du -sh data logs 2>/dev/null | while read -r size dir; do
        log_info "$dir size: $size"
    done
}

# Check permissions
check_permissions() {
    log_check "Checking file permissions..."
    
    local issues=0
    
    # Check script permissions
    find scripts -name "*.sh" -type f | while read -r script; do
        if [[ ! -x "$script" ]]; then
            log_warning "Script not executable: $script"
            issues=$((issues + 1))
        fi
    done
    
    # Check directory permissions
    for dir in data logs config; do
        if [[ -d "$dir" ]]; then
            if [[ -w "$dir" ]]; then
                log_success "$dir is writable"
            else
                log_error "$dir is not writable"
                issues=$((issues + 1))
            fi
        fi
    done
    
    if [[ $issues -gt 0 ]]; then
        log_fix "Run: chmod +x scripts/**/*.sh && chmod -R u+w data logs config"
    fi
}

# Run diagnostics
run_diagnostics() {
    log_info "Running CloudScope diagnostics..."
    echo "===================================="
    
    get_system_info
    check_prerequisites
    check_python_env
    check_configuration
    check_docker_services
    check_database_connectivity
    check_api_health
    check_logs
    check_disk_space
    check_permissions
    
    echo ""
    echo "===================================="
    echo "Diagnostics Summary"
    echo "===================================="
    
    if [[ $ISSUES_FOUND -eq 0 ]]; then
        log_success "No critical issues found!"
    else
        log_error "Found $ISSUES_FOUND critical issues"
    fi
    
    if [[ $WARNINGS_FOUND -gt 0 ]]; then
        log_warning "Found $WARNINGS_FOUND warnings"
    fi
    
    log_info "Diagnostic details saved to: $DIAG_DIR"
}

# Interactive troubleshooting
interactive_troubleshoot() {
    while true; do
        echo ""
        echo "CloudScope Troubleshooting Menu"
        echo "=============================="
        echo "1) Run full diagnostics"
        echo "2) Check specific component"
        echo "3) View recent errors"
        echo "4) Generate support bundle"
        echo "5) Common fixes"
        echo "6) Exit"
        echo ""
        read -p "Select option (1-6): " choice
        
        case $choice in
            1)
                run_diagnostics
                ;;
            2)
                echo "Select component:"
                echo "a) Python environment"
                echo "b) Docker services"
                echo "c) Database connections"
                echo "d) API"
                echo "e) Configuration"
                read -p "Component (a-e): " component
                
                case $component in
                    a) check_python_env ;;
                    b) check_docker_services ;;
                    c) check_database_connectivity ;;
                    d) check_api_health ;;
                    e) check_configuration ;;
                    *) log_error "Invalid selection" ;;
                esac
                ;;
            3)
                view_recent_errors
                ;;
            4)
                generate_support_bundle
                ;;
            5)
                show_common_fixes
                ;;
            6)
                exit 0
                ;;
            *)
                log_error "Invalid selection"
                ;;
        esac
    done
}

# View recent errors
view_recent_errors() {
    log_info "Recent errors from logs:"
    echo "======================="
    
    for log_file in "$LOG_DIR"/*.log; do
        [[ -f "$log_file" ]] || continue
        
        if grep -q -i "error\|exception\|failed" "$log_file" 2>/dev/null; then
            echo ""
            echo "From $(basename "$log_file"):"
            grep -i "error\|exception\|failed" "$log_file" | tail -5
        fi
    done
}

# Show common fixes
show_common_fixes() {
    cat << 'EOF'
Common CloudScope Issues and Fixes
==================================

1. Docker services won't start
   - Check Docker daemon: sudo systemctl status docker
   - Check disk space: df -h
   - Check port conflicts: sudo lsof -i :7687,5432,9200,8000
   - Reset containers: docker-compose down -v && docker-compose up -d

2. Cannot connect to Memgraph
   - Check container: docker ps | grep memgraph
   - Check logs: docker logs cloudscope-memgraph
   - Test connection: docker exec cloudscope-memgraph mgconsole --execute "RETURN 1;"
   - Recreate: docker-compose up -d memgraph

3. API not responding
   - Check process: ps aux | grep gunicorn
   - Check logs: tail -f data/logs/api-*.log
   - Restart: ./scripts/api/manage-api.sh restart
   - Check port: lsof -i :8000

4. Python package issues
   - Activate venv: source venv/bin/activate
   - Upgrade pip: pip install --upgrade pip
   - Reinstall packages: pip install -r requirements.txt --force-reinstall
   - Clear cache: pip cache purge

5. Permission denied errors
   - Fix script permissions: chmod +x scripts/**/*.sh
   - Fix directory permissions: chmod -R u+w data logs config
   - Check ownership: ls -la

6. High memory/CPU usage
   - Check processes: top or htop
   - Limit Docker resources: Edit docker-compose.yml
   - Clear caches: docker system prune -a
   - Restart services: docker-compose restart

7. Collectors failing
   - Check credentials: ./scripts/config/config-manager.sh show
   - Test connectivity: ping/curl to target services
   - Check logs: tail -f data/logs/*_collector_*.log
   - Run manually: ./scripts/collectors/run-all-collectors.sh -d

Press Enter to continue...
EOF
    read -r
}

# Generate support bundle
generate_support_bundle() {
    log_info "Generating support bundle..."
    
    local bundle_dir="${SUPPORT_BUNDLE}_${TIMESTAMP}"
    mkdir -p "$bundle_dir"
    
    # Collect system info
    get_system_info
    cp "$DIAG_DIR/system_info_${TIMESTAMP}.txt" "$bundle_dir/"
    
    # Collect configuration (sanitized)
    if [[ -f "$CONFIG_FILE" ]]; then
        python3 -c "
import json
with open('$CONFIG_FILE', 'r') as f:
    config = json.load(f)
# Remove sensitive data
for key in ['password', 'secret', 'key', 'token']:
    for section in config.values():
        if isinstance(section, dict):
            for k in list(section.keys()):
                if key in k.lower():
                    section[k] = '***REDACTED***'
with open('$bundle_dir/config_sanitized.json', 'w') as f:
    json.dump(config, f, indent=2)
"
    fi
    
    # Collect recent logs (last 1000 lines)
    mkdir -p "$bundle_dir/logs"
    for log_file in "$LOG_DIR"/*.log; do
        [[ -f "$log_file" ]] || continue
        tail -1000 "$log_file" > "$bundle_dir/logs/$(basename "$log_file")"
    done
    
    # Collect Docker info
    docker-compose ps > "$bundle_dir/docker-compose-ps.txt" 2>&1
    docker ps -a > "$bundle_dir/docker-ps.txt" 2>&1
    
    for service in memgraph postgres elasticsearch; do
        docker logs --tail 100 "cloudscope-$service" > "$bundle_dir/docker-${service}.log" 2>&1 || true
    done
    
    # Collect Python info
    pip list > "$bundle_dir/pip-list.txt" 2>&1
    pip check > "$bundle_dir/pip-check.txt" 2>&1 || true
    
    # Create archive
    tar -czf "${bundle_dir}.tar.gz" "$bundle_dir"
    rm -rf "$bundle_dir"
    
    log_success "Support bundle created: ${bundle_dir}.tar.gz"
    log_info "Share this file when requesting support"
}

# Auto-fix common issues
auto_fix() {
    log_info "Attempting to auto-fix common issues..."
    
    # Fix script permissions
    log_fix "Fixing script permissions..."
    find scripts -name "*.sh" -type f -exec chmod +x {} \;
    
    # Create missing directories
    log_fix "Creating missing directories..."
    mkdir -p data/{assets,exports,logs,analysis,reports} config logs
    
    # Fix Python environment
    if [[ ! -d "venv" ]]; then
        log_fix "Creating Python virtual environment..."
        python3 -m venv venv
    fi
    
    # Activate venv and install packages
    if [[ -z "${VIRTUAL_ENV:-}" ]]; then
        source venv/bin/activate
    fi
    
    log_fix "Installing Python packages..."
    pip install --upgrade pip
    pip install -r requirements.txt
    
    # Start Docker services
    log_fix "Starting Docker services..."
    docker-compose up -d
    
    # Wait for services
    log_info "Waiting for services to start..."
    sleep 10
    
    # Initialize database if needed
    if docker exec cloudscope-memgraph echo "MATCH (n) RETURN count(n);" | mgconsole 2>&1 | grep -q "0"; then
        log_fix "Initializing database..."
        if [[ -f "scripts/database/init-memgraph.sh" ]]; then
            bash scripts/database/init-memgraph.sh
        fi
    fi
    
    log_success "Auto-fix completed"
}

# Print usage
usage() {
    cat << EOF
Usage: $0 [COMMAND] [OPTIONS]

Commands:
    diagnose          Run full diagnostics
    check COMPONENT   Check specific component
    errors            View recent errors from logs
    fixes             Show common fixes
    bundle            Generate support bundle
    auto-fix          Attempt to auto-fix common issues
    interactive       Interactive troubleshooting mode
    
Components for check:
    prereq            Prerequisites
    python            Python environment
    config            Configuration
    docker            Docker services
    database          Database connections
    api               API health
    logs              Check logs for errors
    disk              Disk space
    permissions       File permissions

Options:
    -h, --help       Show this help message

Examples:
    # Run full diagnostics
    $0 diagnose

    # Check specific component
    $0 check docker

    # Generate support bundle
    $0 bundle

    # Auto-fix common issues
    $0 auto-fix

    # Interactive mode
    $0 interactive
EOF
}

# Parse command line arguments
case ${1:-} in
    diagnose)
        run_diagnostics
        ;;
    check)
        case ${2:-} in
            prereq) check_prerequisites ;;
            python) check_python_env ;;
            config) check_configuration ;;
            docker) check_docker_services ;;
            database) check_database_connectivity ;;
            api) check_api_health ;;
            logs) check_logs ;;
            disk) check_disk_space ;;
            permissions) check_permissions ;;
            *)
                log_error "Unknown component: ${2:-}"
                echo "Valid components: prereq, python, config, docker, database, api, logs, disk, permissions"
                exit 1
                ;;
        esac
        ;;
    errors)
        view_recent_errors
        ;;
    fixes)
        show_common_fixes
        ;;
    bundle)
        generate_support_bundle
        ;;
    auto-fix)
        auto_fix
        ;;
    interactive)
        interactive_troubleshoot
        ;;
    -h|--help)
        usage
        ;;
    *)
        if [[ -n "${1:-}" ]]; then
            log_error "Unknown command: $1"
        else
            # Default to interactive mode
            interactive_troubleshoot
        fi
        ;;
esac
