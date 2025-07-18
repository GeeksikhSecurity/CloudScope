"""Collector port interface.

Defines the contract for asset collection from various sources.
Requirements: 3.1, 3.2, 5.2
"""

from abc import ABC, abstractmethod
from typing import List, Dict, Any, Optional, Iterator
from datetime import datetime
import logging

from ..domain.models import Asset, Relationship


class Collector(ABC):
    """Port interface for asset collection.
    
    This interface defines how assets are collected from various sources
    (cloud providers, files, APIs, etc.).
    """
    
    def __init__(self, config: Dict[str, Any]):
        """Initialize collector with configuration.
        
        Args:
            config: Collector-specific configuration
        """
        self.config = config
        self.logger = logging.getLogger(self.__class__.__name__)
    
    @property
    @abstractmethod
    def name(self) -> str:
        """Get collector name.
        
        Returns:
            Unique name for this collector
        """
        pass
    
    @property
    @abstractmethod
    def version(self) -> str:
        """Get collector version.
        
        Returns:
            Version string
        """
        pass
    
    @property
    @abstractmethod
    def provider(self) -> str:
        """Get provider name.
        
        Returns:
            Provider this collector supports (aws, azure, gcp, etc.)
        """
        pass
    
    @abstractmethod
    def validate_credentials(self) -> bool:
        """Validate collector credentials.
        
        Returns:
            True if credentials are valid
            
        Raises:
            CollectorError: If validation fails
        """
        pass
    
    @abstractmethod
    def get_supported_types(self) -> List[str]:
        """Get list of supported asset types.
        
        Returns:
            List of asset types this collector can discover
        """
        pass
    
    @abstractmethod
    def collect(self, asset_types: Optional[List[str]] = None,
                filters: Optional[Dict[str, Any]] = None) -> List[Asset]:
        """Collect assets from source.
        
        Args:
            asset_types: Optional list of asset types to collect
            filters: Optional filters to apply during collection
            
        Returns:
            List of discovered assets
            
        Raises:
            CollectorError: If collection fails
        """
        pass
    
    @abstractmethod
    def collect_streaming(self, asset_types: Optional[List[str]] = None,
                         filters: Optional[Dict[str, Any]] = None) -> Iterator[Asset]:
        """Collect assets using streaming for large datasets.
        
        Args:
            asset_types: Optional list of asset types to collect
            filters: Optional filters to apply during collection
            
        Yields:
            Assets as they are discovered
            
        Raises:
            CollectorError: If collection fails
        """
        pass
    
    @abstractmethod
    def collect_relationships(self, assets: List[Asset]) -> List[Relationship]:
        """Discover relationships between assets.
        
        Args:
            assets: List of assets to analyze for relationships
            
        Returns:
            List of discovered relationships
            
        Raises:
            CollectorError: If relationship discovery fails
        """
        pass
    
    @abstractmethod
    def test_connectivity(self) -> Dict[str, Any]:
        """Test connectivity to the source.
        
        Returns:
            Dictionary with connectivity test results
            
        Raises:
            CollectorError: If test fails
        """
        pass
    
    def get_rate_limits(self) -> Dict[str, int]:
        """Get rate limit configuration.
        
        Returns:
            Dictionary with rate limit settings
        """
        return {
            "requests_per_second": self.config.get("rate_limit", {}).get("requests_per_second", 10),
            "burst": self.config.get("rate_limit", {}).get("burst", 20)
        }
    
    def get_timeout(self) -> int:
        """Get timeout configuration.
        
        Returns:
            Timeout in seconds
        """
        return self.config.get("timeout", 300)
    
    def should_collect_asset_type(self, asset_type: str,
                                 requested_types: Optional[List[str]] = None) -> bool:
        """Check if an asset type should be collected.
        
        Args:
            asset_type: Asset type to check
            requested_types: List of requested types (None means all)
            
        Returns:
            True if the asset type should be collected
        """
        if requested_types is None:
            return asset_type in self.get_supported_types()
        
        return asset_type in requested_types and asset_type in self.get_supported_types()


class CloudCollector(Collector):
    """Base class for cloud provider collectors.
    
    Provides common functionality for AWS, Azure, GCP collectors.
    """
    
    @abstractmethod
    def get_regions(self) -> List[str]:
        """Get list of regions to collect from.
        
        Returns:
            List of region identifiers
        """
        pass
    
    @abstractmethod
    def collect_region(self, region: str, 
                      asset_types: Optional[List[str]] = None) -> List[Asset]:
        """Collect assets from a specific region.
        
        Args:
            region: Region identifier
            asset_types: Optional list of asset types to collect
            
        Returns:
            List of assets from the region
            
        Raises:
            CollectorError: If collection fails
        """
        pass
    
    def collect(self, asset_types: Optional[List[str]] = None,
                filters: Optional[Dict[str, Any]] = None) -> List[Asset]:
        """Collect assets from all configured regions.
        
        Args:
            asset_types: Optional list of asset types to collect
            filters: Optional filters to apply
            
        Returns:
            List of discovered assets
        """
        all_assets = []
        regions = self.get_regions()
        
        # Apply region filter if provided
        if filters and "regions" in filters:
            regions = [r for r in regions if r in filters["regions"]]
        
        for region in regions:
            try:
                self.logger.info(f"Collecting from region: {region}")
                assets = self.collect_region(region, asset_types)
                all_assets.extend(assets)
                self.logger.info(f"Collected {len(assets)} assets from {region}")
            except Exception as e:
                self.logger.error(f"Failed to collect from region {region}: {e}")
                if not self.config.get("continue_on_error", True):
                    raise
        
        return all_assets


class FileCollector(Collector):
    """Base class for file-based collectors.
    
    Provides common functionality for CSV, JSON, and other file collectors.
    """
    
    @abstractmethod
    def get_file_paths(self) -> List[str]:
        """Get list of file paths to collect from.
        
        Returns:
            List of file paths
        """
        pass
    
    @abstractmethod
    def parse_file(self, file_path: str) -> List[Asset]:
        """Parse assets from a file.
        
        Args:
            file_path: Path to the file
            
        Returns:
            List of assets parsed from the file
            
        Raises:
            CollectorError: If parsing fails
        """
        pass
    
    def collect(self, asset_types: Optional[List[str]] = None,
                filters: Optional[Dict[str, Any]] = None) -> List[Asset]:
        """Collect assets from configured files.
        
        Args:
            asset_types: Optional list of asset types to collect
            filters: Optional filters to apply
            
        Returns:
            List of discovered assets
        """
        all_assets = []
        
        for file_path in self.get_file_paths():
            try:
                self.logger.info(f"Parsing file: {file_path}")
                assets = self.parse_file(file_path)
                
                # Filter by asset type if requested
                if asset_types:
                    assets = [a for a in assets if a.asset_type in asset_types]
                
                all_assets.extend(assets)
                self.logger.info(f"Parsed {len(assets)} assets from {file_path}")
            except Exception as e:
                self.logger.error(f"Failed to parse file {file_path}: {e}")
                if not self.config.get("continue_on_error", True):
                    raise
        
        return all_assets


class CollectorError(Exception):
    """Base exception for collector errors."""
    pass


class CollectorAuthenticationError(CollectorError):
    """Raised when authentication fails."""
    pass


class CollectorConnectionError(CollectorError):
    """Raised when connection to source fails."""
    pass


class CollectorRateLimitError(CollectorError):
    """Raised when rate limit is exceeded."""
    pass


class CollectorTimeoutError(CollectorError):
    """Raised when operation times out."""
    pass
