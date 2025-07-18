#!/bin/bash
# CloudScope Configuration Manager
# Manage CloudScope configuration, credentials, and secrets

set -euo pipefail

# Configuration paths
CONFIG_DIR="${CONFIG_DIR:-./config}"
CREDENTIALS_DIR="${CREDENTIALS_DIR:-$CONFIG_DIR/credentials}"
MAIN_CONFIG="${MAIN_CONFIG:-$CONFIG_DIR/cloudscope-config.json}"
BACKUP_DIR="${BACKUP_DIR:-$CONFIG_DIR/backups}"

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
log_section() { echo -e "\n${PURPLE}▶ $1${NC}"; }

# Create directories
mkdir -p "$CONFIG_DIR" "$CREDENTIALS_DIR" "$BACKUP_DIR"

# Encrypt/decrypt functions
encrypt_value() {
    local value=$1
    local key=${CLOUDSCOPE_ENCRYPTION_KEY:-}
    
    if [[ -z "$key" ]]; then
        log_warning "No encryption key set. Using base64 encoding only."
        echo "$value" | base64
    else
        echo "$value" | openssl enc -aes-256-cbc -salt -pass pass:"$key" -base64 2>/dev/null
    fi
}

decrypt_value() {
    local encrypted=$1
    local key=${CLOUDSCOPE_ENCRYPTION_KEY:-}
    
    if [[ -z "$key" ]]; then
        echo "$encrypted" | base64 -d 2>/dev/null || echo "$encrypted"
    else
        echo "$encrypted" | base64 -d | openssl enc -aes-256-cbc -d -salt -pass pass:"$key" 2>/dev/null || echo "$encrypted"
    fi
}

# Backup configuration
backup_config() {
    log_info "Backing up configuration..."
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$BACKUP_DIR/config_backup_${timestamp}.tar.gz"
    
    # Create backup
    tar -czf "$backup_file" -C "$CONFIG_DIR" . 2>/dev/null
    
    log_success "Configuration backed up to: $backup_file"
    
    # Keep only last 10 backups
    ls -t "$BACKUP_DIR"/config_backup_*.tar.gz 2>/dev/null | tail -n +11 | xargs rm -f 2>/dev/null || true
}

# Restore configuration
restore_config() {
    local backup_file=$1
    
    if [[ ! -f "$backup_file" ]]; then
        log_error "Backup file not found: $backup_file"
        return 1
    fi
    
    log_info "Restoring configuration from: $backup_file"
    
    # Backup current config first
    backup_config
    
    # Extract backup
    tar -xzf "$backup_file" -C "$CONFIG_DIR"
    
    log_success "Configuration restored"
}

# Initialize configuration
init_config() {
    log_section "Initializing CloudScope configuration"
    
    if [[ -f "$MAIN_CONFIG" ]]; then
        log_warning "Configuration already exists. Use 'update' to modify."
        return
    fi
    
    # Create base configuration
    cat > "$MAIN_CONFIG" << 'EOF'
{
  "environment": "development",
  "version": "1.0.0",
  "database": {
    "memgraph": {
      "host": "localhost",
      "port": 7687,
      "ssl": false
    },
    "postgres": {
      "host": "localhost",
      "port": 5432,
      "database": "cloudscope",
      "user": "cloudscope",
      "password": "",
      "ssl": false
    },
    "elasticsearch": {
      "host": "localhost",
      "port": 9200,
      "ssl": false
    }
  },
  "collectors": {},
  "api": {
    "host": "0.0.0.0",
    "port": 8000,
    "workers": 4,
    "cors_origins": ["*"],
    "debug": false
  },
  "monitoring": {
    "enabled": true,
    "interval": 60,
    "alerts": {
      "email": "",
      "webhook": ""
    }
  },
  "security": {
    "jwt_secret": "",
    "api_key_enabled": false,
    "encryption_key": ""
  },
  "logging": {
    "level": "INFO",
    "format": "json",
    "file": "./data/logs/cloudscope.log",
    "rotation": {
      "enabled": true,
      "max_size": "100MB",
      "max_files": 10
    }
  }
}
EOF
    
    log_success "Base configuration created"
    
    # Generate security keys
    log_info "Generating security keys..."
    local jwt_secret=$(openssl rand -base64 32)
    local encryption_key=$(openssl rand -base64 32)
    
    # Update configuration with keys
    python3 -c "
import json
with open('$MAIN_CONFIG', 'r') as f:
    config = json.load(f)
config['security']['jwt_secret'] = '$jwt_secret'
config['security']['encryption_key'] = '$encryption_key'
with open('$MAIN_CONFIG', 'w') as f:
    json.dump(config, f, indent=2)
"
    
    log_success "Configuration initialized"
}

# Configure database
configure_database() {
    log_section "Database Configuration"
    
    echo "Select database to configure:"
    echo "  1) Memgraph"
    echo "  2) PostgreSQL"
    echo "  3) Elasticsearch"
    read -p "Selection (1-3): " db_choice
    
    case $db_choice in
        1)
            read -p "Memgraph host [localhost]: " host
            read -p "Memgraph port [7687]: " port
            read -p "Enable SSL? (y/N): " ssl
            
            python3 -c "
import json
with open('$MAIN_CONFIG', 'r') as f:
    config = json.load(f)
config['database']['memgraph']['host'] = '${host:-localhost}'
config['database']['memgraph']['port'] = int('${port:-7687}')
config['database']['memgraph']['ssl'] = '${ssl}' in ['y', 'Y']
with open('$MAIN_CONFIG', 'w') as f:
    json.dump(config, f, indent=2)
"
            log_success "Memgraph configuration updated"
            ;;
        2)
            read -p "PostgreSQL host [localhost]: " host
            read -p "PostgreSQL port [5432]: " port
            read -p "Database name [cloudscope]: " database
            read -p "Username [cloudscope]: " username
            read -s -p "Password: " password
            echo
            
            # Encrypt password
            encrypted_password=$(encrypt_value "$password")
            
            python3 -c "
import json
with open('$MAIN_CONFIG', 'r') as f:
    config = json.load(f)
config['database']['postgres']['host'] = '${host:-localhost}'
config['database']['postgres']['port'] = int('${port:-5432}')
config['database']['postgres']['database'] = '${database:-cloudscope}'
config['database']['postgres']['user'] = '${username:-cloudscope}'
config['database']['postgres']['password'] = '$encrypted_password'
with open('$MAIN_CONFIG', 'w') as f:
    json.dump(config, f, indent=2)
"
            log_success "PostgreSQL configuration updated"
            ;;
        3)
            read -p "Elasticsearch host [localhost]: " host
            read -p "Elasticsearch port [9200]: " port
            read -p "Enable SSL? (y/N): " ssl
            
            python3 -c "
import json
with open('$MAIN_CONFIG', 'r') as f:
    config = json.load(f)
config['database']['elasticsearch']['host'] = '${host:-localhost}'
config['database']['elasticsearch']['port'] = int('${port:-9200}')
config['database']['elasticsearch']['ssl'] = '${ssl}' in ['y', 'Y']
with open('$MAIN_CONFIG', 'w') as f:
    json.dump(config, f, indent=2)
"
            log_success "Elasticsearch configuration updated"
            ;;
    esac
}

# Configure collectors
configure_collector() {
    log_section "Collector Configuration"
    
    echo "Select collector to configure:"
    echo "  1) Microsoft 365"
    echo "  2) AWS"
    echo "  3) Azure"
    echo "  4) Google Cloud"
    echo "  5) On-Premises"
    read -p "Selection (1-5): " collector_choice
    
    case $collector_choice in
        1)
            log_info "Configuring Microsoft 365 collector..."
            read -p "Tenant ID: " tenant_id
            read -p "Client ID (App ID): " client_id
            echo "Authentication method:"
            echo "  1) Interactive"
            echo "  2) Certificate"
            echo "  3) Client Secret"
            read -p "Selection (1-3): " auth_method
            
            local config_data="{\"enabled\": true, \"tenant_id\": \"$tenant_id\", \"client_id\": \"$client_id\""
            
            case $auth_method in
                1)
                    config_data="$config_data, \"auth_method\": \"interactive\"}"
                    ;;
                2)
                    read -p "Certificate path: " cert_path
                    config_data="$config_data, \"auth_method\": \"certificate\", \"certificate_path\": \"$cert_path\"}"
                    ;;
                3)
                    read -s -p "Client Secret: " client_secret
                    echo
                    encrypted_secret=$(encrypt_value "$client_secret")
                    config_data="$config_data, \"auth_method\": \"client_secret\", \"client_secret\": \"$encrypted_secret\"}"
                    ;;
            esac
            
            python3 -c "
import json
with open('$MAIN_CONFIG', 'r') as f:
    config = json.load(f)
config['collectors']['microsoft365'] = $config_data
with open('$MAIN_CONFIG', 'w') as f:
    json.dump(config, f, indent=2)
"
            log_success "Microsoft 365 collector configured"
            ;;
            
        2)
            log_info "Configuring AWS collector..."
            read -p "AWS Profile [default]: " profile
            read -p "Regions (comma-separated) [us-east-1]: " regions
            read -p "Enable AssumeRole? (y/N): " assume_role
            
            local config_data="{\"enabled\": true, \"profile\": \"${profile:-default}\""
            config_data="$config_data, \"regions\": [$(echo "${regions:-us-east-1}" | awk '{gsub(/,/, "\",\""); print "\"" $0 "\""}')]"
            
            if [[ "$assume_role" =~ ^[Yy]$ ]]; then
                read -p "Role ARN: " role_arn
                config_data="$config_data, \"assume_role\": true, \"role_arn\": \"$role_arn\""
            fi
            
            config_data="$config_data}"
            
            python3 -c "
import json
with open('$MAIN_CONFIG', 'r') as f:
    config = json.load(f)
config['collectors']['aws'] = $config_data
with open('$MAIN_CONFIG', 'w') as f:
    json.dump(config, f, indent=2)
"
            log_success "AWS collector configured"
            ;;
            
        3)
            log_info "Configuring Azure collector..."
            read -p "Subscription IDs (comma-separated): " subscriptions
            echo "Authentication method:"
            echo "  1) Azure CLI"
            echo "  2) Service Principal"
            read -p "Selection (1-2): " auth_method
            
            local config_data="{\"enabled\": true"
            config_data="$config_data, \"subscription_ids\": [$(echo "$subscriptions" | awk '{gsub(/,/, "\",\""); print "\"" $0 "\""}')]"
            
            if [[ "$auth_method" == "2" ]]; then
                read -p "Tenant ID: " tenant_id
                read -p "Client ID: " client_id
                read -s -p "Client Secret: " client_secret
                echo
                encrypted_secret=$(encrypt_value "$client_secret")
                config_data="$config_data, \"auth_method\": \"service_principal\""
                config_data="$config_data, \"tenant_id\": \"$tenant_id\", \"client_id\": \"$client_id\""
                config_data="$config_data, \"client_secret\": \"$encrypted_secret\""
            else
                config_data="$config_data, \"auth_method\": \"cli\""
            fi
            
            config_data="$config_data}"
            
            python3 -c "
import json
with open('$MAIN_CONFIG', 'r') as f:
    config = json.load(f)
config['collectors']['azure'] = $config_data
with open('$MAIN_CONFIG', 'w') as f:
    json.dump(config, f, indent=2)
"
            log_success "Azure collector configured"
            ;;
    esac
}

# Set environment
set_environment() {
    log_section "Environment Configuration"
    
    echo "Select environment:"
    echo "  1) Development"
    echo "  2) Staging"
    echo "  3) Production"
    read -p "Selection (1-3): " env_choice
    
    local environment=""
    case $env_choice in
        1) environment="development" ;;
        2) environment="staging" ;;
        3) environment="production" ;;
        *) log_error "Invalid selection"; return ;;
    esac
    
    python3 -c "
import json
with open('$MAIN_CONFIG', 'r') as f:
    config = json.load(f)
config['environment'] = '$environment'

# Adjust settings based on environment
if '$environment' == 'production':
    config['api']['debug'] = False
    config['logging']['level'] = 'WARNING'
elif '$environment' == 'development':
    config['api']['debug'] = True
    config['logging']['level'] = 'DEBUG'

with open('$MAIN_CONFIG', 'w') as f:
    json.dump(config, f, indent=2)
"
    
    log_success "Environment set to: $environment"
}

# Configure monitoring
configure_monitoring() {
    log_section "Monitoring Configuration"
    
    read -p "Enable monitoring? (Y/n): " enable
    
    if [[ ! "$enable" =~ ^[Nn]$ ]]; then
        read -p "Check interval in seconds [60]: " interval
        read -p "Alert email (optional): " email
        read -p "Alert webhook URL (optional): " webhook
        
        python3 -c "
import json
with open('$MAIN_CONFIG', 'r') as f:
    config = json.load(f)
config['monitoring']['enabled'] = True
config['monitoring']['interval'] = int('${interval:-60}')
config['monitoring']['alerts']['email'] = '$email'
config['monitoring']['alerts']['webhook'] = '$webhook'
with open('$MAIN_CONFIG', 'w') as f:
    json.dump(config, f, indent=2)
"
        log_success "Monitoring configured"
    else
        python3 -c "
import json
with open('$MAIN_CONFIG', 'r') as f:
    config = json.load(f)
config['monitoring']['enabled'] = False
with open('$MAIN_CONFIG', 'w') as f:
    json.dump(config, f, indent=2)
"
        log_info "Monitoring disabled"
    fi
}

# Validate configuration
validate_config() {
    log_section "Validating configuration"
    
    # Check if config file exists
    if [[ ! -f "$MAIN_CONFIG" ]]; then
        log_error "Configuration file not found: $MAIN_CONFIG"
        return 1
    fi
    
    # Validate JSON syntax
    if ! python3 -m json.tool "$MAIN_CONFIG" > /dev/null 2>&1; then
        log_error "Invalid JSON syntax in configuration file"
        return 1
    fi
    
    # Validate required fields
    python3 << 'EOF'
import json
import sys

with open('$MAIN_CONFIG', 'r') as f:
    config = json.load(f)

errors = []

# Check required top-level fields
required_fields = ['environment', 'database', 'collectors', 'api']
for field in required_fields:
    if field not in config:
        errors.append(f"Missing required field: {field}")

# Check database configuration
if 'database' in config:
    if 'memgraph' not in config['database']:
        errors.append("Missing Memgraph configuration")

# Check API configuration
if 'api' in config:
    if 'port' not in config['api']:
        errors.append("Missing API port configuration")

# Report errors
if errors:
    for error in errors:
        print(f"ERROR: {error}")
    sys.exit(1)
else:
    print("Configuration is valid")
EOF
    
    if [[ $? -eq 0 ]]; then
        log_success "Configuration validation passed"
    else
        log_error "Configuration validation failed"
        return 1
    fi
}

# Export configuration
export_config() {
    local format=${1:-json}
    local output_file=${2:-"cloudscope-config-export.${format}"}
    
    log_info "Exporting configuration to: $output_file"
    
    case $format in
        json)
            cp "$MAIN_CONFIG" "$output_file"
            ;;
        yaml)
            python3 -c "
import json
import yaml
with open('$MAIN_CONFIG', 'r') as f:
    config = json.load(f)
with open('$output_file', 'w') as f:
    yaml.dump(config, f, default_flow_style=False)
"
            ;;
        env)
            python3 -c "
import json

def flatten_dict(d, parent_key='', sep='_'):
    items = []
    for k, v in d.items():
        new_key = f'{parent_key}{sep}{k}' if parent_key else k
        if isinstance(v, dict):
            items.extend(flatten_dict(v, new_key, sep=sep).items())
        else:
            items.append((new_key.upper(), v))
    return dict(items)

with open('$MAIN_CONFIG', 'r') as f:
    config = json.load(f)

flat_config = flatten_dict(config)

with open('$output_file', 'w') as f:
    for key, value in flat_config.items():
        f.write(f'export CLOUDSCOPE_{key}=\"{value}\"\n')
"
            ;;
        *)
            log_error "Unsupported format: $format"
            return 1
            ;;
    esac
    
    log_success "Configuration exported"
}

# Interactive configuration wizard
config_wizard() {
    log_section "CloudScope Configuration Wizard"
    
    echo "This wizard will help you configure CloudScope step by step."
    echo ""
    
    # Initialize if needed
    if [[ ! -f "$MAIN_CONFIG" ]]; then
        init_config
    fi
    
    # Environment
    set_environment
    
    # Database
    echo ""
    read -p "Configure database connections? (Y/n): " configure_db
    if [[ ! "$configure_db" =~ ^[Nn]$ ]]; then
        configure_database
    fi
    
    # Collectors
    echo ""
    read -p "Configure collectors? (Y/n): " configure_col
    if [[ ! "$configure_col" =~ ^[Nn]$ ]]; then
        while true; do
            configure_collector
            read -p "Configure another collector? (y/N): " another
            if [[ ! "$another" =~ ^[Yy]$ ]]; then
                break
            fi
        done
    fi
    
    # Monitoring
    echo ""
    configure_monitoring
    
    # Validate
    echo ""
    validate_config
    
    # Backup
    backup_config
    
    log_success "Configuration wizard completed!"
}

# Show configuration
show_config() {
    if [[ ! -f "$MAIN_CONFIG" ]]; then
        log_error "Configuration file not found"
        return 1
    fi
    
    log_section "Current Configuration"
    
    # Pretty print with syntax highlighting if available
    if command -v jq &> /dev/null; then
        jq . "$MAIN_CONFIG"
    elif command -v python3 &> /dev/null; then
        python3 -m json.tool "$MAIN_CONFIG"
    else
        cat "$MAIN_CONFIG"
    fi
}

# Reset configuration
reset_config() {
    log_warning "This will reset configuration to defaults"
    read -p "Are you sure? (y/N): " confirm
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        backup_config
        rm -f "$MAIN_CONFIG"
        init_config
        log_success "Configuration reset to defaults"
    else
        log_info "Reset cancelled"
    fi
}

# Print usage
usage() {
    cat << EOF
Usage: $0 [COMMAND] [OPTIONS]

Commands:
    init                Initialize configuration
    wizard              Run configuration wizard (interactive)
    show                Display current configuration
    validate            Validate configuration
    backup              Backup current configuration
    restore FILE        Restore configuration from backup
    
    set-env             Set environment (dev/staging/prod)
    configure-db        Configure database connection
    configure-collector Configure a collector
    configure-monitoring Configure monitoring settings
    
    export [FORMAT]     Export configuration (json/yaml/env)
    reset               Reset to default configuration
    
Options:
    -h, --help         Show this help message

Environment Variables:
    CLOUDSCOPE_ENCRYPTION_KEY    Key for encrypting sensitive values
    CONFIG_DIR                   Configuration directory (default: ./config)

Examples:
    # Run configuration wizard
    $0 wizard
    
    # Validate configuration
    $0 validate
    
    # Export as environment variables
    $0 export env
    
    # Backup configuration
    $0 backup
EOF
}

# Main execution
case ${1:-} in
    init)
        init_config
        ;;
    wizard)
        config_wizard
        ;;
    show)
        show_config
        ;;
    validate)
        validate_config
        ;;
    backup)
        backup_config
        ;;
    restore)
        restore_config "${2:-}"
        ;;
    set-env)
        set_environment
        ;;
    configure-db)
        configure_database
        ;;
    configure-collector)
        configure_collector
        ;;
    configure-monitoring)
        configure_monitoring
        ;;
    export)
        export_config "${2:-json}" "${3:-}"
        ;;
    reset)
        reset_config
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
