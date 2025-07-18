"""Exporter port interface.

Defines the contract for exporting assets in various formats.
Requirements: 3.1, 3.2, 5.2, 6.1, 6.2
"""

from abc import ABC, abstractmethod
from typing import List, Dict, Any, Optional, IO, Iterator
from datetime import datetime
import logging

from ..domain.models import Asset, Relationship


class Exporter(ABC):
    """Port interface for asset export.
    
    This interface defines how assets are exported to various formats
    (CSV, JSON, XML, etc.) for consumption by other systems.
    """
    
    def __init__(self, config: Dict[str, Any]):
        """Initialize exporter with configuration.
        
        Args:
            config: Exporter-specific configuration
        """
        self.config = config
        self.logger = logging.getLogger(self.__class__.__name__)
    
    @property
    @abstractmethod
    def name(self) -> str:
        """Get exporter name.
        
        Returns:
            Unique name for this exporter
        """
        pass
    
    @property
    @abstractmethod
    def version(self) -> str:
        """Get exporter version.
        
        Returns:
            Version string
        """
        pass
    
    @property
    @abstractmethod
    def format(self) -> str:
        """Get export format.
        
        Returns:
            Format this exporter produces (csv, json, xml, etc.)
        """
        pass
    
    @abstractmethod
    def export(self, assets: List[Asset], output: IO[str],
               relationships: Optional[List[Relationship]] = None,
               metadata: Optional[Dict[str, Any]] = None) -> None:
        """Export assets to the specified output.
        
        Args:
            assets: List of assets to export
            output: Output stream to write to
            relationships: Optional list of relationships to include
            metadata: Optional metadata to include in export
            
        Raises:
            ExporterError: If export fails
        """
        pass
    
    @abstractmethod
    def export_streaming(self, assets: Iterator[Asset], output: IO[str],
                        relationships: Optional[Iterator[Relationship]] = None,
                        metadata: Optional[Dict[str, Any]] = None) -> None:
        """Export assets using streaming for large datasets.
        
        Args:
            assets: Iterator of assets to export
            output: Output stream to write to
            relationships: Optional iterator of relationships
            metadata: Optional metadata to include in export
            
        Raises:
            ExporterError: If export fails
        """
        pass
    
    @abstractmethod
    def validate_output(self, output: IO[str]) -> bool:
        """Validate that the output is writable.
        
        Args:
            output: Output stream to validate
            
        Returns:
            True if output is valid
            
        Raises:
            ExporterError: If validation fails
        """
        pass
    
    def get_file_extension(self) -> str:
        """Get recommended file extension for this format.
        
        Returns:
            File extension (without dot)
        """
        return self.format
    
    def get_mime_type(self) -> str:
        """Get MIME type for this format.
        
        Returns:
            MIME type string
        """
        mime_types = {
            "csv": "text/csv",
            "json": "application/json",
            "xml": "application/xml",
            "yaml": "application/x-yaml",
            "html": "text/html",
            "pdf": "application/pdf"
        }
        return mime_types.get(self.format, "application/octet-stream")


class TabularExporter(Exporter):
    """Base class for tabular format exporters (CSV, TSV, Excel).
    
    Provides common functionality for flattening hierarchical data.
    """
    
    @abstractmethod
    def get_columns(self) -> List[str]:
        """Get list of columns to include in export.
        
        Returns:
            List of column names
        """
        pass
    
    def flatten_asset(self, asset: Asset) -> Dict[str, Any]:
        """Flatten asset to tabular format.
        
        Args:
            asset: Asset to flatten
            
        Returns:
            Flattened dictionary representation
        """
        flattened = {
            "asset_id": asset.asset_id,
            "asset_type": asset.asset_type,
            "provider": asset.provider,
            "name": asset.name,
            "status": asset.status,
            "health": asset.health,
            "compliance_status": asset.compliance_status,
            "risk_score": asset.risk_score,
            "estimated_cost": asset.estimated_cost,
            "created_at": asset.created_at.isoformat(),
            "updated_at": asset.updated_at.isoformat(),
            "discovered_at": asset.discovered_at.isoformat()
        }
        
        # Flatten properties
        for key, value in asset.properties.items():
            flattened[f"property_{key}"] = str(value)
        
        # Flatten tags
        for key, value in asset.tags.items():
            flattened[f"tag_{key}"] = value
        
        # Add relationship count
        flattened["relationship_count"] = len(asset.relationships)
        
        return flattened
    
    def flatten_relationship(self, relationship: Relationship) -> Dict[str, Any]:
        """Flatten relationship to tabular format.
        
        Args:
            relationship: Relationship to flatten
            
        Returns:
            Flattened dictionary representation
        """
        flattened = {
            "relationship_id": relationship.relationship_id,
            "source_id": relationship.source_id,
            "target_id": relationship.target_id,
            "relationship_type": relationship.relationship_type,
            "confidence": relationship.confidence,
            "discovered_by": relationship.discovered_by,
            "discovery_method": relationship.discovery_method,
            "created_at": relationship.created_at.isoformat(),
            "updated_at": relationship.updated_at.isoformat()
        }
        
        # Flatten properties
        for key, value in relationship.properties.items():
            flattened[f"property_{key}"] = str(value)
        
        return flattened


class HierarchicalExporter(Exporter):
    """Base class for hierarchical format exporters (JSON, XML, YAML).
    
    Preserves the hierarchical structure of assets and relationships.
    """
    
    def create_export_structure(self, assets: List[Asset],
                              relationships: Optional[List[Relationship]] = None,
                              metadata: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """Create hierarchical export structure.
        
        Args:
            assets: List of assets
            relationships: Optional list of relationships
            metadata: Optional metadata
            
        Returns:
            Dictionary structure ready for serialization
        """
        export_data = {
            "metadata": {
                "export_date": datetime.utcnow().isoformat(),
                "exporter": self.name,
                "version": self.version,
                "asset_count": len(assets),
                "relationship_count": len(relationships) if relationships else 0
            },
            "assets": [asset.to_dict() for asset in assets]
        }
        
        if relationships:
            export_data["relationships"] = [rel.to_dict() for rel in relationships]
        
        if metadata:
            export_data["metadata"].update(metadata)
        
        return export_data


class LLMOptimizedExporter(TabularExporter):
    """Base class for LLM-optimized exporters.
    
    Formats data specifically for Large Language Model consumption.
    Requirements: 6.5, 6.6
    """
    
    def create_llm_context(self, asset: Asset, 
                          relationships: List[Relationship]) -> str:
        """Create LLM-friendly context for an asset.
        
        Args:
            asset: Asset to describe
            relationships: Related relationships
            
        Returns:
            Text description optimized for LLM understanding
        """
        context_parts = [
            f"Asset: {asset.name} (ID: {asset.asset_id})",
            f"Type: {asset.asset_type}",
            f"Provider: {asset.provider}",
            f"Status: {asset.status}",
            f"Risk Score: {asset.risk_score}/100"
        ]
        
        # Add important properties
        if asset.properties:
            context_parts.append("Properties:")
            for key, value in sorted(asset.properties.items())[:5]:
                context_parts.append(f"  - {key}: {value}")
        
        # Add tags
        if asset.tags:
            tags_str = ", ".join(f"{k}={v}" for k, v in asset.tags.items())
            context_parts.append(f"Tags: {tags_str}")
        
        # Add relationships
        if relationships:
            context_parts.append("Relationships:")
            for rel in relationships[:5]:  # Limit to avoid token explosion
                if rel.source_id == asset.asset_id:
                    context_parts.append(f"  - {rel.relationship_type} -> {rel.target_id}")
                else:
                    context_parts.append(f"  - {rel.source_id} -> {rel.relationship_type}")
        
        return "\n".join(context_parts)


class ExporterError(Exception):
    """Base exception for exporter errors."""
    pass


class ExporterValidationError(ExporterError):
    """Raised when export validation fails."""
    pass


class ExporterFormatError(ExporterError):
    """Raised when format-specific error occurs."""
    pass


class ExporterIOError(ExporterError):
    """Raised when I/O operation fails."""
    pass
