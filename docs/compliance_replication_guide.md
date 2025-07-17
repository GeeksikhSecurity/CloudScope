# Compliance-as-Code Replication Guide

## Overview

This guide shows how to replicate CloudScope's compliance-as-code framework across different Git repositories and adapt it for various AI development tools.

## Part 1: Creating a Reusable Compliance Framework

### 1.1 Extract Core Components into a Template Repository

Create a new repository `compliance-as-code-template`:

```bash
# Create template repository structure
mkdir compliance-as-code-template
cd compliance-as-code-template

# Core compliance models (language-agnostic)
mkdir -p core/models
mkdir -p core/interfaces
mkdir -p core/mappings

# Framework-specific implementations
mkdir -p frameworks/owasp-asvs
mkdir -p frameworks/soc2
mkdir -p frameworks/iso27001

# Tool integrations
mkdir -p integrations/kiro
mkdir -p integrations/claude
mkdir -p integrations/aws-q

# Scripts and automation
mkdir -p scripts
mkdir -p hooks
```

### 1.2 Create Universal Compliance Schema

```yaml
# core/schema/compliance-meta.yaml
compliance_framework:
  name: "Universal Compliance Schema"
  version: "1.0.0"
  
  control_template:
    id: string
    framework: enum[OWASP_ASVS, SOC2, ISO27001, PCI_DSS, HIPAA]
    category: string
    title: string
    description: string
    severity: enum[CRITICAL, HIGH, MEDIUM, LOW, INFO]
    automated: boolean
    implementation_guidance: string
    verification_steps: list
    
  asset_types:
    - web_application
    - api
    - database
    - infrastructure
    - mobile_app
    - desktop_app
```

### 1.3 Python Implementation Package

Create a pip-installable package:

```python
# setup.py
from setuptools import setup, find_packages

setup(
    name="compliance-as-code",
    version="1.0.0",
    packages=find_packages(),
    install_requires=[
        "pyyaml>=6.0",
        "jsonschema>=4.0",
        "click>=8.0",
    ],
    entry_points={
        'console_scripts': [
            'cac-init=compliance_as_code.cli:init',
            'cac-check=compliance_as_code.cli:check',
            'cac-report=compliance_as_code.cli:report',
        ],
    },
)
```

## Part 2: Replication Script for Any Git Repository

### 2.1 Universal Installation Script

```bash
#!/bin/bash
# install-compliance.sh

echo "=== Installing Compliance-as-Code Framework ==="

# Detect project type
detect_project_type() {
    if [ -f "package.json" ]; then
        echo "node"
    elif [ -f "requirements.txt" ] || [ -f "setup.py" ] || [ -f "pyproject.toml" ]; then
        echo "python"
    elif [ -f "go.mod" ]; then
        echo "go"
    elif [ -f "pom.xml" ]; then
        echo "java"
    else
        echo "generic"
    fi
}

PROJECT_TYPE=$(detect_project_type)
echo "Detected project type: $PROJECT_TYPE"

# Create compliance directory structure
mkdir -p .compliance/{models,checks,reports,config}
mkdir -p .github/workflows
mkdir -p .kiro/{specs,steering,hooks}

# Download core compliance files
curl -sL https://github.com/your-org/compliance-as-code-template/archive/main.tar.gz | tar xz
cp -r compliance-as-code-template-main/core/* .compliance/

# Install language-specific components
case $PROJECT_TYPE in
    python)
        pip install compliance-as-code
        cp compliance-as-code-template-main/languages/python/* .compliance/
        ;;
    node)
        npm install @compliance/as-code
        cp compliance-as-code-template-main/languages/javascript/* .compliance/
        ;;
    *)
        echo "Using generic compliance templates"
        ;;
esac

# Setup Git hooks
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
# Run compliance checks before commit
python -m compliance_as_code check --format json > .compliance/reports/pre-commit-check.json
if [ $? -ne 0 ]; then
    echo "❌ Compliance checks failed. See .compliance/reports/pre-commit-check.json"
    exit 1
fi
EOF
chmod +x .git/hooks/pre-commit

echo "✅ Compliance-as-Code framework installed successfully!"
```

### 2.2 Framework Configuration

```yaml
# .compliance/config/frameworks.yaml
enabled_frameworks:
  - name: OWASP_ASVS
    version: "5.0"
    level: 2  # L1, L2, or L3
    config_file: owasp-asvs-v5.yaml
    
  - name: SOC2
    trust_services: [CC6.1, CC7.2, CC8.1]
    config_file: soc2-controls.yaml
    
  - name: ISO27001
    enabled: true
    config_file: iso27001-controls.yaml

scanning:
  auto_remediation: true
  fail_on_critical: true
  generate_reports: true
  
integrations:
  github_issues: true
  slack_notifications: false
  email_alerts: false
```

## Part 3: Adapting for Claude Code

Since Claude Code doesn't have Kiro's steering/hooks, we use alternative approaches:

### 3.1 Claude Code Integration Strategy

```python
# .claude/compliance_context.py
"""
Context file for Claude to understand compliance requirements
Place this in your project root for Claude to reference
"""

COMPLIANCE_RULES = """
# Compliance Requirements for This Project

## OWASP ASVS 5.0 Requirements
1. **Authentication (V1)**
   - Password minimum 12 characters (V1.2.3)
   - MFA required for admin (V1.2.4)
   
2. **Session Management (V3)**
   - Session timeout after 30 minutes (V3.3.1)
   - Secure session token generation (V3.2.1)

## SOC2 Controls
- CC6.1: Logical and Physical Access Controls
- CC7.2: System Monitoring
- CC8.1: Change Management

## Implementation Notes
- All user inputs must be validated
- All outputs must be encoded
- Use parameterized queries for database access
- Log all security events
"""

# Include in your prompts to Claude:
CLAUDE_PROMPT_PREFIX = """
You are working on a project with strict compliance requirements.
Please ensure all code follows these rules:
{COMPLIANCE_RULES}
"""
```

### 3.2 Claude-Friendly Compliance Checklist

```markdown
# .claude/compliance_checklist.md

## Before Writing Code, Ask Claude To:

1. **Review Compliance Requirements**
   ```
   "Please review the compliance requirements in .claude/compliance_context.py 
   before implementing [feature]"
   ```

2. **Generate Compliant Code**
   ```
   "Implement [feature] ensuring it meets OWASP ASVS L2 requirements,
   particularly V5 (Input Validation) and V3 (Session Management)"
   ```

3. **Verify Compliance**
   ```
   "Review this code for compliance with our security requirements.
   Check for: input validation, output encoding, secure session handling"
   ```

## Compliance Verification Prompts

- "Does this authentication flow meet OWASP ASVS V1.2.3 and V1.2.4?"
- "Verify this meets SOC2 CC6.1 access control requirements"
- "Add compliance documentation comments referencing specific controls"
```

### 3.3 Automated Compliance Checking for Claude Projects

```python
# scripts/check_claude_compliance.py
#!/usr/bin/env python3
"""
Run this after Claude generates code to verify compliance
"""
import ast
import re
from pathlib import Path

class ComplianceChecker:
    def __init__(self):
        self.violations = []
        
    def check_file(self, filepath):
        """Check a single file for compliance violations"""
        content = Path(filepath).read_text()
        
        # Check for hardcoded passwords
        if re.search(r'password\s*=\s*["\'][^"\']+["\']', content, re.I):
            self.violations.append(f"{filepath}: Hardcoded password found (ASVS V2.1.1)")
            
        # Check for SQL injection vulnerabilities
        if re.search(r'(query|execute)\s*\(\s*["\'].*%[sf].*["\'].*%', content):
            self.violations.append(f"{filepath}: Potential SQL injection (ASVS V5.3.3)")
            
        # Check for missing input validation
        if 'request.' in content and 'validate' not in content:
            self.violations.append(f"{filepath}: Missing input validation (ASVS V5.1.1)")
            
        return self.violations

# Usage:
# python scripts/check_claude_compliance.py src/
```

## Part 4: AWS Q Developer Integration

### 4.1 AWS Q Developer Configuration

```json
// .q/security-config.json
{
  "security_scanning": {
    "enabled": true,
    "scanners": [
      {
        "name": "OWASP_ASVS_Scanner",
        "rules": "https://github.com/your-org/asvs-rules-q.json",
        "severity_threshold": "MEDIUM"
      }
    ]
  },
  "code_suggestions": {
    "include_security_context": true,
    "compliance_frameworks": ["OWASP_ASVS_5.0", "SOC2"],
    "auto_fix_violations": true
  },
  "custom_prompts": {
    "security_review": "Review code for OWASP ASVS compliance",
    "generate_secure": "Generate secure code following OWASP ASVS"
  }
}
```

### 4.2 Q Developer Security Profile

```yaml
# .q/security-profile.yaml
name: "Compliance-First Development"
description: "Enforce OWASP ASVS and SOC2 compliance"

rules:
  - id: "AUTH-001"
    framework: "OWASP_ASVS"
    control: "V1.2.3"
    description: "Enforce minimum password length"
    severity: "HIGH"
    
  - id: "INPUT-001"
    framework: "OWASP_ASVS"
    control: "V5.1.1"
    description: "Validate all inputs"
    severity: "CRITICAL"

actions:
  on_violation:
    - block_commit: true
    - suggest_fix: true
    - create_issue: true
```

## Part 5: Cross-Tool Compliance Workflows

### 5.1 Unified Compliance Pipeline

```yaml
# .github/workflows/compliance-check.yml
name: Unified Compliance Check

on: [push, pull_request]

jobs:
  compliance:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup Compliance Tools
      run: |
        pip install compliance-as-code
        npm install -g @compliance/cli
        
    - name: Run OWASP ASVS Checks
      run: |
        cac-check --framework owasp-asvs --level 2 --output json > asvs-report.json
        
    - name: Run SOC2 Checks
      run: |
        cac-check --framework soc2 --controls CC6.1,CC7.2 --output json > soc2-report.json
        
    - name: Generate Unified Report
      run: |
        cac-report combine asvs-report.json soc2-report.json --format html > compliance-report.html
        
    - name: Upload Reports
      uses: actions/upload-artifact@v3
      with:
        name: compliance-reports
        path: |
          *-report.json
          compliance-report.html
```

### 5.2 Tool-Specific Adaptations

```bash
#!/bin/bash
# adapt-compliance-for-tool.sh

TOOL=${1:-"claude"} # claude, kiro, or q

case $TOOL in
  claude)
    echo "Setting up for Claude Code..."
    mkdir -p .claude
    cp templates/claude/* .claude/
    echo "Add .claude/compliance_context.py to your project context"
    ;;
    
  kiro)
    echo "Setting up for AWS Kiro..."
    mkdir -p .kiro/{steering,hooks,specs}
    cp templates/kiro/steering/* .kiro/steering/
    cp templates/kiro/hooks.yaml .kiro/
    kiro sync
    ;;
    
  q)
    echo "Setting up for AWS Q Developer..."
    mkdir -p .q
    cp templates/q/* .q/
    echo "Q Developer will now use security profile"
    ;;
esac
```

## Part 6: Quick Start Commands

```bash
# 1. Clone and setup in any repository
git clone https://github.com/your-org/compliance-as-code-template
cd your-project
curl -sL https://your-domain/install-compliance.sh | bash

# 2. Configure for your tool
./adapt-compliance-for-tool.sh claude  # or kiro, or q

# 3. Run initial compliance check
cac-check --auto-fix

# 4. Generate compliance report
cac-report --format html --output compliance-status.html
```

## Summary

This approach provides:
1. **Universal compliance framework** that works across repositories
2. **Tool-specific adaptations** for Claude, Kiro, and Q Developer
3. **Automated checking and reporting**
4. **Easy replication** to any Git repository
5. **Continuous compliance** through Git hooks and CI/CD

The key is to maintain the compliance rules in a tool-agnostic format and provide adapters for each development tool's specific features.