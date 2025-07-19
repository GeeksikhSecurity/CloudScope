#!/bin/bash
# CloudScope Production Deployment Script
# Deploy CloudScope to production environments

set -euo pipefail

# Configuration
DEPLOYMENT_ENV="${DEPLOYMENT_ENV:-production}"
DEPLOY_USER="${DEPLOY_USER:-cloudscope}"
DEPLOY_DIR="${DEPLOY_DIR:-/opt/cloudscope}"
BACKUP_DIR="${BACKUP_DIR:-/var/backups/cloudscope}"
CONFIG_DIR="${CONFIG_DIR:-/etc/cloudscope}"
LOG_DIR="${LOG_DIR:-/var/log/cloudscope}"
SYSTEMD_DIR="/etc/systemd/system"

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

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root for production deployment"
        exit 1
    fi
}

# Create deployment user
create_deployment_user() {
    log_info "Creating deployment user: $DEPLOY_USER"
    
    if id "$DEPLOY_USER" &>/dev/null; then
        log_warning "User $DEPLOY_USER already exists"
    else
        useradd -r -s /bin/bash -d "$DEPLOY_DIR" -m "$DEPLOY_USER"
        log_success "Created user: $DEPLOY_USER"
    fi
}

# Create directory structure
create_directories() {
    log_info "Creating directory structure..."
    
    # Create directories with proper ownership
    mkdir -p "$DEPLOY_DIR"/{app,data,logs,backups,config}
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$LOG_DIR"
    mkdir -p "$BACKUP_DIR"
    
    # Set ownership
    chown -R "$DEPLOY_USER:$DEPLOY_USER" "$DEPLOY_DIR"
    chown -R "$DEPLOY_USER:$DEPLOY_USER" "$LOG_DIR"
    chown -R "$DEPLOY_USER:$DEPLOY_USER" "$BACKUP_DIR"
    
    # Set permissions
    chmod 755 "$DEPLOY_DIR"
    chmod 750 "$CONFIG_DIR"
    chmod 755 "$LOG_DIR"
    chmod 750 "$BACKUP_DIR"
}

# Deploy application files
deploy_application() {
    log_info "Deploying application files..."
    
    # Get current directory (where script is run from)
    SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    
    # Create backup of existing deployment
    if [[ -d "$DEPLOY_DIR/app/cloudscope" ]]; then
        log_info "Backing up existing deployment..."
        TIMESTAMP=$(date +%Y%m%d_%H%M%S)
        tar -czf "$BACKUP_DIR/cloudscope_backup_${TIMESTAMP}.tar.gz" -C "$DEPLOY_DIR/app" .
    fi
    
    # Copy application files
    log_info "Copying application files..."
    rsync -av --exclude='.git' \
              --exclude='__pycache__' \
              --exclude='*.pyc' \
              --exclude='.pytest_cache' \
              --exclude='htmlcov' \
              --exclude='venv' \
              --exclude='data' \
              --exclude='logs' \
              "$SOURCE_DIR/" "$DEPLOY_DIR/app/"
    
    # Set ownership
    chown -R "$DEPLOY_USER:$DEPLOY_USER" "$DEPLOY_DIR/app"
}

# Setup Python environment
setup_python_env() {
    log_info "Setting up Python environment..."
    
    cd "$DEPLOY_DIR/app"
    
    # Create virtual environment as deploy user
    sudo -u "$DEPLOY_USER" python3.11 -m venv venv
    
    # Install dependencies
    sudo -u "$DEPLOY_USER" bash -c "source venv/bin/activate && pip install --upgrade pip"
    sudo -u "$DEPLOY_USER" bash -c "source venv/bin/activate && pip install -r requirements.txt"
    
    # Install production server
    sudo -u "$DEPLOY_USER" bash -c "source venv/bin/activate && pip install gunicorn uvicorn"
}

# Deploy configuration
deploy_configuration() {
    log_info "Deploying configuration..."
    
    # Copy configuration template
    if [[ ! -f "$CONFIG_DIR/cloudscope-config.json" ]]; then
        cp "$DEPLOY_DIR/app/config/cloudscope-config.example.json" "$CONFIG_DIR/cloudscope-config.json"
        log_warning "Created default configuration. Please update: $CONFIG_DIR/cloudscope-config.json"
    fi
    
    # Create environment file
    cat > "$CONFIG_DIR/cloudscope.env" << EOF
# CloudScope Environment Configuration
DEPLOYMENT_ENV=$DEPLOYMENT_ENV
CONFIG_FILE=$CONFIG_DIR/cloudscope-config.json
LOG_DIR=$LOG_DIR
DATA_DIR=$DEPLOY_DIR/data
MEMGRAPH_HOST=localhost
MEMGRAPH_PORT=7687
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
ELASTICSEARCH_HOST=localhost
ELASTICSEARCH_PORT=9200
EOF
    
    # Set permissions
    chmod 640 "$CONFIG_DIR/cloudscope-config.json"
    chmod 640 "$CONFIG_DIR/cloudscope.env"
    chown root:"$DEPLOY_USER" "$CONFIG_DIR"/*
}

# Create systemd service
create_systemd_service() {
    log_info "Creating systemd service..."
    
    # Create main application service
    cat > "$SYSTEMD_DIR/cloudscope.service" << EOF
[Unit]
Description=CloudScope Asset Inventory Service
After=network.target docker.service
Requires=docker.service

[Service]
Type=notify
User=$DEPLOY_USER
Group=$DEPLOY_USER
WorkingDirectory=$DEPLOY_DIR/app
EnvironmentFile=$CONFIG_DIR/cloudscope.env
ExecStart=$DEPLOY_DIR/app/venv/bin/gunicorn \
    --workers 4 \
    --worker-class uvicorn.workers.UvicornWorker \
    --bind 0.0.0.0:8000 \
    --access-logfile $LOG_DIR/access.log \
    --error-logfile $LOG_DIR/error.log \
    --log-level info \
    cloudscope.main:app
ExecReload=/bin/kill -s HUP \$MAINPID
KillMode=mixed
KillSignal=SIGQUIT
TimeoutStopSec=5
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    # Create collector timer service
    cat > "$SYSTEMD_DIR/cloudscope-collector.service" << EOF
[Unit]
Description=CloudScope Asset Collector
After=network.target cloudscope.service

[Service]
Type=oneshot
User=$DEPLOY_USER
Group=$DEPLOY_USER
WorkingDirectory=$DEPLOY_DIR/app
EnvironmentFile=$CONFIG_DIR/cloudscope.env
ExecStart=$DEPLOY_DIR/app/scripts/collectors/run-all-collectors.sh
StandardOutput=append:$LOG_DIR/collector.log
StandardError=append:$LOG_DIR/collector-error.log
EOF

    # Create collector timer
    cat > "$SYSTEMD_DIR/cloudscope-collector.timer" << EOF
[Unit]
Description=Run CloudScope Asset Collector every hour
Requires=cloudscope-collector.service

[Timer]
OnBootSec=10min
OnUnitActiveSec=1h
Persistent=true

[Install]
WantedBy=timers.target
EOF

    # Reload systemd
    systemctl daemon-reload
}

# Setup Docker containers
setup_docker() {
    log_info "Setting up Docker containers..."
    
    # Create docker-compose override for production
    cat > "$DEPLOY_DIR/app/docker-compose.prod.yml" << 'EOF'
version: '3.8'

services:
  memgraph:
    restart: always
    volumes:
      - memgraph-data:/var/lib/memgraph
      - memgraph-logs:/var/log/memgraph
    environment:
      - MEMGRAPH_TELEMETRY_ENABLED=false
    
  postgres:
    restart: always
    volumes:
      - postgres-data:/var/lib/postgresql/data
    environment:
      - POSTGRES_DB=cloudscope
      - POSTGRES_USER=cloudscope
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
    
  elasticsearch:
    restart: always
    volumes:
      - elasticsearch-data:/usr/share/elasticsearch/data
    environment:
      - discovery.type=single-node
      - xpack.security.enabled=false
      - ES_JAVA_OPTS=-Xms512m -Xmx512m

volumes:
  memgraph-data:
  memgraph-logs:
  postgres-data:
  elasticsearch-data:
EOF

    # Start Docker containers
    cd "$DEPLOY_DIR/app"
    docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d
}

# Setup firewall rules
setup_firewall() {
    log_info "Setting up firewall rules..."
    
    # Check if ufw is installed
    if command -v ufw &> /dev/null; then
        # Allow CloudScope API
        ufw allow 8000/tcp comment "CloudScope API"
        
        # Allow Grafana (if needed)
        ufw allow 3000/tcp comment "CloudScope Grafana"
        
        log_success "Firewall rules configured"
    else
        log_warning "UFW not found. Please configure firewall manually."
    fi
}

# Setup monitoring
setup_monitoring() {
    log_info "Setting up monitoring..."
    
    # Create Prometheus configuration
    mkdir -p "$CONFIG_DIR/prometheus"
    cat > "$CONFIG_DIR/prometheus/cloudscope.yml" << EOF
# CloudScope Prometheus metrics
- job_name: 'cloudscope'
  static_configs:
    - targets: ['localhost:8000']
  metrics_path: '/metrics'
  
- job_name: 'memgraph'
  static_configs:
    - targets: ['localhost:7687']
    
- job_name: 'node'
  static_configs:
    - targets: ['localhost:9100']
EOF

    # Create health check script
    cat > "$DEPLOY_DIR/app/scripts/monitoring/health-check.sh" << 'EOF'
#!/bin/bash
# CloudScope Health Check Script

# Check API
if curl -f http://localhost:8000/health > /dev/null 2>&1; then
    echo "API: OK"
else
    echo "API: FAILED"
    exit 1
fi

# Check Memgraph
if docker exec cloudscope-memgraph echo "MATCH (n) RETURN count(n);" | mgconsole > /dev/null 2>&1; then
    echo "Memgraph: OK"
else
    echo "Memgraph: FAILED"
    exit 1
fi

# Check disk space
DISK_USAGE=$(df -h "$DEPLOY_DIR" | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 90 ]; then
    echo "Disk Space: WARNING (${DISK_USAGE}% used)"
else
    echo "Disk Space: OK (${DISK_USAGE}% used)"
fi

echo "Health Check: PASSED"
EOF

    chmod +x "$DEPLOY_DIR/app/scripts/monitoring/health-check.sh"
}

# Setup log rotation
setup_log_rotation() {
    log_info "Setting up log rotation..."
    
    cat > "/etc/logrotate.d/cloudscope" << EOF
$LOG_DIR/*.log {
    daily
    rotate 14
    compress
    delaycompress
    missingok
    notifempty
    create 0640 $DEPLOY_USER $DEPLOY_USER
    sharedscripts
    postrotate
        systemctl reload cloudscope.service > /dev/null 2>&1 || true
    endscript
}
EOF
}

# Setup backup
setup_backup() {
    log_info "Setting up backup..."
    
    # Create backup script
    cat > "$DEPLOY_DIR/app/scripts/backup/backup-cloudscope.sh" << 'EOF'
#!/bin/bash
# CloudScope Backup Script

set -euo pipefail

BACKUP_DIR="/var/backups/cloudscope"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="cloudscope_backup_${TIMESTAMP}"

# Create backup directory
mkdir -p "$BACKUP_DIR/$BACKUP_NAME"

# Backup Memgraph
echo "Backing up Memgraph..."
docker exec cloudscope-memgraph mgconsole --execute "DUMP DATABASE;" > "$BACKUP_DIR/$BACKUP_NAME/memgraph.cypher"

# Backup PostgreSQL
echo "Backing up PostgreSQL..."
docker exec cloudscope-postgres pg_dump -U cloudscope cloudscope > "$BACKUP_DIR/$BACKUP_NAME/postgres.sql"

# Backup configuration
echo "Backing up configuration..."
cp -r /etc/cloudscope "$BACKUP_DIR/$BACKUP_NAME/config"

# Create archive
echo "Creating archive..."
cd "$BACKUP_DIR"
tar -czf "${BACKUP_NAME}.tar.gz" "$BACKUP_NAME"
rm -rf "$BACKUP_NAME"

# Remove old backups (keep last 7 days)
find "$BACKUP_DIR" -name "cloudscope_backup_*.tar.gz" -mtime +7 -delete

echo "Backup completed: ${BACKUP_NAME}.tar.gz"
EOF

    chmod +x "$DEPLOY_DIR/app/scripts/backup/backup-cloudscope.sh"
    
    # Create backup cron job
    cat > "/etc/cron.d/cloudscope-backup" << EOF
# CloudScope daily backup
0 2 * * * $DEPLOY_USER $DEPLOY_DIR/app/scripts/backup/backup-cloudscope.sh >> $LOG_DIR/backup.log 2>&1
EOF
}

# Perform deployment verification
verify_deployment() {
    log_info "Verifying deployment..."
    
    # Check if services are running
    if systemctl is-active --quiet cloudscope.service; then
        log_success "CloudScope service is running"
    else
        log_error "CloudScope service is not running"
    fi
    
    # Check if API is responding
    if curl -f http://localhost:8000/health > /dev/null 2>&1; then
        log_success "API is responding"
    else
        log_error "API is not responding"
    fi
    
    # Check Docker containers
    if docker ps | grep -q cloudscope; then
        log_success "Docker containers are running"
    else
        log_error "Docker containers are not running"
    fi
}

# Print deployment summary
print_summary() {
    cat << EOF

${GREEN}CloudScope Deployment Summary${NC}
=============================

Deployment Directory: $DEPLOY_DIR
Configuration Directory: $CONFIG_DIR
Log Directory: $LOG_DIR
Backup Directory: $BACKUP_DIR

Services:
- Main Service: systemctl status cloudscope.service
- Collector Timer: systemctl status cloudscope-collector.timer
- Docker Containers: docker-compose -f $DEPLOY_DIR/app/docker-compose.yml ps

Next Steps:
1. Update configuration: $CONFIG_DIR/cloudscope-config.json
2. Initialize database: $DEPLOY_DIR/app/scripts/database/init-memgraph.sh
3. Start services: systemctl start cloudscope.service cloudscope-collector.timer
4. Configure PowerShell modules for collectors
5. Set up SSL/TLS certificates for production

Access:
- API: http://localhost:8000
- API Documentation: http://localhost:8000/docs
- Health Check: http://localhost:8000/health

Monitoring:
- Logs: $LOG_DIR/
- Health Check: $DEPLOY_DIR/app/scripts/monitoring/health-check.sh
- Metrics: http://localhost:8000/metrics

EOF
}

# Main deployment flow
main() {
    log_info "CloudScope Production Deployment"
    log_info "================================"
    
    check_root
    
    # Ask for confirmation
    echo -e "\nThis script will deploy CloudScope to: $DEPLOY_DIR"
    echo "Environment: $DEPLOYMENT_ENV"
    read -p "Continue with deployment? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Deployment cancelled"
        exit 0
    fi
    
    # Perform deployment steps
    create_deployment_user
    create_directories
    deploy_application
    setup_python_env
    deploy_configuration
    create_systemd_service
    setup_docker
    setup_firewall
    setup_monitoring
    setup_log_rotation
    setup_backup
    
    # Enable services (but don't start yet)
    systemctl enable cloudscope.service
    systemctl enable cloudscope-collector.timer
    
    # Verify deployment
    verify_deployment
    
    # Print summary
    print_summary
    
    log_success "Deployment completed successfully!"
}

# Run main function
main "$@"
