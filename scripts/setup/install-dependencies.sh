#!/bin/bash
# CloudScope Dependencies Installation Script
# This script installs all required dependencies for CloudScope

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "This script should not be run as root!"
        exit 1
    fi
}

# Detect OS
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="linux"
        DISTRO=$(lsb_release -si 2>/dev/null || echo "Unknown")
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
    else
        log_error "Unsupported operating system: $OSTYPE"
        exit 1
    fi
    log_info "Detected OS: $OS"
}

# Install system dependencies
install_system_deps() {
    log_info "Installing system dependencies..."
    
    if [[ "$OS" == "macos" ]]; then
        # Check if Homebrew is installed
        if ! command -v brew &> /dev/null; then
            log_info "Installing Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        fi
        
        # Install dependencies via Homebrew
        brew install python@3.11 docker docker-compose git curl wget jq
        
        # Install PowerShell
        if ! command -v pwsh &> /dev/null; then
            log_info "Installing PowerShell..."
            brew install --cask powershell
        fi
        
    elif [[ "$OS" == "linux" ]]; then
        # Update package lists
        sudo apt-get update
        
        # Install dependencies
        sudo apt-get install -y \
            python3.11 python3.11-venv python3-pip \
            docker.io docker-compose \
            git curl wget jq \
            build-essential libssl-dev libffi-dev
        
        # Install PowerShell
        if ! command -v pwsh &> /dev/null; then
            log_info "Installing PowerShell..."
            # Download and install PowerShell
            wget -q "https://github.com/PowerShell/PowerShell/releases/download/v7.4.0/powershell_7.4.0-1.deb_amd64.deb"
            sudo dpkg -i powershell_7.4.0-1.deb_amd64.deb
            sudo apt-get install -f -y
            rm powershell_7.4.0-1.deb_amd64.deb
        fi
        
        # Add user to docker group
        sudo usermod -aG docker $USER
        log_warning "You need to log out and back in for docker group changes to take effect"
    fi
}

# Setup Python environment
setup_python_env() {
    log_info "Setting up Python virtual environment..."
    
    # Create virtual environment
    python3.11 -m venv venv
    
    # Activate virtual environment
    source venv/bin/activate
    
    # Upgrade pip
    pip install --upgrade pip
    
    # Install Python dependencies
    log_info "Installing Python dependencies..."
    pip install -r requirements.txt
    
    # Install development dependencies
    if [[ -f "requirements-dev.txt" ]]; then
        log_info "Installing development dependencies..."
        pip install -r requirements-dev.txt
    fi
}

# Install PowerShell modules
install_powershell_modules() {
    log_info "Installing PowerShell modules..."
    
    pwsh -Command "
        # Set PSGallery as trusted repository
        Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
        
        # Install required modules
        \$modules = @(
            'Microsoft.Graph',
            'Microsoft.Graph.Beta',
            'Az',
            'ExchangeOnlineManagement',
            'MicrosoftTeams',
            'SharePointPnPPowerShellOnline'
        )
        
        foreach (\$module in \$modules) {
            Write-Host \"Installing \$module...\"
            Install-Module -Name \$module -Scope CurrentUser -Force -AllowClobber
        }
    "
}

# Setup Memgraph
setup_memgraph() {
    log_info "Setting up Memgraph..."
    
    # Check if Memgraph is already running
    if docker ps | grep -q memgraph; then
        log_warning "Memgraph container is already running"
    else
        # Pull Memgraph Docker image
        docker pull memgraph/memgraph-platform:latest
        
        # Create data directory
        mkdir -p ./data/memgraph
        
        log_success "Memgraph setup complete. Run 'docker-compose up -d memgraph' to start"
    fi
}

# Setup configuration
setup_config() {
    log_info "Setting up configuration..."
    
    # Create config directory if it doesn't exist
    mkdir -p config
    
    # Copy example config if it doesn't exist
    if [[ ! -f "config/cloudscope-config.json" && -f "config/cloudscope-config.example.json" ]]; then
        cp config/cloudscope-config.example.json config/cloudscope-config.json
        log_info "Created config/cloudscope-config.json from example"
    fi
    
    # Create data directories
    mkdir -p data/{assets,exports,logs}
}

# Verify installation
verify_installation() {
    log_info "Verifying installation..."
    
    # Check Python
    if python3 --version &> /dev/null; then
        log_success "Python: $(python3 --version)"
    else
        log_error "Python installation failed"
    fi
    
    # Check PowerShell
    if pwsh --version &> /dev/null; then
        log_success "PowerShell: $(pwsh --version)"
    else
        log_error "PowerShell installation failed"
    fi
    
    # Check Docker
    if docker --version &> /dev/null; then
        log_success "Docker: $(docker --version)"
    else
        log_error "Docker installation failed"
    fi
    
    # Check Docker Compose
    if docker-compose --version &> /dev/null; then
        log_success "Docker Compose: $(docker-compose --version)"
    else
        log_error "Docker Compose installation failed"
    fi
}

# Main installation flow
main() {
    log_info "CloudScope Dependencies Installation"
    log_info "===================================="
    
    check_root
    detect_os
    
    # Ask for confirmation
    echo -e "\nThis script will install the following:"
    echo "- Python 3.11 and virtual environment"
    echo "- Docker and Docker Compose"
    echo "- PowerShell Core"
    echo "- Required PowerShell modules"
    echo "- Memgraph database"
    echo ""
    read -p "Continue with installation? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Installation cancelled"
        exit 0
    fi
    
    install_system_deps
    setup_python_env
    install_powershell_modules
    setup_memgraph
    setup_config
    verify_installation
    
    log_success "Installation complete!"
    log_info "Next steps:"
    echo "  1. Activate Python virtual environment: source venv/bin/activate"
    echo "  2. Start services: docker-compose up -d"
    echo "  3. Configure collectors: edit config/cloudscope-config.json"
    echo "  4. Run first collection: ./scripts/collectors/run-all-collectors.sh"
}

# Run main function
main "$@"
