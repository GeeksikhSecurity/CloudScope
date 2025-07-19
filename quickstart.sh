#!/bin/bash
# CloudScope Quick Start Script
# One-command setup and launch for CloudScope

set -euo pipefail

# Script version
VERSION="1.0.0"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# ASCII Art Banner
show_banner() {
    echo -e "${CYAN}"
    cat << 'EOF'
   _____ _                 _ _____                      
  / ____| |               | / ____|                     
 | |    | | ___  _   _  __| | (___   ___ ___  _ __   ___ 
 | |    | |/ _ \| | | |/ _` |\___ \ / __/ _ \| '_ \ / _ \
 | |____| | (_) | |_| | (_| |____) | (_| (_) | |_) |  __/
  \_____|_|\___/ \__,_|\__,_|_____/ \___\___/| .__/ \___|
                                              | |         
                                              |_|         
EOF
    echo -e "${NC}"
    echo -e "${BLUE}Open Source Unified Asset Inventory Platform${NC}"
    echo -e "${GREEN}Version: $VERSION${NC}"
    echo ""
}

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }
log_step() { echo -e "\n${PURPLE}▶ $1${NC}"; }

# Spinner function
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Check system requirements
check_requirements() {
    log_step "Checking system requirements"
    
    local missing=()
    
    # Check Docker
    if command -v docker &> /dev/null; then
        log_success "Docker: $(docker --version | cut -d' ' -f3 | tr -d ',')"
    else
        missing+=("Docker")
    fi
    
    # Check Docker Compose
    if command -v docker-compose &> /dev/null; then
        log_success "Docker Compose: $(docker-compose --version | cut -d' ' -f4 | tr -d ',')"
    else
        missing+=("Docker Compose")
    fi
    
    # Check Python
    if command -v python3 &> /dev/null; then
        log_success "Python: $(python3 --version | cut -d' ' -f2)"
    else
        missing+=("Python 3")
    fi
    
    # Check PowerShell
    if command -v pwsh &> /dev/null; then
        log_success "PowerShell: $(pwsh --version | head -1)"
    else
        log_warning "PowerShell Core not found (optional for Microsoft collectors)"
    fi
    
    # Check Git
    if command -v git &> /dev/null; then
        log_success "Git: $(git --version | cut -d' ' -f3)"
    else
        missing+=("Git")
    fi
    
    # Report missing requirements
    if [ ${#missing[@]} -ne 0 ]; then
        log_error "Missing required software: ${missing[*]}"
        echo ""
        echo "Please install missing requirements:"
        echo "  - Docker: https://docs.docker.com/get-docker/"
        echo "  - Docker Compose: https://docs.docker.com/compose/install/"
        echo "  - Python 3: https://www.python.org/downloads/"
        echo "  - Git: https://git-scm.com/downloads"
        exit 1
    fi
}

# Setup Python environment
setup_python() {
    log_step "Setting up Python environment"
    
    # Create virtual environment
    if [[ ! -d "venv" ]]; then
        log_info "Creating virtual environment..."
        python3 -m venv venv &
        spinner $!
        log_success "Virtual environment created"
    else
        log_success "Virtual environment exists"
    fi
    
    # Activate virtual environment
    source venv/bin/activate
    
    # Upgrade pip
    log_info "Upgrading pip..."
    pip install --upgrade pip --quiet
    
    # Install requirements
    if [[ -f "requirements.txt" ]]; then
        log_info "Installing Python dependencies..."
        pip install -r requirements.txt --quiet &
        spinner $!
        log_success "Python dependencies installed"
    fi
    
    # Install development requirements
    if [[ -f "requirements-dev.txt" ]]; then
        pip install -r requirements-dev.txt --quiet &
        spinner $!
        log_success "Development dependencies installed"
    fi
}

# Setup configuration
setup_config() {
    log_step "Setting up configuration"
    
    # Create config directory
    mkdir -p config
    
    # Create example config if it doesn't exist
    if [[ ! -f "config/cloudscope-config.example.json" ]]; then
        cat > config/cloudscope-config.example.json << 'EOF'
{
  "environment": "development",
  "database": {
    "memgraph": {
      "host": "localhost",
      "port": 7687
    },
    "postgres": {
      "host": "localhost",
      "port": 5432,
      "database": "cloudscope",
      "user": "cloudscope",
      "password": "changeme"
    },
    "elasticsearch": {
      "host": "localhost",
      "port": 9200
    }
  },
  "collectors": {
    "microsoft365": {
      "enabled": false,
      "tenant_id": "",
      "client_id": "",
      "auth_method": "interactive"
    },
    "aws": {
      "enabled": false,
      "regions": ["us-east-1", "us-west-2"],
      "profile": "default"
    },
    "azure": {
      "enabled": false,
      "subscription_ids": []
    }
  },
  "api": {
    "host": "0.0.0.0",
    "port": 8000,
    "workers": 4
  },
  "monitoring": {
    "enabled": true,
    "metrics_port": 9090
  }
}
EOF
    fi
    
    # Copy to actual config if it doesn't exist
    if [[ ! -f "config/cloudscope-config.json" ]]; then
        cp config/cloudscope-config.example.json config/cloudscope-config.json
        log_success "Configuration file created"
        log_warning "Please update config/cloudscope-config.json with your settings"
    else
        log_success "Configuration file exists"
    fi
}

# Start Docker services
start_docker() {
    log_step "Starting Docker services"
    
    # Check if services are already running
    if docker-compose ps | grep -q "Up"; then
        log_success "Docker services already running"
    else
        log_info "Starting Docker containers..."
        docker-compose up -d &
        spinner $!
        
        # Wait for services to be ready
        log_info "Waiting for services to be ready..."
        sleep 10
        
        log_success "Docker services started"
    fi
    
    # Show service status
    echo ""
    docker-compose ps
}

# Initialize database
init_database() {
    log_step "Initializing database"
    
    # Check if Memgraph is ready
    if docker exec cloudscope-memgraph echo "MATCH (n) RETURN count(n);" | mgconsole &> /dev/null; then
        log_success "Memgraph is ready"
        
        # Run initialization script
        if [[ -f "scripts/database/init-memgraph.sh" ]]; then
            log_info "Running database initialization..."
            bash scripts/database/init-memgraph.sh
        fi
    else
        log_error "Memgraph is not ready. Please check Docker logs."
        exit 1
    fi
}

# Install PowerShell modules
install_ps_modules() {
    log_step "Installing PowerShell modules (optional)"
    
    if command -v pwsh &> /dev/null; then
        read -p "Install PowerShell modules for Microsoft collectors? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "Installing PowerShell modules..."
            pwsh scripts/powershell/Manage-Collectors.ps1 -Action Install
            log_success "PowerShell modules installed"
        fi
    else
        log_warning "PowerShell not found, skipping module installation"
    fi
}

# Start API
start_api() {
    log_step "Starting CloudScope API"
    
    if [[ -f "scripts/api/manage-api.sh" ]]; then
        bash scripts/api/manage-api.sh start-dev
    else
        log_warning "API management script not found"
    fi
}

# Run first collection
run_first_collection() {
    log_step "Running first collection (optional)"
    
    read -p "Run a test collection now? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if [[ -f "scripts/collectors/run-all-collectors.sh" ]]; then
            log_info "Running collectors..."
            bash scripts/collectors/run-all-collectors.sh --dry-run
            log_success "Test collection completed"
        fi
    fi
}

# Show next steps
show_next_steps() {
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}CloudScope is ready!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "Access Points:"
    echo "  • API:          http://localhost:8000"
    echo "  • API Docs:     http://localhost:8000/docs"
    echo "  • Memgraph Lab: http://localhost:3000"
    echo ""
    echo "Quick Commands:"
    echo "  • Start API:       ./scripts/api/manage-api.sh start"
    echo "  • Run collectors:  ./scripts/collectors/run-all-collectors.sh"
    echo "  • Health check:    ./scripts/monitoring/health-monitor.sh check"
    echo "  • View logs:       docker-compose logs -f"
    echo ""
    echo "Configuration:"
    echo "  • Main config:     config/cloudscope-config.json"
    echo "  • Collectors:      collectors/powershell/"
    echo ""
    echo "Documentation:"
    echo "  • README:          README.md"
    echo "  • Quick Start:     docs/quickstart.md"
    echo "  • Contributing:    CONTRIBUTING.md"
    echo ""
}

# Stop all services
stop_all() {
    log_step "Stopping CloudScope services"
    
    # Stop API
    if [[ -f "scripts/api/manage-api.sh" ]]; then
        bash scripts/api/manage-api.sh stop 2>/dev/null || true
    fi
    
    # Stop Docker services
    docker-compose down
    
    log_success "All services stopped"
}

# Clean up everything
clean_all() {
    log_step "Cleaning CloudScope installation"
    
    read -p "This will remove all data and containers. Are you sure? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Stop services
        stop_all
        
        # Remove containers and volumes
        docker-compose down -v
        
        # Remove virtual environment
        rm -rf venv
        
        # Remove data directories
        rm -rf data logs htmlcov .coverage .pytest_cache
        
        # Remove __pycache__
        find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
        
        log_success "CloudScope cleaned"
    else
        log_info "Clean cancelled"
    fi
}

# Main menu
show_menu() {
    echo ""
    echo "What would you like to do?"
    echo "  1) Quick Start (recommended for first time)"
    echo "  2) Start services only"
    echo "  3) Stop all services"
    echo "  4) Show status"
    echo "  5) Clean everything"
    echo "  6) Exit"
    echo ""
}

# Show status
show_status() {
    log_step "CloudScope Status"
    
    # Docker services
    echo -e "\n${BLUE}Docker Services:${NC}"
    docker-compose ps
    
    # API status
    echo -e "\n${BLUE}API Status:${NC}"
    if [[ -f "scripts/api/manage-api.sh" ]]; then
        bash scripts/api/manage-api.sh status 2>/dev/null || echo "API not running"
    fi
    
    # Database status
    echo -e "\n${BLUE}Database Status:${NC}"
    if docker exec cloudscope-memgraph echo "MATCH (n) RETURN count(n) AS count;" | mgconsole 2>/dev/null; then
        echo "Memgraph: Connected"
    else
        echo "Memgraph: Not available"
    fi
}

# Main execution
main() {
    # Show banner
    clear
    show_banner
    
    # Parse command line arguments
    case ${1:-} in
        start)
            check_requirements
            setup_python
            setup_config
            start_docker
            init_database
            start_api
            show_next_steps
            ;;
        stop)
            stop_all
            ;;
        status)
            show_status
            ;;
        clean)
            clean_all
            ;;
        -h|--help)
            echo "Usage: $0 [start|stop|status|clean]"
            echo ""
            echo "Commands:"
            echo "  start    Start CloudScope (quick setup)"
            echo "  stop     Stop all services"
            echo "  status   Show service status"
            echo "  clean    Remove all data and containers"
            echo ""
            echo "Interactive mode: Run without arguments"
            ;;
        "")
            # Interactive mode
            while true; do
                show_menu
                read -p "Select option (1-6): " choice
                
                case $choice in
                    1)
                        check_requirements
                        setup_python
                        setup_config
                        start_docker
                        init_database
                        install_ps_modules
                        start_api
                        run_first_collection
                        show_next_steps
                        break
                        ;;
                    2)
                        start_docker
                        start_api
                        ;;
                    3)
                        stop_all
                        ;;
                    4)
                        show_status
                        ;;
                    5)
                        clean_all
                        ;;
                    6)
                        log_info "Goodbye!"
                        exit 0
                        ;;
                    *)
                        log_error "Invalid option"
                        ;;
                esac
            done
            ;;
        *)
            log_error "Unknown command: $1"
            echo "Use '$0 --help' for usage information"
            exit 1
            ;;
    esac
}

# Make all scripts executable
find scripts/ -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
find scripts/ -name "*.ps1" -exec chmod +x {} \; 2>/dev/null || true

# Run main function
main "$@"
