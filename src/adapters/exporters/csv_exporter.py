"""CSV exporter implementation with LLM optimization.

Exports assets to CSV format with support for streaming and LLM-optimized output.
Requirements: 6.1, 6.2, 6.5, 6.6, 6.7, 6.8
"""

import csv
import json
from typing import List, Dict, Any, Optional, IO, Iterator
from datetime import datetime
import logging

from ...domain.models import Asset, Relationship
from ...ports.exporter import TabularExporter, LLMOptimizedExporter, ExporterError


class CSVExporter(TabularExporter):
    """Standard CSV exporter for assets and relationships."""
    
    def __init__(self, config: Dict[str, Any]):
        """Initialize CSV exporter.
        
        Args:
            config: Exporter configuration including:
                - delimiter: CSV delimiter (default: ,)
                - include_headers: Include header row (default: True)
                - columns: List of columns to include
                - date_format: Date formatting string
                - max_field_length: Maximum field length
                - escape_newlines: Replace newlines in fields
        """
        super().__init__(config)
        self.delimiter = config.get("delimiter", ",")
        self.include_headers = config.get("include_headers", True)
        self.columns = config.get("columns", [])
        self.date_format = config.get("date_format", "%Y-%m-%d %H:%M:%S")
        self.max_field_length = config.get("max_field_length", 32767)
        self.escape_newlines = config.get("escape_newlines", True)
    
    @property
    def name(self) -> str:
        """Get exporter name."""
        return "csv-exporter"
    
    @property
    def version(self) -> str:
        """Get exporter version."""
        return "1.0.0"
    
    @property
    def format(self) -> str:
        """Get export format."""
        return "csv"
    
    def get_columns(self) -> List[str]:
        """Get list of columns to include in export."""
        if self.columns:
            return self.columns
        
        # Default columns
        return [
            "asset_id",
            "name", 
            "asset_type",
            "provider",
            "status",
            "health",
            "compliance_status",
            "risk_score",
            "estimated_cost",
            "created_at",
            "updated_at",
            "tags",
            "properties",
            "relationship_count"
        ]
    
    def validate_output(self, output: IO[str]) -> bool:
        """Validate that the output is writable."""
        try:
            # Check if output is writable
            if hasattr(output, 'writable') and not output.writable():
                raise ExporterError("Output stream is not writable")
            
            # Try to write empty string to test
            output.write("")
            
            return True
            
        except Exception as e:
            raise ExporterError(f"Invalid output stream: {e}")
    
    def export(self, assets: List[Asset], output: IO[str],
               relationships: Optional[List[Relationship]] = None,
               metadata: Optional[Dict[str, Any]] = None) -> None:
        """Export assets to CSV format.
        
        Args:
            assets: List of assets to export
            output: Output stream to write to
            relationships: Optional list of relationships
            metadata: Optional metadata to include
        """
        self.validate_output(output)
        
        try:
            writer = csv.DictWriter(
                output,
                fieldnames=self.get_columns(),
                delimiter=self.delimiter
            )
            
            # Write headers if configured
            if self.include_headers:
                writer.writeheader()
            
            # Write metadata as comment if provided
            if metadata:
                output.write(f"# Metadata: {json.dumps(metadata)}\n")
            
            # Write assets
            for asset in assets:
                row = self._prepare_row(asset)
                writer.writerow(row)
            
            self.logger.info(f"Exported {len(assets)} assets to CSV")
            
        except Exception as e:
            self.logger.error(f"Failed to export to CSV: {e}")
            raise ExporterError(f"Failed to export to CSV: {e}")
    
    def export_streaming(self, assets: Iterator[Asset], output: IO[str],
                        relationships: Optional[Iterator[Relationship]] = None,
                        metadata: Optional[Dict[str, Any]] = None) -> None:
        """Export assets using streaming for large datasets.
        
        Args:
            assets: Iterator of assets to export
            output: Output stream to write to
            relationships: Optional iterator of relationships
            metadata: Optional metadata to include
        """
        self.validate_output(output)
        
        try:
            writer = csv.DictWriter(
                output,
                fieldnames=self.get_columns(),
                delimiter=self.delimiter
            )
            
            # Write headers
            if self.include_headers:
                writer.writeheader()
            
            # Write metadata as comment
            if metadata:
                output.write(f"# Metadata: {json.dumps(metadata)}\n")
            
            # Stream assets
            count = 0
            for asset in assets:
                row = self._prepare_row(asset)
                writer.writerow(row)
                count += 1
                
                # Flush periodically for streaming
                if count % 1000 == 0:
                    output.flush()
            
            self.logger.info(f"Streamed {count} assets to CSV")
            
        except Exception as e:
            self.logger.error(f"Failed to stream to CSV: {e}")
            raise ExporterError(f"Failed to stream to CSV: {e}")
    
    def _prepare_row(self, asset: Asset) -> Dict[str, str]:
        """Prepare asset data for CSV row.
        
        Args:
            asset: Asset to prepare
            
        Returns:
            Dictionary representing CSV row
        """
        # Get flattened representation
        row = self.flatten_asset(asset)
        
        # Format dates
        for date_field in ["created_at", "updated_at", "discovered_at"]:
            if date_field in row and row[date_field]:
                row[date_field] = datetime.fromisoformat(row[date_field]).strftime(self.date_format)
        
        # Serialize complex fields
        if "tags" in row and isinstance(row["tags"], dict):
            row["tags"] = self._serialize_tags(row["tags"])
        
        if "properties" in row and isinstance(row["properties"], dict):
            row["properties"] = json.dumps(row["properties"])
        
        # Apply field length limits
        for key, value in row.items():
            if isinstance(value, str) and len(value) > self.max_field_length:
                row[key] = value[:self.max_field_length - 3] + "..."
            
            # Escape newlines if configured
            if self.escape_newlines and isinstance(value, str):
                row[key] = value.replace("\n", "\\n").replace("\r", "\\r")
        
        # Ensure all columns are present
        for col in self.get_columns():
            if col not in row:
                row[col] = ""
        
        # Keep only requested columns
        return {k: str(v) for k, v in row.items() if k in self.get_columns()}
    
    def _serialize_tags(self, tags: Dict[str, str]) -> str:
        """Serialize tags to string format.
        
        Args:
            tags: Dictionary of tags
            
        Returns:
            Serialized tags string
        """
        if not tags:
            return ""
        
        # Use key=value format
        return ",".join(f"{k}={v}" for k, v in sorted(tags.items()))


class LLMOptimizedCSVExporter(LLMOptimizedExporter, CSVExporter):
    """CSV exporter optimized for Large Language Model consumption.
    
    This exporter creates CSV files that are specifically formatted to be
    easily understood and processed by LLMs, with additional context and
    relationship information included.
    Requirements: 6.5, 6.6
    """
    
    def __init__(self, config: Dict[str, Any]):
        """Initialize LLM-optimized CSV exporter.
        
        Args:
            config: Exporter configuration including:
                - include_context: Include LLM context column
                - include_relationships: Include relationship information
                - context_max_length: Maximum length for context field
                - relationship_limit: Max relationships to include per asset
        """
        super().__init__(config)
        self.include_context = config.get("include_context", True)
        self.include_relationships = config.get("include_relationships", True)
        self.context_max_length = config.get("context_max_length", 2000)
        self.relationship_limit = config.get("relationship_limit", 10)
        
        # Track relationships for context building
        self._relationships = {}
        self._asset_lookup = {}
    
    @property
    def name(self) -> str:
        """Get exporter name."""
        return "llm-csv-exporter"
    
    def get_columns(self) -> List[str]:
        """Get list of columns to include in export."""
        columns = super().get_columns()
        
        # Add LLM-specific columns
        if self.include_context:
            columns.insert(0, "llm_context")
        
        if self.include_relationships:
            columns.extend([
                "related_assets",
                "relationship_summary"
            ])
        
        return columns
    
    def export(self, assets: List[Asset], output: IO[str],
               relationships: Optional[List[Relationship]] = None,
               metadata: Optional[Dict[str, Any]] = None) -> None:
        """Export assets to LLM-optimized CSV format.
        
        Args:
            assets: List of assets to export
            output: Output stream to write to
            relationships: Optional list of relationships
            metadata: Optional metadata to include
        """
        # Build lookup structures
        self._asset_lookup = {asset.asset_id: asset for asset in assets}
        
        if relationships:
            for rel in relationships:
                if rel.source_id not in self._relationships:
                    self._relationships[rel.source_id] = []
                self._relationships[rel.source_id].append(rel)
                
                if rel.target_id not in self._relationships:
                    self._relationships[rel.target_id] = []
                self._relationships[rel.target_id].append(rel)
        
        # Add LLM-friendly metadata
        if metadata is None:
            metadata = {}
        
        metadata.update({
            "format": "llm-optimized-csv",
            "description": "Asset inventory optimized for LLM analysis",
            "total_assets": len(assets),
            "total_relationships": len(relationships) if relationships else 0,
            "export_date": datetime.utcnow().isoformat(),
            "columns": self.get_columns()
        })
        
        # Export using parent method
        super().export(assets, output, relationships, metadata)
    
    def _prepare_row(self, asset: Asset) -> Dict[str, str]:
        """Prepare asset data for LLM-optimized CSV row.
        
        Args:
            asset: Asset to prepare
            
        Returns:
            Dictionary representing CSV row
        """
        # Get base row from parent
        row = super()._prepare_row(asset)
        
        # Add LLM context
        if self.include_context:
            asset_relationships = self._relationships.get(asset.asset_id, [])
            context = self.create_llm_context(asset, asset_relationships)
            
            # Limit context length
            if len(context) > self.context_max_length:
                context = context[:self.context_max_length - 3] + "..."
            
            row["llm_context"] = context
        
        # Add relationship information
        if self.include_relationships:
            asset_relationships = self._relationships.get(asset.asset_id, [])
            
            # List related assets
            related_assets = []
            relationship_summary = []
            
            for rel in asset_relationships[:self.relationship_limit]:
                if rel.source_id == asset.asset_id:
                    related_id = rel.target_id
                    rel_desc = f"-{rel.relationship_type}->"
                else:
                    related_id = rel.source_id
                    rel_desc = f"<-{rel.relationship_type}-"
                
                related_assets.append(related_id)
                
                # Get related asset name if available
                related_asset = self._asset_lookup.get(related_id)
                if related_asset:
                    rel_summary = f"{rel_desc} {related_asset.name} ({related_asset.asset_type})"
                else:
                    rel_summary = f"{rel_desc} {related_id}"
                
                relationship_summary.append(rel_summary)
            
            row["related_assets"] = ";".join(related_assets)
            row["relationship_summary"] = "; ".join(relationship_summary)
            
            # Add count if there are more relationships
            if len(asset_relationships) > self.relationship_limit:
                additional = len(asset_relationships) - self.relationship_limit
                row["relationship_summary"] += f"; +{additional} more"
        
        return row
    
    def export_relationships_csv(self, relationships: List[Relationship], 
                               output: IO[str]) -> None:
        """Export relationships to a separate CSV file.
        
        Args:
            relationships: List of relationships to export
            output: Output stream for relationships CSV
        """
        try:
            fieldnames = [
                "relationship_id",
                "source_id",
                "source_name",
                "target_id", 
                "target_name",
                "relationship_type",
                "confidence",
                "discovered_by",
                "created_at",
                "properties"
            ]
            
            writer = csv.DictWriter(output, fieldnames=fieldnames, delimiter=self.delimiter)
            
            if self.include_headers:
                writer.writeheader()
            
            for rel in relationships:
                row = {
                    "relationship_id": rel.relationship_id,
                    "source_id": rel.source_id,
                    "target_id": rel.target_id,
                    "relationship_type": rel.relationship_type,
                    "confidence": rel.confidence,
                    "discovered_by": rel.discovered_by,
                    "created_at": rel.created_at.strftime(self.date_format),
                    "properties": json.dumps(rel.properties) if rel.properties else ""
                }
                
                # Add asset names if available
                source_asset = self._asset_lookup.get(rel.source_id)
                if source_asset:
                    row["source_name"] = source_asset.name
                else:
                    row["source_name"] = ""
                
                target_asset = self._asset_lookup.get(rel.target_id)
                if target_asset:
                    row["target_name"] = target_asset.name
                else:
                    row["target_name"] = ""
                
                writer.writerow(row)
            
            self.logger.info(f"Exported {len(relationships)} relationships to CSV")
            
        except Exception as e:
            self.logger.error(f"Failed to export relationships: {e}")
            raise ExporterError(f"Failed to export relationships: {e}")
