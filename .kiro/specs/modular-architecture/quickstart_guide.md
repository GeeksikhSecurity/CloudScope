# CloudScope Modular Architecture: Quick Start Guide

## Overview

This quick start guide provides a fast path to understanding and working with CloudScope's modular architecture. It includes practical examples, common patterns, and answers to frequently asked questions to help new developers get up to speed quickly.

## 🚀 Getting Started in 5 Minutes

### 1. Setup Your Environment

```bash
# Clone the repository
git clone https://github.com/GeeksikhSecurity/CloudScope.git
cd CloudScope

# Install dependencies
pip install -r requirements.txt

# Install development tools
pip install -r requirements-dev.txt

# Install Kiro CLI
pip install kiro-cli

# Initialize Kiro
kiro init
```

### 2. Run Your First Component

```bash
# Start the file-based storage version
python -m cloudscope.main --storage file --config examples/simple-config.yaml

# Collect assets from a CSV file
python -m cloudscope.collectors.file_collector --input examples/assets.csv
```

### 3. Create Your First Plugin

```python
# plugins/my_collector.py
from cloudscope.ports.collectors import Collector
from cloudscope.domain.models.asset import Asset
from typing import List
import uuid

class MyCollector(Collector):
    """A simple example collector plugin."""
    
    def get_name(self) -> str:
        return "my-collector"
    
    def get_version(self) -> str:
        return "1.0.0"
    
    def get_api_version(self) -> str:
        return "1.0.0"
    
    def collect(self) -> List[Asset]:
        """Collect example assets."""
        assets = []
        
        # Create a sample asset
        asset = Asset(
            id=str(uuid.uuid4()),
            name="Example Asset",
            asset_type="server",
            source="my-collector"
        )
        asset.add_metadata("environment", "development")
        asset.add_tag("owner", "example-team")
        
        assets.append(asset)
        return assets
```

### 4. Run the Tests

```bash
# Run all tests
pytest

# Run specific tests
pytest tests/domain/test_asset.py

# Run tests with coverage
pytest --cov=cloudscope
```

### 5. Check Compliance with Kiro Rules

```bash
# Run all safeguards
kiro safeguard check

# Run specific safeguard
kiro safeguard check --rule hexagonal-architecture
```

## 🧩 Common Patterns

### Repository Pattern

```python
# Example repository usage
from cloudscope.adapters.repositories import FileBasedAssetRepository

# Create repository
repo = FileBasedAssetRepository(base_path="/tmp/cloudscope-data")

# Save asset
asset_id = repo.save(asset)

# Retrieve asset
retrieved_asset = repo.get_by_id(asset_id)

# Find assets
assets = repo.find({"asset_type": "server"}, limit=10)

# Update asset
asset.add_tag("environment", "production")
repo.save(asset)

# Delete asset
repo.delete(asset_id)
```

### Plugin System

```python
# Example plugin manager usage
from cloudscope.infrastructure.plugins import PluginManager

# Create plugin manager
plugin_manager = PluginManager(plugin_dir="plugins")

# Load plugins
plugin_manager.load_plugins()

# Get collector plugins
collector_plugins = plugin_manager.get_collector_plugins()

# Execute collector plugin
for plugin in collector_plugins:
    collector = plugin.get_collector()
    assets = collector.collect()
    print(f"Collected {len(assets)} assets from {collector.get_name()}")
```

### Observability

```python
# Example structured logging
from cloudscope.infrastructure.logging import StructuredLogger

# Create logger
logger = StructuredLogger("my-component")

# Log information
logger.info("Processing asset", asset_id=asset.id, asset_type=asset.asset_type)

# Log error
try:
    # Some operation
    pass
except Exception as e:
    logger.error("Failed to process asset", asset_id=asset.id, error=str(e))
```

### Compliance Annotations

```python
# Example compliance annotations
from cloudscope.compliance import data_classification, encrypted

class User:
    """User domain model with compliance annotations."""
    
    @data_classification("personal")
    def __init__(self, user_id: str, name: str, email: str):
        self.user_id = user_id
        self.name = name  # Personal data
        self.email = email  # Personal data
    
    @encrypted
    def set_password(self, password: str):
        """Set encrypted password."""
        self._password = password
```

## 📋 Common Tasks

### Adding a New Domain Model

1. Create a test file first:

```python
# tests/domain/test_network.py
import pytest
from cloudscope.domain.models.network import Network

def test_network_creation():
    """Test network creation."""
    network = Network(
        id="net-123",
        name="Test Network",
        cidr="10.0.0.0/24",
        source="test"
    )
    
    assert network.id == "net-123"
    assert network.name == "Test Network"
    assert network.cidr == "10.0.0.0/24"
    assert network.source == "test"

def test_network_add_metadata():
    """Test adding metadata to network."""
    network = Network(
        id="net-123",
        name="Test Network",
        cidr="10.0.0.0/24",
        source="test"
    )
    
    network.add_metadata("region", "us-west-2")
    
    assert network.metadata.get("region") == "us-west-2"
```

2. Implement the domain model:

```python
# cloudscope/domain/models/network.py
from typing import Dict, Any, Optional
from datetime import datetime

class Network:
    """Network domain model."""
    
    def __init__(self, id: str, name: str, cidr: str, source: str):
        """
        Initialize a network.
        
        Args:
            id: Network ID
            name: Network name
            cidr: Network CIDR
            source: Data source
        """
        self.id = id
        self.name = name
        self.cidr = cidr
        self.source = source
        self.metadata: Dict[str, Any] = {}
        self.tags: Dict[str, str] = {}
        self.created_at = datetime.now()
        self.updated_at = datetime.now()
    
    def add_metadata(self, key: str, value: Any) -> None:
        """
        Add metadata to the network.
        
        Args:
            key: Metadata key
            value: Metadata value
        """
        self.metadata[key] = value
        self.updated_at = datetime.now()
    
    def add_tag(self, key: str, value: str) -> None:
        """
        Add tag to the network.
        
        Args:
            key: Tag key
            value: Tag value
        """
        self.tags[key] = value
        self.updated_at = datetime.now()
```

### Adding a New Repository Adapter

1. Create a test file first:

```python
# tests/adapters/repositories/test_sqlite_network_repository.py
import pytest
import tempfile
import os
from cloudscope.adapters.repositories.sqlite_network_repository import SQLiteNetworkRepository
from cloudscope.domain.models.network import Network

@pytest.fixture
def repo():
    """Create a temporary SQLite repository."""
    db_path = os.path.join(tempfile.mkdtemp(), "test.db")
    repo = SQLiteNetworkRepository(db_path=db_path)
    yield repo
    os.remove(db_path)

def test_save_and_get(repo):
    """Test saving and retrieving a network."""
    network = Network(
        id="net-123",
        name="Test Network",
        cidr="10.0.0.0/24",
        source="test"
    )
    
    # Save network
    saved_id = repo.save(network)
    
    # Get network
    retrieved_network = repo.get_by_id(saved_id)
    
    assert retrieved_network is not None
    assert retrieved_network.id == network.id
    assert retrieved_network.name == network.name
    assert retrieved_network.cidr == network.cidr
```

2. Implement the repository adapter:

```python
# cloudscope/adapters/repositories/sqlite_network_repository.py
import sqlite3
import json
from typing import List, Dict, Any, Optional
from cloudscope.ports.repositories import NetworkRepository
from cloudscope.domain.models.network import Network

class SQLiteNetworkRepository(NetworkRepository):
    """SQLite implementation of NetworkRepository."""
    
    def __init__(self, db_path: str):
        """
        Initialize SQLite network repository.
        
        Args:
            db_path: Path to SQLite database file
        """
        self.db_path = db_path
        self._create_tables_if_not_exist()
    
    def _create_tables_if_not_exist(self):
        """Create tables if they don't exist."""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('''
        CREATE TABLE IF NOT EXISTS networks (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            cidr TEXT NOT NULL,
            source TEXT NOT NULL,
            metadata TEXT,
            tags TEXT,
            created_at TEXT,
            updated_at TEXT
        )
        ''')
        
        conn.commit()
        conn.close()
    
    def save(self, network: Network) -> str:
        """
        Save a network.
        
        Args:
            network: Network to save
            
        Returns:
            Network ID
        """
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute(
            '''
            INSERT OR REPLACE INTO networks
            (id, name, cidr, source, metadata, tags, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ''',
            (
                network.id,
                network.name,
                network.cidr,
                network.source,
                json.dumps(network.metadata),
                json.dumps(network.tags),
                network.created_at.isoformat(),
                network.updated_at.isoformat()
            )
        )
        
        conn.commit()
        conn.close()
        
        return network.id
    
    def get_by_id(self, network_id: str) -> Optional[Network]:
        """
        Get a network by ID.
        
        Args:
            network_id: Network ID
            
        Returns:
            Network if found, None otherwise
        """
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute(
            'SELECT id, name, cidr, source, metadata, tags, created_at, updated_at FROM networks WHERE id = ?',
            (network_id,)
        )
        
        row = cursor.fetchone()
        conn.close()
        
        if not row:
            return None
        
        network = Network(
            id=row[0],
            name=row[1],
            cidr=row[2],
            source=row[3]
        )
        
        network.metadata = json.loads(row[4])
        network.tags = json.loads(row[5])
        
        return network
```

## ❓ Frequently Asked Questions

### 1. How do I add a new dependency?

**Answer:** To add a new dependency, follow these steps:

1. Add the dependency to `requirements.txt` or `requirements-dev.txt` (for development dependencies)
2. Update the dependency injection container in `cloudscope/infrastructure/di/container.py`
3. Use constructor injection to receive the dependency in your classes

Example:

```python
# Add to requirements.txt
requests==2.28.1

# Update container.py
from cloudscope.infrastructure.http import HttpClient

class Container:
    def __init__(self):
        # Other dependencies...
        self.http_client = HttpClient()
    
    def get_http_client(self):
        return self.http_client

# Use in your class
class ApiCollector(Collector):
    def __init__(self, http_client: HttpClient):
        self.http_client = http_client
    
    def collect(self):
        response = self.http_client.get("https://api.example.com/assets")
        # Process response...
```

### 2. How do I implement a new collector?

**Answer:** To implement a new collector, follow these steps:

1. Create a new file in `cloudscope/adapters/collectors` or `plugins` directory
2. Implement the `Collector` interface
3. Register the collector with the plugin system or dependency injection container

Example:

```python
from cloudscope.ports.collectors import Collector
from cloudscope.domain.models.asset import Asset
from typing import List
import requests

class ApiCollector(Collector):
    def __init__(self, api_url: str, api_key: str):
        self.api_url = api_url
        self.api_key = api_key
    
    def get_name(self) -> str:
        return "api-collector"
    
    def get_version(self) -> str:
        return "1.0.0"
    
    def collect(self) -> List[Asset]:
        response = requests.get(
            f"{self.api_url}/assets",
            headers={"Authorization": f"Bearer {self.api_key}"}
        )
        response.raise_for_status()
        
        assets = []
        for item in response.json():
            asset = Asset(
                id=item["id"],
                name=item["name"],
                asset_type=item["type"],
                source="api-collector"
            )
            assets.append(asset)
        
        return assets
```

### 3. How do I handle database migrations?

**Answer:** Database migrations are handled through the `DataMigrator` interface:

1. Create a new migration file in `cloudscope/infrastructure/migrations`
2. Implement the `DataMigrator` interface
3. Register the migration with the migration manager

Example:

```python
from cloudscope.ports.migrations import DataMigrator
from typing import Dict, Any

class AddNetworkTableMigration(DataMigrator):
    def get_version(self) -> str:
        return "1.0.0"
    
    def get_description(self) -> str:
        return "Add networks table"
    
    def migrate_up(self, connection: Any) -> bool:
        """Execute forward migration."""
        cursor = connection.cursor()
        
        cursor.execute('''
        CREATE TABLE IF NOT EXISTS networks (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            cidr TEXT NOT NULL,
            source TEXT NOT NULL,
            metadata TEXT,
            tags TEXT,
            created_at TEXT,
            updated_at TEXT
        )
        ''')
        
        connection.commit()
        return True
    
    def migrate_down(self, connection: Any) -> bool:
        """Execute rollback migration."""
        cursor = connection.cursor()
        cursor.execute('DROP TABLE IF EXISTS networks')
        connection.commit()
        return True
    
    def validate_migration(self) -> bool:
        """Validate migration integrity."""
        # Implementation to verify migration was successful
        return True
```

### 4. How do I add a new compliance control?

**Answer:** To add a new compliance control, follow these steps:

1. Define the control in the appropriate compliance framework file
2. Create annotations or validators for the control
3. Update the compliance verification logic

Example:

```python
# Define control in cloudscope/compliance/frameworks/gdpr.py
GDPR_CONTROLS = {
    "GDPR-7": {
        "id": "GDPR-7",
        "name": "Data Portability",
        "description": "The right to receive personal data in a structured, commonly used, machine-readable format",
        "implementation": ["@data_portability"],
        "validation": "validate_data_portability"
    }
}

# Create annotation in cloudscope/compliance/annotations.py
def data_portability(func):
    """
    Decorator for data portability compliance.
    """
    @wraps(func)
    def wrapper(*args, **kwargs):
        # Implementation
        return func(*args, **kwargs)
    
    # Add metadata to function for static analysis
    wrapper.__data_portability__ = True
    return wrapper

# Update verification in cloudscope/compliance/verification.py
def validate_data_portability(module_path: str) -> List[str]:
    """
    Validate data portability compliance.
    """
    issues = []
    
    # Parse module AST
    with open(module_path, 'r') as f:
        tree = ast.parse(f.read())
    
    # Check for data portability implementation
    for node in ast.walk(tree):
        if isinstance(node, ast.ClassDef):
            # Check if class has data portability method
            has_portability_method = False
            for method in [n for n in node.body if isinstance(n, ast.FunctionDef)]:
                if method.name == "get_data_export" or has_data_portability_annotation(method):
                    has_portability_method = True
                    break
            
            # Check if class has personal data
            has_personal_data = False
            for attr in [n for n in node.body if isinstance(n, ast.AnnAssign)]:
                if has_personal_data_annotation(attr):
                    has_personal_data = True
                    break
            
            # If class has personal data but no portability method
            if has_personal_data and not has_portability_method:
                issues.append(f"Class '{node.name}' has personal data but no data portability method")
    
    return issues
```

### 5. How do I debug Kiro rule violations?

**Answer:** To debug Kiro rule violations, follow these steps:

1. Run Kiro safeguards with verbose output
2. Check the specific rule that's failing
3. Use the troubleshooting guide for that rule
4. Fix the issue and re-run the check

Example:

```bash
# Run with verbose output
kiro safeguard check --verbose

# Check specific rule
kiro safeguard check --rule hexagonal-architecture --verbose

# Get help for a rule
kiro safeguard help hexagonal-architecture
```

Common fixes for rule violations:

- **hexagonal-architecture**: Ensure domain layer doesn't import from adapters
- **test-first-development**: Create test files before implementation files
- **documentation-required**: Add docstrings to classes and functions
- **input-validation**: Add validation for all inputs
- **compliance-annotation**: Add compliance annotations to sensitive data

## 🔄 Development Workflow

### TDD Workflow

1. Write a test for the feature
2. Run the test to see it fail
3. Implement the feature
4. Run the test to see it pass
5. Refactor the code
6. Run the test again to ensure it still passes

Example:

```bash
# 1. Write a test
vim tests/domain/test_network.py

# 2. Run the test to see it fail
pytest tests/domain/test_network.py -v

# 3. Implement the feature
vim cloudscope/domain/models/network.py

# 4. Run the test to see it pass
pytest tests/domain/test_network.py -v

# 5. Refactor the code
vim cloudscope/domain/models/network.py

# 6. Run the test again
pytest tests/domain/test_network.py -v
```

### Compliance Workflow

1. Identify compliance requirements
2. Add compliance annotations to code
3. Run compliance verification
4. Fix compliance issues
5. Generate compliance report

Example:

```bash
# 1. Identify compliance requirements
vim .kiro/compliance/gdpr.json

# 2. Add compliance annotations to code
vim cloudscope/domain/models/user.py

# 3. Run compliance verification
kiro verify compliance --framework GDPR

# 4. Fix compliance issues
vim cloudscope/domain/models/user.py

# 5. Generate compliance report
kiro generate compliance-report --framework GDPR --output reports/gdpr-compliance.md
```

## 🧠 Design Principles Quick Reference

### Hexagonal Architecture

- **Domain Layer**: Contains business logic and domain models
- **Ports Layer**: Defines interfaces for external dependencies
- **Adapters Layer**: Implements interfaces for specific technologies
- **Infrastructure Layer**: Provides cross-cutting concerns

### Progressive Enhancement

- **Phase 1**: Simple, file-based implementations
- **Phase 2**: Enhanced features with caching and patterns
- **Phase 3**: Advanced features with AI/ML integration

### Test-Driven Development

- Write tests before implementation
- Follow Red-Green-Refactor cycle
- Use AAA pattern (Arrange, Act, Assert)

### Compliance as Code

- Use annotations for compliance requirements
- Verify compliance through automated checks
- Generate compliance reports from code

## 🔗 Additional Resources

- [Full Documentation](docs/README.md)
- [API Reference](docs/api/README.md)
- [Architecture Guide](docs/architecture/README.md)
- [Troubleshooting Guide](.kiro/specs/modular-architecture/troubleshooting_guide.md)
- [Compliance Guide](.kiro/specs/modular-architecture/compliance_as_code.md)
- [Technical Notes](.kiro/specs/modular-architecture/technical_notes.md)
- [Kiro Rules](.kiro/specs/modular-architecture/kiro_rules.md)

## 🚀 Next Steps

1. Complete the [Developer Onboarding Tutorial](docs/tutorials/onboarding.md)
2. Explore the [Example Projects](examples/README.md)
3. Join the [Community Discord](https://discord.gg/cloudscope)
4. Contribute to the [Project Roadmap](ROADMAP.md)