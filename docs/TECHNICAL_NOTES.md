# Technical Architecture and Design Notes

## 🏗️ **System Architecture Overview**

CloudScope implements a modular, microservices-based architecture designed for scalability, security, and extensibility. The system follows the principle of separation of concerns with clear boundaries between data collection, processing, storage, and presentation layers.

### **Core Design Principles**

1. **Security First**: Every component designed with security as the primary concern
2. **Modular Architecture**: Loosely coupled components for flexibility and maintainability
3. **API-First Design**: All functionality exposed through well-defined APIs
4. **Cloud-Native**: Built for containerized deployment and cloud environments
5. **Open Source Standards**: Leveraging proven open-source technologies

## 🔧 **Component Architecture**

### **1. Data Collection Layer**

#### **PowerShell Collectors**
```
collectors/powershell/
├── microsoft-365/
│   ├── Get-M365Assets.ps1          # Main collection script
│   ├── modules/
│   │   ├── M365Auth.psm1           # Authentication module
│   │   ├── UserCollector.psm1      # User data collection
│   │   ├── DeviceCollector.psm1    # Device data collection
│   │   └── RiskScoring.psm1        # Risk assessment module
│   └── config/
│       ├── permissions.json        # Required Graph permissions
│       └── collection-rules.json   # Data collection rules
```

**Design Rationale**: PowerShell chosen for Microsoft ecosystem integration due to:
- Native Microsoft Graph SDK support
- Familiar to Windows administrators
- Strong error handling and logging capabilities
- Built-in credential management features

#### **Python Collectors**
```
collectors/python/
├── aws/
│   ├── ec2_collector.py            # EC2 instance collection
│   ├── s3_collector.py             # S3 bucket collection
│   ├── iam_collector.py            # IAM resource collection
│   └── base_collector.py           # Base collector interface
├── gcp/
│   ├── compute_collector.py        # GCE instance collection
│   ├── storage_collector.py        # Cloud Storage collection
│   └── iam_collector.py            # IAM resource collection
└── shared/
    ├── auth_manager.py             # Cross-platform authentication
    ├── rate_limiter.py             # API rate limiting
    └── data_normalizer.py          # Data format standardization
```

**Design Rationale**: Python chosen for cloud providers due to:
- Excellent SDK support for AWS, GCP, Azure
- Rich ecosystem for data processing
- Strong typing support with modern Python
- Extensive testing frameworks

### **2. Data Processing Layer**

#### **Asset Processor Engine**
```python
# core/processors/asset_processor.py

class AssetProcessor:
    """
    Central processing engine for asset data normalization,
    relationship detection, and enrichment.
    
    Design Pattern: Pipeline Pattern
    - Input validation
    - Data normalization  
    - Relationship calculation
    - Risk scoring
    - Output formatting
    """
    
    def __init__(self, db_connector, config):
        self.db = db_connector
        self.config = config
        self.pipeline_stages = [
            ValidationStage(),
            NormalizationStage(),
            RelationshipStage(),
            RiskScoringStage(),
            EnrichmentStage()
        ]
    
    async def process_batch(self, raw_data: Dict[str, Any]) -> ProcessingResult:
        """
        Process a batch of asset data through the pipeline.
        
        Args:
            raw_data: Raw asset data from collectors
            
        Returns:
            ProcessingResult with success status and metadata
            
        Raises:
            ValidationError: If data fails validation
            ProcessingError: If pipeline stage fails
        """
        try:
            result = raw_data
            for stage in self.pipeline_stages:
                result = await stage.process(result)
            
            return ProcessingResult(success=True, data=result)
            
        except Exception as e:
            logger.error(f"Processing failed: {e}")
            raise ProcessingError(f"Pipeline failed at stage: {stage.name}")
```

#### **Relationship Detection Algorithm**
```python
# core/processors/relationship_detector.py

class RelationshipDetector:
    """
    Advanced relationship detection using multiple algorithms:
    1. Direct references (IDs, names)
    2. Network topology analysis
    3. Access patterns
    4. Temporal correlation
    5. Machine learning inference
    """
    
    def detect_relationships(self, assets: List[Asset]) -> List[Relationship]:
        """
        Multi-algorithm relationship detection with confidence scoring.
        
        Algorithms:
        - DirectReferenceDetector: 95% confidence
        - NetworkTopologyDetector: 85% confidence  
        - AccessPatternDetector: 75% confidence
        - TemporalCorrelationDetector: 65% confidence
        - MLInferenceDetector: 50% confidence
        """
        relationships = []
        
        # Direct reference detection (highest confidence)
        relationships.extend(self._detect_direct_references(assets))
        
        # Network topology analysis
        relationships.extend(self._detect_network_relationships(assets))
        
        # Access pattern correlation
        relationships.extend(self._detect_access_patterns(assets))
        
        # Temporal correlation
        relationships.extend(self._detect_temporal_patterns(assets))
        
        # ML-based inference
        relationships.extend(self._ml_relationship_inference(assets))
        
        return self._deduplicate_relationships(relationships)
```

### **3. Storage Layer**

#### **Memgraph Database Design**
```cypher
// Graph schema for asset relationships

// Asset nodes with labels for different types
CREATE CONSTRAINT ON (a:Asset) ASSERT a.id IS UNIQUE;
CREATE CONSTRAINT ON (u:User) ASSERT u.id IS UNIQUE;
CREATE CONSTRAINT ON (d:Device) ASSERT d.id IS UNIQUE;
CREATE CONSTRAINT ON (app:Application) ASSERT app.id IS UNIQUE;

// Relationship types with metadata
(:User)-[:OWNS {confidence: float, created: datetime}]->(:Device)
(:User)-[:MEMBER_OF {role: string, created: datetime}]->(:Group)
(:Device)-[:CONNECTS_TO {protocol: string, port: int}]->(:Network)
(:Application)-[:INSTALLED_ON {version: string, installed: datetime}]->(:Device)
(:Asset)-[:DEPENDS_ON {dependency_type: string, criticality: string}]->(:Asset)

// Indexes for performance
CREATE INDEX ON :Asset(asset_type);
CREATE INDEX ON :Asset(source);
CREATE INDEX ON :Asset(risk_score);
CREATE INDEX ON :Asset(last_updated);
```

**Design Rationale**: Memgraph chosen over Neo4j for:
- 8x faster read performance
- 50x faster write performance
- Full Cypher compatibility
- Open source with commercial support
- Better handling of real-time updates

## 🚀 **Deployment Architecture**

### **Container Configuration**
```dockerfile
# Dockerfile with security hardening

# Multi-stage build for minimal attack surface
FROM python:3.11-slim as builder

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# Production stage
FROM python:3.11-slim

# Create non-root user
RUN groupadd -r cloudscope && useradd -r -g cloudscope cloudscope

# Copy Python packages from builder
COPY --from=builder /root/.local /home/cloudscope/.local

# Copy application code
COPY --chown=cloudscope:cloudscope . /app
WORKDIR /app

# Security hardening
RUN chmod -R 755 /app && \
    chown -R cloudscope:cloudscope /app

# Switch to non-root user
USER cloudscope

# Environment variables
ENV PATH=/home/cloudscope/.local/bin:$PATH
ENV PYTHONPATH=/app

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8000/health || exit 1

# Expose port
EXPOSE 8000

# Start application
CMD ["uvicorn", "core.api.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### **Docker Compose Configuration**
```yaml
# docker-compose.yml

version: '3.8'

services:
  # Memgraph Database
  memgraph:
    image: memgraph/memgraph:latest
    container_name: cloudscope-memgraph
    ports:
      - "7687:7687"
      - "7444:7444"
    environment:
      - MEMGRAPH_USER=cloudscope
      - MEMGRAPH_PASSWORD=${MEMGRAPH_PASSWORD}
    volumes:
      - memgraph_data:/var/lib/memgraph
      - memgraph_log:/var/log/memgraph
      - memgraph_etc:/etc/memgraph
    networks:
      - cloudscope-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "echo 'MATCH (n) RETURN count(n);' | mgconsole"]
      interval: 30s
      timeout: 10s
      retries: 3

  # PostgreSQL for metadata
  postgres:
    image: postgres:15-alpine
    container_name: cloudscope-postgres
    environment:
      - POSTGRES_DB=cloudscope
      - POSTGRES_USER=cloudscope
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./scripts/init-postgres.sql:/docker-entrypoint-initdb.d/init.sql
    networks:
      - cloudscope-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U cloudscope"]
      interval: 30s
      timeout: 10s
      retries: 3

  # Redis Cache
  redis:
    image: redis:7-alpine
    container_name: cloudscope-redis
    command: redis-server --appendonly yes --requirepass ${REDIS_PASSWORD}
    volumes:
      - redis_data:/data
    networks:
      - cloudscope-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "redis-cli", "--raw", "incr", "ping"]
      interval: 30s
      timeout: 10s
      retries: 3

  # CloudScope API
  api:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: cloudscope-api
    ports:
      - "8000:8000"
    environment:
      - DEBUG=false
      - LOG_LEVEL=INFO
      - MEMGRAPH_HOST=memgraph
      - POSTGRES_HOST=postgres
      - REDIS_HOST=redis
      - JWT_SECRET_KEY=${JWT_SECRET_KEY}
    depends_on:
      - memgraph
      - postgres
      - redis
    volumes:
      - ./config:/app/config:ro
      - ./logs:/app/logs
    networks:
      - cloudscope-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  # Web UI
  web:
    build:
      context: ./web-ui
      dockerfile: Dockerfile
    container_name: cloudscope-web
    ports:
      - "3000:3000"
    environment:
      - REACT_APP_API_URL=http://localhost:8000
      - NODE_ENV=production
    depends_on:
      - api
    networks:
      - cloudscope-network
    restart: unless-stopped

  # Elasticsearch for logging
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.11.0
    container_name: cloudscope-elasticsearch
    environment:
      - discovery.type=single-node
      - "ES_JAVA_OPTS=-Xms512m -Xmx512m"
      - xpack.security.enabled=false
    volumes:
      - elasticsearch_data:/usr/share/elasticsearch/data
    networks:
      - cloudscope-network
    restart: unless-stopped

  # Kibana for log visualization
  kibana:
    image: docker.elastic.co/kibana/kibana:8.11.0
    container_name: cloudscope-kibana
    ports:
      - "5601:5601"
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
    depends_on:
      - elasticsearch
    networks:
      - cloudscope-network
    restart: unless-stopped

  # Grafana for dashboards
  grafana:
    image: grafana/grafana:latest
    container_name: cloudscope-grafana
    ports:
      - "3001:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_PASSWORD}
    volumes:
      - grafana_data:/var/lib/grafana
      - ./grafana/dashboards:/etc/grafana/provisioning/dashboards
      - ./grafana/datasources:/etc/grafana/provisioning/datasources
    networks:
      - cloudscope-network
    restart: unless-stopped

volumes:
  memgraph_data:
  memgraph_log:
  memgraph_etc:
  postgres_data:
  redis_data:
  elasticsearch_data:
  grafana_data:

networks:
  cloudscope-network:
    driver: bridge
```

## 📊 **Performance Architecture**

### **Horizontal Scaling Strategy**
```yaml
# kubernetes/deployment.yaml

apiVersion: apps/v1
kind: Deployment
metadata:
  name: cloudscope-api
  labels:
    app: cloudscope-api
spec:
  replicas: 3
  selector:
    matchLabels:
      app: cloudscope-api
  template:
    metadata:
      labels:
        app: cloudscope-api
    spec:
      containers:
      - name: api
        image: cloudscope/api:latest
        ports:
        - containerPort: 8000
        env:
        - name: MEMGRAPH_HOST
          value: "memgraph-service"
        - name: REDIS_HOST
          value: "redis-service"
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 8000
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: cloudscope-api-service
spec:
  selector:
    app: cloudscope-api
  ports:
  - protocol: TCP
    port: 80
    targetPort: 8000
  type: LoadBalancer
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: cloudscope-api-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: cloudscope-api
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

### **Caching Strategy**
```python
# core/cache/cache_manager.py

import asyncio
import redis.asyncio as redis
from typing import Optional, Any, Dict, List
import json
import pickle
from datetime import timedelta
import hashlib

class MultiLevelCacheManager:
    """
    Multi-level caching strategy for optimal performance:
    
    L1 Cache: In-memory LRU cache (fastest, smallest)
    L2 Cache: Redis (fast, shared across instances)
    L3 Cache: Database query cache (slower, persistent)
    """
    
    def __init__(self, redis_url: str, max_memory_cache_size: int = 1000):
        self.redis_pool = redis.ConnectionPool.from_url(redis_url)
        self.redis_client = redis.Redis(connection_pool=self.redis_pool)
        
        # L1 Cache: In-memory LRU
        from cachetools import TTLCache
        self.memory_cache = TTLCache(maxsize=max_memory_cache_size, ttl=300)  # 5 minutes
        
        # Cache statistics
        self.stats = {
            'l1_hits': 0, 'l1_misses': 0,
            'l2_hits': 0, 'l2_misses': 0,
            'l3_hits': 0, 'l3_misses': 0
        }
    
    async def get(self, key: str) -> Optional[Any]:
        """Get value from cache with fallback strategy."""
        cache_key = self._hash_key(key)
        
        # L1 Cache check
        if cache_key in self.memory_cache:
            self.stats['l1_hits'] += 1
            return self.memory_cache[cache_key]
        self.stats['l1_misses'] += 1
        
        # L2 Cache check (Redis)
        try:
            cached_data = await self.redis_client.get(f"cache:{cache_key}")
            if cached_data:
                self.stats['l2_hits'] += 1
                data = pickle.loads(cached_data)
                # Populate L1 cache
                self.memory_cache[cache_key] = data
                return data
        except Exception as e:
            logger.warning(f"Redis cache error: {e}")
        
        self.stats['l2_misses'] += 1
        return None
    
    async def set(self, key: str, value: Any, ttl: int = 3600):
        """Set value in all cache levels."""
        cache_key = self._hash_key(key)
        
        # L1 Cache
        self.memory_cache[cache_key] = value
        
        # L2 Cache (Redis)
        try:
            serialized_data = pickle.dumps(value)
            await self.redis_client.setex(f"cache:{cache_key}", ttl, serialized_data)
        except Exception as e:
            logger.warning(f"Redis cache set error: {e}")
    
    async def invalidate(self, pattern: str):
        """Invalidate cache entries matching pattern."""
        # Clear L1 cache matching pattern
        keys_to_remove = [k for k in self.memory_cache.keys() if pattern in k]
        for key in keys_to_remove:
            del self.memory_cache[key]
        
        # Clear L2 cache (Redis)
        try:
            cursor = 0
            while True:
                cursor, keys = await self.redis_client.scan(
                    cursor=cursor, 
                    match=f"cache:*{pattern}*", 
                    count=100
                )
                if keys:
                    await self.redis_client.delete(*keys)
                if cursor == 0:
                    break
        except Exception as e:
            logger.warning(f"Redis cache invalidation error: {e}")
    
    def _hash_key(self, key: str) -> str:
        """Create consistent hash for cache key."""
        return hashlib.md5(key.encode()).hexdigest()
    
    def get_stats(self) -> Dict[str, Any]:
        """Get cache performance statistics."""
        total_requests = sum(self.stats.values())
        if total_requests == 0:
            return self.stats
        
        return {
            **self.stats,
            'l1_hit_rate': self.stats['l1_hits'] / (self.stats['l1_hits'] + self.stats['l1_misses']),
            'l2_hit_rate': self.stats['l2_hits'] / (self.stats['l2_hits'] + self.stats['l2_misses']),
            'total_hit_rate': (self.stats['l1_hits'] + self.stats['l2_hits']) / total_requests
        }
```

## 🔒 **Security Implementation**

### **Comprehensive Security Layer**
```python
# core/security/security_manager.py

import bcrypt
import jwt
from cryptography.fernet import Fernet
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
import secrets
import base64
from datetime import datetime, timedelta
from typing import Optional, Dict, Any
import logging

class SecurityManager:
    """
    Comprehensive security management with multiple layers of protection.
    
    Features:
    - Password hashing with bcrypt
    - JWT token management
    - Field-level encryption
    - API key generation and validation
    - Rate limiting
    - Audit logging
    """
    
    def __init__(self, config: SecurityConfig):
        self.config = config
        self.jwt_secret = config.jwt_secret_key
        self.encryption_key = self._derive_encryption_key(config.encryption_password)
        self.fernet = Fernet(self.encryption_key)
        self.rate_limiter = RateLimiter()
        self.audit_logger = logging.getLogger('cloudscope.audit')
    
    def _derive_encryption_key(self, password: str) -> bytes:
        """Derive encryption key from password using PBKDF2."""
        salt = b'cloudscope_salt_v1'  # In production, use random salt per field
        kdf = PBKDF2HMAC(
            algorithm=hashes.SHA256(),
            length=32,
            salt=salt,
            iterations=100000,
        )
        key = base64.urlsafe_b64encode(kdf.derive(password.encode()))
        return key
    
    def hash_password(self, password: str) -> str:
        """Hash password using bcrypt with salt."""
        salt = bcrypt.gensalt(rounds=12)
        hashed = bcrypt.hashpw(password.encode('utf-8'), salt)
        return hashed.decode('utf-8')
    
    def verify_password(self, password: str, hashed: str) -> bool:
        """Verify password against hash."""
        return bcrypt.checkpw(password.encode('utf-8'), hashed.encode('utf-8'))
    
    def create_access_token(self, user_data: Dict[str, Any], expires_delta: Optional[timedelta] = None) -> str:
        """Create JWT access token with user claims."""
        to_encode = user_data.copy()
        
        if expires_delta:
            expire = datetime.utcnow() + expires_delta
        else:
            expire = datetime.utcnow() + timedelta(minutes=self.config.jwt_expiration_minutes)
        
        # Add standard JWT claims
        to_encode.update({
            "exp": expire,
            "iat": datetime.utcnow(),
            "iss": "cloudscope",
            "aud": "cloudscope-api"
        })
        
        token = jwt.encode(to_encode, self.jwt_secret, algorithm="HS256")
        
        # Audit log token creation
        self.audit_logger.info(f"JWT token created for user: {user_data.get('username', 'unknown')}")
        
        return token
    
    def verify_token(self, token: str) -> Optional[Dict[str, Any]]:
        """Verify JWT token and return payload."""
        try:
            payload = jwt.decode(
                token, 
                self.jwt_secret, 
                algorithms=["HS256"],
                audience="cloudscope-api",
                issuer="cloudscope"
            )
            
            # Check if token is not expired
            if payload.get('exp', 0) < datetime.utcnow().timestamp():
                return None
            
            return payload
            
        except jwt.InvalidTokenError as e:
            self.audit_logger.warning(f"Invalid token: {e}")
            return None
    
    def encrypt_sensitive_field(self, data: str) -> str:
        """Encrypt sensitive data for database storage."""
        if not data:
            return data
        
        encrypted_data = self.fernet.encrypt(data.encode())
        return base64.b64encode(encrypted_data).decode()
    
    def decrypt_sensitive_field(self, encrypted_data: str) -> str:
        """Decrypt sensitive data from database."""
        if not encrypted_data:
            return encrypted_data
        
        try:
            decoded_data = base64.b64decode(encrypted_data.encode())
            decrypted_data = self.fernet.decrypt(decoded_data)
            return decrypted_data.decode()
        except Exception as e:
            logger.error(f"Decryption failed: {e}")
            return ""
    
    def generate_api_key(self, user_id: str, permissions: List[str]) -> str:
        """Generate secure API key with embedded permissions."""
        # Create API key payload
        payload = {
            "user_id": user_id,
            "permissions": permissions,
            "created_at": datetime.utcnow().isoformat(),
            "key_id": secrets.token_hex(16)
        }
        
        # Encode as JWT (allows for validation and expiration)
        api_key = jwt.encode(payload, self.jwt_secret, algorithm="HS256")
        
        # Audit log API key creation
        self.audit_logger.info(f"API key created for user: {user_id}")
        
        return api_key
    
    def validate_api_key(self, api_key: str) -> Optional[Dict[str, Any]]:
        """Validate API key and return permissions."""
        try:
            payload = jwt.decode(api_key, self.jwt_secret, algorithms=["HS256"])
            
            # Check rate limiting
            user_id = payload.get('user_id')
            if not self.rate_limiter.check_rate_limit(user_id):
                self.audit_logger.warning(f"Rate limit exceeded for user: {user_id}")
                return None
            
            return payload
            
        except jwt.InvalidTokenError:
            self.audit_logger.warning("Invalid API key used")
            return None

class RateLimiter:
    """Token bucket rate limiter for API endpoints."""
    
    def __init__(self):
        self.buckets = {}  # user_id -> (tokens, last_refill)
        self.max_tokens = 100
        self.refill_rate = 10  # tokens per minute
    
    def check_rate_limit(self, user_id: str) -> bool:
        """Check if user has tokens available."""
        now = datetime.utcnow()
        
        if user_id not in self.buckets:
            self.buckets[user_id] = (self.max_tokens - 1, now)
            return True
        
        tokens, last_refill = self.buckets[user_id]
        
        # Refill tokens based on time elapsed
        time_elapsed = (now - last_refill).total_seconds() / 60  # minutes
        tokens_to_add = int(time_elapsed * self.refill_rate)
        tokens = min(self.max_tokens, tokens + tokens_to_add)
        
        if tokens > 0:
            self.buckets[user_id] = (tokens - 1, now)
            return True
        else:
            self.buckets[user_id] = (0, last_refill)
            return False
```

## 🧪 **Testing Architecture**

### **Comprehensive Testing Strategy**
```python
# tests/conftest.py

import pytest
import asyncio
from typing import AsyncGenerator
from testcontainers import compose
from httpx import AsyncClient
from core.api.main import app
from core.database.memgraph_connector import CloudScopeDatabase
from core.config.settings import CloudScopeConfig

@pytest.fixture(scope="session")
def event_loop():
    """Create an instance of the default event loop for the test session."""
    loop = asyncio.get_event_loop_policy().new_event_loop()
    yield loop
    loop.close()

@pytest.fixture(scope="session")
async def docker_services():
    """Start CloudScope services for integration testing."""
    with compose.DockerCompose(".", compose_file_name="docker-compose.test.yml") as services:
        # Wait for services to be ready
        services.wait_for("http://localhost:8000/health")
        yield services

@pytest.fixture
async def test_config() -> CloudScopeConfig:
    """Test configuration with safe defaults."""
    return CloudScopeConfig(
        debug=True,
        database=DatabaseConfig(
            host="localhost",
            port=7687,
            username="test",
            password="test"
        ),
        security=SecurityConfig(
            jwt_secret_key="test-secret-key-for-testing-only",
            jwt_expiration_minutes=60
        )
    )

@pytest.fixture
async def test_database(test_config) -> AsyncGenerator[CloudScopeDatabase, None]:
    """Test database connection with cleanup."""
    db = CloudScopeDatabase(
        host=test_config.database.host,
        port=test_config.database.port,
        username=test_config.database.username,
        password=test_config.database.password
    )
    
    yield db
    
    # Cleanup test data
    await db.execute("MATCH (n) DETACH DELETE n")

@pytest.fixture
async def test_client(test_config) -> AsyncGenerator[AsyncClient, None]:
    """HTTP test client for API testing."""
    async with AsyncClient(app=app, base_url="http://test") as client:
        yield client

@pytest.fixture
async def authenticated_client(test_client, test_config) -> AsyncGenerator[AsyncClient, None]:
    """Authenticated HTTP client with valid JWT token."""
    from core.security.security_manager import SecurityManager
    
    security_manager = SecurityManager(test_config.security)
    token = security_manager.create_access_token({"username": "testuser", "role": "admin"})
    
    test_client.headers.update({"Authorization": f"Bearer {token}"})
    yield test_client

@pytest.fixture
def sample_asset_data():
    """Sample asset data for testing."""
    return {
        "users": [
            {
                "id": "user-123",
                "display_name": "Test User",
                "user_principal_name": "test.user@example.com",
                "account_enabled": True,
                "risk_score": 25
            }
        ],
        "devices": [
            {
                "id": "device-456",
                "name": "Test Device",
                "device_type": "laptop",
                "os": "Windows 11",
                "risk_score": 15
            }
        ]
    }

# Integration Tests
class TestAssetProcessingWorkflow:
    """Test complete asset processing workflow."""
    
    async def test_end_to_end_asset_collection(
        self, 
        authenticated_client: AsyncClient,
        test_database: CloudScopeDatabase,
        sample_asset_data: dict
    ):
        """Test complete asset collection and processing workflow."""
        
        # 1. Submit asset data via API
        response = await authenticated_client.post(
            "/api/v1/assets/bulk",
            json=sample_asset_data
        )
        assert response.status_code == 200
        
        # 2. Verify assets are stored in database
        assets = await test_database.get_assets()
        assert len(assets) == 2
        
        # 3. Verify relationships are detected
        relationships = await test_database.get_relationships()
        assert len(relationships) > 0
        
        # 4. Verify risk scores are calculated
        user_asset = next(a for a in assets if a['asset_type'] == 'user')
        assert user_asset['risk_score'] == 25

# Performance Tests
class TestPerformance:
    """Performance and load testing."""
    
    @pytest.mark.asyncio
    async def test_bulk_import_performance(
        self,
        authenticated_client: AsyncClient,
        test_database: CloudScopeDatabase
    ):
        """Test performance with large asset batches."""
        import time
        
        # Generate large dataset
        large_dataset = {
            "users": [
                {
                    "id": f"user-{i}",
                    "display_name": f"User {i}",
                    "user_principal_name": f"user{i}@example.com",
                    "account_enabled": True,
                    "risk_score": i % 100
                }
                for i in range(1000)
            ]
        }
        
        start_time = time.time()
        
        response = await authenticated_client.post(
            "/api/v1/assets/bulk",
            json=large_dataset
        )
        
        end_time = time.time()
        processing_time = end_time - start_time
        
        assert response.status_code == 200
        assert processing_time < 30  # Should process 1000 assets in under 30 seconds
        
        # Verify all assets were processed
        assets = await test_database.get_assets()
        assert len(assets) == 1000

# Security Tests
class TestSecurity:
    """Security testing for authentication and authorization."""
    
    async def test_unauthorized_access_blocked(self, test_client: AsyncClient):
        """Test that unauthorized requests are blocked."""
        response = await test_client.get("/api/v1/assets")
        assert response.status_code == 401
    
    async def test_invalid_token_rejected(self, test_client: AsyncClient):
        """Test that invalid JWT tokens are rejected."""
        test_client.headers.update({"Authorization": "Bearer invalid-token"})
        response = await test_client.get("/api/v1/assets")
        assert response.status_code == 401
    
    async def test_input_validation_prevents_injection(
        self, 
        authenticated_client: AsyncClient
    ):
        """Test that malicious input is properly validated."""
        malicious_data = {
            "users": [
                {
                    "id": "'; DROP TABLE assets; --",
                    "display_name": "<script>alert('xss')</script>",
                    "user_principal_name": "malicious@evil.com"
                }
            ]
        }
        
        response = await authenticated_client.post(
            "/api/v1/assets/bulk",
            json=malicious_data
        )
        
        # Should either reject with 400 or sanitize the input
        if response.status_code == 200:
            # Verify data was sanitized
            assets = await test_database.get_assets()
            asset = assets[0]
            assert "<script>" not in asset['display_name']
            assert "DROP TABLE" not in asset['id']
```

## 📚 **Documentation System**

### **Automated Documentation Generation**
```python
# docs/generate_docs.py

import ast
import inspect
from typing import List, Dict, Any
from pathlib import Path
import json

class DocumentationGenerator:
    """
    Automated documentation generator for CloudScope components.
    
    Generates:
    - API documentation from FastAPI
    - Code documentation from docstrings
    - Configuration reference from Pydantic models
    - Database schema from Cypher queries
    """
    
    def __init__(self, source_dirs: List[str], output_dir: str):
        self.source_dirs = [Path(d) for d in source_dirs]
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(exist_ok=True)
    
    def generate_all_docs(self):
        """Generate comprehensive documentation."""
        print("🔄 Generating CloudScope documentation...")
        
        # Generate API docs
        self._generate_api_docs()
        
        # Generate code docs
        self._generate_code_docs()
        
        # Generate configuration docs
        self._generate_config_docs()
        
        # Generate database schema docs
        self._generate_schema_docs()
        
        # Generate deployment docs
        self._generate_deployment_docs()
        
        print("✅ Documentation generated successfully!")
    
    def _generate_api_docs(self):
        """Generate API documentation from FastAPI."""
        from core.api.main import app
        
        openapi_schema = app.openapi()
        
        # Save OpenAPI schema
        with open(self.output_dir / "api-schema.json", "w") as f:
            json.dump(openapi_schema, f, indent=2)
        
        # Generate human-readable API docs
        api_docs = self._format_api_docs(openapi_schema)
        with open(self.output_dir / "api-reference.md", "w") as f:
            f.write(api_docs)
    
    def _format_api_docs(self, schema: dict) -> str:
        """Format OpenAPI schema as Markdown documentation."""
        docs = ["# CloudScope API Reference\n\n"]
        
        for path, methods in schema.get("paths", {}).items():
            docs.append(f"## {path}\n\n")
            
            for method, details in methods.items():
                docs.append(f"### {method.upper()}\n\n")
                docs.append(f"**Summary**: {details.get('summary', 'No summary')}\n\n")
                docs.append(f"**Description**: {details.get('description', 'No description')}\n\n")
                
                # Parameters
                if 'parameters' in details:
                    docs.append("**Parameters**:\n\n")
                    for param in details['parameters']:
                        docs.append(f"- `{param['name']}` ({param.get('in', 'query')}): {param.get('description', 'No description')}\n")
                    docs.append("\n")
                
                # Request body
                if 'requestBody' in details:
                    docs.append("**Request Body**:\n\n")
                    content = details['requestBody'].get('content', {})
                    for content_type, schema_info in content.items():
                        docs.append(f"Content-Type: `{content_type}`\n\n")
                        if 'schema' in schema_info:
                            docs.append(f"```json\n{json.dumps(schema_info['schema'], indent=2)}\n```\n\n")
                
                # Responses
                if 'responses' in details:
                    docs.append("**Responses**:\n\n")
                    for status_code, response in details['responses'].items():
                        docs.append(f"- `{status_code}`: {response.get('description', 'No description')}\n")
                    docs.append("\n")
                
                docs.append("---\n\n")
        
        return "".join(docs)
    
    def _generate_code_docs(self):
        """Generate code documentation from Python docstrings."""
        docs = ["# CloudScope Code Documentation\n\n"]
        
        for source_dir in self.source_dirs:
            for py_file in source_dir.rglob("*.py"):
                if py_file.name.startswith("__"):
                    continue
                
                module_docs = self._extract_module_docs(py_file)
                if module_docs:
                    docs.append(module_docs)
        
        with open(self.output_dir / "code-reference.md", "w") as f:
            f.write("".join(docs))
    
    def _extract_module_docs(self, file_path: Path) -> str:
        """Extract documentation from Python module."""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                source = f.read()
            
            tree = ast.parse(source)
            
            docs = [f"## {file_path.relative_to(file_path.parents[2])}\n\n"]
            
            # Module docstring
            if ast.get_docstring(tree):
                docs.append(f"{ast.get_docstring(tree)}\n\n")
            
            # Classes and functions
            for node in ast.walk(tree):
                if isinstance(node, ast.ClassDef):
                    docs.append(f"### Class: {node.name}\n\n")
                    if ast.get_docstring(node):
                        docs.append(f"{ast.get_docstring(node)}\n\n")
                
                elif isinstance(node, ast.FunctionDef) and not node.name.startswith("_"):
                    docs.append(f"#### Function: {node.name}\n\n")
                    if ast.get_docstring(node):
                        docs.append(f"{ast.get_docstring(node)}\n\n")
            
            docs.append("---\n\n")
            return "".join(docs)
            
        except Exception as e:
            print(f"Error processing {file_path}: {e}")
            return ""
```

This comprehensive technical documentation provides the foundation for a robust, secure, and scalable CloudScope implementation. The architecture emphasizes modularity, security, and performance while maintaining the open-source community focus.
