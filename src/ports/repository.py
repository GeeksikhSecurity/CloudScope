"""Repository port interfaces.

These interfaces define the contracts for data persistence,
independent of the actual storage implementation.
Requirements: 1.2, 1.3, 5.2
"""

from abc import ABC, abstractmethod
from typing import List, Optional, Dict, Any, Tuple
from datetime import datetime

from ..domain.models import Asset, Relationship


class AssetRepository(ABC):
    """Port interface for asset persistence.
    
    This interface defines all operations for storing and retrieving assets,
    regardless of the underlying storage mechanism (file, database, etc.).
    """
    
    @abstractmethod
    def save(self, asset: Asset) -> Asset:
        """Save a single asset.
        
        Args:
            asset: Asset to save
            
        Returns:
            Saved asset with any updates (e.g., generated IDs)
            
        Raises:
            RepositoryError: If save operation fails
        """
        pass
    
    @abstractmethod
    def save_batch(self, assets: List[Asset]) -> List[Asset]:
        """Save multiple assets in batch.
        
        Args:
            assets: List of assets to save
            
        Returns:
            List of saved assets
            
        Raises:
            RepositoryError: If batch save fails
        """
        pass
    
    @abstractmethod
    def find_by_id(self, asset_id: str) -> Optional[Asset]:
        """Find asset by ID.
        
        Args:
            asset_id: Unique asset identifier
            
        Returns:
            Asset if found, None otherwise
            
        Raises:
            RepositoryError: If query fails
        """
        pass
    
    @abstractmethod
    def find_all(self, filters: Optional[Dict[str, Any]] = None,
                 limit: Optional[int] = None,
                 offset: Optional[int] = None) -> List[Asset]:
        """Find all assets matching filters.
        
        Args:
            filters: Optional filters to apply
            limit: Maximum number of results
            offset: Number of results to skip
            
        Returns:
            List of matching assets
            
        Raises:
            RepositoryError: If query fails
        """
        pass
    
    @abstractmethod
    def find_by_type(self, asset_type: str) -> List[Asset]:
        """Find all assets of a specific type.
        
        Args:
            asset_type: Type of assets to find
            
        Returns:
            List of assets of the specified type
            
        Raises:
            RepositoryError: If query fails
        """
        pass
    
    @abstractmethod
    def find_by_provider(self, provider: str) -> List[Asset]:
        """Find all assets from a specific provider.
        
        Args:
            provider: Provider name
            
        Returns:
            List of assets from the provider
            
        Raises:
            RepositoryError: If query fails
        """
        pass
    
    @abstractmethod
    def find_by_tags(self, tags: Dict[str, str]) -> List[Asset]:
        """Find assets with specific tags.
        
        Args:
            tags: Tags to match (all must be present)
            
        Returns:
            List of assets with matching tags
            
        Raises:
            RepositoryError: If query fails
        """
        pass
    
    @abstractmethod
    def update(self, asset: Asset) -> Asset:
        """Update existing asset.
        
        Args:
            asset: Asset with updated data
            
        Returns:
            Updated asset
            
        Raises:
            RepositoryError: If update fails
            AssetNotFoundError: If asset doesn't exist
        """
        pass
    
    @abstractmethod
    def update_batch(self, assets: List[Asset]) -> List[Asset]:
        """Update multiple assets in batch.
        
        Args:
            assets: List of assets to update
            
        Returns:
            List of updated assets
            
        Raises:
            RepositoryError: If batch update fails
        """
        pass
    
    @abstractmethod
    def delete(self, asset_id: str) -> bool:
        """Delete asset by ID.
        
        Args:
            asset_id: ID of asset to delete
            
        Returns:
            True if deleted, False if not found
            
        Raises:
            RepositoryError: If delete fails
        """
        pass
    
    @abstractmethod
    def delete_batch(self, asset_ids: List[str]) -> int:
        """Delete multiple assets by ID.
        
        Args:
            asset_ids: List of asset IDs to delete
            
        Returns:
            Number of assets deleted
            
        Raises:
            RepositoryError: If batch delete fails
        """
        pass
    
    @abstractmethod
    def count(self, filters: Optional[Dict[str, Any]] = None) -> int:
        """Count assets matching filters.
        
        Args:
            filters: Optional filters to apply
            
        Returns:
            Number of matching assets
            
        Raises:
            RepositoryError: If count fails
        """
        pass
    
    @abstractmethod
    def exists(self, asset_id: str) -> bool:
        """Check if asset exists.
        
        Args:
            asset_id: Asset ID to check
            
        Returns:
            True if exists, False otherwise
            
        Raises:
            RepositoryError: If check fails
        """
        pass
    
    @abstractmethod
    def search(self, query: str, limit: Optional[int] = None) -> List[Asset]:
        """Full-text search for assets.
        
        Args:
            query: Search query
            limit: Maximum number of results
            
        Returns:
            List of matching assets
            
        Raises:
            RepositoryError: If search fails
        """
        pass
    
    @abstractmethod
    def get_statistics(self) -> Dict[str, Any]:
        """Get repository statistics.
        
        Returns:
            Dictionary with statistics (counts by type, provider, etc.)
            
        Raises:
            RepositoryError: If operation fails
        """
        pass


class RelationshipRepository(ABC):
    """Port interface for relationship persistence.
    
    This interface defines all operations for storing and retrieving
    relationships between assets.
    """
    
    @abstractmethod
    def save(self, relationship: Relationship) -> Relationship:
        """Save a single relationship.
        
        Args:
            relationship: Relationship to save
            
        Returns:
            Saved relationship
            
        Raises:
            RepositoryError: If save fails
        """
        pass
    
    @abstractmethod
    def save_batch(self, relationships: List[Relationship]) -> List[Relationship]:
        """Save multiple relationships in batch.
        
        Args:
            relationships: List of relationships to save
            
        Returns:
            List of saved relationships
            
        Raises:
            RepositoryError: If batch save fails
        """
        pass
    
    @abstractmethod
    def find_by_id(self, relationship_id: str) -> Optional[Relationship]:
        """Find relationship by ID.
        
        Args:
            relationship_id: Unique relationship identifier
            
        Returns:
            Relationship if found, None otherwise
            
        Raises:
            RepositoryError: If query fails
        """
        pass
    
    @abstractmethod
    def find_by_source(self, source_id: str) -> List[Relationship]:
        """Find all relationships from a source asset.
        
        Args:
            source_id: Source asset ID
            
        Returns:
            List of relationships from the source
            
        Raises:
            RepositoryError: If query fails
        """
        pass
    
    @abstractmethod
    def find_by_target(self, target_id: str) -> List[Relationship]:
        """Find all relationships to a target asset.
        
        Args:
            target_id: Target asset ID
            
        Returns:
            List of relationships to the target
            
        Raises:
            RepositoryError: If query fails
        """
        pass
    
    @abstractmethod
    def find_by_asset(self, asset_id: str) -> List[Relationship]:
        """Find all relationships involving an asset.
        
        Args:
            asset_id: Asset ID (can be source or target)
            
        Returns:
            List of relationships involving the asset
            
        Raises:
            RepositoryError: If query fails
        """
        pass
    
    @abstractmethod
    def find_by_type(self, relationship_type: str) -> List[Relationship]:
        """Find all relationships of a specific type.
        
        Args:
            relationship_type: Type of relationships to find
            
        Returns:
            List of relationships of the specified type
            
        Raises:
            RepositoryError: If query fails
        """
        pass
    
    @abstractmethod
    def find_between(self, asset_id1: str, asset_id2: str) -> List[Relationship]:
        """Find relationships between two assets.
        
        Args:
            asset_id1: First asset ID
            asset_id2: Second asset ID
            
        Returns:
            List of relationships between the assets (in either direction)
            
        Raises:
            RepositoryError: If query fails
        """
        pass
    
    @abstractmethod
    def update(self, relationship: Relationship) -> Relationship:
        """Update existing relationship.
        
        Args:
            relationship: Relationship with updated data
            
        Returns:
            Updated relationship
            
        Raises:
            RepositoryError: If update fails
            RelationshipNotFoundError: If relationship doesn't exist
        """
        pass
    
    @abstractmethod
    def delete(self, relationship_id: str) -> bool:
        """Delete relationship by ID.
        
        Args:
            relationship_id: ID of relationship to delete
            
        Returns:
            True if deleted, False if not found
            
        Raises:
            RepositoryError: If delete fails
        """
        pass
    
    @abstractmethod
    def delete_by_asset(self, asset_id: str) -> int:
        """Delete all relationships involving an asset.
        
        Args:
            asset_id: Asset ID
            
        Returns:
            Number of relationships deleted
            
        Raises:
            RepositoryError: If delete fails
        """
        pass
    
    @abstractmethod
    def count(self, filters: Optional[Dict[str, Any]] = None) -> int:
        """Count relationships matching filters.
        
        Args:
            filters: Optional filters to apply
            
        Returns:
            Number of matching relationships
            
        Raises:
            RepositoryError: If count fails
        """
        pass
    
    @abstractmethod
    def get_graph_statistics(self) -> Dict[str, Any]:
        """Get graph statistics.
        
        Returns:
            Dictionary with graph metrics (nodes, edges, connectivity, etc.)
            
        Raises:
            RepositoryError: If operation fails
        """
        pass


class RepositoryError(Exception):
    """Base exception for repository errors."""
    pass


class AssetNotFoundError(RepositoryError):
    """Raised when an asset is not found."""
    pass


class RelationshipNotFoundError(RepositoryError):
    """Raised when a relationship is not found."""
    pass


class DuplicateAssetError(RepositoryError):
    """Raised when attempting to create a duplicate asset."""
    pass


class DuplicateRelationshipError(RepositoryError):
    """Raised when attempting to create a duplicate relationship."""
    pass
