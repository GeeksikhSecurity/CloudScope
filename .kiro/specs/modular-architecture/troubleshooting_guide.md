# Troubleshooting Guide for CloudScope Modular Architecture

This guide provides solutions for common issues encountered when working with the CloudScope modular architecture. It is designed to be used alongside the Kiro rules and technical notes.

## Common Issues and Solutions

### 1. Plugin Loading Failures

**Symptoms:**
- Plugins not appearing in the available plugins list
- Error messages about missing dependencies
- Plugin loading exceptions in logs

**Troubleshooting Steps:**

1. **Check Plugin Structure**
   ```bash
   # Verify plugin directory structure
   ls -la /path/to/plugins/
   
   # Check plugin file permissions
   chmod 644 /path/to/plugins/*.py
   ```

2. **Validate Plugin Interface Implementation**
   ```python
   # Plugin must implement all required methods
   class MyPlugin(Plugin):
       def get_name(self) -> str:
           return "my-plugin"
       
       def get_version(self) -> str:
           return "1.0.0"
       
       def get_api_version(self) -> str:
           return "1.0.0"
   ```

3. **Check Dependencies**
   ```bash
   # Install plugin dependencies
   pip install -r /path/to/plugins/requirements.txt
   
   # Check for version conflicts
   pip check
   ```

4. **Enable Debug Logging**
   ```bash
   # Set environment variable for debug logging
   export CLOUDSCOPE_LOG_LEVEL=DEBUG
   
   # Run with verbose plugin loading
   cloudscope run --verbose
   ```

### 2. Database Connection Issues

**Symptoms:**
- Error messages about failed database connections
- Timeout errors when accessing data
- Repository operations failing

**Troubleshooting Steps:**

1. **Check Database Configuration**
   ```bash
   # Verify configuration file
   cat /etc/cloudscope/config.yaml | grep database -A 10
   
   # Check environment variables
   env | grep CLOUDSCOPE_DB
   ```

2. **Test Database Connectivity**
   ```bash
   # For file-based storage
   ls -la /path/to/data/directory
   
   # For SQLite
   sqlite3 /path/to/database.db .tables
   
   # For Memgraph
   telnet localhost 7687
   ```

3. **Check Permissions**
   ```bash
   # Verify file permissions
   sudo chown -R cloudscope:cloudscope /path/to/data/directory
   
   # Check database user permissions
   sudo -u cloudscope touch /path/to/data/test.txt
   ```

4. **Use Fallback Storage**
   ```bash
   # Force file-based storage
   export CLOUDSCOPE_DB_ADAPTER=file
   export CLOUDSCOPE_DB_PATH=/tmp/cloudscope-fallback
   ```

### 3. Performance Issues

**Symptoms:**
- Slow response times
- High memory usage
- CPU spikes during operations

**Troubleshooting Steps:**

1. **Check Resource Usage**
   ```bash
   # Monitor system resources
   top -u cloudscope
   
   # Check disk I/O
   iostat -x 5
   ```

2. **Enable Performance Metrics**
   ```bash
   # Enable detailed metrics
   export CLOUDSCOPE_METRICS_ENABLED=true
   
   # View metrics dashboard
   open http://localhost:3000/dashboards/performance
   ```

3. **Optimize Batch Sizes**
   ```bash
   # Adjust batch size for large datasets
   export CLOUDSCOPE_BATCH_SIZE=500
   ```

4. **Enable Caching**
   ```bash
   # Configure caching
   export CLOUDSCOPE_CACHE_ENABLED=true
   export CLOUDSCOPE_CACHE_TTL=3600
   ```

### 4. Kiro Rule Violations

**Symptoms:**
- CI/CD pipeline failures
- Pre-commit hook rejections
- Error messages about rule violations

**Troubleshooting Steps:**

1. **Check Rule Violations**
   ```bash
   # Run Kiro safeguards with verbose output
   kiro safeguard check --verbose
   
   # Check specific rule
   kiro safeguard check --rule hexagonal-architecture
   ```

2. **Fix Common Violations**
   ```bash
   # Fix domain layer imports
   grep -r "from cloudscope.adapters" cloudscope/domain/
   
   # Fix missing docstrings
   kiro fix docstrings
   ```

3. **Temporarily Disable Rules**
   ```bash
   # Disable specific rule for development
   export KIRO_DISABLED_RULES=docstring-coverage
   
   # Add inline rule exception
   # kiro-disable-next-line: test-first-development
   ```

4. **Update Rule Configuration**
   ```bash
   # Adjust rule severity
   vi .kiro/safeguards/documentation-rules.yaml
   ```

## Integration with Kiro Rules

The troubleshooting steps above can be integrated with Kiro rules to provide automated diagnostics and solutions:

```yaml
# .kiro/safeguards/troubleshooting-rules.yaml
name: "Troubleshooting Rules"
description: "Rules for diagnosing and fixing common issues"
version: "1.0.0"
rules:
  - name: "plugin-structure-check"
    description: "Checks plugin structure for common issues"
    check:
      type: "custom-script"
      script: ".kiro/scripts/check_plugin_structure.py"
    message: "Plugin structure issues detected"
    fix:
      type: "custom-script"
      script: ".kiro/scripts/fix_plugin_structure.py"
    severity: "warning"
  
  - name: "database-connectivity-check"
    description: "Checks database connectivity"
    check:
      type: "custom-script"
      script: ".kiro/scripts/check_db_connectivity.py"
    message: "Database connectivity issues detected"
    fix:
      type: "custom-script"
      script: ".kiro/scripts/fix_db_connectivity.py"
    severity: "error"
  
  - name: "performance-check"
    description: "Checks for performance bottlenecks"
    check:
      type: "custom-script"
      script: ".kiro/scripts/check_performance.py"
    message: "Performance issues detected"
    fix:
      type: "custom-script"
      script: ".kiro/scripts/optimize_performance.py"
    severity: "warning"
```

## Automated Diagnostics

Kiro can be extended with automated diagnostic tools:

```python
# .kiro/scripts/diagnose.py
#!/usr/bin/env python3
"""
Automated diagnostics for CloudScope.
"""
import os
import sys
import subprocess
import json

def check_environment():
    """Check environment configuration."""
    issues = []
    
    # Check Python version
    python_version = sys.version_info
    if python_version.major < 3 or (python_version.major == 3 and python_version.minor < 9):
        issues.append("Python version must be 3.9 or higher")
    
    # Check required environment variables
    required_vars = ["CLOUDSCOPE_CONFIG_PATH"]
    for var in required_vars:
        if var not in os.environ:
            issues.append(f"Missing environment variable: {var}")
    
    return issues

def check_dependencies():
    """Check required dependencies."""
    issues = []
    
    # Check required packages
    required_packages = ["fastapi", "pydantic", "uvicorn", "pytest"]
    for package in required_packages:
        try:
            __import__(package)
        except ImportError:
            issues.append(f"Missing required package: {package}")
    
    return issues

def check_configuration():
    """Check configuration files."""
    issues = []
    
    # Check config file exists
    config_path = os.environ.get("CLOUDSCOPE_CONFIG_PATH", "/etc/cloudscope/config.yaml")
    if not os.path.exists(config_path):
        issues.append(f"Configuration file not found: {config_path}")
    
    return issues

def main():
    """Run diagnostics and report issues."""
    all_issues = []
    
    all_issues.extend(check_environment())
    all_issues.extend(check_dependencies())
    all_issues.extend(check_configuration())
    
    if all_issues:
        print("Diagnostic issues found:")
        for issue in all_issues:
            print(f"- {issue}")
        sys.exit(1)
    else:
        print("No issues found. Environment is correctly configured.")
        sys.exit(0)

if __name__ == "__main__":
    main()
```

## Conclusion

This troubleshooting guide provides solutions for common issues encountered when working with the CloudScope modular architecture. By integrating these troubleshooting steps with Kiro rules, we can provide automated diagnostics and solutions for developers.