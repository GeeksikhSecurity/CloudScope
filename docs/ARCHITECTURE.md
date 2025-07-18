# CloudScope Architecture Documentation

## Overview

CloudScope is a comprehensive IT asset inventory system designed with a modular, plugin-based architecture following Domain-Driven Design (DDD) principles and hexagonal architecture patterns (Requirements: 5.1, 5.2, 5.3, 5.4).

## System Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         External Systems                              │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌──────────┐ │
│  │   AWS   │  │  Azure  │  │   GCP   │  │   K8s   │  │ On-Prem  │ │
│  └────┬────┘  └────┬────┘  └────┬────┘  └────┬────┘  └────┬─────┘ │
└───────┼────────────┼────────────┼────────────┼────────────┼────────┘
        │            │            │            │            │
┌───────┼────────────┼────────────┼────────────┼────────────┼────────┐
│       │            │            │            │            │         │
│  ┌────▼────────────▼────────────▼────────────▼────────────▼─────┐  │
│  │                      Plugin Layer (Collectors)                │  │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐        │  │
│  │  │AWS Plugin│  │Azure Pl.│  │GCP Plugin│  │K8s Plugin│  ...  │  │
│  │  └─────────┘  └─────────┘  └─────────┘  └─────────┘        │  │
│  └───────────────────────────┬──────────────────────────────────┘  │
│                              │                                      │
│  ┌───────────────────────────▼──────────────────────────────────┐  │
│  │                    Core Domain Layer                          │  │
│  │  ┌──────────┐  ┌──────────────┐  ┌─────────────────────┐   │  │
│  │  │  Asset   │  │ Relationship │  │  Business Rules     │   │  │
│  │  │  Model   │  │    Model     │  │  & Validation       │   │  │
│  │  └──────────┘  └──────────────┘  └─────────────────────┘   │  │
│  └───────────────────────────┬──────────────────────────────────┘  │
│                              │                                      │
│  ┌───────────────────────────▼──────────────────────────────────┐  │
│  │                    Port Interfaces                            │  │
│  │  ┌────────────┐  ┌────────────┐  ┌────────────┐            │  │
│  │  │Repository  │  │ Collector  │  │  Exporter  │            │  │
│  │  │Interface   │  │ Interface  │  │ Interface  │            │  │
│  │  └──────┬─────┘  └────────────┘  └──────┬─────┘            │  │
│  └─────────┼────────────────────────────────┼───────────────────┘  │
│            │                                │                       │
│  ┌─────────▼────────────────────────────────▼───────────────────┐  │
│  │                    Adapter Layer                              │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌─────────────┐ │  │
│  │  │   File   │  │  SQLite  │  │ Memgraph │  │   CSV/JSON  │ │  │
│  │  │ Storage  │  │ Storage  │  │ Storage  │  │  Exporters  │ │  │
│  │  └──────────┘  └──────────┘  └──────────┘  └─────────────┘ │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │              Infrastructure & Cross-Cutting Concerns           │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌─────────────┐ │  │
│  │  │ Logging  │  │ Metrics  │  │ Tracing  │  │Health Checks│ │  │
│  │  └──────────┘  └──────────┘  └──────────┘  └─────────────┘ │  │
│  └───────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

## Core Components

### 1. Domain Layer (Requirements: 5.3, 5.4)

The domain layer contains the core business logic and models, independent of external concerns.

#### Asset Model
```python
class Asset:
    """Core asset domain model"""
    def __init__(self, asset_id: str, asset_type: str, provider: str):
        self.id = asset_id
        self.type = asset_type
        self.provider = provider
        self.properties = {}
        self.tags = {}
        self.created_at = datetime.utcnow()
        self.updated_at = datetime.utcnow()
        
    def validate(self) -> bool:
        """Validate asset according to business rules"""
        # Business validation logic
        pass
        
    def add_relationship(self, relationship: Relationship):
        """Add relationship to another asset"""
        # Relationship management logic
        pass
```

#### Relationship Model
```python
class Relationship:
    """Domain model for asset relationships"""
    def __init__(self, source_id: str, target_id: str, 
                 relationship_type: str):
        self.source_id = source_id
        self.target_id = target_id
        self.type = relationship_type
        self.properties = {}
        self.confidence = 1.0
        
    def validate(self) -> bool:
        """Validate relationship constraints"""
        # Validation logic
        pass
```

### 2. Port Interfaces (Requirements: 1.2, 1.3, 5.2)

Ports define the contracts between the domain and external systems.

#### Repository Interface
```python
from abc import ABC, abstractmethod
from typing import List, Optional

class AssetRepository(ABC):
    """Port interface for asset persistence"""
    
    @abstractmethod
    def save(self, asset: Asset) -> Asset:
        """Save a single asset"""
        pass
        
    @abstractmethod
    def save_batch(self, assets: List[Asset]) -> List[Asset]:
        """Save multiple assets in batch"""
        pass
        
    @abstractmethod
    def find_by_id(self, asset_id: str) -> Optional[Asset]:
        """Find asset by ID"""
        pass
        
    @abstractmethod
    def find_all(self, filters: dict = None) -> List[Asset]:
        """Find all assets matching filters"""
        pass
        
    @abstractmethod
    def update(self, asset: Asset) -> Asset:
        """Update existing asset"""
        pass
        
    @abstractmethod
    def update_batch(self, assets: List[Asset]) -> List[Asset]:
        """Update multiple assets in batch"""
        pass
        
    @abstractmethod
    def delete(self, asset_id: str) -> bool:
        """Delete asset by ID"""
        pass
```

#### Collector Interface
```python
class Collector(ABC):
    """Port interface for asset collection"""
    
    @abstractmethod
    def collect(self) -> List[Asset]:
        """Collect assets from source"""
        pass
        
    @abstractmethod
    def validate_credentials(self) -> bool:
        """Validate collector credentials"""
        pass
        
    @abstractmethod
    def get_supported_types(self) -> List[str]:
        """Get list of supported asset types"""
        pass
```

### 3. Adapter Layer (Requirements: 1.1, 1.2, 1.4)

Adapters implement the port interfaces for specific technologies.

#### File-Based Storage Adapter
```python
class FileBasedAssetRepository(AssetRepository):
    """File system implementation of AssetRepository"""
    
    def __init__(self, base_path: str):
        self.base_path = Path(base_path)
        self.base_path.mkdir(parents=True, exist_ok=True)
        
    def save(self, asset: Asset) -> Asset:
        file_path = self.base_path / f"{asset.id}.json"
        with open(file_path, 'w') as f:
            json.dump(asset.to_dict(), f, indent=2)
        return asset
```

#### SQLite Storage Adapter
```python
class SQLiteAssetRepository(AssetRepository):
    """SQLite implementation of AssetRepository"""
    
    def __init__(self, connection_string: str):
        self.engine = create_engine(connection_string)
        self.session_factory = sessionmaker(bind=self.engine)
        
    def save(self, asset: Asset) -> Asset:
        with self.session_factory() as session:
            db_asset = AssetEntity.from_domain(asset)
            session.add(db_asset)
            session.commit()
        return asset
```

### 4. Plugin System (Requirements: 3.3, 3.4, 3.5, 3.6)

The plugin system enables extensibility through a well-defined API.

#### Plugin Interface
```python
class Plugin(ABC):
    """Base plugin interface"""
    
    @property
    @abstractmethod
    def name(self) -> str:
        """Plugin name"""
        pass
        
    @property
    @abstractmethod
    def version(self) -> str:
        """Plugin version"""
        pass
        
    @abstractmethod
    def initialize(self, config: dict) -> None:
        """Initialize plugin with configuration"""
        pass
        
    @abstractmethod
    def execute(self) -> Any:
        """Execute plugin functionality"""
        pass
        
    @abstractmethod
    def cleanup(self) -> None:
        """Cleanup plugin resources"""
        pass
```

#### Plugin Manager
```python
class PluginManager:
    """Manages plugin lifecycle and execution"""
    
    def __init__(self):
        self.plugins = {}
        self.rate_limiters = {}
        
    def discover_plugins(self, plugin_dir: Path) -> None:
        """Discover and load plugins from directory"""
        for plugin_path in plugin_dir.glob("*/plugin.py"):
            self._load_plugin(plugin_path)
            
    def register_plugin(self, plugin: Plugin) -> None:
        """Register a plugin instance"""
        self.plugins[plugin.name] = plugin
        self.rate_limiters[plugin.name] = RateLimiter(
            requests_per_minute=60
        )
        
    def execute_plugin(self, name: str, **kwargs) -> Any:
        """Execute plugin with rate limiting"""
        if name not in self.plugins:
            raise PluginNotFoundError(f"Plugin {name} not found")
            
        # Check rate limit
        limiter = self.rate_limiters[name]
        if not limiter.allow_request():
            raise RateLimitExceededError(
                f"Rate limit exceeded for plugin {name}"
            )
            
        # Execute plugin
        plugin = self.plugins[name]
        return plugin.execute(**kwargs)
```

## Data Flow

### Asset Collection Flow
```
1. Scheduler triggers collection
   ↓
2. PluginManager selects appropriate collector plugin
   ↓
3. Collector plugin connects to external system
   ↓
4. Raw data retrieved and transformed to Asset domain model
   ↓
5. Assets validated according to business rules
   ↓
6. Repository adapter persists assets to storage
   ↓
7. Relationships detected and stored
   ↓
8. Metrics and events published
```

### Export Flow
```
1. Export request received with filters
   ↓
2. Repository queries assets based on filters
   ↓
3. Assets retrieved with relationships
   ↓
4. Exporter plugin transforms to requested format
   ↓
5. Streaming initiated for large datasets
   ↓
6. Output written to destination
```

## Security Architecture (Requirements: 4.1, 4.3, 7.5, 7.6)

### Security Layers

```
┌─────────────────────────────────────────┐
│          External Requests              │
└─────────────────┬───────────────────────┘
                  │
┌─────────────────▼───────────────────────┐
│         Rate Limiting Layer             │
│    (Requests/minute, burst control)     │
└─────────────────┬───────────────────────┘
                  │
┌─────────────────▼───────────────────────┐
│      Authentication Layer (JWT)         │
│    (Token validation, expiration)       │
└─────────────────┬───────────────────────┘
                  │
┌─────────────────▼───────────────────────┐
│      Authorization Layer (RBAC)         │
│    (Role-based access control)          │
└─────────────────┬───────────────────────┘
                  │
┌─────────────────▼───────────────────────┐
│       Input Validation Layer            │
│    (Schema validation, sanitization)    │
└─────────────────┬───────────────────────┘
                  │
┌─────────────────▼───────────────────────┐
│          Business Logic                 │
└─────────────────────────────────────────┘
```

### Security Components

#### Input Validation
```python
from pydantic import BaseModel, validator

class AssetCreateRequest(BaseModel):
    """Validated asset creation request"""
    asset_type: str
    provider: str
    properties: dict
    
    @validator('asset_type')
    def validate_asset_type(cls, v):
        allowed_types = ['compute', 'storage', 'network', 'database']
        if v not in allowed_types:
            raise ValueError(f"Invalid asset type: {v}")
        return v
        
    @validator('properties')
    def validate_properties(cls, v):
        # Custom validation logic
        return v
```

#### Authentication & Authorization
```python
class SecurityMiddleware:
    """Security middleware for request processing"""
    
    def authenticate(self, token: str) -> User:
        """Validate JWT token"""
        try:
            payload = jwt.decode(token, SECRET_KEY, algorithms=['HS256'])
            return User.from_payload(payload)
        except jwt.InvalidTokenError:
            raise AuthenticationError("Invalid token")
            
    def authorize(self, user: User, resource: str, action: str) -> bool:
        """Check user authorization"""
        return self.rbac.check_permission(user.role, resource, action)
```

## Resilience Patterns (Requirements: 10.4, 10.5)

### Circuit Breaker Implementation
```python
class CircuitBreaker:
    """Circuit breaker for external dependencies"""
    
    def __init__(self, failure_threshold: int = 5, 
                 timeout: int = 60):
        self.failure_threshold = failure_threshold
        self.timeout = timeout
        self.failure_count = 0
        self.last_failure_time = None
        self.state = CircuitState.CLOSED
        
    def call(self, func: Callable, *args, **kwargs) -> Any:
        if self.state == CircuitState.OPEN:
            if self._should_attempt_reset():
                self.state = CircuitState.HALF_OPEN
            else:
                raise CircuitOpenError("Circuit breaker is open")
                
        try:
            result = func(*args, **kwargs)
            self._on_success()
            return result
        except Exception as e:
            self._on_failure()
            raise
```

### Retry Logic
```python
@retry(
    stop=stop_after_attempt(3),
    wait=wait_exponential(multiplier=1, min=4, max=10),
    retry=retry_if_exception_type(TransientError)
)
def collect_with_retry(collector: Collector) -> List[Asset]:
    """Collect assets with automatic retry"""
    return collector.collect()
```

## Performance Optimization

### Caching Strategy
```python
class CacheLayer:
    """Caching layer for frequently accessed data"""
    
    def __init__(self, ttl: int = 300):
        self.cache = TTLCache(maxsize=1000, ttl=ttl)
        
    def get_or_compute(self, key: str, compute_func: Callable) -> Any:
        if key in self.cache:
            return self.cache[key]
            
        value = compute_func()
        self.cache[key] = value
        return value
```

### Batch Processing
```python
class BatchProcessor:
    """Process assets in configurable batches"""
    
    def process_assets(self, assets: List[Asset], 
                      batch_size: int = 100) -> None:
        for i in range(0, len(assets), batch_size):
            batch = assets[i:i + batch_size]
            self._process_batch(batch)
```

## Deployment Architecture

### Container Architecture
```yaml
# docker-compose.yml
version: '3.8'

services:
  cloudscope:
    build: .
    ports:
      - "8080:8080"
    environment:
      - STORAGE_TYPE=sqlite
      - LOG_LEVEL=INFO
    volumes:
      - ./data:/app/data
      - ./config:/app/config
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      
  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      
  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_PASSWORD}
```

### Kubernetes Architecture
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cloudscope
spec:
  replicas: 3
  selector:
    matchLabels:
      app: cloudscope
  template:
    metadata:
      labels:
        app: cloudscope
    spec:
      containers:
      - name: cloudscope
        image: cloudscope:latest
        ports:
        - containerPort: 8080
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
        resources:
          requests:
            memory: "256Mi"
            cpu: "500m"
          limits:
            memory: "1Gi"
            cpu: "2000m"
```

## Extension Points

### Custom Collectors
Developers can create custom collectors by implementing the Collector interface:

```python
class CustomCollector(Collector):
    """Custom collector implementation"""
    
    def collect(self) -> List[Asset]:
        # Custom collection logic
        pass
```

### Custom Exporters
Export data in custom formats:

```python
class CustomExporter(Exporter):
    """Custom exporter implementation"""
    
    def export(self, assets: List[Asset], output: IO) -> None:
        # Custom export logic
        pass
```

### Event Hooks
Subscribe to system events:

```python
@event_handler('asset.created')
def on_asset_created(asset: Asset):
    # Handle asset creation event
    pass
```

## Future Architecture Considerations

### Planned Enhancements
1. **Machine Learning Integration**: Anomaly detection and predictive analytics
2. **Multi-tenancy Support**: Isolated environments for different organizations
3. **Federation**: Connect multiple CloudScope instances
4. **GraphQL API**: Alternative query interface
5. **Real-time Updates**: WebSocket support for live asset updates

### Scalability Roadmap
1. **Horizontal Scaling**: Support for distributed collection
2. **Sharding**: Database sharding for large deployments
3. **Event Streaming**: Integration with Kafka/Pulsar
4. **Edge Deployment**: Lightweight collectors for edge locations

## Architecture Decision Records (ADRs)

### ADR-001: Use Hexagonal Architecture
**Status**: Accepted  
**Context**: Need clear separation between business logic and infrastructure  
**Decision**: Implement hexagonal architecture with ports and adapters  
**Consequences**: Higher initial complexity but better testability and flexibility

### ADR-002: Plugin-Based Extensibility
**Status**: Accepted  
**Context**: Need to support multiple cloud providers and custom integrations  
**Decision**: Implement plugin system with versioned API  
**Consequences**: Easier third-party integrations but need careful API versioning

### ADR-003: Multi-Storage Support
**Status**: Accepted  
**Context**: Different deployment scenarios require different storage backends  
**Decision**: Support file, SQLite, and Memgraph with adapter pattern  
**Consequences**: More complex storage layer but greater deployment flexibility