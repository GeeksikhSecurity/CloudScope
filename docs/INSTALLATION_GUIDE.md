# CloudScope Installation Guide

## System Requirements

### Minimum Requirements
- **Operating System**: Linux (Ubuntu 20.04+, RHEL 8+, Debian 10+) or macOS 10.15+
- **Python**: 3.8 or higher
- **Memory**: 2GB RAM minimum, 4GB recommended
- **Storage**: 1GB for application, additional space for data
- **CPU**: 2 cores minimum, 4 cores recommended

### Optional Requirements
- **Docker**: 20.10+ (for containerized deployment)
- **Docker Compose**: 2.0+ (for multi-container setup)
- **Memgraph**: 2.0+ (for graph database support)

## Installation Methods

### Method 1: Native Python Package Installation (Requirements: 2.1, 2.2, 2.3, 2.4)

#### Step 1: Clone the Repository
```bash
git clone https://github.com/your-org/cloudscope.git
cd cloudscope
```

#### Step 2: Create Virtual Environment
```bash
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

#### Step 3: Install Dependencies
```bash
pip install --upgrade pip
pip install -r requirements.txt
pip install -e .  # Install CloudScope in development mode
```

#### Step 4: Verify Installation
```bash
cloudscope --version
cloudscope health-check
```

### Method 2: Docker Installation (Requirements: 2.1, 2.3, 2.4)

#### Step 1: Pull Docker Image
```bash
docker pull cloudscope/cloudscope:latest
```

#### Step 2: Run Container
```bash
docker run -d \
  --name cloudscope \
  -p 8080:8080 \
  -v $(pwd)/config:/app/config \
  -v $(pwd)/data:/app/data \
  cloudscope/cloudscope:latest
```

#### Step 3: Verify Container
```bash
docker exec cloudscope cloudscope health-check
```

### Method 3: Docker Compose Installation

#### Step 1: Download docker-compose.yml
```bash
wget https://raw.githubusercontent.com/your-org/cloudscope/main/docker-compose.yml
```

#### Step 2: Configure Environment
```bash
cp .env.example .env
# Edit .env file with your settings
```

#### Step 3: Start Services
```bash
docker-compose up -d
```

#### Step 4: Verify Services
```bash
docker-compose ps
docker-compose exec cloudscope cloudscope health-check
```

## Initial Configuration

### Step 1: Generate Default Configuration
```bash
cloudscope config init
```

### Step 2: Configure Storage Backend

#### File-Based Storage (Default)
```json
{
  "storage": {
    "type": "file",
    "path": "./data/assets"
  }
}
```

#### SQLite Storage
```json
{
  "storage": {
    "type": "sqlite",
    "connection": {
      "path": "./data/cloudscope.db"
    }
  }
}
```

#### Memgraph Storage (Optional)
```json
{
  "storage": {
    "type": "memgraph",
    "connection": {
      "host": "localhost",
      "port": 7687,
      "username": "memgraph",
      "password": "${MEMGRAPH_PASSWORD}"
    },
    "fallback": {
      "type": "file",
      "path": "./data/assets"
    }
  }
}
```

### Step 3: Configure Collectors
```bash
# Enable cloud provider collectors
cloudscope collector enable aws
cloudscope collector enable azure
cloudscope collector enable gcp

# Configure collector credentials
export AWS_ACCESS_KEY_ID="your-key"
export AWS_SECRET_ACCESS_KEY="your-secret"
```

### Step 4: Initialize Database
```bash
# Run database migrations
cloudscope db migrate

# Verify database
cloudscope db status
```

## Plugin Installation (Requirements: 3.3, 3.4, 3.5, 3.6)

### Installing Official Plugins
```bash
# List available plugins
cloudscope plugin list --available

# Install a plugin
cloudscope plugin install cloudscope-aws-extended

# Verify plugin
cloudscope plugin list --installed
```

### Installing Custom Plugins
```bash
# From local directory
cloudscope plugin install ./my-custom-plugin/

# From Git repository
cloudscope plugin install https://github.com/user/cloudscope-plugin.git
```

## Post-Installation Setup

### 1. Set Up Logging
```bash
# Configure log rotation
sudo tee /etc/logrotate.d/cloudscope << EOF
/var/log/cloudscope/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
}
EOF
```

### 2. Configure Systemd Service (Linux)
```bash
# Create service file
sudo tee /etc/systemd/system/cloudscope.service << EOF
[Unit]
Description=CloudScope Asset Inventory
After=network.target

[Service]
Type=simple
User=cloudscope
Group=cloudscope
WorkingDirectory=/opt/cloudscope
Environment="PATH=/opt/cloudscope/venv/bin"
ExecStart=/opt/cloudscope/venv/bin/cloudscope server
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable and start service
sudo systemctl enable cloudscope
sudo systemctl start cloudscope
```

### 3. Set Up Scheduled Tasks
```bash
# Add to crontab for regular collection
crontab -e

# Add these lines:
# Collect assets every hour
0 * * * * /opt/cloudscope/scripts/collectors/run-collection.sh
# Generate daily reports
0 2 * * * /opt/cloudscope/scripts/reporting/generate-report.sh daily
# Weekly risk analysis
0 3 * * 0 /opt/cloudscope/scripts/risk-analysis/risk-scoring.sh calculate
```

### 4. Configure Monitoring
```bash
# Set up health check monitoring
*/5 * * * * /opt/cloudscope/scripts/utilities/cloudscope-utils.sh health-check || /opt/cloudscope/scripts/integrations/external-integrations.sh pagerduty "$PAGERDUTY_KEY" "CloudScope Health Check Failed" "error"
```

## Security Hardening

### 1. Create Dedicated User
```bash
sudo useradd -r -s /bin/false cloudscope
sudo chown -R cloudscope:cloudscope /opt/cloudscope
```

### 2. Set File Permissions
```bash
chmod 750 /opt/cloudscope
chmod 640 /opt/cloudscope/config/*
chmod 600 /opt/cloudscope/.env
```

### 3. Configure Firewall
```bash
# Allow only necessary ports
sudo ufw allow 8080/tcp  # CloudScope API
sudo ufw enable
```

### 4. Enable Audit Logging
```json
{
  "security": {
    "audit_logging": true,
    "audit_log_path": "/var/log/cloudscope/audit.log",
    "encrypt_sensitive_data": true
  }
}
```

## Verification Steps

### 1. Check Installation
```bash
cloudscope --version
cloudscope health-check --detailed
```

### 2. Test Collectors
```bash
cloudscope collector test aws
cloudscope collector test azure
```

### 3. Verify Storage
```bash
cloudscope storage test
cloudscope storage stats
```

### 4. Run Sample Collection
```bash
cloudscope collect --dry-run
cloudscope collect --limit 10
```

## Troubleshooting Installation

### Common Issues

#### Python Version Mismatch
```bash
# Check Python version
python3 --version

# Use pyenv to install correct version
pyenv install 3.8.10
pyenv local 3.8.10
```

#### Permission Errors
```bash
# Fix ownership
sudo chown -R $(whoami) /opt/cloudscope

# Fix permissions
chmod -R u+rw /opt/cloudscope
```

#### Database Connection Issues
```bash
# Test database connection
cloudscope db test

# Check database logs
tail -f /var/log/cloudscope/db.log
```

#### Missing Dependencies
```bash
# Install system dependencies
sudo apt-get update
sudo apt-get install -y python3-dev libpq-dev build-essential

# Reinstall Python packages
pip install --force-reinstall -r requirements.txt
```

## Uninstallation

### Native Installation
```bash
# Deactivate virtual environment
deactivate

# Remove application files
rm -rf /opt/cloudscope

# Remove system service
sudo systemctl stop cloudscope
sudo systemctl disable cloudscope
sudo rm /etc/systemd/system/cloudscope.service

# Remove user
sudo userdel cloudscope

# Remove logs
sudo rm -rf /var/log/cloudscope
```

### Docker Installation
```bash
# Stop and remove containers
docker stop cloudscope
docker rm cloudscope

# Remove images
docker rmi cloudscope/cloudscope:latest

# Remove volumes (careful - this deletes data)
docker volume rm cloudscope_data cloudscope_config
```

## Next Steps

1. Read the [Configuration Guide](CONFIGURATION_GUIDE.md)
2. Review the [Scripts Documentation](SCRIPTS_DOCUMENTATION.md)
3. Set up [Integrations](INTEGRATIONS_GUIDE.md)
4. Configure [Monitoring and Alerts](MONITORING_GUIDE.md)

## Support

For installation support:
- Check the [FAQ](FAQ.md)
- Review [Troubleshooting Guide](TROUBLESHOOTING.md)
- Submit issues to the project repository
- Contact support at support@cloudscope.io