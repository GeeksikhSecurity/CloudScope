# CloudScope Scripts Documentation

## Overview

CloudScope provides a comprehensive set of shell scripts organized into functional categories to manage and monitor cloud infrastructure assets. This documentation covers all available scripts, their usage, and integration points.

## Script Categories

### 1. Reporting Scripts (`/scripts/reporting/`)

#### generate-report.sh
Generates comprehensive asset inventory reports in multiple formats.

**Usage:**
```bash
./generate-report.sh [format] [options]
```

**Parameters:**
- `format`: Output format (json|csv|html|pdf|markdown)
- `--filter`: Apply filters to the report
- `--date-range`: Specify date range for the report
- `--include-relationships`: Include asset relationships

**Features:**
- Multi-format export (Requirements: 6.1, 6.2, 6.5)
- Streaming support for large datasets (Requirements: 6.7, 6.8, 6.10)
- LLM-optimized CSV export (Requirements: 6.5, 6.6)
- Relationship context inclusion (Requirements: 6.5, 6.6)

**Example:**
```bash
# Generate CSV report optimized for LLM analysis
./generate-report.sh csv --include-relationships --filter "type=compute"

# Generate HTML report for the last 30 days
./generate-report.sh html --date-range "30d" --output-dir ./reports
```

### 2. Risk Analysis Scripts (`/scripts/risk-analysis/`)

#### risk-scoring.sh
Analyzes assets and calculates risk scores based on multiple factors.

**Usage:**
```bash
./risk-scoring.sh [action] [options]
```

**Actions:**
- `calculate`: Calculate risk scores for all assets
- `analyze`: Perform detailed risk analysis
- `report`: Generate risk assessment report
- `monitor`: Real-time risk monitoring

**Risk Factors:**
- Security vulnerabilities
- Compliance violations
- Configuration drift
- Dependency risks
- Age and lifecycle status

**Example:**
```bash
# Calculate risk scores with custom thresholds
./risk-scoring.sh calculate --threshold-config ./config/risk-thresholds.json

# Generate risk report
./risk-scoring.sh report --format pdf --output risk-assessment.pdf
```

### 3. Troubleshooting Scripts (`/scripts/troubleshooting/`)

#### diagnose-issues.sh
Comprehensive troubleshooting and diagnostic tool for CloudScope.

**Usage:**
```bash
./diagnose-issues.sh [component] [action]
```

**Components:**
- `collectors`: Diagnose data collection issues
- `storage`: Check storage adapter health
- `plugins`: Troubleshoot plugin problems
- `performance`: Analyze performance issues
- `connectivity`: Test external connections

**Actions:**
- `check`: Run health checks
- `diagnose`: Perform detailed diagnosis
- `fix`: Attempt automatic fixes
- `report`: Generate diagnostic report

**Example:**
```bash
# Diagnose collector issues
./diagnose-issues.sh collectors diagnose --verbose

# Run full system diagnostic
./diagnose-issues.sh all check --output diagnostic-report.json
```

### 4. Utilities Scripts (`/scripts/utilities/`)

#### cloudscope-utils.sh
Common utilities and helper functions for CloudScope operations.

**Usage:**
```bash
./cloudscope-utils.sh [utility] [options]
```

**Utilities:**
- `backup`: Backup CloudScope data
- `restore`: Restore from backup
- `validate`: Validate configurations
- `migrate`: Run data migrations
- `cleanup`: Clean temporary files
- `export`: Quick export functions
- `import`: Import external data

**Example:**
```bash
# Create full backup
./cloudscope-utils.sh backup --full --destination /backups/

# Validate all configurations
./cloudscope-utils.sh validate --config-dir ./config/
```

### 5. Integration Scripts (`/scripts/integrations/`)

#### external-integrations.sh
Integrate CloudScope with third-party tools and services.

**Usage:**
```bash
./external-integrations.sh <action> [parameters]
```

**Supported Integrations:**
- **Slack**: Send notifications to Slack channels
- **Microsoft Teams**: Send alerts to Teams channels
- **Jira**: Create and update Jira issues
- **ServiceNow**: Create incidents in ServiceNow
- **PagerDuty**: Trigger PagerDuty alerts
- **Splunk**: Send data to Splunk HEC
- **DataDog**: Send metrics to DataDog
- **GitHub Actions**: Trigger CI/CD workflows
- **Generic Webhooks**: Call any webhook endpoint

**Example:**
```bash
# Send Slack notification
./external-integrations.sh slack "$WEBHOOK_URL" "Asset inventory completed" "#alerts"

# Create Jira issue
./external-integrations.sh jira "$JIRA_URL" "$API_TOKEN" "CLOUD" "New assets detected" "Details..."

# Send metrics to DataDog
./external-integrations.sh datadog "$API_KEY" "assets.total" "1523" "env:prod,service:cloudscope"
```

## Configuration Files

### Global Configuration (`/config/cloudscope-config.json`)
```json
{
  "storage": {
    "type": "sqlite",
    "connection": {
      "path": "./data/cloudscope.db"
    }
  },
  "collectors": {
    "enabled": ["aws", "azure", "gcp"],
    "rate_limit": 100,
    "timeout": 300
  },
  "reporting": {
    "default_format": "json",
    "output_directory": "./reports"
  },
  "logging": {
    "level": "INFO",
    "format": "json",
    "output": "./logs/cloudscope.log"
  }
}
```

### Integration Configuration (`/config/integrations.json`)
```json
{
  "slack": {
    "webhook_url": "${SLACK_WEBHOOK_URL}",
    "default_channel": "#cloudscope-alerts"
  },
  "jira": {
    "url": "${JIRA_URL}",
    "project_key": "CLOUD",
    "api_token": "${JIRA_API_TOKEN}"
  },
  "splunk": {
    "hec_url": "${SPLUNK_HEC_URL}",
    "hec_token": "${SPLUNK_HEC_TOKEN}"
  }
}
```

## Environment Variables

All scripts support the following environment variables:

- `CLOUDSCOPE_CONFIG`: Path to main configuration file
- `CLOUDSCOPE_LOG_LEVEL`: Logging level (DEBUG|INFO|WARNING|ERROR)
- `CLOUDSCOPE_DATA_DIR`: Data directory path
- `CLOUDSCOPE_PLUGIN_DIR`: Plugin directory path
- `CLOUDSCOPE_TEMP_DIR`: Temporary files directory

## Health Checks and Monitoring

### Health Check Endpoints (Requirements: 8.3, 8.5)

All scripts include built-in health check functionality:

```bash
# Check script health
./any-script.sh --health-check

# Get detailed status
./any-script.sh --status --format json
```

### Performance Monitoring (Requirements: 8.3, 8.4)

Scripts automatically collect performance metrics:
- Execution time
- Resource usage
- Error rates
- Operation counts

## Error Handling and Circuit Breakers

### Circuit Breaker Implementation (Requirements: 10.4, 10.5)

All external operations include circuit breaker protection:
- Automatic failure detection
- Configurable thresholds
- Graceful degradation
- Automatic recovery

### Error Codes

Standard error codes across all scripts:
- `0`: Success
- `1`: General error
- `2`: Configuration error
- `3`: Connection error
- `4`: Permission error
- `5`: Validation error
- `10`: Circuit breaker open

## Security Considerations

### Input Validation (Requirements: 4.1, 7.5, 7.6)
- All inputs are validated before processing
- SQL injection protection
- Path traversal prevention
- Command injection safeguards

### Secure Configuration
- Sensitive data stored in environment variables
- Encrypted configuration support
- Secure credential storage

## Migration and Rollback

### Migration Support (Requirements: 10.3, 10.5)
```bash
# Run migrations
./cloudscope-utils.sh migrate --up

# Rollback migrations
./cloudscope-utils.sh migrate --down --version 1.2.0
```

### Configuration Rollback (Requirements: 10.1, 10.2)
```bash
# View configuration history
./cloudscope-utils.sh config --history

# Rollback to previous configuration
./cloudscope-utils.sh config --rollback --version 2
```

## Troubleshooting Guide

### Common Issues

1. **Collection Failures**
   ```bash
   ./diagnose-issues.sh collectors check
   ```

2. **Performance Problems**
   ```bash
   ./diagnose-issues.sh performance analyze --detailed
   ```

3. **Integration Errors**
   ```bash
   ./diagnose-issues.sh connectivity test --service slack
   ```

### Debug Mode

Enable debug mode for detailed logging:
```bash
export CLOUDSCOPE_LOG_LEVEL=DEBUG
./any-script.sh --debug
```

## Best Practices

1. **Regular Backups**
   - Schedule daily backups using cron
   - Test restore procedures monthly

2. **Monitoring**
   - Set up alerts for critical errors
   - Monitor performance metrics
   - Review logs regularly

3. **Security**
   - Rotate credentials regularly
   - Use least privilege principles
   - Enable audit logging

4. **Performance**
   - Use streaming for large datasets
   - Enable caching where appropriate
   - Monitor resource usage

## Support and Contributing

For additional support or to contribute:
- Check the [Troubleshooting Guide](#troubleshooting-guide)
- Review logs in `./logs/`
- Submit issues to the project repository
- Follow the contribution guidelines

## Version History

- v1.0.0: Initial release with core functionality
- v1.1.0: Added plugin system support
- v1.2.0: Enhanced security and validation
- v1.3.0: Integration improvements
- v1.4.0: Performance optimizations