# Kiro Rules for CloudScope Modular Architecture

## Overview

This document defines the Kiro rules and safeguards that enforce the architectural principles, lean stack methodology, TDD practices, and compliance requirements for the CloudScope modular architecture. These rules are implemented as automated checks that run during development and in CI/CD pipelines.

The rules are organized into categories including technical rules, troubleshooting rules, and compliance as code rules, providing a comprehensive framework for maintaining code quality and ensuring adherence to architectural principles.

## Rule Categories

### 1. Test-Driven Development Rules

These rules enforce the TDD methodology of writing tests before implementation code.

```yaml
# .kiro/safeguards/tdd-rules.yaml
name: "Test-Driven Development Rules"
description: "Ensures tests are written before implementation code"
version: "1.0.0"
rules:
  - name: "test-first-development"
    description: "Ensures tests are written before implementation code"
    check:
      type: "file-pattern"
      pattern: "test_*.py"
      condition: "must-exist-before"
      target-pattern: "*.py"
      exclude: ["__init__.py", "conftest.py"]
    message: "Tests must be written before implementation code"
    severity: "error"
    
  - name: "test-coverage"
    description: "Ensures adequate test coverage"
    check:
      type: "coverage-check"
      min-coverage: 80
      critical-paths:
        - "cloudscope/domain/**/*.py"
        - "cloudscope/ports/**/*.py"
      min-critical-coverage: 90
    message: "Test coverage below threshold"
    severity: "warning"
    
  - name: "test-naming-convention"
    description: "Ensures test files follow naming conventions"
    check:
      type: "file-pattern"
      pattern: "tests/**/*.py"
      content-pattern: "^(import|from).*pytest"
      condition: "must-contain"
    message: "Test files must import pytest and follow naming conventions"
    severity: "warning"
```

### 2. Hexagonal Architecture Rules

These rules enforce the hexagonal architecture pattern, ensuring proper separation of concerns.

```yaml
# .kiro/safeguards/hexagonal-architecture-rules.yaml
name: "Hexagonal Architecture Rules"
description: "Enforces hexagonal architecture principles"
version: "1.0.0"
rules:
  - name: "domain-independence"
    description: "Ensures domain layer doesn't depend on adapters"
    check:
      type: "import-check"
      source-pattern: "cloudscope/domain/**/*.py"
      forbidden-imports: 
        - "cloudscope/adapters/**"
        - "cloudscope/infrastructure/**"
    message: "Domain layer cannot depend on adapter or infrastructure layers"
    severity: "error"
    
  - name: "ports-independence"
    description: "Ensures ports don't depend on specific adapters"
    check:
      type: "import-check"
      source-pattern: "cloudscope/ports/**/*.py"
      forbidden-imports: ["cloudscope/adapters/**"]
    message: "Ports cannot depend on specific adapter implementations"
    severity: "error"
    
  - name: "adapter-implementation"
    description: "Ensures adapters implement the correct ports"
    check:
      type: "inheritance-check"
      source-pattern: "cloudscope/adapters/**/*.py"
      must-inherit-from: ["cloudscope.ports.*"]
    message: "Adapters must implement port interfaces"
    severity: "error"
```

### 3. Documentation Rules

These rules enforce documentation standards.

```yaml
# .kiro/safeguards/documentation-rules.yaml
name: "Documentation Rules"
description: "Enforces documentation standards"
version: "1.0.0"
rules:
  - name: "docstring-coverage"
    description: "Ensures all public functions and classes have docstrings"
    check:
      type: "docstring-check"
      pattern: "**/*.py"
      exclude: ["tests/**"]
      min-coverage: 80
    message: "All public functions and classes must have docstrings"
    severity: "warning"
    
  - name: "example-code"
    description: "Ensures documentation includes examples"
    check:
      type: "content-check"
      pattern: "docs/**/*.md"
      content-pattern: "```(python|bash)"
      condition: "must-contain"
    message: "Documentation must include code examples"
    severity: "warning"
    
  - name: "api-documentation"
    description: "Ensures API changes update documentation"
    check:
      type: "file-change-check"
      source-pattern: "cloudscope/ports/**/*.py"
      related-pattern: "docs/api/**/*.md"
      condition: "must-change-together"
    message: "API changes must update corresponding documentation"
    severity: "warning"
```

### 4. Progressive Enhancement Rules

These rules enforce the progressive enhancement approach.

```yaml
# .kiro/safeguards/progressive-enhancement-rules.yaml
name: "Progressive Enhancement Rules"
description: "Enforces progressive enhancement approach"
version: "1.0.0"
rules:
  - name: "fallback-implementation"
    description: "Ensures advanced features have fallbacks"
    check:
      type: "custom-script"
      script: ".kiro/scripts/check_fallbacks.py"
    message: "Advanced features must have simple fallbacks"
    severity: "warning"
    
  - name: "feature-flags"
    description: "Ensures features can be toggled"
    check:
      type: "content-check"
      pattern: "cloudscope/features/**/*.py"
      content-pattern: "feature_enabled\\("
      condition: "must-contain"
    message: "Features should be toggleable with feature flags"
    severity: "warning"
    
  - name: "graceful-degradation"
    description: "Ensures error handling allows graceful degradation"
    check:
      type: "content-check"
      pattern: "cloudscope/adapters/**/*.py"
      content-pattern: "try:.*except.*:"
      condition: "must-contain"
    message: "Adapters must implement error handling for graceful degradation"
    severity: "warning"
```

### 5. Security Rules

These rules enforce security best practices.

```yaml
# .kiro/safeguards/security-rules.yaml
name: "Security Rules"
description: "Enforces security best practices"
version: "1.0.0"
rules:
  - name: "input-validation"
    description: "Ensures all inputs are validated"
    check:
      type: "content-check"
      pattern: "cloudscope/adapters/**/*.py"
      content-pattern: "(validate|sanitize)"
      condition: "must-contain"
    message: "All inputs must be validated or sanitized"
    severity: "error"
    
  - name: "no-hardcoded-secrets"
    description: "Ensures no hardcoded secrets"
    check:
      type: "content-check"
      pattern: "**/*.py"
      content-pattern: "(password|secret|key|token)\\s*=\\s*['\"][^'\"]+['\"]"
      condition: "must-not-contain"
    message: "No hardcoded secrets allowed"
    severity: "error"
    
  - name: "secure-by-default"
    description: "Ensures secure defaults"
    check:
      type: "custom-script"
      script: ".kiro/scripts/check_secure_defaults.py"
    message: "All components must have secure defaults"
    severity: "error"
```

### 6. Troubleshooting Rules

These rules help diagnose and fix common issues in the codebase.

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
    
  - name: "dependency-check"
    description: "Checks for missing or conflicting dependencies"
    check:
      type: "custom-script"
      script: ".kiro/scripts/check_dependencies.py"
    message: "Dependency issues detected"
    fix:
      type: "custom-script"
      script: ".kiro/scripts/fix_dependencies.py"
    severity: "error"
```

### 7. Compliance as Code Rules

These rules enforce compliance requirements as code, ensuring that the system meets regulatory and organizational standards.

```yaml
# .kiro/safeguards/compliance-rules.yaml
name: "Compliance as Code Rules"
description: "Enforces compliance requirements as code"
version: "1.0.0"
rules:
  - name: "gdpr-compliance"
    description: "Ensures GDPR compliance for data handling"
    check:
      type: "content-check"
      pattern: "cloudscope/domain/models/**/*.py"
      content-pattern: "@data_classification\\(['\"]personal['\"]\\)"
      condition: "must-contain-for-matches"
      match-pattern: ".*user.*|.*email.*|.*name.*|.*address.*|.*phone.*"
    message: "Personal data must be classified according to GDPR requirements"
    severity: "error"
    
  - name: "pci-dss-compliance"
    description: "Ensures PCI DSS compliance for payment data"
    check:
      type: "content-check"
      pattern: "cloudscope/domain/models/**/*.py"
      content-pattern: "@encrypted"
      condition: "must-contain-for-matches"
      match-pattern: ".*card.*|.*payment.*|.*credit.*|.*cvv.*"
    message: "Payment data must be encrypted according to PCI DSS requirements"
    severity: "error"
    
  - name: "hipaa-compliance"
    description: "Ensures HIPAA compliance for health data"
    check:
      type: "content-check"
      pattern: "cloudscope/domain/models/**/*.py"
      content-pattern: "@data_classification\\(['\"]health['\"]\\)"
      condition: "must-contain-for-matches"
      match-pattern: ".*health.*|.*medical.*|.*patient.*|.*diagnosis.*"
    message: "Health data must be classified according to HIPAA requirements"
    severity: "error"
    
  - name: "audit-logging"
    description: "Ensures audit logging for sensitive operations"
    check:
      type: "content-check"
      pattern: "cloudscope/application/use_cases/**/*.py"
      content-pattern: "audit_logger\\.log_"
      condition: "must-contain"
    message: "Sensitive operations must include audit logging"
    severity: "error"
    
  - name: "data-retention"
    description: "Ensures data retention policies are implemented"
    check:
      type: "custom-script"
      script: ".kiro/scripts/check_data_retention.py"
    message: "Data retention policies must be implemented"
    severity: "warning"
    
  - name: "access-control"
    description: "Ensures proper access control for endpoints"
    check:
      type: "content-check"
      pattern: "cloudscope/adapters/api/**/*.py"
      content-pattern: "@require_permission\\(['\"].*['\"]\\)"
      condition: "must-contain"
    message: "API endpoints must implement access control"
    severity: "error"
    
  - name: "compliance-documentation"
    description: "Ensures compliance documentation is up to date"
    check:
      type: "file-change-check"
      source-pattern: "cloudscope/domain/models/**/*.py"
      related-pattern: "docs/compliance/**/*.md"
      condition: "must-change-together"
    message: "Compliance documentation must be updated when domain models change"
    severity: "warning"
```

### 8. Technical Notes Rules

These rules ensure that technical notes are maintained and up to date.

```yaml
# .kiro/safeguards/technical-notes-rules.yaml
name: "Technical Notes Rules"
description: "Enforces maintenance of technical notes"
version: "1.0.0"
rules:
  - name: "architecture-documentation"
    description: "Ensures architecture documentation is up to date"
    check:
      type: "file-change-check"
      source-pattern: "cloudscope/domain/**/*.py"
      related-pattern: "docs/architecture/**/*.md"
      condition: "must-change-together"
    message: "Architecture documentation must be updated when domain layer changes"
    severity: "warning"
    
  - name: "api-documentation"
    description: "Ensures API documentation is up to date"
    check:
      type: "file-change-check"
      source-pattern: "cloudscope/ports/**/*.py"
      related-pattern: "docs/api/**/*.md"
      condition: "must-change-together"
    message: "API documentation must be updated when port interfaces change"
    severity: "warning"
    
  - name: "database-schema-documentation"
    description: "Ensures database schema documentation is up to date"
    check:
      type: "file-change-check"
      source-pattern: "cloudscope/adapters/repositories/**/*.py"
      related-pattern: "docs/database/**/*.md"
      condition: "must-change-together"
    message: "Database schema documentation must be updated when repositories change"
    severity: "warning"
    
  - name: "technical-debt-tracking"
    description: "Ensures technical debt is tracked"
    check:
      type: "content-check"
      pattern: "**/*.py"
      content-pattern: "# TODO|# FIXME"
      condition: "must-not-contain"
    message: "Technical debt must be tracked in the issue tracker, not in code comments"
    severity: "warning"
    
  - name: "decision-records"
    description: "Ensures architectural decisions are documented"
    check:
      type: "custom-script"
      script: ".kiro/scripts/check_decision_records.py"
    message: "Architectural decisions must be documented in ADRs"
    severity: "warning"
```

## Kiro Workflow Integration

### Workflow Definition

```yaml
# .kiro/workflows/modular-architecture-workflow.yaml
name: "Modular Architecture Workflow"
description: "Workflow for implementing modular architecture features"
version: "1.0.0"
steps:
  - name: "requirements-validation"
    description: "Validate requirements against lean principles"
    action: "run-script"
    script: ".kiro/scripts/validate_requirements.py"
    
  - name: "test-creation"
    description: "Create test files for new features"
    action: "template"
    template: ".kiro/templates/test_template.py.j2"
    output: "tests/{{ feature_name }}/test_{{ module_name }}.py"
    
  - name: "implementation"
    description: "Implement feature after tests"
    action: "template"
    template: ".kiro/templates/implementation_template.py.j2"
    output: "cloudscope/{{ module_path }}/{{ module_name }}.py"
    requires: ["test-creation"]
    
  - name: "documentation"
    description: "Generate documentation from code"
    action: "run-script"
    script: ".kiro/scripts/generate_docs.py"
    requires: ["implementation"]
    
  - name: "validation"
    description: "Run safeguards and tests"
    action: "run-command"
    command: "pytest tests/{{ feature_name }} -v && kiro safeguard check"
    requires: ["implementation", "documentation"]
```

### Templates

#### Test Template

```jinja
# .kiro/templates/test_template.py.j2
"""
Tests for {{ module_name }} module.
"""
import pytest
from cloudscope.{{ module_path }}.{{ module_name }} import *

class Test{{ class_name }}:
    """Test cases for {{ class_name }} class."""
    
    @pytest.fixture
    def setup_fixture(self):
        """Set up test fixture."""
        # Setup code here
        pass
    
    def test_initialization(self, setup_fixture):
        """Test initialization of {{ class_name }}."""
        # Test code here
        pass
    
    def test_functionality(self, setup_fixture):
        """Test core functionality of {{ class_name }}."""
        # Test code here
        pass
    
    def test_error_handling(self, setup_fixture):
        """Test error handling of {{ class_name }}."""
        # Test code here
        pass
```

#### Implementation Template

```jinja
# .kiro/templates/implementation_template.py.j2
"""
{{ module_name }} module for CloudScope.

This module provides {{ class_name }} functionality.
"""
from typing import Dict, List, Optional, Any
from abc import ABC, abstractmethod

class {{ class_name }}:
    """
    {{ class_name }} implementation.
    
    This class provides functionality for {{ purpose }}.
    
    Attributes:
        attr1: Description of attribute 1
        attr2: Description of attribute 2
    """
    
    def __init__(self):
        """Initialize {{ class_name }}."""
        # Initialization code here
        pass
    
    def method1(self, param1: str, param2: int = 0) -> Any:
        """
        Description of method1.
        
        Args:
            param1: Description of param1
            param2: Description of param2
            
        Returns:
            Description of return value
            
        Raises:
            ValueError: If input is invalid
        """
        # Method implementation here
        pass
```

## CI/CD Integration

```yaml
# .github/workflows/modular-architecture-ci.yml
name: Modular Architecture CI

on:
  push:
    branches: [ main ]
    paths:
      - 'cloudscope/**'
      - 'tests/**'
  pull_request:
    branches: [ main ]

jobs:
  safeguard-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'
      - name: Install dependencies
        run: |
          python -m pip install --upgrade pip
          pip install kiro-cli
      - name: Run Kiro safeguards
        run: kiro safeguard check

  test:
    runs-on: ubuntu-latest
    needs: safeguard-check
    steps:
      - uses: actions/checkout@v3
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'
      - name: Install dependencies
        run: |
          python -m pip install --upgrade pip
          pip install -r requirements-dev.txt
      - name: Test with pytest
        run: |
          pytest --cov=cloudscope tests/
      - name: Upload coverage report
        uses: codecov/codecov-action@v3

  build:
    runs-on: ubuntu-latest
    needs: test
    steps:
      - uses: actions/checkout@v3
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'
      - name: Install dependencies
        run: |
          python -m pip install --upgrade pip
          pip install build
      - name: Build package
        run: python -m build
      - name: Store build artifacts
        uses: actions/upload-artifact@v3
        with:
          name: dist
          path: dist/
```

## Using Kiro Rules

### Installation

```bash
# Install Kiro CLI
pip install kiro-cli

# Initialize Kiro in your project
kiro init

# Install safeguards
kiro safeguard install
```

### Running Checks

```bash
# Run all safeguards
kiro safeguard check

# Run specific safeguard
kiro safeguard check --rule test-first-development

# Run safeguards for specific files
kiro safeguard check --files cloudscope/domain/

# Run workflow
kiro workflow run modular-architecture-workflow --params feature_name=asset_repository module_name=file_repository
```

### Pre-commit Integration

```yaml
# .pre-commit-config.yaml
repos:
  - repo: local
    hooks:
      - id: kiro-safeguards
        name: Kiro Safeguards
        entry: kiro safeguard check
        language: system
        pass_filenames: false
        always_run: true
```

## Conclusion

These Kiro rules and workflows enforce the architectural principles, lean stack methodology, and TDD practices for the CloudScope modular architecture. By automating these checks, we ensure consistent application of best practices throughout the development process.