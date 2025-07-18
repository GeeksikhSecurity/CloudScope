#!/bin/bash
# CloudScope Health Monitoring Script
# Monitor CloudScope services and system health

set -euo pipefail

# Configuration
CHECK_INTERVAL="${CHECK_INTERVAL:-60}"  # seconds
ALERT_EMAIL="${ALERT_EMAIL:-}"
ALERT_WEBHOOK="${ALERT_WEBHOOK:-}"
LOG_FILE="${LOG_FILE:-./data/logs/health-monitor.log}"
STATE_FILE="${STATE_FILE:-./data/monitoring-state.json}"
MEMGRAPH_HOST="${MEMGRAPH_HOST:-localhost}"
MEMGRAPH_PORT="${MEMGRAPH_PORT:-7687}"
API_HOST="${API_HOST:-localhost}"
API_PORT="${API_PORT:-8000}"

# Thresholds
CPU_THRESHOLD="${CPU_THRESHOLD:-80}"
MEMORY_THRESHOLD="${MEMORY_THRESHOLD:-85}"
DISK_THRESHOLD="${DISK_THRESHOLD:-90}"
RESPONSE_TIME_THRESHOLD="${RESPONSE_TIME_THRESHOLD:-2}"  # seconds

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log_info() { 
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log_success() { 
    echo -e "${GREEN}[OK]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log_warning() { 
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log_error() { 
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Create directories
mkdir -p "$(dirname "$LOG_FILE")"
mkdir -p "$(dirname "$STATE_FILE")"

# Initialize state file
init_state() {
    if [[ ! -f "$STATE_FILE" ]]; then
        echo '{"checks": {}, "alerts": {}}' > "$STATE_FILE"
    fi
}

# Update state
update_state() {
    local check=$1
    local status=$2
    local message=$3
    
    python3 -c "
import json
import datetime

with open('$STATE_FILE', 'r') as f:
    state = json.load(f)

state['checks']['$check'] = {
    'status': '$status',
    'message': '$message',
    'timestamp': datetime.datetime.now().isoformat()
}

with open('$STATE_FILE', 'w') as f:
    json.dump(state, f, indent=2)
"
}

# Send alert
send_alert() {
    local severity=$1
    local component=$2
    local message=$3
    
    log_error "ALERT [$severity] $component: $message"
    
    # Send email alert
    if [[ -n "$ALERT_EMAIL" ]] && command -v mail &> /dev/null; then
        echo -e "CloudScope Health Alert\n\nSeverity: $severity\nComponent: $component\nMessage: $message\nTime: $(date)" | \
            mail -s "CloudScope Alert: $severity - $component" "$ALERT_EMAIL"
    fi
    
    # Send webhook alert
    if [[ -n "$ALERT_WEBHOOK" ]]; then
        curl -s -X POST "$ALERT_WEBHOOK" \
            -H "Content-Type: application/json" \
            -d "{
                \"severity\": \"$severity\",
                \"component\": \"$component\",
                \"message\": \"$message\",
                \"timestamp\": \"$(date -Iseconds)\"
            }" > /dev/null 2>&1 || true
    fi
}

# Check system resources
check_system_resources() {
    log_info "Checking system resources..."
    
    # Check CPU usage
    CPU_USAGE=$(top -b -n1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 | cut -d'.' -f1)
    if [[ "$CPU_USAGE" -gt "$CPU_THRESHOLD" ]]; then
        send_alert "WARNING" "System" "High CPU usage: ${CPU_USAGE}%"
        update_state "cpu" "warning" "High CPU usage: ${CPU_USAGE}%"
    else
        log_success "CPU usage: ${CPU_USAGE}%"
        update_state "cpu" "ok" "CPU usage: ${CPU_USAGE}%"
    fi
    
    # Check memory usage
    MEMORY_USAGE=$(free | grep Mem | awk '{print int($3/$2 * 100)}')
    if [[ "$MEMORY_USAGE" -gt "$MEMORY_THRESHOLD" ]]; then
        send_alert "WARNING" "System" "High memory usage: ${MEMORY_USAGE}%"
        update_state "memory" "warning" "High memory usage: ${MEMORY_USAGE}%"
    else
        log_success "Memory usage: ${MEMORY_USAGE}%"
        update_state "memory" "ok" "Memory usage: ${MEMORY_USAGE}%"
    fi
    
    # Check disk usage
    DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [[ "$DISK_USAGE" -gt "$DISK_THRESHOLD" ]]; then
        send_alert "WARNING" "System" "High disk usage: ${DISK_USAGE}%"
        update_state "disk" "warning" "High disk usage: ${DISK_USAGE}%"
    else
        log_success "Disk usage: ${DISK_USAGE}%"
        update_state "disk" "ok" "Disk usage: ${DISK_USAGE}%"
    fi
}

# Check Docker containers
check_docker_containers() {
    log_info "Checking Docker containers..."
    
    local required_containers=("cloudscope-memgraph" "cloudscope-postgres" "cloudscope-elasticsearch")
    local all_healthy=true
    
    for container in "${required_containers[@]}"; do
        if docker ps --format "table {{.Names}}" | grep -q "^$container$"; then
            # Check container health
            HEALTH=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "none")
            
            if [[ "$HEALTH" == "healthy" ]] || [[ "$HEALTH" == "none" ]]; then
                log_success "Container $container is running"
                update_state "docker_$container" "ok" "Container is running"
            else
                send_alert "WARNING" "Docker" "Container $container is unhealthy: $HEALTH"
                update_state "docker_$container" "warning" "Container is unhealthy: $HEALTH"
                all_healthy=false
            fi
        else
            send_alert "ERROR" "Docker" "Container $container is not running"
            update_state "docker_$container" "error" "Container is not running"
            all_healthy=false
        fi
    done
    
    return $([ "$all_healthy" = true ])
}

# Check API health
check_api_health() {
    log_info "Checking API health..."
    
    # Measure response time
    START=$(date +%s.%N)
    
    if curl -s -f -m 5 "http://$API_HOST:$API_PORT/health" > /dev/null 2>&1; then
        END=$(date +%s.%N)
        RESPONSE_TIME=$(echo "$END - $START" | bc)
        
        if (( $(echo "$RESPONSE_TIME > $RESPONSE_TIME_THRESHOLD" | bc -l) )); then
            log_warning "API is slow: ${RESPONSE_TIME}s"
            update_state "api" "warning" "API is slow: ${RESPONSE_TIME}s"
        else
            log_success "API is healthy (response time: ${RESPONSE_TIME}s)"
            update_state "api" "ok" "API is healthy (response time: ${RESPONSE_TIME}s)"
        fi
    else
        send_alert "ERROR" "API" "API health check failed"
        update_state "api" "error" "API health check failed"
        return 1
    fi
}

# Check Memgraph
check_memgraph() {
    log_info "Checking Memgraph..."
    
    if docker exec cloudscope-memgraph echo "MATCH (n) RETURN count(n) AS count;" | mgconsole > /dev/null 2>&1; then
        # Get node count
        NODE_COUNT=$(docker exec cloudscope-memgraph mgconsole --execute "MATCH (n) RETURN count(n) AS count;" | grep -oE '[0-9]+' | tail -1)
        log_success "Memgraph is healthy (nodes: $NODE_COUNT)"
        update_state "memgraph" "ok" "Memgraph is healthy (nodes: $NODE_COUNT)"
    else
        send_alert "ERROR" "Memgraph" "Memgraph connection failed"
        update_state "memgraph" "error" "Memgraph connection failed"
        return 1
    fi
}

# Check collectors
check_collectors() {
    log_info "Checking collectors..."
    
    # Check last collection time
    if [[ -d "./data/logs" ]]; then
        # Find most recent collector log
        LATEST_LOG=$(find ./data/logs -name "*_collector_*.log" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)
        
        if [[ -n "$LATEST_LOG" ]]; then
            # Check if collection ran in last 2 hours
            if [[ $(find "$LATEST_LOG" -mmin -120 | wc -l) -gt 0 ]]; then
                log_success "Collectors ran recently"
                update_state "collectors" "ok" "Collectors ran recently"
            else
                log_warning "Collectors haven't run in 2 hours"
                update_state "collectors" "warning" "Collectors haven't run in 2 hours"
            fi
        else
            log_warning "No collector logs found"
            update_state "collectors" "warning" "No collector logs found"
        fi
    fi
}

# Check data freshness
check_data_freshness() {
    log_info "Checking data freshness..."
    
    # Query for assets updated in last 24 hours
    FRESH_ASSETS=$(docker exec cloudscope-memgraph mgconsole --execute "
        MATCH (a:Asset)
        WHERE datetime(a.updated_at) > datetime() - duration('P1D')
        RETURN count(a) AS count;
    " 2>/dev/null | grep -oE '[0-9]+' | tail -1 || echo "0")
    
    if [[ "$FRESH_ASSETS" -gt 0 ]]; then
        log_success "Data is fresh ($FRESH_ASSETS assets updated in last 24h)"
        update_state "data_freshness" "ok" "Data is fresh ($FRESH_ASSETS assets updated in last 24h)"
    else
        log_warning "No fresh data (0 assets updated in last 24h)"
        update_state "data_freshness" "warning" "No fresh data"
    fi
}

# Check for security findings
check_security_findings() {
    log_info "Checking security findings..."
    
    # Query for critical findings
    CRITICAL_FINDINGS=$(docker exec cloudscope-memgraph mgconsole --execute "
        MATCH (f:Finding)
        WHERE f.severity = 'CRITICAL' AND f.status = 'OPEN'
        RETURN count(f) AS count;
    " 2>/dev/null | grep -oE '[0-9]+' | tail -1 || echo "0")
    
    if [[ "$CRITICAL_FINDINGS" -gt 0 ]]; then
        send_alert "WARNING" "Security" "$CRITICAL_FINDINGS critical findings detected"
        update_state "security_findings" "warning" "$CRITICAL_FINDINGS critical findings"
    else
        log_success "No critical findings"
        update_state "security_findings" "ok" "No critical findings"
    fi
}

# Generate health report
generate_health_report() {
    log_info "Generating health report..."
    
    python3 -c "
import json
import datetime

with open('$STATE_FILE', 'r') as f:
    state = json.load(f)

# Calculate overall health
statuses = [check['status'] for check in state['checks'].values()]
if 'error' in statuses:
    overall_status = 'ERROR'
elif 'warning' in statuses:
    overall_status = 'WARNING'
else:
    overall_status = 'HEALTHY'

# Generate report
report = {
    'timestamp': datetime.datetime.now().isoformat(),
    'overall_status': overall_status,
    'checks': state['checks'],
    'summary': {
        'total_checks': len(state['checks']),
        'errors': len([s for s in statuses if s == 'error']),
        'warnings': len([s for s in statuses if s == 'warning']),
        'ok': len([s for s in statuses if s == 'ok'])
    }
}

# Save report
with open('./data/logs/health-report-latest.json', 'w') as f:
    json.dump(report, f, indent=2)

# Print summary
print(f\"Overall Status: {overall_status}\")
print(f\"Checks: {report['summary']['ok']} OK, {report['summary']['warnings']} Warnings, {report['summary']['errors']} Errors\")
"
}

# Run continuous monitoring
run_monitoring() {
    log_info "Starting continuous health monitoring (interval: ${CHECK_INTERVAL}s)"
    
    while true; do
        echo -e "\n${BLUE}=== Health Check $(date '+%Y-%m-%d %H:%M:%S') ===${NC}"
        
        # Run all checks
        check_system_resources
        check_docker_containers || true
        check_api_health || true
        check_memgraph || true
        check_collectors || true
        check_data_freshness || true
        check_security_findings || true
        
        # Generate report
        generate_health_report
        
        echo -e "${BLUE}=== Next check in ${CHECK_INTERVAL}s ===${NC}\n"
        sleep "$CHECK_INTERVAL"
    done
}

# Run single health check
run_single_check() {
    log_info "Running single health check..."
    
    check_system_resources
    check_docker_containers
    check_api_health
    check_memgraph
    check_collectors
    check_data_freshness
    check_security_findings
    
    generate_health_report
}

# Show status dashboard
show_dashboard() {
    clear
    
    echo -e "${BLUE}CloudScope Health Dashboard${NC}"
    echo "=========================="
    echo "Last Update: $(date)"
    echo ""
    
    if [[ -f "$STATE_FILE" ]]; then
        python3 -c "
import json
import datetime

with open('$STATE_FILE', 'r') as f:
    state = json.load(f)

# Define status symbols
symbols = {
    'ok': '✅',
    'warning': '⚠️ ',
    'error': '❌'
}

# Print checks
for check, data in sorted(state['checks'].items()):
    status = data['status']
    message = data['message']
    timestamp = data.get('timestamp', 'Unknown')
    
    # Format timestamp
    try:
        dt = datetime.datetime.fromisoformat(timestamp)
        time_ago = datetime.datetime.now() - dt
        if time_ago.seconds < 60:
            time_str = f'{time_ago.seconds}s ago'
        elif time_ago.seconds < 3600:
            time_str = f'{time_ago.seconds // 60}m ago'
        else:
            time_str = f'{time_ago.seconds // 3600}h ago'
    except:
        time_str = 'Unknown'
    
    symbol = symbols.get(status, '?')
    check_name = check.replace('_', ' ').title()
    
    print(f'{symbol} {check_name:<25} {message:<50} ({time_str})')
"
    else
        echo "No health data available. Run a health check first."
    fi
}

# Print usage
usage() {
    cat << EOF
Usage: $0 [COMMAND] [OPTIONS]

Commands:
    monitor             Run continuous monitoring
    check               Run single health check
    dashboard           Show health dashboard
    report              Generate and show health report
    
Options:
    -i, --interval SEC  Check interval in seconds (default: 60)
    -e, --email EMAIL   Alert email address
    -w, --webhook URL   Alert webhook URL
    -h, --help          Show this help message

Environment Variables:
    CHECK_INTERVAL              Check interval in seconds (default: 60)
    ALERT_EMAIL                Email for alerts
    ALERT_WEBHOOK              Webhook URL for alerts
    CPU_THRESHOLD              CPU usage threshold % (default: 80)
    MEMORY_THRESHOLD           Memory usage threshold % (default: 85)
    DISK_THRESHOLD             Disk usage threshold % (default: 90)
    RESPONSE_TIME_THRESHOLD    API response time threshold in seconds (default: 2)

Examples:
    # Run continuous monitoring
    $0 monitor

    # Run with email alerts
    $0 monitor -e admin@example.com

    # Run single check
    $0 check

    # Show dashboard
    $0 dashboard
EOF
}

# Parse command line arguments
COMMAND=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -i|--interval)
            CHECK_INTERVAL="$2"
            shift 2
            ;;
        -e|--email)
            ALERT_EMAIL="$2"
            shift 2
            ;;
        -w|--webhook)
            ALERT_WEBHOOK="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        monitor|check|dashboard|report)
            COMMAND="$1"
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Initialize state
init_state

# Execute command
case $COMMAND in
    monitor)
        run_monitoring
        ;;
    check)
        run_single_check
        ;;
    dashboard)
        show_dashboard
        ;;
    report)
        if [[ -f "./data/logs/health-report-latest.json" ]]; then
            cat "./data/logs/health-report-latest.json" | python -m json.tool
        else
            log_error "No health report found. Run a check first."
            exit 1
        fi
        ;;
    *)
        log_error "No command specified"
        usage
        exit 1
        ;;
esac
