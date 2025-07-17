# Onboarding Kiro Rules for CloudScope Modular Architecture
<!-- Created by: Claude -->
<!-- Last modified by: Claude -->
<!-- Date: 2025-07-16 -->

## Overview

This document defines Kiro rules specifically designed to facilitate faster onboarding for new developers working with CloudScope's modular architecture. These rules ensure that onboarding documentation is maintained, examples are up-to-date, and new developers can quickly become productive.

## Rule Categories

### 1. Documentation Accessibility Rules

These rules ensure that onboarding documentation is easily accessible and up-to-date.

```yaml
# .kiro/safeguards/onboarding-documentation-rules.yaml
name: "Onboarding Documentation Rules"
description: "Ensures onboarding documentation is accessible and up-to-date"
version: "1.0.0"
rules:
  - name: "quick-start-guide-exists"
    description: "Ensures quick start guide exists and is accessible"
    check:
      type: "file-existence-check"
      pattern: ".kiro/specs/modular-architecture/quickstart_guide.md"
      condition: "must-exist"
    message: "Quick start guide must exist and be accessible"
    severity: "error"
    
  - name: "faq-exists"
    description: "Ensures FAQ exists and is accessible"
    check:
      type: "file-existence-check"
      pattern: ".kiro/specs/modular-architecture/faq.md"
      condition: "must-exist"
    message: "FAQ must exist and be accessible"
    severity: "error"
    
  - name: "readme-contains-onboarding-links"
    description: "Ensures README contains links to onboarding documentation"
    check:
      type: "content-check"
      pattern: "README.md"
      content-pattern: "quick_start_guide|getting_started|onboarding"
      condition: "must-contain"
    message: "README must contain links to onboarding documentation"
    severity: "warning"
```

### 2. Example Validation Rules

These rules ensure that code examples in documentation are valid and up-to-date.

```yaml
# .kiro/safeguards/example-validation-rules.yaml
name: "Example Validation Rules"
description: "Ensures code examples are valid and up-to-date"
version: "1.0.0"
rules:
  - name: "quick-start-examples-valid"
    description: "Ensures examples in quick start guide are valid"
    check:
      type: "custom-script"
      script: ".kiro/scripts/validate_examples.py"
      args: [".kiro/specs/modular-architecture/quickstart_guide.md"]
    message: "Examples in quick start guide must be valid Python code"
    severity: "error"
    
  - name: "faq-examples-valid"
    description: "Ensures examples in FAQ are valid"
    check:
      type: "custom-script"
      script: ".kiro/scripts/validate_examples.py"
      args: [".kiro/specs/modular-architecture/faq.md"]
    message: "Examples in FAQ must be valid Python code"
    severity: "error"
    
  - name: "examples-up-to-date"
    description: "Ensures examples are up-to-date with current API"
    check:
      type: "file-change-check"
      source-pattern: "cloudscope/ports/**/*.py"
      related-pattern: ".kiro/specs/modular-architecture/quickstart_guide.md"
      condition: "must-update-if-changed"
    message: "Update examples in quick start guide when changing API"
    severity: "warning"
```

### 3. Onboarding Project Rules

These rules ensure that onboarding projects and exercises are maintained.

```yaml
# .kiro/safeguards/onboarding-project-rules.yaml
name: "Onboarding Project Rules"
description: "Ensures onboarding projects and exercises are maintained"
version: "1.0.0"
rules:
  - name: "onboarding-projects-exist"
    description: "Ensures onboarding projects exist"
    check:
      type: "file-existence-check"
      pattern: "examples/onboarding/**/*.py"
      condition: "must-exist"
    message: "Onboarding projects must exist"
    severity: "warning"
    
  - name: "onboarding-projects-up-to-date"
    description: "Ensures onboarding projects are up-to-date"
    check:
      type: "file-change-check"
      source-pattern: "cloudscope/ports/**/*.py"
      related-pattern: "examples/onboarding/**/*.py"
      condition: "must-update-if-changed"
    message: "Update onboarding projects when changing API"
    severity: "warning"
    
  - name: "onboarding-tests-pass"
    description: "Ensures onboarding project tests pass"
    check:
      type: "custom-script"
      script: ".kiro/scripts/run_onboarding_tests.py"
    message: "Onboarding project tests must pass"
    severity: "error"
```

### 4. Development Environment Rules

These rules ensure that development environment setup is straightforward and well-documented.

```yaml
# .kiro/safeguards/development-environment-rules.yaml
name: "Development Environment Rules"
description: "Ensures development environment setup is straightforward"
version: "1.0.0"
rules:
  - name: "dev-setup-script-exists"
    description: "Ensures development environment setup script exists"
    check:
      type: "file-existence-check"
      pattern: "scripts/setup_dev_environment.{sh,bat,ps1}"
      condition: "must-exist"
    message: "Development environment setup script must exist"
    severity: "warning"
    
  - name: "dev-requirements-exists"
    description: "Ensures development requirements file exists"
    check:
      type: "file-existence-check"
      pattern: "requirements-dev.txt"
      condition: "must-exist"
    message: "Development requirements file must exist"
    severity: "error"
    
  - name: "dev-environment-docs-exists"
    description: "Ensures development environment documentation exists"
    check:
      type: "file-existence-check"
      pattern: "docs/development_environment.md"
      condition: "must-exist"
    message: "Development environment documentation must exist"
    severity: "warning"
```

## Example Validation Script

```python
# .kiro/scripts/validate_examples.py
#!/usr/bin/env python3
"""
Validate code examples in documentation.
"""
import sys
import re
import ast
from pathlib import Path

def extract_python_examples(file_path):
    """Extract Python code examples from markdown file."""
    with open(file_path, 'r') as f:
        content = f.read()
    
    # Find Python code blocks
    pattern = r'```python\n(.+?)\n```'
    matches = re.findall(pattern, content, re.DOTALL)
    
    return matches

def validate_python_code(code):
    """Validate Python code by parsing it with ast."""
    try:
        ast.parse(code)
        return True, None
    except SyntaxError as e:
        return False, f"Syntax error: {str(e)}"
    except Exception as e:
        return False, f"Error: {str(e)}"

def main():
    """Main entry point."""
    if len(sys.argv) < 2:
        print("Usage: validate_examples.py <file_path>")
        return 1
    
    file_path = sys.argv[1]
    if not Path(file_path).exists():
        print(f"File not found: {file_path}")
        return 1
    
    examples = extract_python_examples(file_path)
    if not examples:
        print(f"No Python examples found in {file_path}")
        return 0
    
    errors = []
    for i, example in enumerate(examples, 1):
        valid, error = validate_python_code(example)
        if not valid:
            errors.append(f"Example {i}: {error}")
    
    if errors:
        print(f"Found {len(errors)} errors in {file_path}:")
        for error in errors:
            print(f"- {error}")
        return 1
    else:
        print(f"All {len(examples)} examples in {file_path} are valid")
        return 0

if __name__ == "__main__":
    sys.exit(main())
```

## Onboarding Test Script

```python
# .kiro/scripts/run_onboarding_tests.py
#!/usr/bin/env python3
"""
Run tests for onboarding projects.
"""
import sys
import subprocess
from pathlib import Path

def find_onboarding_tests():
    """Find all test files for onboarding projects."""
    onboarding_dir = Path("examples/onboarding")
    if not onboarding_dir.exists():
        return []
    
    test_files = []
    for test_file in onboarding_dir.glob("**/test_*.py"):
        test_files.append(str(test_file))
    
    return test_files

def run_tests(test_files):
    """Run tests and return success status."""
    if not test_files:
        print("No onboarding tests found")
        return True
    
    print(f"Running {len(test_files)} onboarding test files")
    
    for test_file in test_files:
        print(f"Running {test_file}...")
        result = subprocess.run([sys.executable, "-m", "pytest", test_file, "-v"], capture_output=True)
        
        if result.returncode != 0:
            print(f"Test failed: {test_file}")
            print(result.stdout.decode())
            print(result.stderr.decode())
            return False
    
    print("All onboarding tests passed")
    return True

def main():
    """Main entry point."""
    test_files = find_onboarding_tests()
    success = run_tests(test_files)
    
    return 0 if success else 1

if __name__ == "__main__":
    sys.exit(main())
```

## Onboarding Workflow

```yaml
# .kiro/workflows/onboarding-workflow.yaml
name: "Onboarding Workflow"
description: "Workflow for onboarding new developers"
version: "1.0.0"
steps:
  - name: "setup-environment"
    description: "Set up development environment"
    action: "run-script"
    script: "scripts/setup_dev_environment.sh"
    
  - name: "create-onboarding-project"
    description: "Create onboarding project from template"
    action: "template"
    template: ".kiro/templates/onboarding_project.py.j2"
    output: "examples/onboarding/{{ developer_name }}/{{ project_name }}.py"
    
  - name: "create-onboarding-test"
    description: "Create onboarding project test from template"
    action: "template"
    template: ".kiro/templates/onboarding_test.py.j2"
    output: "examples/onboarding/{{ developer_name }}/test_{{ project_name }}.py"
    
  - name: "validate-examples"
    description: "Validate examples in documentation"
    action: "run-script"
    script: ".kiro/scripts/validate_examples.py"
    args: [".kiro/specs/modular-architecture/quickstart_guide.md"]
    
  - name: "run-onboarding-tests"
    description: "Run onboarding project tests"
    action: "run-script"
    script: ".kiro/scripts/run_onboarding_tests.py"
```

## Onboarding Project Template

```jinja
# .kiro/templates/onboarding_project.py.j2
"""
Onboarding project for {{ developer_name }}.

This project demonstrates how to use CloudScope's modular architecture.
"""
from cloudscope.domain.models import Asset
from cloudscope.ports.collectors import Collector
from cloudscope.ports.repositories import AssetRepository
from typing import List, Dict, Any, Optional

class {{ project_name }}:
    """{{ project_name }} implementation."""
    
    def __init__(self, collector: Collector, repository: AssetRepository):
        """Initialize {{ project_name }}."""
        self.collector = collector
        self.repository = repository
    
    def collect_and_store(self) -> int:
        """Collect assets and store them in the repository."""
        assets = self.collector.collect()
        count = 0
        
        for asset in assets:
            self.repository.save(asset)
            count += 1
        
        return count
    
    def find_assets(self, query: Dict[str, Any]) -> List[Asset]:
        """Find assets matching query."""
        return self.repository.find(query)
    
    def get_asset(self, asset_id: str) -> Optional[Asset]:
        """Get asset by ID."""
        return self.repository.get_by_id(asset_id)
```

## Onboarding Test Template

```jinja
# .kiro/templates/onboarding_test.py.j2
"""
Tests for {{ project_name }}.
"""
import pytest
from cloudscope.domain.models import Asset
from examples.onboarding.{{ developer_name }}.{{ project_name }} import {{ project_name }}

class MockCollector:
    """Mock collector for testing."""
    
    def __init__(self, assets=None):
        self.assets = assets or []
    
    def collect(self):
        """Return mock assets."""
        return self.assets
    
    def get_source_name(self):
        """Return mock source name."""
        return "mock-collector"

class MockRepository:
    """Mock repository for testing."""
    
    def __init__(self):
        self.assets = {}
    
    def save(self, asset):
        """Save asset to mock storage."""
        self.assets[asset.id] = asset
        return asset.id
    
    def get_by_id(self, asset_id):
        """Get asset by ID from mock storage."""
        return self.assets.get(asset_id)
    
    def find(self, query):
        """Find assets matching query in mock storage."""
        results = []
        for asset in self.assets.values():
            match = True
            for key, value in query.items():
                if key == "asset_type" and asset.asset_type != value:
                    match = False
                    break
            if match:
                results.append(asset)
        return results

class Test{{ project_name }}:
    """Tests for {{ project_name }}."""
    
    @pytest.fixture
    def setup(self):
        """Set up test fixtures."""
        assets = [
            Asset(id="test-1", name="Test Asset 1", asset_type="server", source="mock"),
            Asset(id="test-2", name="Test Asset 2", asset_type="database", source="mock")
        ]
        collector = MockCollector(assets)
        repository = MockRepository()
        project = {{ project_name }}(collector, repository)
        
        return {
            "assets": assets,
            "collector": collector,
            "repository": repository,
            "project": project
        }
    
    def test_collect_and_store(self, setup):
        """Test collect_and_store method."""
        count = setup["project"].collect_and_store()
        
        assert count == 2
        assert len(setup["repository"].assets) == 2
        assert "test-1" in setup["repository"].assets
        assert "test-2" in setup["repository"].assets
    
    def test_find_assets(self, setup):
        """Test find_assets method."""
        setup["project"].collect_and_store()
        
        servers = setup["project"].find_assets({"asset_type": "server"})
        databases = setup["project"].find_assets({"asset_type": "database"})
        
        assert len(servers) == 1
        assert servers[0].id == "test-1"
        
        assert len(databases) == 1
        assert databases[0].id == "test-2"
    
    def test_get_asset(self, setup):
        """Test get_asset method."""
        setup["project"].collect_and_store()
        
        asset = setup["project"].get_asset("test-1")
        
        assert asset is not None
        assert asset.id == "test-1"
        assert asset.name == "Test Asset 1"
        assert asset.asset_type == "server"
```

## CI/CD Integration

```yaml
# .github/workflows/onboarding-validation.yml
name: Onboarding Validation

on:
  push:
    branches: [ main ]
    paths:
      - '.kiro/specs/modular-architecture/quickstart_guide.md'
      - '.kiro/specs/modular-architecture/faq.md'
      - 'examples/onboarding/**'
      - 'docs/development_environment.md'
  pull_request:
    branches: [ main ]
    paths:
      - '.kiro/specs/modular-architecture/quickstart_guide.md'
      - '.kiro/specs/modular-architecture/faq.md'
      - 'examples/onboarding/**'
      - 'docs/development_environment.md'

jobs:
  validate:
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
          pip install -r requirements-dev.txt
          pip install kiro-cli
      
      - name: Validate examples
        run: python .kiro/scripts/validate_examples.py .kiro/specs/modular-architecture/quickstart_guide.md
      
      - name: Validate FAQ examples
        run: python .kiro/scripts/validate_examples.py .kiro/specs/modular-architecture/faq.md
      
      - name: Run onboarding tests
        run: python .kiro/scripts/run_onboarding_tests.py
```

## Conclusion

These Kiro rules and workflows ensure that onboarding documentation, examples, and projects are maintained and up-to-date, facilitating faster onboarding for new developers. By automating the validation of examples and onboarding projects, we ensure that new developers can quickly become productive with CloudScope's modular architecture.
