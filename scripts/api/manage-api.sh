#!/bin/bash
# CloudScope API Management Script
# Start, stop, and manage CloudScope API services

set -euo pipefail

# Configuration
API_HOST="${API_HOST:-0.0.0.0}"
API_PORT="${API_PORT:-8000}"
WORKERS="${WORKERS:-4}"
LOG_DIR="${LOG_DIR:-./data/logs}"
PID_FILE="${PID_FILE:-./cloudscope-api.pid}"
CONFIG_FILE="${CONFIG_FILE:-./config/cloudscope-config.json}"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Create log directory
mkdir -p "$LOG_DIR"

# Check if virtual environment is active
check_venv() {
    if [[ -z "${VIRTUAL_ENV:-}" ]]; then
        log_warning "Virtual environment not active"
        if [[ -f "venv/bin/activate" ]]; then
            log_info "Activating virtual environment..."
            source venv/bin/activate
        else
            log_error "Virtual environment not found"
            exit 1
        fi
    fi
}

# Check if API is running
is_running() {
    if [[ -f "$PID_FILE" ]]; then
        PID=$(cat "$PID_FILE")
        if ps -p "$PID" > /dev/null 2>&1; then
            return 0
        else
            rm -f "$PID_FILE"
        fi
    fi
    return 1
}

# Start API in development mode
start_dev() {
    log_info "Starting CloudScope API in development mode..."
    
    check_venv
    
    if is_running; then
        log_warning "API is already running (PID: $(cat "$PID_FILE"))"
        return 1
    fi
    
    # Start with uvicorn for auto-reload
    uvicorn cloudscope.main:app \
        --host "$API_HOST" \
        --port "$API_PORT" \
        --reload \
        --log-level debug \
        --access-log \
        --log-config ./config/logging.yaml \
        > "$LOG_DIR/api-dev.log" 2>&1 &
    
    echo $! > "$PID_FILE"
    
    log_success "API started in development mode (PID: $(cat "$PID_FILE"))"
    log_info "API URL: http://$API_HOST:$API_PORT"
    log_info "API Docs: http://$API_HOST:$API_PORT/docs"
    log_info "Logs: $LOG_DIR/api-dev.log"
}

# Start API in production mode
start_prod() {
    log_info "Starting CloudScope API in production mode..."
    
    check_venv
    
    if is_running; then
        log_warning "API is already running (PID: $(cat "$PID_FILE"))"
        return 1
    fi
    
    # Start with gunicorn for production
    gunicorn cloudscope.main:app \
        --workers "$WORKERS" \
        --worker-class uvicorn.workers.UvicornWorker \
        --bind "$API_HOST:$API_PORT" \
        --daemon \
        --pid "$PID_FILE" \
        --access-logfile "$LOG_DIR/access.log" \
        --error-logfile "$LOG_DIR/error.log" \
        --log-level info \
        --timeout 120 \
        --graceful-timeout 30 \
        --max-requests 1000 \
        --max-requests-jitter 50
    
    # Wait for startup
    sleep 2
    
    if is_running; then
        log_success "API started in production mode (PID: $(cat "$PID_FILE"))"
        log_info "API URL: http://$API_HOST:$API_PORT"
    else
        log_error "Failed to start API"
        return 1
    fi
}

# Stop API
stop_api() {
    log_info "Stopping CloudScope API..."
    
    if ! is_running; then
        log_warning "API is not running"
        return 0
    fi
    
    PID=$(cat "$PID_FILE")
    
    # Try graceful shutdown first
    kill -TERM "$PID" 2>/dev/null || true
    
    # Wait for process to stop
    local count=0
    while ps -p "$PID" > /dev/null 2>&1 && [ $count -lt 30 ]; do
        sleep 1
        count=$((count + 1))
    done
    
    # Force kill if still running
    if ps -p "$PID" > /dev/null 2>&1; then
        log_warning "Forcing API shutdown..."
        kill -KILL "$PID" 2>/dev/null || true
    fi
    
    rm -f "$PID_FILE"
    log_success "API stopped"
}

# Restart API
restart_api() {
    stop_api
    sleep 2
    
    if [[ "${MODE:-prod}" == "dev" ]]; then
        start_dev
    else
        start_prod
    fi
}

# Show API status
show_status() {
    if is_running; then
        PID=$(cat "$PID_FILE")
        log_success "API is running (PID: $PID)"
        
        # Show process info
        ps -p "$PID" -o pid,ppid,user,%cpu,%mem,etime,cmd | tail -n +1
        
        # Check API health
        if curl -s -f "http://$API_HOST:$API_PORT/health" > /dev/null 2>&1; then
            log_success "API health check: OK"
            
            # Get API info
            API_INFO=$(curl -s "http://$API_HOST:$API_PORT/api/v1/info" 2>/dev/null || echo "{}")
            echo -e "\nAPI Information:"
            echo "$API_INFO" | python -m json.tool 2>/dev/null || echo "$API_INFO"
        else
            log_warning "API health check: FAILED"
        fi
    else
        log_error "API is not running"
        return 1
    fi
}

# Show API logs
show_logs() {
    local lines=${1:-50}
    local follow=${2:-false}
    
    log_info "Showing API logs..."
    
    if [[ "$follow" == "true" ]]; then
        # Follow logs
        if [[ -f "$LOG_DIR/error.log" ]]; then
            tail -f "$LOG_DIR/error.log" "$LOG_DIR/access.log"
        else
            tail -f "$LOG_DIR/api-dev.log"
        fi
    else
        # Show recent logs
        if [[ -f "$LOG_DIR/error.log" ]]; then
            echo -e "\n${BLUE}=== Error Logs ===${NC}"
            tail -n "$lines" "$LOG_DIR/error.log"
            echo -e "\n${BLUE}=== Access Logs ===${NC}"
            tail -n "$lines" "$LOG_DIR/access.log"
        else
            tail -n "$lines" "$LOG_DIR/api-dev.log"
        fi
    fi
}

# Run database migrations
run_migrations() {
    log_info "Running database migrations..."
    
    check_venv
    
    # Run Alembic migrations if available
    if [[ -f "alembic.ini" ]]; then
        alembic upgrade head
        log_success "Migrations completed"
    else
        log_warning "No migrations found"
    fi
}

# Generate API client
generate_client() {
    local language=${1:-python}
    local output_dir=${2:-./clients}
    
    log_info "Generating $language API client..."
    
    check_venv
    
    # Ensure API is running
    if ! is_running; then
        log_error "API must be running to generate client"
        return 1
    fi
    
    # Get OpenAPI schema
    curl -s "http://$API_HOST:$API_PORT/openapi.json" > /tmp/cloudscope-openapi.json
    
    # Generate client based on language
    case $language in
        python)
            pip install openapi-python-client
            openapi-python-client generate --path /tmp/cloudscope-openapi.json --output-path "$output_dir/python"
            ;;
        typescript)
            npx @openapitools/openapi-generator-cli generate \
                -i /tmp/cloudscope-openapi.json \
                -g typescript-fetch \
                -o "$output_dir/typescript"
            ;;
        go)
            npx @openapitools/openapi-generator-cli generate \
                -i /tmp/cloudscope-openapi.json \
                -g go \
                -o "$output_dir/go"
            ;;
        *)
            log_error "Unsupported language: $language"
            return 1
            ;;
    esac
    
    rm -f /tmp/cloudscope-openapi.json
    log_success "Client generated in: $output_dir/$language"
}

# Run API tests
test_api() {
    log_info "Running API tests..."
    
    check_venv
    
    # Ensure API is running
    if ! is_running; then
        log_warning "Starting API for testing..."
        start_dev
        sleep 5
    fi
    
    # Run API tests
    python -m pytest tests/api/ -v --tb=short
    
    log_success "API tests completed"
}

# Show API metrics
show_metrics() {
    log_info "API Metrics"
    log_info "==========="
    
    if ! is_running; then
        log_error "API is not running"
        return 1
    fi
    
    # Get metrics from API
    METRICS=$(curl -s "http://$API_HOST:$API_PORT/metrics" 2>/dev/null || echo "No metrics available")
    
    # Parse and display key metrics
    echo "$METRICS" | grep -E "^(http_requests_total|http_request_duration_seconds|active_connections)" || echo "No metrics data"
    
    # Show resource usage
    if [[ -f "$PID_FILE" ]]; then
        PID=$(cat "$PID_FILE")
        echo -e "\n${BLUE}Resource Usage:${NC}"
        ps -p "$PID" -o pid,%cpu,%mem,rss,vsz | tail -n +1
    fi
}

# Create systemd service file
create_service() {
    log_info "Creating systemd service file..."
    
    cat > cloudscope-api.service << EOF
[Unit]
Description=CloudScope API Service
After=network.target

[Service]
Type=forking
User=$USER
WorkingDirectory=$(pwd)
Environment="PATH=$(pwd)/venv/bin:/usr/local/bin:/usr/bin:/bin"
ExecStart=$(pwd)/scripts/api/manage-api.sh start
ExecStop=$(pwd)/scripts/api/manage-api.sh stop
ExecReload=$(pwd)/scripts/api/manage-api.sh restart
PIDFile=$(pwd)/cloudscope-api.pid
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    log_success "Service file created: cloudscope-api.service"
    log_info "To install: sudo cp cloudscope-api.service /etc/systemd/system/"
    log_info "Then: sudo systemctl daemon-reload && sudo systemctl enable cloudscope-api"
}

# Print usage
usage() {
    cat << EOF
Usage: $0 [COMMAND] [OPTIONS]

Commands:
    start               Start API in production mode
    start-dev           Start API in development mode (with auto-reload)
    stop                Stop API
    restart             Restart API
    status              Show API status
    logs [LINES]        Show recent logs (default: 50 lines)
    follow              Follow logs in real-time
    test                Run API tests
    metrics             Show API metrics
    migrate             Run database migrations
    client [LANG]       Generate API client (python|typescript|go)
    create-service      Create systemd service file

Options:
    -h, --help         Show this help message
    -p, --port PORT    API port (default: 8000)
    -w, --workers NUM  Number of workers (default: 4)

Environment Variables:
    API_HOST           API host (default: 0.0.0.0)
    API_PORT           API port (default: 8000)
    WORKERS            Number of workers (default: 4)
    LOG_DIR            Log directory (default: ./data/logs)
    CONFIG_FILE        Config file (default: ./config/cloudscope-config.json)

Examples:
    # Start API in production
    $0 start

    # Start API in development with auto-reload
    $0 start-dev

    # Check status
    $0 status

    # Follow logs
    $0 follow

    # Generate Python client
    $0 client python
EOF
}

# Parse command line arguments
case ${1:-} in
    start)
        MODE=prod start_prod
        ;;
    start-dev)
        MODE=dev start_dev
        ;;
    stop)
        stop_api
        ;;
    restart)
        MODE=${2:-prod}
        restart_api
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs "${2:-50}" false
        ;;
    follow)
        show_logs 50 true
        ;;
    test)
        test_api
        ;;
    metrics)
        show_metrics
        ;;
    migrate)
        run_migrations
        ;;
    client)
        generate_client "${2:-python}" "${3:-./clients}"
        ;;
    create-service)
        create_service
        ;;
    -h|--help)
        usage
        ;;
    *)
        if [[ -n "${1:-}" ]]; then
            log_error "Unknown command: $1"
        fi
        usage
        exit 1
        ;;
esac
