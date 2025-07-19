# CloudScope Monitoring Guide

## Overview

CloudScope provides comprehensive monitoring capabilities through structured logging, metrics collection, distributed tracing, and health checks (Requirements: 8.1, 8.2, 8.3, 8.4, 8.5).

## Architecture

```
┌─────────────────┐     ┌──────────────┐     ┌───────────────┐
│   CloudScope    │────▶│   Metrics    │────▶│  Prometheus   │
│   Application   │     │  Exporter    │     │   DataDog     │
└─────────────────┘     └──────────────┘     └───────────────┘
         │                      │                      │
         │              ┌──────────────┐     ┌───────────────┐
         │─────────────▶│    Logs      │────▶│  ELK Stack    │
         │              │  Aggregator  │     │   Splunk      │
         │              └──────────────┘     └───────────────┘
         │                      │                      │
         │              ┌──────────────┐     ┌───────────────┐
         └─────────────▶│   Traces     │────▶│    Jaeger     │
                        │  Collector   │     │   Zipkin      │
                        └──────────────┘     └───────────────┘
```

## Structured Logging (Requirements: 8.1, 8.4)

### Log Format
All CloudScope logs use structured JSON format:

```json
{
  "timestamp": "2024-01-20T10:30:45.123Z",
  "level": "INFO",
  "service": "cloudscope",
  "component": "collector.aws",
  "trace_id": "abc123def456",
  "span_id": "789ghi012",
  "message": "AWS collection completed",
  "context": {
    "region": "us-east-1",
    "assets_collected": 342,
    "duration_ms": 5234,
    "errors": 0
  }
}
```

### Log Levels
- **DEBUG**: Detailed debugging information
- **INFO**: General operational information
- **WARNING**: Warning conditions that don't prevent operation
- **ERROR**: Error conditions that may affect functionality
- **CRITICAL**: Critical conditions requiring immediate attention

### Logging Configuration
```json
{
  "logging": {
    "level": "INFO",
    "format": "json",
    "outputs": [
      {
        "type": "file",
        "path": "/var/log/cloudscope/app.log",
        "rotation": {
          "max_size": "100MB",
          "max_files": 10,
          "compress": true
        }
      },
      {
        "type": "syslog",
        "protocol": "tcp",
        "address": "syslog.internal:514",
        "facility": "local0"
      },
      {
        "type": "console",
        "format": "human",
        "color": true
      }
    ]
  }
}
```

### Log Aggregation

#### ELK Stack Integration
```yaml
# logstash.conf
input {
  file {
    path => "/var/log/cloudscope/*.log"
    codec => "json"
    type => "cloudscope"
  }
}

filter {
  if [type] == "cloudscope" {
    date {
      match => [ "timestamp", "ISO8601" ]
    }
    
    mutate {
      add_field => { "environment" => "${ENVIRONMENT}" }
    }
  }
}

output {
  elasticsearch {
    hosts => ["elasticsearch:9200"]
    index => "cloudscope-%{+YYYY.MM.dd}"
  }
}
```

#### Splunk Integration
```bash
# Send logs to Splunk HEC
./external-integrations.sh splunk "$SPLUNK_HEC_URL" "$SPLUNK_TOKEN" '{"event": "log_data"}' "cloudscope"
```

## Metrics Collection (Requirements: 8.2, 8.3, 8.4)

### Available Metrics

#### Application Metrics
- `cloudscope_assets_total`: Total number of assets by type
- `cloudscope_collection_duration_seconds`: Collection duration histogram
- `cloudscope_collection_errors_total`: Total collection errors
- `cloudscope_api_requests_total`: API request counter
- `cloudscope_api_request_duration_seconds`: API response time histogram

#### System Metrics
- `cloudscope_cpu_usage_percent`: CPU usage percentage
- `cloudscope_memory_usage_bytes`: Memory usage in bytes
- `cloudscope_disk_usage_bytes`: Disk usage by path
- `cloudscope_goroutines_count`: Number of active goroutines

#### Business Metrics
- `cloudscope_assets_discovered_total`: New assets discovered
- `cloudscope_assets_modified_total`: Assets modified
- `cloudscope_relationships_total`: Total relationships
- `cloudscope_compliance_score`: Compliance score (0-100)

### Prometheus Configuration

#### Prometheus Scrape Config
```yaml
# prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'cloudscope'
    static_configs:
      - targets: ['cloudscope:8080']
    metrics_path: '/metrics'
    scrape_interval: 30s
```

#### Custom Metrics Example
```python
from prometheus_client import Counter, Histogram, Gauge

# Define metrics
assets_collected = Counter(
    'cloudscope_assets_collected_total',
    'Total assets collected',
    ['provider', 'type']
)

collection_duration = Histogram(
    'cloudscope_collection_duration_seconds',
    'Collection duration in seconds',
    ['provider']
)

active_collectors = Gauge(
    'cloudscope_active_collectors',
    'Number of active collectors'
)

# Use metrics
assets_collected.labels(provider='aws', type='ec2').inc(42)
with collection_duration.labels(provider='aws').time():
    # Collection logic
    pass
active_collectors.set(3)
```

### DataDog Integration
```bash
# Send custom metrics to DataDog
./external-integrations.sh datadog "$DD_API_KEY" "assets.total" "1523" "env:prod,service:cloudscope"
```

## Distributed Tracing (Requirements: 8.2, 8.3, 8.4)

### OpenTelemetry Setup

#### Configuration
```json
{
  "tracing": {
    "enabled": true,
    "service_name": "cloudscope",
    "endpoint": "http://otel-collector:4317",
    "sampling": {
      "type": "probability",
      "rate": 0.1
    },
    "propagators": ["w3c", "jaeger", "b3"]
  }
}
```

#### Instrumentation Example
```python
from opentelemetry import trace
from opentelemetry.trace import Status, StatusCode

tracer = trace.get_tracer(__name__)

@tracer.start_as_current_span("collect_assets")
def collect_assets(provider):
    span = trace.get_current_span()
    span.set_attribute("provider", provider)
    
    try:
        # Collection logic
        assets = perform_collection()
        span.set_attribute("asset_count", len(assets))
        return assets
    except Exception as e:
        span.record_exception(e)
        span.set_status(Status(StatusCode.ERROR))
        raise
```

### Trace Context Propagation
```python
# HTTP request with trace context
import requests
from opentelemetry.propagate import inject

headers = {}
inject(headers)
response = requests.get("http://service/api", headers=headers)
```

## Health Checks (Requirements: 8.3, 8.5)

### Health Check Framework

#### Endpoint Configuration
```json
{
  "health_checks": {
    "endpoint": "/health",
    "detailed_endpoint": "/health/detailed",
    "checks": {
      "database": {
        "enabled": true,
        "critical": true,
        "timeout": 5,
        "interval": 30
      },
      "storage": {
        "enabled": true,
        "critical": true,
        "timeout": 3,
        "interval": 60
      },
      "collectors": {
        "enabled": true,
        "critical": false,
        "timeout": 10,
        "interval": 120
      },
      "memory": {
        "enabled": true,
        "critical": false,
        "threshold_percent": 80
      }
    }
  }
}
```

#### Health Check Response
```json
{
  "status": "healthy",
  "timestamp": "2024-01-20T10:30:45Z",
  "version": "1.4.0",
  "checks": {
    "database": {
      "status": "healthy",
      "latency_ms": 12,
      "message": "Connected to SQLite"
    },
    "storage": {
      "status": "healthy",
      "latency_ms": 5,
      "message": "Storage accessible"
    },
    "collectors": {
      "status": "degraded",
      "message": "AWS collector unavailable",
      "details": {
        "aws": "unhealthy",
        "azure": "healthy",
        "gcp": "healthy"
      }
    }
  }
}
```

### Custom Health Checks
```python
from cloudscope.health import HealthChecker, HealthStatus

class DatabaseHealthCheck:
    def check(self) -> HealthStatus:
        try:
            # Test database connection
            db.execute("SELECT 1")
            return HealthStatus(
                status="healthy",
                message="Database connection successful"
            )
        except Exception as e:
            return HealthStatus(
                status="unhealthy",
                message=f"Database error: {str(e)}"
            )

# Register health check
health_checker.register("database", DatabaseHealthCheck())
```

## Performance Monitoring (Requirements: 8.3, 8.4)

### Performance Metrics

#### Response Time Monitoring
```python
from functools import wraps
import time

def monitor_performance(operation_name):
    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            start_time = time.time()
            try:
                result = func(*args, **kwargs)
                duration = time.time() - start_time
                
                # Record metric
                performance_histogram.labels(
                    operation=operation_name
                ).observe(duration)
                
                # Log if exceeds threshold
                if duration > PERFORMANCE_THRESHOLD:
                    logger.warning(
                        f"Performance threshold exceeded",
                        operation=operation_name,
                        duration_seconds=duration
                    )
                
                return result
            except Exception as e:
                duration = time.time() - start_time
                error_counter.labels(
                    operation=operation_name
                ).inc()
                raise
        return wrapper
    return decorator
```

#### Memory Profiling
```python
import tracemalloc
import psutil

def monitor_memory():
    # Get current memory usage
    process = psutil.Process()
    memory_info = process.memory_info()
    
    # Record metrics
    memory_gauge.set(memory_info.rss)
    
    # Check threshold
    memory_percent = process.memory_percent()
    if memory_percent > MEMORY_THRESHOLD:
        logger.warning(
            f"High memory usage: {memory_percent:.1f}%",
            rss_bytes=memory_info.rss,
            vms_bytes=memory_info.vms
        )
```

## Alerting Configuration

### Alert Rules

#### Prometheus Alerting Rules
```yaml
# alerts.yml
groups:
  - name: cloudscope_alerts
    interval: 30s
    rules:
      # High error rate
      - alert: HighErrorRate
        expr: rate(cloudscope_errors_total[5m]) > 0.1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High error rate detected"
          description: "Error rate is {{ $value }} errors/sec"
      
      # Collection failures
      - alert: CollectionFailure
        expr: cloudscope_collection_failures_total > 5
        for: 10m
        labels:
          severity: critical
        annotations:
          summary: "Collection failures detected"
          description: "{{ $value }} collection failures"
      
      # Memory usage
      - alert: HighMemoryUsage
        expr: cloudscope_memory_usage_bytes / 1024 / 1024 / 1024 > 2
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage"
          description: "Memory usage is {{ $value }}GB"
      
      # API latency
      - alert: HighAPILatency
        expr: histogram_quantile(0.95, cloudscope_api_request_duration_seconds) > 1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High API latency"
          description: "95th percentile latency is {{ $value }}s"
```

### Alert Routing
```yaml
# alertmanager.yml
route:
  group_by: ['alertname', 'severity']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 12h
  receiver: 'default'
  routes:
    - match:
        severity: critical
      receiver: 'pagerduty'
    - match:
        severity: warning
      receiver: 'slack'

receivers:
  - name: 'default'
    webhook_configs:
      - url: 'http://cloudscope/webhooks/alerts'
  
  - name: 'pagerduty'
    pagerduty_configs:
      - service_key: '${PAGERDUTY_SERVICE_KEY}'
  
  - name: 'slack'
    slack_configs:
      - api_url: '${SLACK_WEBHOOK_URL}'
        channel: '#cloudscope-alerts'
```

## Dashboard Templates

### Grafana Dashboard
```json
{
  "dashboard": {
    "title": "CloudScope Monitoring",
    "panels": [
      {
        "title": "Asset Count by Type",
        "targets": [{
          "expr": "sum(cloudscope_assets_total) by (type)"
        }],
        "type": "graph"
      },
      {
        "title": "Collection Duration",
        "targets": [{
          "expr": "histogram_quantile(0.95, cloudscope_collection_duration_seconds)"
        }],
        "type": "graph"
      },
      {
        "title": "Error Rate",
        "targets": [{
          "expr": "rate(cloudscope_errors_total[5m])"
        }],
        "type": "graph"
      },
      {
        "title": "API Response Time",
        "targets": [{
          "expr": "histogram_quantile(0.95, cloudscope_api_request_duration_seconds)"
        }],
        "type": "graph"
      }
    ]
  }
}
```

## Monitoring Best Practices

### 1. Use Structured Logging
- Include trace IDs in all logs
- Use consistent field names
- Add contextual information
- Avoid sensitive data in logs

### 2. Implement SLIs/SLOs
```yaml
# SLI: API availability
- name: api_availability
  query: |
    sum(rate(cloudscope_api_requests_total{status!~"5.."}[5m])) /
    sum(rate(cloudscope_api_requests_total[5m]))
  target: 0.999

# SLO: Collection success rate
- name: collection_success_rate
  query: |
    sum(rate(cloudscope_collection_success_total[1h])) /
    sum(rate(cloudscope_collection_attempts_total[1h]))
  target: 0.95
```

### 3. Monitor Business Metrics
- Asset discovery rate
- Compliance scores
- Cost optimization savings
- Security vulnerability trends

### 4. Set Up Runbooks
Link alerts to runbooks for quick resolution:
```yaml
annotations:
  runbook_url: "https://wiki.internal/cloudscope/runbooks/high-error-rate"
```

## Troubleshooting Monitoring Issues

### Missing Metrics
```bash
# Check metrics endpoint
curl http://localhost:8080/metrics

# Verify Prometheus scraping
curl http://prometheus:9090/api/v1/targets
```

### Log Collection Issues
```bash
# Check log output
tail -f /var/log/cloudscope/app.log

# Verify log format
jq . /var/log/cloudscope/app.log | head
```

### Trace Connectivity
```bash
# Test OpenTelemetry collector
curl http://otel-collector:13133/v1/health
```

## Monitoring Scripts

### Quick Status Check
```bash
#!/bin/bash
# check-monitoring.sh

echo "=== CloudScope Monitoring Status ==="

# Check health endpoint
echo -n "Health Check: "
curl -s http://localhost:8080/health | jq -r .status

# Check metrics
echo -n "Metrics Available: "
curl -s http://localhost:8080/metrics | grep -c "cloudscope_"

# Check recent errors
echo "Recent Errors:"
grep ERROR /var/log/cloudscope/app.log | tail -5
```

## Next Steps

1. Set up [Alerting Rules](ALERTING_GUIDE.md)
2. Create [Custom Dashboards](DASHBOARDS_GUIDE.md)
3. Implement [SLI/SLO Monitoring](SLO_GUIDE.md)
4. Configure [Log Analysis](LOG_ANALYSIS_GUIDE.md)