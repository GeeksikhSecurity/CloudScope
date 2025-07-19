"""File-based storage adapter implementation.

Implements asset and relationship repositories using the file system.
Requirements: 1.1, 1.2, 1.4, 0.1
"""

import json
import os
import gzip
import shutil
from pathlib import Path
from typing import List, Optional, Dict, Any, Iterator
from datetime import datetime
import fcntl
import logging
from threading import Lock

from ...domain.models import Asset, Relationship
from ...ports.repository import (
    AssetRepository, RelationshipRepository,
    RepositoryError, AssetNotFoundError, RelationshipNotFoundError,
    DuplicateAssetError, DuplicateRelationshipError
)


class FileBasedAssetRepository(AssetRepository):
    """File system implementation of AssetRepository.
    
    Stores each asset as a separate JSON file, optionally compressed.
    Supports atomic operations and concurrent access.
    """
    
    def __init__(self, base_path: str, compress: bool = True):
        """Initialize file-based repository.
        
        Args:
            base_path: Base directory for storing assets
            compress: Whether to compress files with gzip
        """
        self.base_path = Path(base_path)
        self.compress = compress
        self.extension = ".json.gz" if compress else ".json"
        self.logger = logging.getLogger(self.__class__.__name__)
        self._lock = Lock()
        
        # Create directory structure
        self.base_path.mkdir(parents=True, exist_ok=True)
        self._init_indices()
    
    def _init_indices(self):
        """Initialize index files for efficient queries."""
        self.index_dir = self.base_path / ".indices"
        self.index_dir.mkdir(exist_ok=True)
        
        # Index files
        self.type_index = self.index_dir / "by_type.json"
        self.provider_index = self.index_dir / "by_provider.json"
        self.tag_index = self.index_dir / "by_tags.json"
        
        # Create empty indices if they don't exist
        for index_file in [self.type_index, self.provider_index, self.tag_index]:
            if not index_file.exists():
                self._write_json(index_file, {})
    
    def _get_asset_path(self, asset_id: str) -> Path:
        """Get file path for an asset.
        
        Args:
            asset_id: Asset ID
            
        Returns:
            Path to asset file
        """
        # Use subdirectories to avoid too many files in one directory
        subdir = asset_id[:2] if len(asset_id) >= 2 else "00"
        dir_path = self.base_path / subdir
        dir_path.mkdir(exist_ok=True)
        return dir_path / f"{asset_id}{self.extension}"
    
    def _read_json(self, path: Path) -> Dict[str, Any]:
        """Read JSON from file, handling compression.
        
        Args:
            path: File path
            
        Returns:
            Parsed JSON data
        """
        if self.compress and path.suffix == ".gz":
            with gzip.open(path, 'rt', encoding='utf-8') as f:
                return json.load(f)
        else:
            with open(path, 'r', encoding='utf-8') as f:
                return json.load(f)
    
    def _write_json(self, path: Path, data: Dict[str, Any]) -> None:
        """Write JSON to file, handling compression.
        
        Args:
            path: File path
            data: Data to write
        """
        # Write to temporary file first for atomicity
        temp_path = path.with_suffix('.tmp')
        
        if self.compress and path.suffix == ".gz":
            with gzip.open(temp_path, 'wt', encoding='utf-8') as f:
                json.dump(data, f, indent=2, default=str)
        else:
            with open(temp_path, 'w', encoding='utf-8') as f:
                json.dump(data, f, indent=2, default=str)
        
        # Atomic rename
        shutil.move(str(temp_path), str(path))
    
    def _update_index(self, asset: Asset, remove: bool = False) -> None:
        """Update indices when asset is added/removed.
        
        Args:
            asset: Asset to index
            remove: Whether to remove from index
        """
        with self._lock:
            # Update type index
            type_idx = self._read_json(self.type_index)
            if remove:
                if asset.asset_type in type_idx:
                    type_idx[asset.asset_type].remove(asset.asset_id)
                    if not type_idx[asset.asset_type]:
                        del type_idx[asset.asset_type]
            else:
                if asset.asset_type not in type_idx:
                    type_idx[asset.asset_type] = []
                if asset.asset_id not in type_idx[asset.asset_type]:
                    type_idx[asset.asset_type].append(asset.asset_id)
            self._write_json(self.type_index, type_idx)
            
            # Update provider index
            provider_idx = self._read_json(self.provider_index)
            if remove:
                if asset.provider in provider_idx:
                    provider_idx[asset.provider].remove(asset.asset_id)
                    if not provider_idx[asset.provider]:
                        del provider_idx[asset.provider]
            else:
                if asset.provider not in provider_idx:
                    provider_idx[asset.provider] = []
                if asset.asset_id not in provider_idx[asset.provider]:
                    provider_idx[asset.provider].append(asset.asset_id)
            self._write_json(self.provider_index, provider_idx)
            
            # Update tag index
            tag_idx = self._read_json(self.tag_index)
            for tag_key, tag_value in asset.tags.items():
                tag_str = f"{tag_key}={tag_value}"
                if remove:
                    if tag_str in tag_idx:
                        tag_idx[tag_str].remove(asset.asset_id)
                        if not tag_idx[tag_str]:
                            del tag_idx[tag_str]
                else:
                    if tag_str not in tag_idx:
                        tag_idx[tag_str] = []
                    if asset.asset_id not in tag_idx[tag_str]:
                        tag_idx[tag_str].append(asset.asset_id)
            self._write_json(self.tag_index, tag_idx)
    
    def save(self, asset: Asset) -> Asset:
        """Save a single asset."""
        try:
            asset_path = self._get_asset_path(asset.asset_id)
            
            # Check if already exists
            if asset_path.exists():
                raise DuplicateAssetError(f"Asset {asset.asset_id} already exists")
            
            # Save asset
            self._write_json(asset_path, asset.to_dict())
            
            # Update indices
            self._update_index(asset)
            
            self.logger.info(f"Saved asset {asset.asset_id}")
            return asset
            
        except Exception as e:
            self.logger.error(f"Failed to save asset {asset.asset_id}: {e}")
            raise RepositoryError(f"Failed to save asset: {e}")
    
    def save_batch(self, assets: List[Asset]) -> List[Asset]:
        """Save multiple assets in batch."""
        saved_assets = []
        errors = []
        
        for asset in assets:
            try:
                saved_assets.append(self.save(asset))
            except DuplicateAssetError:
                # For batch operations, skip duplicates
                self.logger.warning(f"Skipping duplicate asset {asset.asset_id}")
            except Exception as e:
                errors.append(f"{asset.asset_id}: {e}")
        
        if errors and not saved_assets:
            raise RepositoryError(f"Batch save failed: {'; '.join(errors)}")
        
        return saved_assets
    
    def find_by_id(self, asset_id: str) -> Optional[Asset]:
        """Find asset by ID."""
        try:
            asset_path = self._get_asset_path(asset_id)
            
            if not asset_path.exists():
                return None
            
            data = self._read_json(asset_path)
            return Asset.from_dict(data)
            
        except Exception as e:
            self.logger.error(f"Failed to find asset {asset_id}: {e}")
            raise RepositoryError(f"Failed to find asset: {e}")
    
    def find_all(self, filters: Optional[Dict[str, Any]] = None,
                 limit: Optional[int] = None,
                 offset: Optional[int] = None) -> List[Asset]:
        """Find all assets matching filters."""
        try:
            assets = []
            count = 0
            
            # Iterate through all asset files
            for subdir in self.base_path.iterdir():
                if subdir.name.startswith('.'):
                    continue
                    
                if not subdir.is_dir():
                    continue
                
                for asset_file in subdir.glob(f"*{self.extension}"):
                    # Apply offset
                    if offset and count < offset:
                        count += 1
                        continue
                    
                    # Apply limit
                    if limit and len(assets) >= limit:
                        return assets
                    
                    # Load and filter asset
                    data = self._read_json(asset_file)
                    asset = Asset.from_dict(data)
                    
                    if self._matches_filters(asset, filters):
                        assets.append(asset)
                    
                    count += 1
            
            return assets
            
        except Exception as e:
            self.logger.error(f"Failed to find assets: {e}")
            raise RepositoryError(f"Failed to find assets: {e}")
    
    def find_by_type(self, asset_type: str) -> List[Asset]:
        """Find all assets of a specific type."""
        try:
            type_idx = self._read_json(self.type_index)
            asset_ids = type_idx.get(asset_type, [])
            
            assets = []
            for asset_id in asset_ids:
                asset = self.find_by_id(asset_id)
                if asset:
                    assets.append(asset)
            
            return assets
            
        except Exception as e:
            self.logger.error(f"Failed to find assets by type: {e}")
            raise RepositoryError(f"Failed to find assets by type: {e}")
    
    def find_by_provider(self, provider: str) -> List[Asset]:
        """Find all assets from a specific provider."""
        try:
            provider_idx = self._read_json(self.provider_index)
            asset_ids = provider_idx.get(provider, [])
            
            assets = []
            for asset_id in asset_ids:
                asset = self.find_by_id(asset_id)
                if asset:
                    assets.append(asset)
            
            return assets
            
        except Exception as e:
            self.logger.error(f"Failed to find assets by provider: {e}")
            raise RepositoryError(f"Failed to find assets by provider: {e}")
    
    def find_by_tags(self, tags: Dict[str, str]) -> List[Asset]:
        """Find assets with specific tags."""
        try:
            tag_idx = self._read_json(self.tag_index)
            
            # Find assets that have all specified tags
            matching_ids = None
            for tag_key, tag_value in tags.items():
                tag_str = f"{tag_key}={tag_value}"
                tag_asset_ids = set(tag_idx.get(tag_str, []))
                
                if matching_ids is None:
                    matching_ids = tag_asset_ids
                else:
                    matching_ids = matching_ids.intersection(tag_asset_ids)
            
            if not matching_ids:
                return []
            
            assets = []
            for asset_id in matching_ids:
                asset = self.find_by_id(asset_id)
                if asset:
                    assets.append(asset)
            
            return assets
            
        except Exception as e:
            self.logger.error(f"Failed to find assets by tags: {e}")
            raise RepositoryError(f"Failed to find assets by tags: {e}")
    
    def update(self, asset: Asset) -> Asset:
        """Update existing asset."""
        try:
            asset_path = self._get_asset_path(asset.asset_id)
            
            if not asset_path.exists():
                raise AssetNotFoundError(f"Asset {asset.asset_id} not found")
            
            # Get old asset for index updates
            old_data = self._read_json(asset_path)
            old_asset = Asset.from_dict(old_data)
            
            # Update timestamp
            asset.updated_at = datetime.utcnow()
            
            # Save updated asset
            self._write_json(asset_path, asset.to_dict())
            
            # Update indices if needed
            if (old_asset.asset_type != asset.asset_type or
                old_asset.provider != asset.provider or
                old_asset.tags != asset.tags):
                self._update_index(old_asset, remove=True)
                self._update_index(asset, remove=False)
            
            self.logger.info(f"Updated asset {asset.asset_id}")
            return asset
            
        except Exception as e:
            self.logger.error(f"Failed to update asset {asset.asset_id}: {e}")
            raise RepositoryError(f"Failed to update asset: {e}")
    
    def update_batch(self, assets: List[Asset]) -> List[Asset]:
        """Update multiple assets in batch."""
        updated_assets = []
        errors = []
        
        for asset in assets:
            try:
                updated_assets.append(self.update(asset))
            except AssetNotFoundError:
                errors.append(f"{asset.asset_id}: not found")
            except Exception as e:
                errors.append(f"{asset.asset_id}: {e}")
        
        if errors and not updated_assets:
            raise RepositoryError(f"Batch update failed: {'; '.join(errors)}")
        
        return updated_assets
    
    def delete(self, asset_id: str) -> bool:
        """Delete asset by ID."""
        try:
            asset_path = self._get_asset_path(asset_id)
            
            if not asset_path.exists():
                return False
            
            # Get asset for index updates
            data = self._read_json(asset_path)
            asset = Asset.from_dict(data)
            
            # Delete file
            asset_path.unlink()
            
            # Update indices
            self._update_index(asset, remove=True)
            
            self.logger.info(f"Deleted asset {asset_id}")
            return True
            
        except Exception as e:
            self.logger.error(f"Failed to delete asset {asset_id}: {e}")
            raise RepositoryError(f"Failed to delete asset: {e}")
    
    def delete_batch(self, asset_ids: List[str]) -> int:
        """Delete multiple assets by ID."""
        deleted_count = 0
        
        for asset_id in asset_ids:
            try:
                if self.delete(asset_id):
                    deleted_count += 1
            except Exception as e:
                self.logger.warning(f"Failed to delete asset {asset_id}: {e}")
        
        return deleted_count
    
    def count(self, filters: Optional[Dict[str, Any]] = None) -> int:
        """Count assets matching filters."""
        # For file-based storage, we need to iterate through all assets
        # In production, consider maintaining a count index
        return len(self.find_all(filters))
    
    def exists(self, asset_id: str) -> bool:
        """Check if asset exists."""
        asset_path = self._get_asset_path(asset_id)
        return asset_path.exists()
    
    def search(self, query: str, limit: Optional[int] = None) -> List[Asset]:
        """Full-text search for assets."""
        # Simple implementation - search in name and properties
        # In production, consider using a proper search index
        results = []
        query_lower = query.lower()
        
        for asset in self.find_all():
            # Search in name
            if query_lower in asset.name.lower():
                results.append(asset)
                if limit and len(results) >= limit:
                    return results
                continue
            
            # Search in properties
            for key, value in asset.properties.items():
                if query_lower in str(value).lower():
                    results.append(asset)
                    if limit and len(results) >= limit:
                        return results
                    break
            
            # Search in tags
            for key, value in asset.tags.items():
                if query_lower in key.lower() or query_lower in value.lower():
                    results.append(asset)
                    if limit and len(results) >= limit:
                        return results
                    break
        
        return results
    
    def get_statistics(self) -> Dict[str, Any]:
        """Get repository statistics."""
        try:
            type_idx = self._read_json(self.type_index)
            provider_idx = self._read_json(self.provider_index)
            tag_idx = self._read_json(self.tag_index)
            
            # Count total assets
            all_asset_ids = set()
            for asset_ids in type_idx.values():
                all_asset_ids.update(asset_ids)
            
            stats = {
                "total_assets": len(all_asset_ids),
                "by_type": {k: len(v) for k, v in type_idx.items()},
                "by_provider": {k: len(v) for k, v in provider_idx.items()},
                "unique_tags": len(tag_idx),
                "storage_path": str(self.base_path),
                "compressed": self.compress
            }
            
            # Calculate storage size
            total_size = 0
            for subdir in self.base_path.iterdir():
                if subdir.name.startswith('.'):
                    continue
                if subdir.is_dir():
                    for asset_file in subdir.glob(f"*{self.extension}"):
                        total_size += asset_file.stat().st_size
            
            stats["storage_size_bytes"] = total_size
            stats["storage_size_mb"] = round(total_size / (1024 * 1024), 2)
            
            return stats
            
        except Exception as e:
            self.logger.error(f"Failed to get statistics: {e}")
            raise RepositoryError(f"Failed to get statistics: {e}")
    
    def _matches_filters(self, asset: Asset, filters: Optional[Dict[str, Any]]) -> bool:
        """Check if asset matches filters.
        
        Args:
            asset: Asset to check
            filters: Filters to apply
            
        Returns:
            True if asset matches all filters
        """
        if not filters:
            return True
        
        for key, value in filters.items():
            if key == "asset_type" and asset.asset_type != value:
                return False
            elif key == "provider" and asset.provider != value:
                return False
            elif key == "status" and asset.status != value:
                return False
            elif key == "min_risk_score" and asset.risk_score < value:
                return False
            elif key == "max_risk_score" and asset.risk_score > value:
                return False
            elif key == "tags":
                # Check if all filter tags are present
                for tag_key, tag_value in value.items():
                    if asset.tags.get(tag_key) != tag_value:
                        return False
        
        return True


class FileBasedRelationshipRepository(RelationshipRepository):
    """File system implementation of RelationshipRepository.
    
    Stores relationships in a similar manner to assets.
    """
    
    def __init__(self, base_path: str, compress: bool = True):
        """Initialize file-based relationship repository.
        
        Args:
            base_path: Base directory for storing relationships
            compress: Whether to compress files with gzip
        """
        self.base_path = Path(base_path)
        self.compress = compress
        self.extension = ".json.gz" if compress else ".json"
        self.logger = logging.getLogger(self.__class__.__name__)
        self._lock = Lock()
        
        # Create directory structure
        self.base_path.mkdir(parents=True, exist_ok=True)
        self._init_indices()
    
    def _init_indices(self):
        """Initialize index files for efficient queries."""
        self.index_dir = self.base_path / ".indices"
        self.index_dir.mkdir(exist_ok=True)
        
        # Index files
        self.source_index = self.index_dir / "by_source.json"
        self.target_index = self.index_dir / "by_target.json"
        self.type_index = self.index_dir / "by_type.json"
        
        # Create empty indices if they don't exist
        for index_file in [self.source_index, self.target_index, self.type_index]:
            if not index_file.exists():
                self._write_json(index_file, {})
    
    def _get_relationship_path(self, relationship_id: str) -> Path:
        """Get file path for a relationship."""
        subdir = relationship_id[:3] if len(relationship_id) >= 3 else "rel"
        dir_path = self.base_path / subdir
        dir_path.mkdir(exist_ok=True)
        return dir_path / f"{relationship_id}{self.extension}"
    
    def _read_json(self, path: Path) -> Dict[str, Any]:
        """Read JSON from file, handling compression."""
        if self.compress and path.suffix == ".gz":
            with gzip.open(path, 'rt', encoding='utf-8') as f:
                return json.load(f)
        else:
            with open(path, 'r', encoding='utf-8') as f:
                return json.load(f)
    
    def _write_json(self, path: Path, data: Dict[str, Any]) -> None:
        """Write JSON to file, handling compression."""
        temp_path = path.with_suffix('.tmp')
        
        if self.compress and path.suffix == ".gz":
            with gzip.open(temp_path, 'wt', encoding='utf-8') as f:
                json.dump(data, f, indent=2, default=str)
        else:
            with open(temp_path, 'w', encoding='utf-8') as f:
                json.dump(data, f, indent=2, default=str)
        
        shutil.move(str(temp_path), str(path))
    
    def _update_index(self, relationship: Relationship, remove: bool = False) -> None:
        """Update indices when relationship is added/removed."""
        with self._lock:
            # Update source index
            source_idx = self._read_json(self.source_index)
            if remove:
                if relationship.source_id in source_idx:
                    source_idx[relationship.source_id].remove(relationship.relationship_id)
                    if not source_idx[relationship.source_id]:
                        del source_idx[relationship.source_id]
            else:
                if relationship.source_id not in source_idx:
                    source_idx[relationship.source_id] = []
                if relationship.relationship_id not in source_idx[relationship.source_id]:
                    source_idx[relationship.source_id].append(relationship.relationship_id)
            self._write_json(self.source_index, source_idx)
            
            # Update target index
            target_idx = self._read_json(self.target_index)
            if remove:
                if relationship.target_id in target_idx:
                    target_idx[relationship.target_id].remove(relationship.relationship_id)
                    if not target_idx[relationship.target_id]:
                        del target_idx[relationship.target_id]
            else:
                if relationship.target_id not in target_idx:
                    target_idx[relationship.target_id] = []
                if relationship.relationship_id not in target_idx[relationship.target_id]:
                    target_idx[relationship.target_id].append(relationship.relationship_id)
            self._write_json(self.target_index, target_idx)
            
            # Update type index
            type_idx = self._read_json(self.type_index)
            if remove:
                if relationship.relationship_type in type_idx:
                    type_idx[relationship.relationship_type].remove(relationship.relationship_id)
                    if not type_idx[relationship.relationship_type]:
                        del type_idx[relationship.relationship_type]
            else:
                if relationship.relationship_type not in type_idx:
                    type_idx[relationship.relationship_type] = []
                if relationship.relationship_id not in type_idx[relationship.relationship_type]:
                    type_idx[relationship.relationship_type].append(relationship.relationship_id)
            self._write_json(self.type_index, type_idx)
    
    def save(self, relationship: Relationship) -> Relationship:
        """Save a single relationship."""
        try:
            rel_path = self._get_relationship_path(relationship.relationship_id)
            
            # Check for duplicates
            if rel_path.exists():
                raise DuplicateRelationshipError(
                    f"Relationship {relationship.relationship_id} already exists"
                )
            
            # Check for existing relationship between same assets
            existing = self._find_exact_relationship(
                relationship.source_id,
                relationship.target_id,
                relationship.relationship_type
            )
            if existing:
                raise DuplicateRelationshipError(
                    f"Relationship already exists: {existing.relationship_id}"
                )
            
            # Save relationship
            self._write_json(rel_path, relationship.to_dict())
            
            # Update indices
            self._update_index(relationship)
            
            self.logger.info(f"Saved relationship {relationship.relationship_id}")
            return relationship
            
        except Exception as e:
            self.logger.error(f"Failed to save relationship: {e}")
            raise RepositoryError(f"Failed to save relationship: {e}")
    
    def save_batch(self, relationships: List[Relationship]) -> List[Relationship]:
        """Save multiple relationships in batch."""
        saved_relationships = []
        errors = []
        
        for relationship in relationships:
            try:
                saved_relationships.append(self.save(relationship))
            except DuplicateRelationshipError:
                self.logger.warning(
                    f"Skipping duplicate relationship {relationship.relationship_id}"
                )
            except Exception as e:
                errors.append(f"{relationship.relationship_id}: {e}")
        
        if errors and not saved_relationships:
            raise RepositoryError(f"Batch save failed: {'; '.join(errors)}")
        
        return saved_relationships
    
    def find_by_id(self, relationship_id: str) -> Optional[Relationship]:
        """Find relationship by ID."""
        try:
            rel_path = self._get_relationship_path(relationship_id)
            
            if not rel_path.exists():
                return None
            
            data = self._read_json(rel_path)
            return Relationship.from_dict(data)
            
        except Exception as e:
            self.logger.error(f"Failed to find relationship {relationship_id}: {e}")
            raise RepositoryError(f"Failed to find relationship: {e}")
    
    def find_by_source(self, source_id: str) -> List[Relationship]:
        """Find all relationships from a source asset."""
        try:
            source_idx = self._read_json(self.source_index)
            rel_ids = source_idx.get(source_id, [])
            
            relationships = []
            for rel_id in rel_ids:
                rel = self.find_by_id(rel_id)
                if rel:
                    relationships.append(rel)
            
            return relationships
            
        except Exception as e:
            self.logger.error(f"Failed to find relationships by source: {e}")
            raise RepositoryError(f"Failed to find relationships by source: {e}")
    
    def find_by_target(self, target_id: str) -> List[Relationship]:
        """Find all relationships to a target asset."""
        try:
            target_idx = self._read_json(self.target_index)
            rel_ids = target_idx.get(target_id, [])
            
            relationships = []
            for rel_id in rel_ids:
                rel = self.find_by_id(rel_id)
                if rel:
                    relationships.append(rel)
            
            return relationships
            
        except Exception as e:
            self.logger.error(f"Failed to find relationships by target: {e}")
            raise RepositoryError(f"Failed to find relationships by target: {e}")
    
    def find_by_asset(self, asset_id: str) -> List[Relationship]:
        """Find all relationships involving an asset."""
        # Combine relationships where asset is source or target
        source_rels = self.find_by_source(asset_id)
        target_rels = self.find_by_target(asset_id)
        
        # Remove duplicates (shouldn't happen, but just in case)
        seen = set()
        all_rels = []
        
        for rel in source_rels + target_rels:
            if rel.relationship_id not in seen:
                seen.add(rel.relationship_id)
                all_rels.append(rel)
        
        return all_rels
    
    def find_by_type(self, relationship_type: str) -> List[Relationship]:
        """Find all relationships of a specific type."""
        try:
            type_idx = self._read_json(self.type_index)
            rel_ids = type_idx.get(relationship_type, [])
            
            relationships = []
            for rel_id in rel_ids:
                rel = self.find_by_id(rel_id)
                if rel:
                    relationships.append(rel)
            
            return relationships
            
        except Exception as e:
            self.logger.error(f"Failed to find relationships by type: {e}")
            raise RepositoryError(f"Failed to find relationships by type: {e}")
    
    def find_between(self, asset_id1: str, asset_id2: str) -> List[Relationship]:
        """Find relationships between two assets."""
        relationships = []
        
        # Find relationships from asset1 to asset2
        for rel in self.find_by_source(asset_id1):
            if rel.target_id == asset_id2:
                relationships.append(rel)
        
        # Find relationships from asset2 to asset1
        for rel in self.find_by_source(asset_id2):
            if rel.target_id == asset_id1:
                relationships.append(rel)
        
        return relationships
    
    def update(self, relationship: Relationship) -> Relationship:
        """Update existing relationship."""
        try:
            rel_path = self._get_relationship_path(relationship.relationship_id)
            
            if not rel_path.exists():
                raise RelationshipNotFoundError(
                    f"Relationship {relationship.relationship_id} not found"
                )
            
            # Get old relationship for index updates
            old_data = self._read_json(rel_path)
            old_rel = Relationship.from_dict(old_data)
            
            # Update timestamp
            relationship.updated_at = datetime.utcnow()
            
            # Save updated relationship
            self._write_json(rel_path, relationship.to_dict())
            
            # Update indices if needed
            if (old_rel.source_id != relationship.source_id or
                old_rel.target_id != relationship.target_id or
                old_rel.relationship_type != relationship.relationship_type):
                self._update_index(old_rel, remove=True)
                self._update_index(relationship, remove=False)
            
            self.logger.info(f"Updated relationship {relationship.relationship_id}")
            return relationship
            
        except Exception as e:
            self.logger.error(f"Failed to update relationship: {e}")
            raise RepositoryError(f"Failed to update relationship: {e}")
    
    def delete(self, relationship_id: str) -> bool:
        """Delete relationship by ID."""
        try:
            rel_path = self._get_relationship_path(relationship_id)
            
            if not rel_path.exists():
                return False
            
            # Get relationship for index updates
            data = self._read_json(rel_path)
            relationship = Relationship.from_dict(data)
            
            # Delete file
            rel_path.unlink()
            
            # Update indices
            self._update_index(relationship, remove=True)
            
            self.logger.info(f"Deleted relationship {relationship_id}")
            return True
            
        except Exception as e:
            self.logger.error(f"Failed to delete relationship: {e}")
            raise RepositoryError(f"Failed to delete relationship: {e}")
    
    def delete_by_asset(self, asset_id: str) -> int:
        """Delete all relationships involving an asset."""
        relationships = self.find_by_asset(asset_id)
        deleted_count = 0
        
        for rel in relationships:
            if self.delete(rel.relationship_id):
                deleted_count += 1
        
        return deleted_count
    
    def count(self, filters: Optional[Dict[str, Any]] = None) -> int:
        """Count relationships matching filters."""
        # Simple implementation - count all relationships
        # In production, maintain count indices
        if not filters:
            source_idx = self._read_json(self.source_index)
            total = sum(len(rel_ids) for rel_ids in source_idx.values())
            return total
        
        # With filters, we need to iterate
        count = 0
        for subdir in self.base_path.iterdir():
            if subdir.name.startswith('.'):
                continue
            if subdir.is_dir():
                for rel_file in subdir.glob(f"*{self.extension}"):
                    if self._relationship_matches_filters(rel_file, filters):
                        count += 1
        
        return count
    
    def get_graph_statistics(self) -> Dict[str, Any]:
        """Get graph statistics."""
        try:
            source_idx = self._read_json(self.source_index)
            target_idx = self._read_json(self.target_index)
            type_idx = self._read_json(self.type_index)
            
            # Get unique nodes
            nodes = set(source_idx.keys()) | set(target_idx.keys())
            
            # Count edges
            total_edges = sum(len(rel_ids) for rel_ids in source_idx.values())
            
            # Calculate average degree
            degrees = {}
            for node in nodes:
                out_degree = len(source_idx.get(node, []))
                in_degree = len(target_idx.get(node, []))
                degrees[node] = out_degree + in_degree
            
            avg_degree = sum(degrees.values()) / len(nodes) if nodes else 0
            
            stats = {
                "node_count": len(nodes),
                "edge_count": total_edges,
                "relationship_types": list(type_idx.keys()),
                "average_degree": round(avg_degree, 2),
                "max_degree": max(degrees.values()) if degrees else 0,
                "by_type": {k: len(v) for k, v in type_idx.items()}
            }
            
            return stats
            
        except Exception as e:
            self.logger.error(f"Failed to get graph statistics: {e}")
            raise RepositoryError(f"Failed to get graph statistics: {e}")
    
    def _find_exact_relationship(self, source_id: str, target_id: str,
                                relationship_type: str) -> Optional[Relationship]:
        """Find exact relationship between assets."""
        for rel in self.find_by_source(source_id):
            if (rel.target_id == target_id and 
                rel.relationship_type == relationship_type):
                return rel
        return None
    
    def _relationship_matches_filters(self, rel_path: Path,
                                    filters: Dict[str, Any]) -> bool:
        """Check if relationship file matches filters."""
        try:
            data = self._read_json(rel_path)
            
            for key, value in filters.items():
                if key == "source_id" and data.get("source_id") != value:
                    return False
                elif key == "target_id" and data.get("target_id") != value:
                    return False
                elif key == "relationship_type" and data.get("relationship_type") != value:
                    return False
                elif key == "min_confidence" and data.get("confidence", 0) < value:
                    return False
            
            return True
        except:
            return False
