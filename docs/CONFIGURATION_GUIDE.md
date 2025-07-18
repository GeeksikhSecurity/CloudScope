# CloudScope Configuration Guide

## Overview

CloudScope uses a flexible configuration system that supports multiple formats, environment variables, and versioned configurations with rollback capabilities (Requirements: 10.1, 10.2, 10.5).

## Configuration Hierarchy

CloudScope loads configuration in the following order (later sources override earlier ones):
1. Default configuration (built-in)
2. System configuration (`/etc/cloudscope/config.json`)
3. User configuration (`~/.cloudscope/config.json`)
4. Project configuration (`./config/cloudscope-config.json`)
5. Environment variables
6. Command-line arguments

## Main Configuration File

### Basic Structure
```json
{
  "version": "1.4.0",
  "metadata": {
    "created": "2024-01-20T10:00:00Z",
    "modified": "2024-01-20T10:00:00Z",
    "description": "Production CloudScope configuration"
  },
  "storage": {},
  "collectors": {},
  "plugins": {},
  "reporting": {},
  "security": {},
  "observability": {},
  "integrations": {}
}
```

## Storage Configuration

### File-Based Storage (Requirements: 1.1, 1.2, 1.4, 0.1)
```json
{
  "storage": {
    "type": "file",
    "path": "./data/assets",
    "format": "json",
    "compression": "gzip",
    "encryption": {
      "enabled": false,
      "algorithm": "AES-256-GCM"
    },
    "retention": {
      "enabled": true,
      "days": 90
    }
  }
}
```

### SQLite Storage (Requirements: 1.1, 1.2, 1.3, 0.2)
```json
{
  "storage": {
    "type": "sqlite",
    "connection": {
      "path": "./data/cloudscope.db",
      "pragmas": {
        "journal_mode": "WAL",
        "synchronous": "NORMAL",
        "cache_size": -64000,
        "temp_store": "MEMORY"
      }
    },
    "pool": {
      "size": 5,
      "timeout": 30
    },
    "migrations": {
      "auto_migrate": true,
      "migration_path": "./migrations/sqlite"
    }
  }
}
```

### Memgraph Storage (Requirements: 1.1, 1.2, 1.3, 0.3)
```json
{
  "storage": {
    "type": "memgraph",
    "connection": {
      "host": "${MEMGRAPH_HOST:-localhost}",
      "port": 7687,
      "username": "${MEMGRAPH_USER:-memgraph}",
      "password": "${MEMGRAPH_PASSWORD}",
      "database": "cloudscope",
      "ssl": {
        "enabled": true,
        "verify": true,
        "cert_path": "/etc/ssl/certs/memgraph.crt"
      }
    },
    "fallback": {
      "enabled": true,
      "type": "file",
      "path": "./data/fallback"
    },
    "circuit_breaker": {
      "enabled": true,
      "failure_threshold": 5,
      "timeout": 60,
      "half_open_attempts": 3
    }
  }
}
```

## Collector Configuration

### Basic Collector Settings (Requirements: 3.1, 3.2, 3.4, 3.6)
```json
{
  "collectors": {
    "enabled": ["aws", "azure", "gcp", "kubernetes"],
    "schedule": {
      "default": "0 * * * *",
      "aws": "*/30 * * * *",
      "azure": "0 */2 * * *"
    },
    "defaults": {
      "timeout": 300,
      "retry_count": 3,
      "retry_delay": 5,
      "rate_limit": {
        "requests_per_second": 10,
        "burst": 20
      }
    },
    "aws": {
      "regions": ["us-east-1", "us-west-2", "eu-west-1"],
      "services": ["ec2", "s3", "rds", "lambda"],
      "assume_role": {
        "enabled": true,
        "role_arn": "${AWS_ASSUME_ROLE_ARN}",
        "session_name": "CloudScope"
      }
    },
    "azure": {
      "subscriptions": ["${AZURE_SUBSCRIPTION_ID}"],
      "resource_groups": ["*"],
      "tenant_id": "${AZURE_TENANT_ID}"
    },
    "gcp": {
      "projects": ["${GCP_PROJECT_ID}"],
      "zones": ["us-central1-a", "us-east1-b"]
    }
  }
}
```

## Plugin Configuration

### Plugin System Settings (Requirements: 3.3, 3.4, 3.5, 3.6, 3.9)
```json
{
  "plugins": {
    "enabled": true,
    "directory": "./plugins",
    "auto_discover": true,
    "auto_load": ["core", "stable"],
    "rate_limits": {
      "default": {
        "requests_per_minute": 60,
        "requests_per_hour": 1000
      },
      "custom-plugin": {
        "requests_per_minute": 30,
        "requests_per_hour": 500
      }
    },
    "security": {
      "sandbox": true,
      "allowed_imports": ["requests", "json", "datetime"],
      "max_execution_time": 300,
      "max_memory_mb": 512
    },
    "registry": {
      "enabled": true,
      "url": "https://plugins.cloudscope.io",
      "verify_signatures": true
    }
  }
}
```

## Reporting Configuration

### Report Generation Settings (Requirements: 6.1, 6.2, 6.5, 6.7, 6.8)
```json
{
  "reporting": {
    "output_directory": "./reports",
    "default_format": "json",
    "formats": {
      "csv": {
        "delimiter": ",",
        "include_headers": true,
        "llm_optimized": true,
        "max_field_length": 1000,
        "streaming": {
          "enabled": true,
          "chunk_size": 10000
        }
      },
      "json": {
        "pretty_print": true,
        "include_metadata": true
      },
      "html": {
        "template": "default",
        "include_charts": true
      }
    },
    "scheduling": {
      "daily": {
        "enabled": true,
        "time": "02:00",
        "formats": ["json", "csv"]
      },
      "weekly": {
        "enabled": true,
        "day": "sunday",
        "time": "03:00",
        "formats": ["html", "pdf"]
      }
    },
    "retention": {
      "enabled": true,
      "days": 30,
      "compress_after_days": 7
    }
  }
}
```

## Security Configuration

### Security Settings (Requirements: 4.1, 4.3, 7.5, 7.6)
```json
{
  "security": {
    "authentication": {
      "enabled": true,
      "type": "jwt",
      "secret": "${JWT_SECRET}",
      "expiration": 3600
    },
    "authorization": {
      "enabled": true,
      "rbac": {
        "enabled": true,
        "default_role": "viewer"
      }
    },
    "encryption": {
      "at_rest": {
        "enabled": true,
        "algorithm": "AES-256-GCM",
        "key_rotation": {
          "enabled": true,
          "interval_days": 90
        }
      },
      "in_transit": {
        "enabled": true,
        "tls_version": "1.3",
        "cipher_suites": ["TLS_AES_256_GCM_SHA384"]
      }
    },
    "input_validation": {
      "enabled": true,
      "strict_mode": true,
      "max_request_size": "10MB",
      "rate_limiting": {
        "enabled": true,
        "window": 60,
        "max_requests": 100
      }
    },
    "audit_logging": {
      "enabled": true,
      "log_file": "/var/log/cloudscope/audit.log",
      "events": ["authentication", "authorization", "data_access", "configuration_change"]
    }
  }
}
```

## Observability Configuration

### Monitoring and Telemetry (Requirements: 8.1, 8.2, 8.3, 8.4, 8.5)
```json
{
  "observability": {
    "logging": {
      "level": "INFO",
      "format": "json",
      "outputs": [
        {
          "type": "file",
          "path": "/var/log/cloudscope/app.log",
          "rotation": {
            "max_size": "100MB",
            "max_files": 10
          }
        },
        {
          "type": "console",
          "format": "human"
        }
      ],
      "structured": true,
      "include_context": true
    },
    "metrics": {
      "enabled": true,
      "backend": "prometheus",
      "endpoint": "/metrics",
      "collection_interval": 60,
      "custom_metrics": {
        "asset_count": true,
        "collection_duration": true,
        "error_rate": true
      }
    },
    "tracing": {
      "enabled": true,
      "backend": "opentelemetry",
      "endpoint": "${OTEL_EXPORTER_OTLP_ENDPOINT}",
      "sampling_rate": 0.1,
      "propagation": ["w3c", "jaeger"]
    },
    "health_checks": {
      "enabled": true,
      "endpoint": "/health",
      "checks": {
        "database": {
          "enabled": true,
          "timeout": 5,
          "interval": 30
        },
        "storage": {
          "enabled": true,
          "timeout": 3,
          "interval": 60
        },
        "collectors": {
          "enabled": true,
          "timeout": 10,
          "interval": 120
        }
      }
    },
    "performance": {
      "profiling": {
        "enabled": false,
        "endpoint": "/debug/pprof"
      },
      "thresholds": {
        "response_time_ms": 1000,
        "query_time_ms": 500,
        "memory_usage_mb": 1024
      }
    }
  }
}
```

## Integration Configuration

### External Service Integrations
```json
{
  "integrations": {
    "slack": {
      "enabled": true,
      "webhook_url": "${SLACK_WEBHOOK_URL}",
      "channel": "#cloudscope-alerts",
      "notifications": {
        "errors": true,
        "warnings": false,
        "completions": true
      }
    },
    "jira": {
      "enabled": true,
      "url": "${JIRA_URL}",
      "project_key": "CLOUD",
      "api_token": "${JIRA_API_TOKEN}",
      "auto_create_issues": {
        "enabled": true,
        "for_errors": true,
        "for_security_alerts": true
      }
    },
    "splunk": {
      "enabled": false,
      "hec_url": "${SPLUNK_HEC_URL}",
      "hec_token": "${SPLUNK_HEC_TOKEN}",
      "source_type": "cloudscope",
      "index": "cloudscope"
    },
    "datadog": {
      "enabled": false,
      "api_key": "${DATADOG_API_KEY}",
      "site": "datadoghq.com",
      "tags": ["env:prod", "service:cloudscope"]
    }
  }
}
```

## Environment Variables

### Core Variables
```bash
# Storage
export CLOUDSCOPE_STORAGE_TYPE="sqlite"
export CLOUDSCOPE_DATA_DIR="/var/lib/cloudscope"

# Security
export JWT_SECRET="your-secret-key"
export ENCRYPTION_KEY="your-encryption-key"

# Cloud Providers
export AWS_ACCESS_KEY_ID="your-key"
export AWS_SECRET_ACCESS_KEY="your-secret"
export AZURE_TENANT_ID="your-tenant"
export AZURE_CLIENT_ID="your-client-id"
export AZURE_CLIENT_SECRET="your-secret"
export GCP_SERVICE_ACCOUNT_KEY="/path/to/key.json"

# Integrations
export SLACK_WEBHOOK_URL="https://hooks.slack.com/..."
export JIRA_URL="https://your-domain.atlassian.net"
export JIRA_API_TOKEN="your-token"

# Observability
export OTEL_EXPORTER_OTLP_ENDPOINT="http://localhost:4317"
export OTEL_SERVICE_NAME="cloudscope"
```

## Configuration Management

### Version Control (Requirements: 10.1, 10.2, 10.5)
```bash
# Initialize configuration versioning
cloudscope config init --versioned

# Show configuration history
cloudscope config history

# Show specific version
cloudscope config show --version 3

# Compare versions
cloudscope config diff --from 2 --to 3
```

### Configuration Validation
```bash
# Validate configuration file
cloudscope config validate --file config.json

# Test configuration without applying
cloudscope config test --file new-config.json

# Check for deprecated settings
cloudscope config check-deprecations
```

### Rollback Capabilities
```bash
# Rollback to previous version
cloudscope config rollback

# Rollback to specific version
cloudscope config rollback --version 2

# Rollback with confirmation
cloudscope config rollback --version 2 --confirm
```

## Advanced Configuration

### Multi-Environment Setup
```bash
# Development
cloudscope --config config/dev.json

# Staging
cloudscope --config config/staging.json

# Production
cloudscope --config config/prod.json
```

### Dynamic Configuration
```json
{
  "dynamic": {
    "enabled": true,
    "sources": [
      {
        "type": "consul",
        "address": "consul.service.consul:8500",
        "prefix": "cloudscope/config"
      },
      {
        "type": "vault",
        "address": "vault.service.consul:8200",
        "path": "secret/cloudscope"
      }
    ],
    "refresh_interval": 300
  }
}
```

### Feature Flags
```json
{
  "features": {
    "experimental_collectors": false,
    "advanced_relationship_detection": true,
    "ml_anomaly_detection": false,
    "beta_ui": false
  }
}
```

## Configuration Best Practices

1. **Use Environment Variables for Secrets**
   - Never commit secrets to version control
   - Use `.env` files for local development
   - Use secret management systems in production

2. **Version Your Configurations**
   - Enable configuration versioning
   - Document changes in commit messages
   - Test configurations before deployment

3. **Monitor Configuration Changes**
   - Enable audit logging for configuration changes
   - Set up alerts for critical changes
   - Review configuration diffs before applying

4. **Validate Configurations**
   - Always validate before applying
   - Use schema validation
   - Test in non-production environments first

5. **Use Configuration Profiles**
   - Separate configurations by environment
   - Use inheritance to reduce duplication
   - Override only what's necessary

## Troubleshooting Configuration Issues

### Common Problems

1. **Configuration Not Loading**
   ```bash
   # Check configuration path
   cloudscope config show --debug
   
   # Verify file permissions
   ls -la /etc/cloudscope/config.json
   ```

2. **Invalid Configuration**
   ```bash
   # Validate configuration
   cloudscope config validate --verbose
   
   # Check JSON syntax
   jq . config.json
   ```

3. **Environment Variables Not Working**
   ```bash
   # List loaded environment variables
   cloudscope config env
   
   # Check variable expansion
   cloudscope config show --expand-vars
   ```

## Migration from Older Versions

### From v1.x to v2.x
```bash
# Backup current configuration
cloudscope config backup --output config-v1-backup.json

# Run migration tool
cloudscope config migrate --from 1.x --to 2.x

# Verify migrated configuration
cloudscope config validate

# Apply migrated configuration
cloudscope config apply
```

## Next Steps

1. Review [Security Best Practices](SECURITY_GUIDE.md)
2. Set up [Monitoring and Alerts](MONITORING_GUIDE.md)
3. Configure [Plugins](PLUGINS_GUIDE.md)
4. Implement [Backup Strategy](BACKUP_GUIDE.md)