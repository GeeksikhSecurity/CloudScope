"""Base plugin interfaces and classes.

Defines the plugin contract and base implementations.
Requirements: 3.3, 3.4, 3.5
"""

from abc import ABC, abstractmethod
from typing import Dict, Any, List, Optional
from datetime import datetime
import logging
import json
from pathlib import Path

from ..domain.models import Asset, Relationship
from ..ports.collector import Collector
from ..ports.exporter import Exporter


class Plugin(ABC):
    """Base plugin interface for CloudScope plugins."""
    
    def __init__(self):
        """Initialize plugin."""
        self.logger = logging.getLogger(self.__class__.__name__)
        self._config = {}
        self._initialized = False
        self._metadata = {}
    
    @property
    @abstractmethod
    def name(self) -> str:
        """Get plugin name.
        
        Returns:
            Unique plugin name
        """
        pass
    
    @property
    @abstractmethod
    def version(self) -> str:
        """Get plugin version.
        
        Returns:
            Version string (semantic versioning recommended)
        """
        pass
    
    @property
    def description(self) -> str:
        """Get plugin description.
        
        Returns:
            Human-readable description
        """
        return self._metadata.get("description", "No description available")
    
    @property
    def author(self) -> str:
        """Get plugin author.
        
        Returns:
            Author name or organization
        """
        return self._metadata.get("author", "Unknown")
    
    @property
    def dependencies(self) -> List[str]:
        """Get plugin dependencies.
        
        Returns:
            List of required plugin names
        """
        return self._metadata.get("dependencies", [])
    
    @property
    def api_version(self) -> str:
        """Get required CloudScope API version.
        
        Returns:
            API version string
        """
        return self._metadata.get("api_version", "1.0")
    
    @abstractmethod
    def initialize(self, config: Dict[str, Any]) -> None:
        """Initialize plugin with configuration.
        
        Args:
            config: Plugin-specific configuration
            
        Raises:
            PluginError: If initialization fails
        """
        self._config = config
        self._initialized = True
    
    @abstractmethod
    def execute(self, **kwargs) -> Any:
        """Execute plugin functionality.
        
        Args:
            **kwargs: Plugin-specific arguments
            
        Returns:
            Plugin-specific result
            
        Raises:
            PluginError: If execution fails
        """
        if not self._initialized:
            raise PluginError("Plugin not initialized")
    
    @abstractmethod
    def cleanup(self) -> None:
        """Cleanup plugin resources.
        
        Called when plugin is being unloaded.
        """
        self._initialized = False
    
    def validate_config(self, config: Dict[str, Any]) -> bool:
        """Validate plugin configuration.
        
        Args:
            config: Configuration to validate
            
        Returns:
            True if configuration is valid
            
        Raises:
            PluginError: If configuration is invalid
        """
        return True
    
    def get_info(self) -> Dict[str, Any]:
        """Get plugin information.
        
        Returns:
            Dictionary with plugin metadata
        """
        return {
            "name": self.name,
            "version": self.version,
            "description": self.description,
            "author": self.author,
            "dependencies": self.dependencies,
            "api_version": self.api_version,
            "initialized": self._initialized
        }
    
    def load_metadata(self, metadata_path: Path) -> None:
        """Load plugin metadata from file.
        
        Args:
            metadata_path: Path to metadata file (JSON)
        """
        try:
            with open(metadata_path, 'r') as f:
                self._metadata = json.load(f)
        except Exception as e:
            self.logger.warning(f"Failed to load metadata: {e}")


class CollectorPlugin(Plugin, Collector):
    """Base class for collector plugins.
    
    Combines Plugin and Collector interfaces.
    """
    
    def __init__(self):
        """Initialize collector plugin."""
        Plugin.__init__(self)
        # Don't call Collector.__init__ as it requires config
        self._collector_config = {}
    
    def initialize(self, config: Dict[str, Any]) -> None:
        """Initialize collector plugin.
        
        Args:
            config: Plugin configuration
        """
        self.validate_config(config)
        self._config = config
        self._collector_config = config.get("collector", {})
        
        # Initialize collector aspects
        Collector.__init__(self, self._collector_config)
        
        self._initialized = True
    
    def execute(self, **kwargs) -> List[Asset]:
        """Execute collection.
        
        Args:
            **kwargs: Collection parameters
            
        Returns:
            List of collected assets
        """
        super().execute(**kwargs)
        
        # Extract parameters
        asset_types = kwargs.get("asset_types")
        filters = kwargs.get("filters")
        
        # Perform collection
        return self.collect(asset_types, filters)
    
    def cleanup(self) -> None:
        """Cleanup collector resources."""
        # Cleanup any connections or resources
        super().cleanup()


class ExporterPlugin(Plugin, Exporter):
    """Base class for exporter plugins.
    
    Combines Plugin and Exporter interfaces.
    """
    
    def __init__(self):
        """Initialize exporter plugin."""
        Plugin.__init__(self)
        self._exporter_config = {}
    
    def initialize(self, config: Dict[str, Any]) -> None:
        """Initialize exporter plugin.
        
        Args:
            config: Plugin configuration
        """
        self.validate_config(config)
        self._config = config
        self._exporter_config = config.get("exporter", {})
        
        # Initialize exporter aspects
        Exporter.__init__(self, self._exporter_config)
        
        self._initialized = True
    
    def execute(self, **kwargs) -> None:
        """Execute export.
        
        Args:
            **kwargs: Export parameters including:
                - assets: List of assets to export
                - output: Output stream
                - relationships: Optional relationships
                - metadata: Optional metadata
        """
        super().execute(**kwargs)
        
        # Extract parameters
        assets = kwargs.get("assets", [])
        output = kwargs.get("output")
        relationships = kwargs.get("relationships")
        metadata = kwargs.get("metadata")
        
        if not output:
            raise PluginError("Output stream required for export")
        
        # Perform export
        self.export(assets, output, relationships, metadata)
    
    def cleanup(self) -> None:
        """Cleanup exporter resources."""
        super().cleanup()


class TransformerPlugin(Plugin):
    """Base class for transformer plugins.
    
    Transforms assets or adds enrichment.
    """
    
    @abstractmethod
    def transform(self, assets: List[Asset]) -> List[Asset]:
        """Transform assets.
        
        Args:
            assets: List of assets to transform
            
        Returns:
            List of transformed assets
        """
        pass
    
    def execute(self, **kwargs) -> List[Asset]:
        """Execute transformation.
        
        Args:
            **kwargs: Must include 'assets' parameter
            
        Returns:
            Transformed assets
        """
        super().execute(**kwargs)
        
        assets = kwargs.get("assets", [])
        return self.transform(assets)


class AnalyzerPlugin(Plugin):
    """Base class for analyzer plugins.
    
    Analyzes assets and produces insights.
    """
    
    @abstractmethod
    def analyze(self, assets: List[Asset], 
                relationships: Optional[List[Relationship]] = None) -> Dict[str, Any]:
        """Analyze assets and relationships.
        
        Args:
            assets: List of assets to analyze
            relationships: Optional relationships
            
        Returns:
            Analysis results
        """
        pass
    
    def execute(self, **kwargs) -> Dict[str, Any]:
        """Execute analysis.
        
        Args:
            **kwargs: Must include 'assets' parameter
            
        Returns:
            Analysis results
        """
        super().execute(**kwargs)
        
        assets = kwargs.get("assets", [])
        relationships = kwargs.get("relationships")
        
        return self.analyze(assets, relationships)


class PluginError(Exception):
    """Base exception for plugin errors."""
    pass


class PluginInitializationError(PluginError):
    """Raised when plugin initialization fails."""
    pass


class PluginExecutionError(PluginError):
    """Raised when plugin execution fails."""
    pass


class PluginValidationError(PluginError):
    """Raised when plugin validation fails."""
    pass
