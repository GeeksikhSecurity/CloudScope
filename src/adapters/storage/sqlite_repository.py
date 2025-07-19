"""SQLite storage adapter implementation.

Implements asset and relationship repositories using SQLite database.
Requirements: 1.1, 1.2, 1.3, 0.2
"""

import sqlite3
import json
from pathlib import Path
from typing import List, Optional, Dict, Any, Tuple
from datetime import datetime
from contextlib import contextmanager
import logging
from threading import Lock

from ...domain.models import Asset, Relationship
from ...ports.repository import (
    AssetRepository, RelationshipRepository,
    RepositoryError, AssetNotFoundError, RelationshipNotFoundError,
    DuplicateAssetError, DuplicateRelationshipError
)


class SQLiteConnection:
    """Manages SQLite database connections with proper isolation."""
    
    def __init__(self, db_path: str, pragmas: Optional[Dict[str, Any]] = None):
        """Initialize SQLite connection manager.
        
        Args:
            db_path: Path to SQLite database file
            pragmas: SQLite PRAGMA settings
        """
        self.db_path = db_path
        self.pragmas = pragmas or {
            "journal_mode": "WAL",
            "synchronous": "NORMAL",
            "cache_size": -64000,
            "temp_store": "MEMORY",
            "foreign_keys": "ON"
        }
        self.logger = logging.getLogger(self.__class__.__name__)
        self._lock = Lock()
        
        # Ensure database directory exists
        Path(db_path).parent.mkdir(parents=True, exist_ok=True)
        
        # Initialize database
        self._init_database()
    
    @contextmanager
    def get_connection(self):
        """Get a database connection with proper cleanup."""
        conn = sqlite3.connect(self.db_path, timeout=30.0)
        conn.row_factory = sqlite3.Row
        
        try:
            # Set pragmas
            for pragma, value in self.pragmas.items():
                conn.execute(f"PRAGMA {pragma} = {value}")
            
            yield conn
            conn.commit()
        except Exception as e:
            conn.rollback()
            raise
        finally:
            conn.close()
    
    def _init_database(self):
        """Initialize database schema."""
        with self.get_connection() as conn:
            # Create assets table
            conn.execute("""
                CREATE TABLE IF NOT EXISTS assets (
                    asset_id TEXT PRIMARY KEY,
                    asset_type TEXT NOT NULL,
                    provider TEXT NOT NULL,
                    name TEXT NOT NULL,
                    properties TEXT,
                    tags TEXT,
                    metadata TEXT,
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL,
                    discovered_at TEXT NOT NULL,
                    status TEXT NOT NULL,
                    health TEXT NOT NULL,
                    compliance_status TEXT NOT NULL,
                    risk_score REAL NOT NULL,
                    estimated_cost REAL NOT NULL
                )
            """)
            
            # Create indices for assets
            conn.execute("""
                CREATE INDEX IF NOT EXISTS idx_assets_type 
                ON assets(asset_type)
            """)
            conn.execute("""
                CREATE INDEX IF NOT EXISTS idx_assets_provider 
                ON assets(provider)
            """)
            conn.execute("""
                CREATE INDEX IF NOT EXISTS idx_assets_status 
                ON assets(status)
            """)
            conn.execute("""
                CREATE INDEX IF NOT EXISTS idx_assets_risk 
                ON assets(risk_score)
            """)
            
            # Create relationships table
            conn.execute("""
                CREATE TABLE IF NOT EXISTS relationships (
                    relationship_id TEXT PRIMARY KEY,
                    source_id TEXT NOT NULL,
                    target_id TEXT NOT NULL,
                    relationship_type TEXT NOT NULL,
                    properties TEXT,
                    confidence REAL NOT NULL,
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL,
                    discovered_by TEXT NOT NULL,
                    discovery_method TEXT NOT NULL,
                    FOREIGN KEY (source_id) REFERENCES assets(asset_id) ON DELETE CASCADE,
                    FOREIGN KEY (target_id) REFERENCES assets(asset_id) ON DELETE CASCADE,
                    UNIQUE(source_id, target_id, relationship_type)
                )
            """)
            
            # Create indices for relationships
            conn.execute("""
                CREATE INDEX IF NOT EXISTS idx_relationships_source 
                ON relationships(source_id)
            """)
            conn.execute("""
                CREATE INDEX IF NOT EXISTS idx_relationships_target 
                ON relationships(target_id)
            """)
            conn.execute("""
                CREATE INDEX IF NOT EXISTS idx_relationships_type 
                ON relationships(relationship_type)
            """)
            
            # Create asset_tags table for efficient tag queries
            conn.execute("""
                CREATE TABLE IF NOT EXISTS asset_tags (
                    asset_id TEXT NOT NULL,
                    tag_key TEXT NOT NULL,
                    tag_value TEXT NOT NULL,
                    PRIMARY KEY (asset_id, tag_key),
                    FOREIGN KEY (asset_id) REFERENCES assets(asset_id) ON DELETE CASCADE
                )
            """)
            
            # Create index for tag queries
            conn.execute("""
                CREATE INDEX IF NOT EXISTS idx_asset_tags_kv 
                ON asset_tags(tag_key, tag_value)
            """)


class SQLiteAssetRepository(AssetRepository):
    """SQLite implementation of AssetRepository."""
    
    def __init__(self, db_path: str, pragmas: Optional[Dict[str, Any]] = None):
        """Initialize SQLite asset repository.
        
        Args:
            db_path: Path to SQLite database
            pragmas: Optional SQLite PRAGMA settings
        """
        self.connection = SQLiteConnection(db_path, pragmas)
        self.logger = logging.getLogger(self.__class__.__name__)
    
    def _asset_to_row(self, asset: Asset) -> Dict[str, Any]:
        """Convert asset to database row."""
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
    
    def _row_to_asset(self, row: sqlite3.Row) -> Asset:
        """Convert database row to asset."""
        data = dict(row)
        
        # Parse JSON fields
        data["properties"] = json.loads(data["properties"] or "{}")
        data["tags"] = json.loads(data["tags"] or "{}")
        data["metadata"] = json.loads(data["metadata"] or "{}")
        
        # Parse timestamps
        data["created_at"] = datetime.fromisoformat(data["created_at"])
        data["updated_at"] = datetime.fromisoformat(data["updated_at"])
        data["discovered_at"] = datetime.fromisoformat(data["discovered_at"])
        
        # Create asset
        asset = Asset(
            asset_id=data["asset_id"],
            asset_type=data["asset_type"],
            provider=data["provider"],
            name=data["name"]
        )
        
        # Set all fields
        asset.properties = data["properties"]
        asset.tags = data["tags"]
        asset.metadata = data["metadata"]
        asset.created_at = data["created_at"]
        asset.updated_at = data["updated_at"]
        asset.discovered_at = data["discovered_at"]
        asset.status = data["status"]
        asset.health = data["health"]
        asset.compliance_status = data["compliance_status"]
        asset.risk_score = data["risk_score"]
        asset.estimated_cost = data["estimated_cost"]
        
        return asset
    
    def save(self, asset: Asset) -> Asset:
        """Save a single asset."""
        try:
            with self.connection.get_connection() as conn:
                # Check if already exists
                existing = conn.execute(
                    "SELECT 1 FROM assets WHERE asset_id = ?",
                    (asset.asset_id,)
                ).fetchone()
                
                if existing:
                    raise DuplicateAssetError(f"Asset {asset.asset_id} already exists")
                
                # Insert asset
                row_data = self._asset_to_row(asset)
                placeholders = ", ".join(["?"] * len(row_data))
                columns = ", ".join(row_data.keys())
                
                conn.execute(
                    f"INSERT INTO assets ({columns}) VALUES ({placeholders})",
                    list(row_data.values())
                )
                
                # Insert tags
                for tag_key, tag_value in asset.tags.items():
                    conn.execute(
                        "INSERT INTO asset_tags (asset_id, tag_key, tag_value) VALUES (?, ?, ?)",
                        (asset.asset_id, tag_key, tag_value)
                    )
                
                self.logger.info(f"Saved asset {asset.asset_id}")
                return asset
                
        except sqlite3.Error as e:
            self.logger.error(f"Failed to save asset {asset.asset_id}: {e}")
            raise RepositoryError(f"Failed to save asset: {e}")
    
    def save_batch(self, assets: List[Asset]) -> List[Asset]:
        """Save multiple assets in batch."""
        saved_assets = []
        
        try:
            with self.connection.get_connection() as conn:
                for asset in assets:
                    try:
                        # Check if exists
                        existing = conn.execute(
                            "SELECT 1 FROM assets WHERE asset_id = ?",
                            (asset.asset_id,)
                        ).fetchone()
                        
                        if existing:
                            self.logger.warning(f"Skipping duplicate asset {asset.asset_id}")
                            continue
                        
                        # Insert asset
                        row_data = self._asset_to_row(asset)
                        placeholders = ", ".join(["?"] * len(row_data))
                        columns = ", ".join(row_data.keys())
                        
                        conn.execute(
                            f"INSERT INTO assets ({columns}) VALUES ({placeholders})",
                            list(row_data.values())
                        )
                        
                        # Insert tags
                        for tag_key, tag_value in asset.tags.items():
                            conn.execute(
                                "INSERT INTO asset_tags (asset_id, tag_key, tag_value) VALUES (?, ?, ?)",
                                (asset.asset_id, tag_key, tag_value)
                            )
                        
                        saved_assets.append(asset)
                        
                    except Exception as e:
                        self.logger.error(f"Failed to save asset {asset.asset_id}: {e}")
                        if not saved_assets:
                            raise
                
                return saved_assets
                
        except sqlite3.Error as e:
            self.logger.error(f"Batch save failed: {e}")
            raise RepositoryError(f"Batch save failed: {e}")
    
    def find_by_id(self, asset_id: str) -> Optional[Asset]:
        """Find asset by ID."""
        try:
            with self.connection.get_connection() as conn:
                row = conn.execute(
                    "SELECT * FROM assets WHERE asset_id = ?",
                    (asset_id,)
                ).fetchone()
                
                if not row:
                    return None
                
                return self._row_to_asset(row)
                
        except sqlite3.Error as e:
            self.logger.error(f"Failed to find asset {asset_id}: {e}")
            raise RepositoryError(f"Failed to find asset: {e}")
    
    def find_all(self, filters: Optional[Dict[str, Any]] = None,
                 limit: Optional[int] = None,
                 offset: Optional[int] = None) -> List[Asset]:
        """Find all assets matching filters."""
        try:
            with self.connection.get_connection() as conn:
                query = "SELECT * FROM assets WHERE 1=1"
                params = []
                
                # Apply filters
                if filters:
                    if "asset_type" in filters:
                        query += " AND asset_type = ?"
                        params.append(filters["asset_type"])
                    
                    if "provider" in filters:
                        query += " AND provider = ?"
                        params.append(filters["provider"])
                    
                    if "status" in filters:
                        query += " AND status = ?"
                        params.append(filters["status"])
                    
                    if "min_risk_score" in filters:
                        query += " AND risk_score >= ?"
                        params.append(filters["min_risk_score"])
                    
                    if "max_risk_score" in filters:
                        query += " AND risk_score <= ?"
                        params.append(filters["max_risk_score"])
                
                # Add order, limit and offset
                query += " ORDER BY created_at DESC"
                
                if limit:
                    query += " LIMIT ?"
                    params.append(limit)
                
                if offset:
                    query += " OFFSET ?"
                    params.append(offset)
                
                rows = conn.execute(query, params).fetchall()
                return [self._row_to_asset(row) for row in rows]
                
        except sqlite3.Error as e:
            self.logger.error(f"Failed to find assets: {e}")
            raise RepositoryError(f"Failed to find assets: {e}")
    
    def find_by_type(self, asset_type: str) -> List[Asset]:
        """Find all assets of a specific type."""
        return self.find_all({"asset_type": asset_type})
    
    def find_by_provider(self, provider: str) -> List[Asset]:
        """Find all assets from a specific provider."""
        return self.find_all({"provider": provider})
    
    def find_by_tags(self, tags: Dict[str, str]) -> List[Asset]:
        """Find assets with specific tags."""
        try:
            with self.connection.get_connection() as conn:
                # Build query to find assets with all specified tags
                tag_conditions = []
                params = []
                
                for tag_key, tag_value in tags.items():
                    tag_conditions.append(
                        "(tag_key = ? AND tag_value = ?)"
                    )
                    params.extend([tag_key, tag_value])
                
                query = f"""
                    SELECT DISTINCT a.*
                    FROM assets a
                    JOIN asset_tags t ON a.asset_id = t.asset_id
                    WHERE {" OR ".join(tag_conditions)}
                    GROUP BY a.asset_id
                    HAVING COUNT(DISTINCT t.tag_key) = ?
                """
                params.append(len(tags))
                
                rows = conn.execute(query, params).fetchall()
                return [self._row_to_asset(row) for row in rows]
                
        except sqlite3.Error as e:
            self.logger.error(f"Failed to find assets by tags: {e}")
            raise RepositoryError(f"Failed to find assets by tags: {e}")
    
    def update(self, asset: Asset) -> Asset:
        """Update existing asset."""
        try:
            with self.connection.get_connection() as conn:
                # Check if exists
                existing = conn.execute(
                    "SELECT 1 FROM assets WHERE asset_id = ?",
                    (asset.asset_id,)
                ).fetchone()
                
                if not existing:
                    raise AssetNotFoundError(f"Asset {asset.asset_id} not found")
                
                # Update timestamp
                asset.updated_at = datetime.utcnow()
                
                # Update asset
                row_data = self._asset_to_row(asset)
                set_clause = ", ".join([f"{k} = ?" for k in row_data.keys()])
                
                conn.execute(
                    f"UPDATE assets SET {set_clause} WHERE asset_id = ?",
                    list(row_data.values()) + [asset.asset_id]
                )
                
                # Update tags (delete and re-insert)
                conn.execute(
                    "DELETE FROM asset_tags WHERE asset_id = ?",
                    (asset.asset_id,)
                )
                
                for tag_key, tag_value in asset.tags.items():
                    conn.execute(
                        "INSERT INTO asset_tags (asset_id, tag_key, tag_value) VALUES (?, ?, ?)",
                        (asset.asset_id, tag_key, tag_value)
                    )
                
                self.logger.info(f"Updated asset {asset.asset_id}")
                return asset
                
        except sqlite3.Error as e:
            self.logger.error(f"Failed to update asset {asset.asset_id}: {e}")
            raise RepositoryError(f"Failed to update asset: {e}")
    
    def update_batch(self, assets: List[Asset]) -> List[Asset]:
        """Update multiple assets in batch."""
        updated_assets = []
        
        try:
            with self.connection.get_connection() as conn:
                for asset in assets:
                    try:
                        # Check if exists
                        existing = conn.execute(
                            "SELECT 1 FROM assets WHERE asset_id = ?",
                            (asset.asset_id,)
                        ).fetchone()
                        
                        if not existing:
                            self.logger.warning(f"Asset {asset.asset_id} not found")
                            continue
                        
                        # Update timestamp
                        asset.updated_at = datetime.utcnow()
                        
                        # Update asset
                        row_data = self._asset_to_row(asset)
                        set_clause = ", ".join([f"{k} = ?" for k in row_data.keys()])
                        
                        conn.execute(
                            f"UPDATE assets SET {set_clause} WHERE asset_id = ?",
                            list(row_data.values()) + [asset.asset_id]
                        )
                        
                        # Update tags
                        conn.execute(
                            "DELETE FROM asset_tags WHERE asset_id = ?",
                            (asset.asset_id,)
                        )
                        
                        for tag_key, tag_value in asset.tags.items():
                            conn.execute(
                                "INSERT INTO asset_tags (asset_id, tag_key, tag_value) VALUES (?, ?, ?)",
                                (asset.asset_id, tag_key, tag_value)
                            )
                        
                        updated_assets.append(asset)
                        
                    except Exception as e:
                        self.logger.error(f"Failed to update asset {asset.asset_id}: {e}")
                        if not updated_assets:
                            raise
                
                return updated_assets
                
        except sqlite3.Error as e:
            self.logger.error(f"Batch update failed: {e}")
            raise RepositoryError(f"Batch update failed: {e}")
    
    def delete(self, asset_id: str) -> bool:
        """Delete asset by ID."""
        try:
            with self.connection.get_connection() as conn:
                cursor = conn.execute(
                    "DELETE FROM assets WHERE asset_id = ?",
                    (asset_id,)
                )
                
                if cursor.rowcount > 0:
                    self.logger.info(f"Deleted asset {asset_id}")
                    return True
                
                return False
                
        except sqlite3.Error as e:
            self.logger.error(f"Failed to delete asset {asset_id}: {e}")
            raise RepositoryError(f"Failed to delete asset: {e}")
    
    def delete_batch(self, asset_ids: List[str]) -> int:
        """Delete multiple assets by ID."""
        try:
            with self.connection.get_connection() as conn:
                placeholders = ", ".join(["?"] * len(asset_ids))
                cursor = conn.execute(
                    f"DELETE FROM assets WHERE asset_id IN ({placeholders})",
                    asset_ids
                )
                
                deleted_count = cursor.rowcount
                self.logger.info(f"Deleted {deleted_count} assets")
                return deleted_count
                
        except sqlite3.Error as e:
            self.logger.error(f"Batch delete failed: {e}")
            raise RepositoryError(f"Batch delete failed: {e}")
    
    def count(self, filters: Optional[Dict[str, Any]] = None) -> int:
        """Count assets matching filters."""
        try:
            with self.connection.get_connection() as conn:
                query = "SELECT COUNT(*) FROM assets WHERE 1=1"
                params = []
                
                # Apply same filters as find_all
                if filters:
                    if "asset_type" in filters:
                        query += " AND asset_type = ?"
                        params.append(filters["asset_type"])
                    
                    if "provider" in filters:
                        query += " AND provider = ?"
                        params.append(filters["provider"])
                    
                    if "status" in filters:
                        query += " AND status = ?"
                        params.append(filters["status"])
                    
                    if "min_risk_score" in filters:
                        query += " AND risk_score >= ?"
                        params.append(filters["min_risk_score"])
                    
                    if "max_risk_score" in filters:
                        query += " AND risk_score <= ?"
                        params.append(filters["max_risk_score"])
                
                result = conn.execute(query, params).fetchone()
                return result[0]
                
        except sqlite3.Error as e:
            self.logger.error(f"Failed to count assets: {e}")
            raise RepositoryError(f"Failed to count assets: {e}")
    
    def exists(self, asset_id: str) -> bool:
        """Check if asset exists."""
        try:
            with self.connection.get_connection() as conn:
                result = conn.execute(
                    "SELECT 1 FROM assets WHERE asset_id = ? LIMIT 1",
                    (asset_id,)
                ).fetchone()
                
                return result is not None
                
        except sqlite3.Error as e:
            self.logger.error(f"Failed to check asset existence: {e}")
            raise RepositoryError(f"Failed to check asset existence: {e}")
    
    def search(self, query: str, limit: Optional[int] = None) -> List[Asset]:
        """Full-text search for assets."""
        try:
            with self.connection.get_connection() as conn:
                # Simple search in name and JSON fields
                search_query = """
                    SELECT * FROM assets
                    WHERE name LIKE ?
                    OR properties LIKE ?
                    OR tags LIKE ?
                    OR metadata LIKE ?
                    ORDER BY 
                        CASE 
                            WHEN name LIKE ? THEN 1
                            ELSE 2
                        END,
                        created_at DESC
                """
                
                params = [f"%{query}%"] * 4 + [f"%{query}%"]
                
                if limit:
                    search_query += " LIMIT ?"
                    params.append(limit)
                
                rows = conn.execute(search_query, params).fetchall()
                return [self._row_to_asset(row) for row in rows]
                
        except sqlite3.Error as e:
            self.logger.error(f"Search failed: {e}")
            raise RepositoryError(f"Search failed: {e}")
    
    def get_statistics(self) -> Dict[str, Any]:
        """Get repository statistics."""
        try:
            with self.connection.get_connection() as conn:
                # Total assets
                total = conn.execute("SELECT COUNT(*) FROM assets").fetchone()[0]
                
                # By type
                by_type_rows = conn.execute("""
                    SELECT asset_type, COUNT(*) as count
                    FROM assets
                    GROUP BY asset_type
                """).fetchall()
                by_type = {row["asset_type"]: row["count"] for row in by_type_rows}
                
                # By provider
                by_provider_rows = conn.execute("""
                    SELECT provider, COUNT(*) as count
                    FROM assets
                    GROUP BY provider
                """).fetchall()
                by_provider = {row["provider"]: row["count"] for row in by_provider_rows}
                
                # By status
                by_status_rows = conn.execute("""
                    SELECT status, COUNT(*) as count
                    FROM assets
                    GROUP BY status
                """).fetchall()
                by_status = {row["status"]: row["count"] for row in by_status_rows}
                
                # Risk statistics
                risk_stats = conn.execute("""
                    SELECT 
                        AVG(risk_score) as avg_risk,
                        MIN(risk_score) as min_risk,
                        MAX(risk_score) as max_risk,
                        COUNT(CASE WHEN risk_score > 70 THEN 1 END) as high_risk_count
                    FROM assets
                """).fetchone()
                
                # Cost statistics  
                cost_stats = conn.execute("""
                    SELECT 
                        SUM(estimated_cost) as total_cost,
                        AVG(estimated_cost) as avg_cost
                    FROM assets
                """).fetchone()
                
                # Database size
                db_size = Path(self.connection.db_path).stat().st_size
                
                stats = {
                    "total_assets": total,
                    "by_type": by_type,
                    "by_provider": by_provider,
                    "by_status": by_status,
                    "risk_statistics": {
                        "average": round(risk_stats["avg_risk"] or 0, 2),
                        "min": risk_stats["min_risk"] or 0,
                        "max": risk_stats["max_risk"] or 0,
                        "high_risk_count": risk_stats["high_risk_count"] or 0
                    },
                    "cost_statistics": {
                        "total": round(cost_stats["total_cost"] or 0, 2),
                        "average": round(cost_stats["avg_cost"] or 0, 2)
                    },
                    "storage": {
                        "type": "sqlite",
                        "path": self.connection.db_path,
                        "size_bytes": db_size,
                        "size_mb": round(db_size / (1024 * 1024), 2)
                    }
                }
                
                return stats
                
        except sqlite3.Error as e:
            self.logger.error(f"Failed to get statistics: {e}")
            raise RepositoryError(f"Failed to get statistics: {e}")


class SQLiteRelationshipRepository(RelationshipRepository):
    """SQLite implementation of RelationshipRepository."""
    
    def __init__(self, db_path: str, pragmas: Optional[Dict[str, Any]] = None):
        """Initialize SQLite relationship repository.
        
        Args:
            db_path: Path to SQLite database
            pragmas: Optional SQLite PRAGMA settings
        """
        self.connection = SQLiteConnection(db_path, pragmas)
        self.logger = logging.getLogger(self.__class__.__name__)
    
    def _relationship_to_row(self, relationship: Relationship) -> Dict[str, Any]:
        """Convert relationship to database row."""
        return {
            "relationship_id": relationship.relationship_id,
            "source_id": relationship.source_id,
            "target_id": relationship.target_id,
            "relationship_type": relationship.relationship_type,
            "properties": json.dumps(relationship.properties),
            "confidence": relationship.confidence,
            "created_at": relationship.created_at.isoformat(),
            "updated_at": relationship.updated_at.isoformat(),
            "discovered_by": relationship.discovered_by,
            "discovery_method": relationship.discovery_method
        }
    
    def _row_to_relationship(self, row: sqlite3.Row) -> Relationship:
        """Convert database row to relationship."""
        data = dict(row)
        
        # Parse JSON fields
        data["properties"] = json.loads(data["properties"] or "{}")
        
        # Parse timestamps
        data["created_at"] = datetime.fromisoformat(data["created_at"])
        data["updated_at"] = datetime.fromisoformat(data["updated_at"])
        
        return Relationship(
            relationship_id=data["relationship_id"],
            source_id=data["source_id"],
            target_id=data["target_id"],
            relationship_type=data["relationship_type"],
            properties=data["properties"],
            confidence=data["confidence"],
            created_at=data["created_at"],
            updated_at=data["updated_at"],
            discovered_by=data["discovered_by"],
            discovery_method=data["discovery_method"]
        )
    
    def save(self, relationship: Relationship) -> Relationship:
        """Save a single relationship."""
        try:
            with self.connection.get_connection() as conn:
                # Check if already exists
                existing = conn.execute(
                    "SELECT 1 FROM relationships WHERE relationship_id = ?",
                    (relationship.relationship_id,)
                ).fetchone()
                
                if existing:
                    raise DuplicateRelationshipError(
                        f"Relationship {relationship.relationship_id} already exists"
                    )
                
                # Insert relationship
                row_data = self._relationship_to_row(relationship)
                placeholders = ", ".join(["?"] * len(row_data))
                columns = ", ".join(row_data.keys())
                
                conn.execute(
                    f"INSERT INTO relationships ({columns}) VALUES ({placeholders})",
                    list(row_data.values())
                )
                
                self.logger.info(f"Saved relationship {relationship.relationship_id}")
                return relationship
                
        except sqlite3.IntegrityError as e:
            if "UNIQUE constraint failed" in str(e):
                raise DuplicateRelationshipError(
                    "Relationship already exists between these assets"
                )
            raise RepositoryError(f"Failed to save relationship: {e}")
        except sqlite3.Error as e:
            self.logger.error(f"Failed to save relationship: {e}")
            raise RepositoryError(f"Failed to save relationship: {e}")
    
    def save_batch(self, relationships: List[Relationship]) -> List[Relationship]:
        """Save multiple relationships in batch."""
        saved_relationships = []
        
        try:
            with self.connection.get_connection() as conn:
                for relationship in relationships:
                    try:
                        # Check if exists
                        existing = conn.execute(
                            """SELECT 1 FROM relationships 
                               WHERE source_id = ? AND target_id = ? 
                               AND relationship_type = ?""",
                            (relationship.source_id, relationship.target_id,
                             relationship.relationship_type)
                        ).fetchone()
                        
                        if existing:
                            self.logger.warning(
                                f"Skipping duplicate relationship {relationship.relationship_id}"
                            )
                            continue
                        
                        # Insert relationship
                        row_data = self._relationship_to_row(relationship)
                        placeholders = ", ".join(["?"] * len(row_data))
                        columns = ", ".join(row_data.keys())
                        
                        conn.execute(
                            f"INSERT INTO relationships ({columns}) VALUES ({placeholders})",
                            list(row_data.values())
                        )
                        
                        saved_relationships.append(relationship)
                        
                    except Exception as e:
                        self.logger.error(
                            f"Failed to save relationship {relationship.relationship_id}: {e}"
                        )
                        if not saved_relationships:
                            raise
                
                return saved_relationships
                
        except sqlite3.Error as e:
            self.logger.error(f"Batch save failed: {e}")
            raise RepositoryError(f"Batch save failed: {e}")
    
    def find_by_id(self, relationship_id: str) -> Optional[Relationship]:
        """Find relationship by ID."""
        try:
            with self.connection.get_connection() as conn:
                row = conn.execute(
                    "SELECT * FROM relationships WHERE relationship_id = ?",
                    (relationship_id,)
                ).fetchone()
                
                if not row:
                    return None
                
                return self._row_to_relationship(row)
                
        except sqlite3.Error as e:
            self.logger.error(f"Failed to find relationship {relationship_id}: {e}")
            raise RepositoryError(f"Failed to find relationship: {e}")
    
    def find_by_source(self, source_id: str) -> List[Relationship]:
        """Find all relationships from a source asset."""
        try:
            with self.connection.get_connection() as conn:
                rows = conn.execute(
                    """SELECT * FROM relationships 
                       WHERE source_id = ?
                       ORDER BY created_at DESC""",
                    (source_id,)
                ).fetchall()
                
                return [self._row_to_relationship(row) for row in rows]
                
        except sqlite3.Error as e:
            self.logger.error(f"Failed to find relationships by source: {e}")
            raise RepositoryError(f"Failed to find relationships by source: {e}")
    
    def find_by_target(self, target_id: str) -> List[Relationship]:
        """Find all relationships to a target asset."""
        try:
            with self.connection.get_connection() as conn:
                rows = conn.execute(
                    """SELECT * FROM relationships 
                       WHERE target_id = ?
                       ORDER BY created_at DESC""",
                    (target_id,)
                ).fetchall()
                
                return [self._row_to_relationship(row) for row in rows]
                
        except sqlite3.Error as e:
            self.logger.error(f"Failed to find relationships by target: {e}")
            raise RepositoryError(f"Failed to find relationships by target: {e}")
    
    def find_by_asset(self, asset_id: str) -> List[Relationship]:
        """Find all relationships involving an asset."""
        try:
            with self.connection.get_connection() as conn:
                rows = conn.execute(
                    """SELECT * FROM relationships 
                       WHERE source_id = ? OR target_id = ?
                       ORDER BY created_at DESC""",
                    (asset_id, asset_id)
                ).fetchall()
                
                return [self._row_to_relationship(row) for row in rows]
                
        except sqlite3.Error as e:
            self.logger.error(f"Failed to find relationships by asset: {e}")
            raise RepositoryError(f"Failed to find relationships by asset: {e}")
    
    def find_by_type(self, relationship_type: str) -> List[Relationship]:
        """Find all relationships of a specific type."""
        try:
            with self.connection.get_connection() as conn:
                rows = conn.execute(
                    """SELECT * FROM relationships 
                       WHERE relationship_type = ?
                       ORDER BY created_at DESC""",
                    (relationship_type,)
                ).fetchall()
                
                return [self._row_to_relationship(row) for row in rows]
                
        except sqlite3.Error as e:
            self.logger.error(f"Failed to find relationships by type: {e}")
            raise RepositoryError(f"Failed to find relationships by type: {e}")
    
    def find_between(self, asset_id1: str, asset_id2: str) -> List[Relationship]:
        """Find relationships between two assets."""
        try:
            with self.connection.get_connection() as conn:
                rows = conn.execute(
                    """SELECT * FROM relationships 
                       WHERE (source_id = ? AND target_id = ?)
                       OR (source_id = ? AND target_id = ?)
                       ORDER BY created_at DESC""",
                    (asset_id1, asset_id2, asset_id2, asset_id1)
                ).fetchall()
                
                return [self._row_to_relationship(row) for row in rows]
                
        except sqlite3.Error as e:
            self.logger.error(f"Failed to find relationships between assets: {e}")
            raise RepositoryError(f"Failed to find relationships between assets: {e}")
    
    def update(self, relationship: Relationship) -> Relationship:
        """Update existing relationship."""
        try:
            with self.connection.get_connection() as conn:
                # Check if exists
                existing = conn.execute(
                    "SELECT 1 FROM relationships WHERE relationship_id = ?",
                    (relationship.relationship_id,)
                ).fetchone()
                
                if not existing:
                    raise RelationshipNotFoundError(
                        f"Relationship {relationship.relationship_id} not found"
                    )
                
                # Update timestamp
                relationship.updated_at = datetime.utcnow()
                
                # Update relationship
                row_data = self._relationship_to_row(relationship)
                set_clause = ", ".join([f"{k} = ?" for k in row_data.keys()])
                
                conn.execute(
                    f"UPDATE relationships SET {set_clause} WHERE relationship_id = ?",
                    list(row_data.values()) + [relationship.relationship_id]
                )
                
                self.logger.info(f"Updated relationship {relationship.relationship_id}")
                return relationship
                
        except sqlite3.Error as e:
            self.logger.error(f"Failed to update relationship: {e}")
            raise RepositoryError(f"Failed to update relationship: {e}")
    
    def delete(self, relationship_id: str) -> bool:
        """Delete relationship by ID."""
        try:
            with self.connection.get_connection() as conn:
                cursor = conn.execute(
                    "DELETE FROM relationships WHERE relationship_id = ?",
                    (relationship_id,)
                )
                
                if cursor.rowcount > 0:
                    self.logger.info(f"Deleted relationship {relationship_id}")
                    return True
                
                return False
                
        except sqlite3.Error as e:
            self.logger.error(f"Failed to delete relationship: {e}")
            raise RepositoryError(f"Failed to delete relationship: {e}")
    
    def delete_by_asset(self, asset_id: str) -> int:
        """Delete all relationships involving an asset."""
        try:
            with self.connection.get_connection() as conn:
                cursor = conn.execute(
                    "DELETE FROM relationships WHERE source_id = ? OR target_id = ?",
                    (asset_id, asset_id)
                )
                
                deleted_count = cursor.rowcount
                self.logger.info(f"Deleted {deleted_count} relationships for asset {asset_id}")
                return deleted_count
                
        except sqlite3.Error as e:
            self.logger.error(f"Failed to delete relationships by asset: {e}")
            raise RepositoryError(f"Failed to delete relationships by asset: {e}")
    
    def count(self, filters: Optional[Dict[str, Any]] = None) -> int:
        """Count relationships matching filters."""
        try:
            with self.connection.get_connection() as conn:
                query = "SELECT COUNT(*) FROM relationships WHERE 1=1"
                params = []
                
                if filters:
                    if "source_id" in filters:
                        query += " AND source_id = ?"
                        params.append(filters["source_id"])
                    
                    if "target_id" in filters:
                        query += " AND target_id = ?"
                        params.append(filters["target_id"])
                    
                    if "relationship_type" in filters:
                        query += " AND relationship_type = ?"
                        params.append(filters["relationship_type"])
                    
                    if "min_confidence" in filters:
                        query += " AND confidence >= ?"
                        params.append(filters["min_confidence"])
                
                result = conn.execute(query, params).fetchone()
                return result[0]
                
        except sqlite3.Error as e:
            self.logger.error(f"Failed to count relationships: {e}")
            raise RepositoryError(f"Failed to count relationships: {e}")
    
    def get_graph_statistics(self) -> Dict[str, Any]:
        """Get graph statistics."""
        try:
            with self.connection.get_connection() as conn:
                # Total relationships
                total = conn.execute(
                    "SELECT COUNT(*) FROM relationships"
                ).fetchone()[0]
                
                # Unique nodes
                nodes_result = conn.execute("""
                    SELECT COUNT(DISTINCT asset_id) FROM (
                        SELECT source_id as asset_id FROM relationships
                        UNION
                        SELECT target_id as asset_id FROM relationships
                    )
                """).fetchone()
                node_count = nodes_result[0]
                
                # By type
                by_type_rows = conn.execute("""
                    SELECT relationship_type, COUNT(*) as count
                    FROM relationships
                    GROUP BY relationship_type
                """).fetchall()
                by_type = {row["relationship_type"]: row["count"] for row in by_type_rows}
                
                # Node degrees
                degree_stats = conn.execute("""
                    WITH node_degrees AS (
                        SELECT asset_id, COUNT(*) as degree FROM (
                            SELECT source_id as asset_id FROM relationships
                            UNION ALL
                            SELECT target_id as asset_id FROM relationships
                        ) GROUP BY asset_id
                    )
                    SELECT 
                        AVG(degree) as avg_degree,
                        MAX(degree) as max_degree,
                        MIN(degree) as min_degree
                    FROM node_degrees
                """).fetchone()
                
                # Confidence statistics
                confidence_stats = conn.execute("""
                    SELECT 
                        AVG(confidence) as avg_confidence,
                        MIN(confidence) as min_confidence,
                        MAX(confidence) as max_confidence
                    FROM relationships
                """).fetchone()
                
                stats = {
                    "node_count": node_count,
                    "edge_count": total,
                    "relationship_types": list(by_type.keys()),
                    "by_type": by_type,
                    "degree_statistics": {
                        "average": round(degree_stats["avg_degree"] or 0, 2),
                        "max": degree_stats["max_degree"] or 0,
                        "min": degree_stats["min_degree"] or 0
                    },
                    "confidence_statistics": {
                        "average": round(confidence_stats["avg_confidence"] or 0, 2),
                        "min": confidence_stats["min_confidence"] or 0,
                        "max": confidence_stats["max_confidence"] or 0
                    }
                }
                
                return stats
                
        except sqlite3.Error as e:
            self.logger.error(f"Failed to get graph statistics: {e}")
            raise RepositoryError(f"Failed to get graph statistics: {e}")
