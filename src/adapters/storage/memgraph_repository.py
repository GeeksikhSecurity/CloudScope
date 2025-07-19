"""Memgraph storage adapter implementation.

Implements asset and relationship repositories using Memgraph graph database.
Requirements: 1.1, 1.2, 1.3, 0.3
"""

import json
import logging
from typing import List, Optional, Dict, Any, Iterator
from datetime import datetime
from contextlib import contextmanager

try:
    from neo4j import GraphDatabase, Session
    MEMGRAPH_AVAILABLE = True
except ImportError:
    MEMGRAPH_AVAILABLE = False
    GraphDatabase = None
    Session = None

from ...domain.models import Asset, Relationship
from ...ports.repository import (
    AssetRepository, RelationshipRepository,
    RepositoryError, AssetNotFoundError, RelationshipNotFoundError,
    DuplicateAssetError, DuplicateRelationshipError
)
from .file_repository import FileBasedAssetRepository, FileBasedRelationshipRepository


class MemgraphConnection:
    """Manages Memgraph database connections."""
    
    def __init__(self, uri: str, username: str, password: str, database: str = "memgraph"):
        """Initialize Memgraph connection.
        
        Args:
            uri: Memgraph URI (e.g., bolt://localhost:7687)
            username: Username for authentication
            password: Password for authentication
            database: Database name
        """
        if not MEMGRAPH_AVAILABLE:
            raise ImportError("neo4j package is required for Memgraph support")
        
        self.uri = uri
        self.username = username
        self.password = password
        self.database = database
        self.logger = logging.getLogger(self.__class__.__name__)
        
        # Initialize driver
        self.driver = GraphDatabase.driver(uri, auth=(username, password))
        
        # Test connection and create constraints
        self._init_database()
    
    @contextmanager
    def get_session(self) -> Session:
        """Get a database session with proper cleanup."""
        session = self.driver.session(database=self.database)
        try:
            yield session
        finally:
            session.close()
    
    def close(self):
        """Close the driver connection."""
        if self.driver:
            self.driver.close()
    
    def _init_database(self):
        """Initialize database schema and constraints."""
        with self.get_session() as session:
            try:
                # Create constraints for assets
                session.run("""
                    CREATE CONSTRAINT ON (a:Asset) 
                    ASSERT a.asset_id IS UNIQUE
                """)
                
                # Create indices
                session.run("CREATE INDEX ON :Asset(asset_type)")
                session.run("CREATE INDEX ON :Asset(provider)")
                session.run("CREATE INDEX ON :Asset(status)")
                session.run("CREATE INDEX ON :Asset(risk_score)")
                
                self.logger.info("Memgraph database initialized")
            except Exception as e:
                # Constraints might already exist
                self.logger.debug(f"Database initialization: {e}")


class MemgraphAssetRepository(AssetRepository):
    """Memgraph implementation of AssetRepository with fallback support."""
    
    def __init__(self, connection_config: Dict[str, Any], 
                 fallback_config: Optional[Dict[str, Any]] = None):
        """Initialize Memgraph asset repository.
        
        Args:
            connection_config: Memgraph connection configuration
            fallback_config: Optional fallback storage configuration
        """
        self.logger = logging.getLogger(self.__class__.__name__)
        self.fallback_repository = None
        
        # Initialize fallback if configured
        if fallback_config:
            fallback_type = fallback_config.get("type", "file")
            if fallback_type == "file":
                self.fallback_repository = FileBasedAssetRepository(
                    fallback_config.get("path", "./fallback/assets")
                )
            self.logger.info(f"Fallback repository configured: {fallback_type}")
        
        # Initialize Memgraph connection
        try:
            self.connection = MemgraphConnection(
                uri=connection_config.get("uri", "bolt://localhost:7687"),
                username=connection_config.get("username", "memgraph"),
                password=connection_config.get("password", ""),
                database=connection_config.get("database", "memgraph")
            )
            self._available = True
        except Exception as e:
            self.logger.error(f"Failed to connect to Memgraph: {e}")
            self._available = False
            if not self.fallback_repository:
                raise RepositoryError("Memgraph unavailable and no fallback configured")
    
    def _use_fallback(self) -> bool:
        """Check if fallback should be used."""
        return not self._available and self.fallback_repository is not None
    
    def _asset_to_node(self, asset: Asset) -> Dict[str, Any]:
        """Convert asset to Memgraph node properties."""
        return {
            "asset_id": asset.asset_id,
            "asset_type": asset.asset_type,
            "provider": asset.provider,
            "name": asset.name,
            "properties": json.dumps(asset.properties),
            "tags": json.dumps(asset.tags),
            "metadata": json.dumps(asset.metadata),
            "created_at": asset.created_at.isoformat(),
            "updated_at": asset.updated_at.isoformat(),
            "discovered_at": asset.discovered_at.isoformat(),
            "status": asset.status,
            "health": asset.health,
            "compliance_status": asset.compliance_status,
            "risk_score": asset.risk_score,
            "estimated_cost": asset.estimated_cost
        }
    
    def _node_to_asset(self, node: Dict[str, Any]) -> Asset:
        """Convert Memgraph node to asset."""
        # Parse JSON fields
        properties = json.loads(node.get("properties", "{}"))
        tags = json.loads(node.get("tags", "{}"))
        metadata = json.loads(node.get("metadata", "{}"))
        
        # Create asset
        asset = Asset(
            asset_id=node["asset_id"],
            asset_type=node["asset_type"],
            provider=node["provider"],
            name=node["name"]
        )
        
        # Set fields
        asset.properties = properties
        asset.tags = tags
        asset.metadata = metadata
        asset.created_at = datetime.fromisoformat(node["created_at"])
        asset.updated_at = datetime.fromisoformat(node["updated_at"])
        asset.discovered_at = datetime.fromisoformat(node["discovered_at"])
        asset.status = node["status"]
        asset.health = node["health"]
        asset.compliance_status = node["compliance_status"]
        asset.risk_score = node["risk_score"]
        asset.estimated_cost = node["estimated_cost"]
        
        return asset
    
    def save(self, asset: Asset) -> Asset:
        """Save a single asset."""
        if self._use_fallback():
            return self.fallback_repository.save(asset)
        
        try:
            with self.connection.get_session() as session:
                # Check if already exists
                result = session.run(
                    "MATCH (a:Asset {asset_id: $asset_id}) RETURN a",
                    asset_id=asset.asset_id
                )
                
                if result.single():
                    raise DuplicateAssetError(f"Asset {asset.asset_id} already exists")
                
                # Create asset node
                node_props = self._asset_to_node(asset)
                session.run(
                    """
                    CREATE (a:Asset)
                    SET a = $props
                    """,
                    props=node_props
                )
                
                self.logger.info(f"Saved asset {asset.asset_id} to Memgraph")
                return asset
                
        except Exception as e:
            self.logger.error(f"Failed to save asset to Memgraph: {e}")
            if self.fallback_repository:
                self.logger.info("Using fallback repository")
                return self.fallback_repository.save(asset)
            raise RepositoryError(f"Failed to save asset: {e}")
    
    def save_batch(self, assets: List[Asset]) -> List[Asset]:
        """Save multiple assets in batch."""
        if self._use_fallback():
            return self.fallback_repository.save_batch(assets)
        
        saved_assets = []
        
        try:
            with self.connection.get_session() as session:
                for asset in assets:
                    try:
                        # Check if exists
                        result = session.run(
                            "MATCH (a:Asset {asset_id: $asset_id}) RETURN a",
                            asset_id=asset.asset_id
                        )
                        
                        if result.single():
                            self.logger.warning(f"Skipping duplicate asset {asset.asset_id}")
                            continue
                        
                        # Create asset
                        node_props = self._asset_to_node(asset)
                        session.run(
                            """
                            CREATE (a:Asset)
                            SET a = $props
                            """,
                            props=node_props
                        )
                        
                        saved_assets.append(asset)
                        
                    except Exception as e:
                        self.logger.error(f"Failed to save asset {asset.asset_id}: {e}")
                        if not saved_assets:
                            raise
                
                return saved_assets
                
        except Exception as e:
            self.logger.error(f"Batch save failed in Memgraph: {e}")
            if self.fallback_repository:
                return self.fallback_repository.save_batch(assets)
            raise RepositoryError(f"Batch save failed: {e}")
    
    def find_by_id(self, asset_id: str) -> Optional[Asset]:
        """Find asset by ID."""
        if self._use_fallback():
            return self.fallback_repository.find_by_id(asset_id)
        
        try:
            with self.connection.get_session() as session:
                result = session.run(
                    "MATCH (a:Asset {asset_id: $asset_id}) RETURN a",
                    asset_id=asset_id
                )
                
                record = result.single()
                if not record:
                    return None
                
                return self._node_to_asset(dict(record["a"]))
                
        except Exception as e:
            self.logger.error(f"Failed to find asset in Memgraph: {e}")
            if self.fallback_repository:
                return self.fallback_repository.find_by_id(asset_id)
            raise RepositoryError(f"Failed to find asset: {e}")
    
    def find_all(self, filters: Optional[Dict[str, Any]] = None,
                 limit: Optional[int] = None,
                 offset: Optional[int] = None) -> List[Asset]:
        """Find all assets matching filters."""
        if self._use_fallback():
            return self.fallback_repository.find_all(filters, limit, offset)
        
        try:
            with self.connection.get_session() as session:
                # Build query
                query = "MATCH (a:Asset)"
                where_clauses = []
                params = {}
                
                if filters:
                    if "asset_type" in filters:
                        where_clauses.append("a.asset_type = $asset_type")
                        params["asset_type"] = filters["asset_type"]
                    
                    if "provider" in filters:
                        where_clauses.append("a.provider = $provider")
                        params["provider"] = filters["provider"]
                    
                    if "status" in filters:
                        where_clauses.append("a.status = $status")
                        params["status"] = filters["status"]
                    
                    if "min_risk_score" in filters:
                        where_clauses.append("a.risk_score >= $min_risk")
                        params["min_risk"] = filters["min_risk_score"]
                    
                    if "max_risk_score" in filters:
                        where_clauses.append("a.risk_score <= $max_risk")
                        params["max_risk"] = filters["max_risk_score"]
                
                if where_clauses:
                    query += " WHERE " + " AND ".join(where_clauses)
                
                query += " RETURN a ORDER BY a.created_at DESC"
                
                if offset:
                    query += f" SKIP {offset}"
                
                if limit:
                    query += f" LIMIT {limit}"
                
                result = session.run(query, **params)
                
                assets = []
                for record in result:
                    assets.append(self._node_to_asset(dict(record["a"])))
                
                return assets
                
        except Exception as e:
            self.logger.error(f"Failed to find assets in Memgraph: {e}")
            if self.fallback_repository:
                return self.fallback_repository.find_all(filters, limit, offset)
            raise RepositoryError(f"Failed to find assets: {e}")
    
    def find_by_type(self, asset_type: str) -> List[Asset]:
        """Find all assets of a specific type."""
        return self.find_all({"asset_type": asset_type})
    
    def find_by_provider(self, provider: str) -> List[Asset]:
        """Find all assets from a specific provider."""
        return self.find_all({"provider": provider})
    
    def find_by_tags(self, tags: Dict[str, str]) -> List[Asset]:
        """Find assets with specific tags."""
        if self._use_fallback():
            return self.fallback_repository.find_by_tags(tags)
        
        try:
            with self.connection.get_session() as session:
                # For each tag, we need to check if it exists in the JSON
                assets = []
                
                # First get all assets
                result = session.run("MATCH (a:Asset) RETURN a")
                
                for record in result:
                    asset = self._node_to_asset(dict(record["a"]))
                    
                    # Check if all tags match
                    if all(asset.tags.get(k) == v for k, v in tags.items()):
                        assets.append(asset)
                
                return assets
                
        except Exception as e:
            self.logger.error(f"Failed to find assets by tags: {e}")
            if self.fallback_repository:
                return self.fallback_repository.find_by_tags(tags)
            raise RepositoryError(f"Failed to find assets by tags: {e}")
    
    def update(self, asset: Asset) -> Asset:
        """Update existing asset."""
        if self._use_fallback():
            return self.fallback_repository.update(asset)
        
        try:
            with self.connection.get_session() as session:
                # Check if exists
                result = session.run(
                    "MATCH (a:Asset {asset_id: $asset_id}) RETURN a",
                    asset_id=asset.asset_id
                )
                
                if not result.single():
                    raise AssetNotFoundError(f"Asset {asset.asset_id} not found")
                
                # Update timestamp
                asset.updated_at = datetime.utcnow()
                
                # Update asset
                node_props = self._asset_to_node(asset)
                session.run(
                    """
                    MATCH (a:Asset {asset_id: $asset_id})
                    SET a = $props
                    """,
                    asset_id=asset.asset_id,
                    props=node_props
                )
                
                self.logger.info(f"Updated asset {asset.asset_id} in Memgraph")
                return asset
                
        except Exception as e:
            self.logger.error(f"Failed to update asset in Memgraph: {e}")
            if self.fallback_repository:
                return self.fallback_repository.update(asset)
            raise RepositoryError(f"Failed to update asset: {e}")
    
    def update_batch(self, assets: List[Asset]) -> List[Asset]:
        """Update multiple assets in batch."""
        if self._use_fallback():
            return self.fallback_repository.update_batch(assets)
        
        updated_assets = []
        
        try:
            with self.connection.get_session() as session:
                for asset in assets:
                    try:
                        # Check if exists
                        result = session.run(
                            "MATCH (a:Asset {asset_id: $asset_id}) RETURN a",
                            asset_id=asset.asset_id
                        )
                        
                        if not result.single():
                            self.logger.warning(f"Asset {asset.asset_id} not found")
                            continue
                        
                        # Update asset
                        asset.updated_at = datetime.utcnow()
                        node_props = self._asset_to_node(asset)
                        
                        session.run(
                            """
                            MATCH (a:Asset {asset_id: $asset_id})
                            SET a = $props
                            """,
                            asset_id=asset.asset_id,
                            props=node_props
                        )
                        
                        updated_assets.append(asset)
                        
                    except Exception as e:
                        self.logger.error(f"Failed to update asset {asset.asset_id}: {e}")
                        if not updated_assets:
                            raise
                
                return updated_assets
                
        except Exception as e:
            self.logger.error(f"Batch update failed: {e}")
            if self.fallback_repository:
                return self.fallback_repository.update_batch(assets)
            raise RepositoryError(f"Batch update failed: {e}")
    
    def delete(self, asset_id: str) -> bool:
        """Delete asset by ID."""
        if self._use_fallback():
            return self.fallback_repository.delete(asset_id)
        
        try:
            with self.connection.get_session() as session:
                result = session.run(
                    """
                    MATCH (a:Asset {asset_id: $asset_id})
                    DELETE a
                    RETURN COUNT(a) as deleted
                    """,
                    asset_id=asset_id
                )
                
                record = result.single()
                deleted = record["deleted"] > 0
                
                if deleted:
                    self.logger.info(f"Deleted asset {asset_id} from Memgraph")
                
                return deleted
                
        except Exception as e:
            self.logger.error(f"Failed to delete asset: {e}")
            if self.fallback_repository:
                return self.fallback_repository.delete(asset_id)
            raise RepositoryError(f"Failed to delete asset: {e}")
    
    def delete_batch(self, asset_ids: List[str]) -> int:
        """Delete multiple assets by ID."""
        if self._use_fallback():
            return self.fallback_repository.delete_batch(asset_ids)
        
        try:
            with self.connection.get_session() as session:
                result = session.run(
                    """
                    MATCH (a:Asset)
                    WHERE a.asset_id IN $asset_ids
                    DELETE a
                    RETURN COUNT(a) as deleted
                    """,
                    asset_ids=asset_ids
                )
                
                record = result.single()
                deleted_count = record["deleted"]
                
                self.logger.info(f"Deleted {deleted_count} assets from Memgraph")
                return deleted_count
                
        except Exception as e:
            self.logger.error(f"Batch delete failed: {e}")
            if self.fallback_repository:
                return self.fallback_repository.delete_batch(asset_ids)
            raise RepositoryError(f"Batch delete failed: {e}")
    
    def count(self, filters: Optional[Dict[str, Any]] = None) -> int:
        """Count assets matching filters."""
        if self._use_fallback():
            return self.fallback_repository.count(filters)
        
        try:
            with self.connection.get_session() as session:
                query = "MATCH (a:Asset)"
                where_clauses = []
                params = {}
                
                if filters:
                    if "asset_type" in filters:
                        where_clauses.append("a.asset_type = $asset_type")
                        params["asset_type"] = filters["asset_type"]
                    
                    if "provider" in filters:
                        where_clauses.append("a.provider = $provider")
                        params["provider"] = filters["provider"]
                    
                    if "status" in filters:
                        where_clauses.append("a.status = $status")
                        params["status"] = filters["status"]
                
                if where_clauses:
                    query += " WHERE " + " AND ".join(where_clauses)
                
                query += " RETURN COUNT(a) as count"
                
                result = session.run(query, **params)
                record = result.single()
                
                return record["count"]
                
        except Exception as e:
            self.logger.error(f"Failed to count assets: {e}")
            if self.fallback_repository:
                return self.fallback_repository.count(filters)
            raise RepositoryError(f"Failed to count assets: {e}")
    
    def exists(self, asset_id: str) -> bool:
        """Check if asset exists."""
        if self._use_fallback():
            return self.fallback_repository.exists(asset_id)
        
        try:
            with self.connection.get_session() as session:
                result = session.run(
                    "MATCH (a:Asset {asset_id: $asset_id}) RETURN COUNT(a) as count",
                    asset_id=asset_id
                )
                
                record = result.single()
                return record["count"] > 0
                
        except Exception as e:
            self.logger.error(f"Failed to check asset existence: {e}")
            if self.fallback_repository:
                return self.fallback_repository.exists(asset_id)
            raise RepositoryError(f"Failed to check asset existence: {e}")
    
    def search(self, query: str, limit: Optional[int] = None) -> List[Asset]:
        """Full-text search for assets."""
        if self._use_fallback():
            return self.fallback_repository.search(query, limit)
        
        try:
            with self.connection.get_session() as session:
                # Simple search in name field
                # For production, consider using Memgraph's full-text search
                cypher_query = """
                    MATCH (a:Asset)
                    WHERE a.name CONTAINS $query
                    RETURN a
                    ORDER BY a.created_at DESC
                """
                
                if limit:
                    cypher_query += f" LIMIT {limit}"
                
                result = session.run(cypher_query, query=query)
                
                assets = []
                for record in result:
                    assets.append(self._node_to_asset(dict(record["a"])))
                
                return assets
                
        except Exception as e:
            self.logger.error(f"Search failed: {e}")
            if self.fallback_repository:
                return self.fallback_repository.search(query, limit)
            raise RepositoryError(f"Search failed: {e}")
    
    def get_statistics(self) -> Dict[str, Any]:
        """Get repository statistics."""
        if self._use_fallback():
            stats = self.fallback_repository.get_statistics()
            stats["storage"]["fallback_active"] = True
            return stats
        
        try:
            with self.connection.get_session() as session:
                # Total assets
                result = session.run("MATCH (a:Asset) RETURN COUNT(a) as count")
                total = result.single()["count"]
                
                # By type
                result = session.run("""
                    MATCH (a:Asset)
                    RETURN a.asset_type as type, COUNT(a) as count
                    ORDER BY count DESC
                """)
                by_type = {record["type"]: record["count"] for record in result}
                
                # By provider
                result = session.run("""
                    MATCH (a:Asset)
                    RETURN a.provider as provider, COUNT(a) as count
                    ORDER BY count DESC
                """)
                by_provider = {record["provider"]: record["count"] for record in result}
                
                # Risk statistics
                result = session.run("""
                    MATCH (a:Asset)
                    RETURN 
                        AVG(a.risk_score) as avg_risk,
                        MIN(a.risk_score) as min_risk,
                        MAX(a.risk_score) as max_risk,
                        COUNT(CASE WHEN a.risk_score > 70 THEN 1 END) as high_risk
                """)
                risk_stats = result.single()
                
                stats = {
                    "total_assets": total,
                    "by_type": by_type,
                    "by_provider": by_provider,
                    "risk_statistics": {
                        "average": round(risk_stats["avg_risk"] or 0, 2),
                        "min": risk_stats["min_risk"] or 0,
                        "max": risk_stats["max_risk"] or 0,
                        "high_risk_count": risk_stats["high_risk"] or 0
                    },
                    "storage": {
                        "type": "memgraph",
                        "uri": self.connection.uri,
                        "connected": self._available,
                        "fallback_active": False
                    }
                }
                
                return stats
                
        except Exception as e:
            self.logger.error(f"Failed to get statistics: {e}")
            if self.fallback_repository:
                stats = self.fallback_repository.get_statistics()
                stats["storage"]["fallback_active"] = True
                return stats
            raise RepositoryError(f"Failed to get statistics: {e}")


class MemgraphRelationshipRepository(RelationshipRepository):
    """Memgraph implementation of RelationshipRepository with fallback support."""
    
    def __init__(self, connection_config: Dict[str, Any],
                 fallback_config: Optional[Dict[str, Any]] = None):
        """Initialize Memgraph relationship repository.
        
        Args:
            connection_config: Memgraph connection configuration
            fallback_config: Optional fallback storage configuration
        """
        self.logger = logging.getLogger(self.__class__.__name__)
        self.fallback_repository = None
        
        # Initialize fallback if configured
        if fallback_config:
            fallback_type = fallback_config.get("type", "file")
            if fallback_type == "file":
                self.fallback_repository = FileBasedRelationshipRepository(
                    fallback_config.get("path", "./fallback/relationships")
                )
        
        # Share connection with asset repository
        try:
            self.connection = MemgraphConnection(
                uri=connection_config.get("uri", "bolt://localhost:7687"),
                username=connection_config.get("username", "memgraph"),
                password=connection_config.get("password", ""),
                database=connection_config.get("database", "memgraph")
            )
            self._available = True
        except Exception as e:
            self.logger.error(f"Failed to connect to Memgraph: {e}")
            self._available = False
            if not self.fallback_repository:
                raise RepositoryError("Memgraph unavailable and no fallback configured")
    
    def _use_fallback(self) -> bool:
        """Check if fallback should be used."""
        return not self._available and self.fallback_repository is not None
    
    def _relationship_to_edge(self, relationship: Relationship) -> Dict[str, Any]:
        """Convert relationship to edge properties."""
        return {
            "relationship_id": relationship.relationship_id,
            "relationship_type": relationship.relationship_type,
            "properties": json.dumps(relationship.properties),
            "confidence": relationship.confidence,
            "created_at": relationship.created_at.isoformat(),
            "updated_at": relationship.updated_at.isoformat(),
            "discovered_by": relationship.discovered_by,
            "discovery_method": relationship.discovery_method
        }
    
    def _edge_to_relationship(self, edge: Dict[str, Any], 
                            source_id: str, target_id: str) -> Relationship:
        """Convert edge to relationship."""
        return Relationship(
            relationship_id=edge["relationship_id"],
            source_id=source_id,
            target_id=target_id,
            relationship_type=edge["relationship_type"],
            properties=json.loads(edge.get("properties", "{}")),
            confidence=edge["confidence"],
            created_at=datetime.fromisoformat(edge["created_at"]),
            updated_at=datetime.fromisoformat(edge["updated_at"]),
            discovered_by=edge["discovered_by"],
            discovery_method=edge["discovery_method"]
        )
    
    def save(self, relationship: Relationship) -> Relationship:
        """Save a single relationship."""
        if self._use_fallback():
            return self.fallback_repository.save(relationship)
        
        try:
            with self.connection.get_session() as session:
                # Check if relationship already exists
                result = session.run(
                    """
                    MATCH (a1:Asset {asset_id: $source_id})
                          -[r:RELATIONSHIP {relationship_type: $rel_type}]->
                          (a2:Asset {asset_id: $target_id})
                    RETURN r
                    """,
                    source_id=relationship.source_id,
                    target_id=relationship.target_id,
                    rel_type=relationship.relationship_type
                )
                
                if result.single():
                    raise DuplicateRelationshipError("Relationship already exists")
                
                # Create relationship
                edge_props = self._relationship_to_edge(relationship)
                session.run(
                    """
                    MATCH (a1:Asset {asset_id: $source_id})
                    MATCH (a2:Asset {asset_id: $target_id})
                    CREATE (a1)-[r:RELATIONSHIP $props]->(a2)
                    """,
                    source_id=relationship.source_id,
                    target_id=relationship.target_id,
                    props=edge_props
                )
                
                self.logger.info(f"Saved relationship {relationship.relationship_id}")
                return relationship
                
        except Exception as e:
            self.logger.error(f"Failed to save relationship: {e}")
            if self.fallback_repository:
                return self.fallback_repository.save(relationship)
            raise RepositoryError(f"Failed to save relationship: {e}")
    
    def save_batch(self, relationships: List[Relationship]) -> List[Relationship]:
        """Save multiple relationships in batch."""
        if self._use_fallback():
            return self.fallback_repository.save_batch(relationships)
        
        saved_relationships = []
        
        try:
            with self.connection.get_session() as session:
                for relationship in relationships:
                    try:
                        # Check if exists
                        result = session.run(
                            """
                            MATCH (a1:Asset {asset_id: $source_id})
                                  -[r:RELATIONSHIP {relationship_type: $rel_type}]->
                                  (a2:Asset {asset_id: $target_id})
                            RETURN r
                            """,
                            source_id=relationship.source_id,
                            target_id=relationship.target_id,
                            rel_type=relationship.relationship_type
                        )
                        
                        if result.single():
                            self.logger.warning(f"Skipping duplicate relationship")
                            continue
                        
                        # Create relationship
                        edge_props = self._relationship_to_edge(relationship)
                        session.run(
                            """
                            MATCH (a1:Asset {asset_id: $source_id})
                            MATCH (a2:Asset {asset_id: $target_id})
                            CREATE (a1)-[r:RELATIONSHIP $props]->(a2)
                            """,
                            source_id=relationship.source_id,
                            target_id=relationship.target_id,
                            props=edge_props
                        )
                        
                        saved_relationships.append(relationship)
                        
                    except Exception as e:
                        self.logger.error(f"Failed to save relationship: {e}")
                        if not saved_relationships:
                            raise
                
                return saved_relationships
                
        except Exception as e:
            self.logger.error(f"Batch save failed: {e}")
            if self.fallback_repository:
                return self.fallback_repository.save_batch(relationships)
            raise RepositoryError(f"Batch save failed: {e}")
    
    def find_by_id(self, relationship_id: str) -> Optional[Relationship]:
        """Find relationship by ID."""
        if self._use_fallback():
            return self.fallback_repository.find_by_id(relationship_id)
        
        try:
            with self.connection.get_session() as session:
                result = session.run(
                    """
                    MATCH (a1:Asset)-[r:RELATIONSHIP {relationship_id: $rel_id}]->(a2:Asset)
                    RETURN r, a1.asset_id as source_id, a2.asset_id as target_id
                    """,
                    rel_id=relationship_id
                )
                
                record = result.single()
                if not record:
                    return None
                
                return self._edge_to_relationship(
                    dict(record["r"]),
                    record["source_id"],
                    record["target_id"]
                )
                
        except Exception as e:
            self.logger.error(f"Failed to find relationship: {e}")
            if self.fallback_repository:
                return self.fallback_repository.find_by_id(relationship_id)
            raise RepositoryError(f"Failed to find relationship: {e}")
    
    def find_by_source(self, source_id: str) -> List[Relationship]:
        """Find all relationships from a source asset."""
        if self._use_fallback():
            return self.fallback_repository.find_by_source(source_id)
        
        try:
            with self.connection.get_session() as session:
                result = session.run(
                    """
                    MATCH (a1:Asset {asset_id: $source_id})-[r:RELATIONSHIP]->(a2:Asset)
                    RETURN r, a1.asset_id as source_id, a2.asset_id as target_id
                    ORDER BY r.created_at DESC
                    """,
                    source_id=source_id
                )
                
                relationships = []
                for record in result:
                    relationships.append(self._edge_to_relationship(
                        dict(record["r"]),
                        record["source_id"],
                        record["target_id"]
                    ))
                
                return relationships
                
        except Exception as e:
            self.logger.error(f"Failed to find relationships by source: {e}")
            if self.fallback_repository:
                return self.fallback_repository.find_by_source(source_id)
            raise RepositoryError(f"Failed to find relationships by source: {e}")
    
    def find_by_target(self, target_id: str) -> List[Relationship]:
        """Find all relationships to a target asset."""
        if self._use_fallback():
            return self.fallback_repository.find_by_target(target_id)
        
        try:
            with self.connection.get_session() as session:
                result = session.run(
                    """
                    MATCH (a1:Asset)-[r:RELATIONSHIP]->(a2:Asset {asset_id: $target_id})
                    RETURN r, a1.asset_id as source_id, a2.asset_id as target_id
                    ORDER BY r.created_at DESC
                    """,
                    target_id=target_id
                )
                
                relationships = []
                for record in result:
                    relationships.append(self._edge_to_relationship(
                        dict(record["r"]),
                        record["source_id"],
                        record["target_id"]
                    ))
                
                return relationships
                
        except Exception as e:
            self.logger.error(f"Failed to find relationships by target: {e}")
            if self.fallback_repository:
                return self.fallback_repository.find_by_target(target_id)
            raise RepositoryError(f"Failed to find relationships by target: {e}")
    
    def find_by_asset(self, asset_id: str) -> List[Relationship]:
        """Find all relationships involving an asset."""
        if self._use_fallback():
            return self.fallback_repository.find_by_asset(asset_id)
        
        try:
            with self.connection.get_session() as session:
                result = session.run(
                    """
                    MATCH (a:Asset {asset_id: $asset_id})-[r:RELATIONSHIP]-(other:Asset)
                    RETURN r, 
                           CASE 
                               WHEN startNode(r) = a THEN a.asset_id 
                               ELSE other.asset_id 
                           END as source_id,
                           CASE 
                               WHEN endNode(r) = a THEN a.asset_id 
                               ELSE other.asset_id 
                           END as target_id
                    ORDER BY r.created_at DESC
                    """,
                    asset_id=asset_id
                )
                
                relationships = []
                for record in result:
                    relationships.append(self._edge_to_relationship(
                        dict(record["r"]),
                        record["source_id"],
                        record["target_id"]
                    ))
                
                return relationships
                
        except Exception as e:
            self.logger.error(f"Failed to find relationships by asset: {e}")
            if self.fallback_repository:
                return self.fallback_repository.find_by_asset(asset_id)
            raise RepositoryError(f"Failed to find relationships by asset: {e}")
    
    def find_by_type(self, relationship_type: str) -> List[Relationship]:
        """Find all relationships of a specific type."""
        if self._use_fallback():
            return self.fallback_repository.find_by_type(relationship_type)
        
        try:
            with self.connection.get_session() as session:
                result = session.run(
                    """
                    MATCH (a1:Asset)-[r:RELATIONSHIP {relationship_type: $rel_type}]->(a2:Asset)
                    RETURN r, a1.asset_id as source_id, a2.asset_id as target_id
                    ORDER BY r.created_at DESC
                    """,
                    rel_type=relationship_type
                )
                
                relationships = []
                for record in result:
                    relationships.append(self._edge_to_relationship(
                        dict(record["r"]),
                        record["source_id"],
                        record["target_id"]
                    ))
                
                return relationships
                
        except Exception as e:
            self.logger.error(f"Failed to find relationships by type: {e}")
            if self.fallback_repository:
                return self.fallback_repository.find_by_type(relationship_type)
            raise RepositoryError(f"Failed to find relationships by type: {e}")
    
    def find_between(self, asset_id1: str, asset_id2: str) -> List[Relationship]:
        """Find relationships between two assets."""
        if self._use_fallback():
            return self.fallback_repository.find_between(asset_id1, asset_id2)
        
        try:
            with self.connection.get_session() as session:
                result = session.run(
                    """
                    MATCH (a1:Asset)-[r:RELATIONSHIP]-(a2:Asset)
                    WHERE (a1.asset_id = $id1 AND a2.asset_id = $id2)
                       OR (a1.asset_id = $id2 AND a2.asset_id = $id1)
                    RETURN r, 
                           CASE 
                               WHEN a1.asset_id = $id1 THEN a1.asset_id 
                               ELSE a2.asset_id 
                           END as source_id,
                           CASE 
                               WHEN a1.asset_id = $id1 THEN a2.asset_id 
                               ELSE a1.asset_id 
                           END as target_id
                    ORDER BY r.created_at DESC
                    """,
                    id1=asset_id1,
                    id2=asset_id2
                )
                
                relationships = []
                for record in result:
                    relationships.append(self._edge_to_relationship(
                        dict(record["r"]),
                        record["source_id"],
                        record["target_id"]
                    ))
                
                return relationships
                
        except Exception as e:
            self.logger.error(f"Failed to find relationships between assets: {e}")
            if self.fallback_repository:
                return self.fallback_repository.find_between(asset_id1, asset_id2)
            raise RepositoryError(f"Failed to find relationships between assets: {e}")
    
    def update(self, relationship: Relationship) -> Relationship:
        """Update existing relationship."""
        if self._use_fallback():
            return self.fallback_repository.update(relationship)
        
        try:
            with self.connection.get_session() as session:
                # Check if exists
                result = session.run(
                    """
                    MATCH (a1:Asset)-[r:RELATIONSHIP {relationship_id: $rel_id}]->(a2:Asset)
                    RETURN r
                    """,
                    rel_id=relationship.relationship_id
                )
                
                if not result.single():
                    raise RelationshipNotFoundError(
                        f"Relationship {relationship.relationship_id} not found"
                    )
                
                # Update relationship
                relationship.updated_at = datetime.utcnow()
                edge_props = self._relationship_to_edge(relationship)
                
                session.run(
                    """
                    MATCH (a1:Asset)-[r:RELATIONSHIP {relationship_id: $rel_id}]->(a2:Asset)
                    SET r = $props
                    """,
                    rel_id=relationship.relationship_id,
                    props=edge_props
                )
                
                self.logger.info(f"Updated relationship {relationship.relationship_id}")
                return relationship
                
        except Exception as e:
            self.logger.error(f"Failed to update relationship: {e}")
            if self.fallback_repository:
                return self.fallback_repository.update(relationship)
            raise RepositoryError(f"Failed to update relationship: {e}")
    
    def delete(self, relationship_id: str) -> bool:
        """Delete relationship by ID."""
        if self._use_fallback():
            return self.fallback_repository.delete(relationship_id)
        
        try:
            with self.connection.get_session() as session:
                result = session.run(
                    """
                    MATCH (a1:Asset)-[r:RELATIONSHIP {relationship_id: $rel_id}]->(a2:Asset)
                    DELETE r
                    RETURN COUNT(r) as deleted
                    """,
                    rel_id=relationship_id
                )
                
                record = result.single()
                deleted = record["deleted"] > 0
                
                if deleted:
                    self.logger.info(f"Deleted relationship {relationship_id}")
                
                return deleted
                
        except Exception as e:
            self.logger.error(f"Failed to delete relationship: {e}")
            if self.fallback_repository:
                return self.fallback_repository.delete(relationship_id)
            raise RepositoryError(f"Failed to delete relationship: {e}")
    
    def delete_by_asset(self, asset_id: str) -> int:
        """Delete all relationships involving an asset."""
        if self._use_fallback():
            return self.fallback_repository.delete_by_asset(asset_id)
        
        try:
            with self.connection.get_session() as session:
                result = session.run(
                    """
                    MATCH (a:Asset {asset_id: $asset_id})-[r:RELATIONSHIP]-()
                    DELETE r
                    RETURN COUNT(r) as deleted
                    """,
                    asset_id=asset_id
                )
                
                record = result.single()
                deleted_count = record["deleted"]
                
                self.logger.info(f"Deleted {deleted_count} relationships for asset {asset_id}")
                return deleted_count
                
        except Exception as e:
            self.logger.error(f"Failed to delete relationships by asset: {e}")
            if self.fallback_repository:
                return self.fallback_repository.delete_by_asset(asset_id)
            raise RepositoryError(f"Failed to delete relationships by asset: {e}")
    
    def count(self, filters: Optional[Dict[str, Any]] = None) -> int:
        """Count relationships matching filters."""
        if self._use_fallback():
            return self.fallback_repository.count(filters)
        
        try:
            with self.connection.get_session() as session:
                query = "MATCH ()-[r:RELATIONSHIP]->()"
                where_clauses = []
                params = {}
                
                if filters:
                    if "source_id" in filters:
                        query = "MATCH (a1:Asset {asset_id: $source_id})-[r:RELATIONSHIP]->()"
                        params["source_id"] = filters["source_id"]
                    
                    if "target_id" in filters:
                        query = "MATCH ()-[r:RELATIONSHIP]->(a2:Asset {asset_id: $target_id})"
                        params["target_id"] = filters["target_id"]
                    
                    if "relationship_type" in filters:
                        where_clauses.append("r.relationship_type = $rel_type")
                        params["rel_type"] = filters["relationship_type"]
                    
                    if "min_confidence" in filters:
                        where_clauses.append("r.confidence >= $min_conf")
                        params["min_conf"] = filters["min_confidence"]
                
                if where_clauses:
                    query += " WHERE " + " AND ".join(where_clauses)
                
                query += " RETURN COUNT(r) as count"
                
                result = session.run(query, **params)
                record = result.single()
                
                return record["count"]
                
        except Exception as e:
            self.logger.error(f"Failed to count relationships: {e}")
            if self.fallback_repository:
                return self.fallback_repository.count(filters)
            raise RepositoryError(f"Failed to count relationships: {e}")
    
    def get_graph_statistics(self) -> Dict[str, Any]:
        """Get graph statistics."""
        if self._use_fallback():
            return self.fallback_repository.get_graph_statistics()
        
        try:
            with self.connection.get_session() as session:
                # Node and edge counts
                result = session.run("""
                    MATCH (a:Asset)
                    OPTIONAL MATCH (a)-[r:RELATIONSHIP]-()
                    RETURN 
                        COUNT(DISTINCT a) as node_count,
                        COUNT(r) / 2 as edge_count
                """)
                counts = result.single()
                
                # Relationship types
                result = session.run("""
                    MATCH ()-[r:RELATIONSHIP]->()
                    RETURN r.relationship_type as type, COUNT(r) as count
                    ORDER BY count DESC
                """)
                by_type = {record["type"]: record["count"] for record in result}
                
                # Degree statistics
                result = session.run("""
                    MATCH (a:Asset)
                    OPTIONAL MATCH (a)-[r:RELATIONSHIP]-()
                    WITH a, COUNT(r) as degree
                    RETURN 
                        AVG(degree) as avg_degree,
                        MAX(degree) as max_degree,
                        MIN(degree) as min_degree
                """)
                degree_stats = result.single()
                
                # Connected components
                result = session.run("""
                    MATCH (a:Asset)
                    WITH collect(a) as nodes
                    UNWIND nodes as n
                    MATCH path = (n)-[*]-(connected)
                    WITH n, collect(DISTINCT connected) + n as component
                    WITH component, size(component) as size
                    ORDER BY size DESC
                    RETURN COUNT(DISTINCT component) as num_components,
                           MAX(size) as largest_component
                """)
                component_stats = result.single()
                
                stats = {
                    "node_count": counts["node_count"],
                    "edge_count": counts["edge_count"],
                    "relationship_types": list(by_type.keys()),
                    "by_type": by_type,
                    "degree_statistics": {
                        "average": round(degree_stats["avg_degree"] or 0, 2),
                        "max": degree_stats["max_degree"] or 0,
                        "min": degree_stats["min_degree"] or 0
                    },
                    "graph_properties": {
                        "connected_components": component_stats["num_components"] or 1,
                        "largest_component_size": component_stats["largest_component"] or 0,
                        "density": round(
                            (2 * counts["edge_count"]) / 
                            (counts["node_count"] * (counts["node_count"] - 1))
                            if counts["node_count"] > 1 else 0,
                            4
                        )
                    }
                }
                
                return stats
                
        except Exception as e:
            self.logger.error(f"Failed to get graph statistics: {e}")
            if self.fallback_repository:
                return self.fallback_repository.get_graph_statistics()
            raise RepositoryError(f"Failed to get graph statistics: {e}")
