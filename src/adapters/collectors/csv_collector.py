"""CSV file collector implementation.

Collects assets from CSV files with configurable mapping.
Requirements: 3.1, 6.1, 6.2, 0.1
"""

import csv
import json
import os
from pathlib import Path
from typing import List, Dict, Any, Optional, Iterator
from datetime import datetime
import logging

from ...domain.models import Asset, Relationship
from ...ports.collector import FileCollector, CollectorError


class CSVCollector(FileCollector):
    """Collects assets from CSV files.
    
    Supports flexible column mapping and relationship detection.
    """
    
    def __init__(self, config: Dict[str, Any]):
        """Initialize CSV collector.
        
        Args:
            config: Collector configuration including:
                - file_paths: List of CSV file paths
                - column_mapping: Mapping of CSV columns to asset fields
                - delimiter: CSV delimiter (default: ,)
                - encoding: File encoding (default: utf-8)
                - skip_rows: Number of header rows to skip
                - asset_type: Default asset type if not in CSV
                - provider: Default provider if not in CSV
        """
        super().__init__(config)
        self.delimiter = config.get("delimiter", ",")
        self.encoding = config.get("encoding", "utf-8")
        self.skip_rows = config.get("skip_rows", 0)
        self.column_mapping = config.get("column_mapping", {})
        self.default_asset_type = config.get("asset_type", "unknown")
        self.default_provider = config.get("provider", "csv")
        
        # Validate configuration
        if not self.column_mapping:
            self._init_default_mapping()
    
    @property
    def name(self) -> str:
        """Get collector name."""
        return "csv-collector"
    
    @property
    def version(self) -> str:
        """Get collector version."""
        return "1.0.0"
    
    @property
    def provider(self) -> str:
        """Get provider name."""
        return self.default_provider
    
    def _init_default_mapping(self):
        """Initialize default column mapping."""
        self.column_mapping = {
            "asset_id": ["id", "asset_id", "resource_id", "identifier"],
            "name": ["name", "asset_name", "resource_name", "display_name"],
            "asset_type": ["type", "asset_type", "resource_type", "kind"],
            "provider": ["provider", "cloud_provider", "source"],
            "status": ["status", "state", "lifecycle_state"],
            "tags": ["tags", "labels", "metadata"],
            "properties": ["properties", "attributes", "configuration"]
        }
    
    def validate_credentials(self) -> bool:
        """Validate collector credentials."""
        # For CSV collector, just check if files exist
        file_paths = self.get_file_paths()
        
        if not file_paths:
            self.logger.error("No file paths configured")
            return False
        
        for file_path in file_paths:
            if not Path(file_path).exists():
                self.logger.error(f"File not found: {file_path}")
                return False
        
        return True
    
    def get_supported_types(self) -> List[str]:
        """Get list of supported asset types."""
        # CSV collector can support any type
        return [
            "compute", "storage", "network", "database",
            "identity", "security", "application", "custom"
        ]
    
    def get_file_paths(self) -> List[str]:
        """Get list of file paths to collect from."""
        file_paths = self.config.get("file_paths", [])
        
        # Support single file path as string
        if isinstance(file_paths, str):
            file_paths = [file_paths]
        
        # Support glob patterns
        expanded_paths = []
        for path_pattern in file_paths:
            if "*" in path_pattern or "?" in path_pattern:
                # Glob pattern
                for path in Path().glob(path_pattern):
                    if path.is_file() and path.suffix.lower() == ".csv":
                        expanded_paths.append(str(path))
            else:
                expanded_paths.append(path_pattern)
        
        return expanded_paths
    
    def parse_file(self, file_path: str) -> List[Asset]:
        """Parse assets from a CSV file.
        
        Args:
            file_path: Path to CSV file
            
        Returns:
            List of parsed assets
        """
        assets = []
        
        try:
            with open(file_path, 'r', encoding=self.encoding) as f:
                # Skip header rows if configured
                for _ in range(self.skip_rows):
                    next(f)
                
                reader = csv.DictReader(f, delimiter=self.delimiter)
                
                for row_num, row in enumerate(reader, start=1):
                    try:
                        asset = self._parse_row(row, file_path, row_num)
                        if asset:
                            assets.append(asset)
                    except Exception as e:
                        self.logger.error(
                            f"Failed to parse row {row_num} in {file_path}: {e}"
                        )
                        if not self.config.get("continue_on_error", True):
                            raise
            
            self.logger.info(f"Parsed {len(assets)} assets from {file_path}")
            return assets
            
        except Exception as e:
            self.logger.error(f"Failed to parse CSV file {file_path}: {e}")
            raise CollectorError(f"Failed to parse CSV file: {e}")
    
    def _parse_row(self, row: Dict[str, str], file_path: str, 
                   row_num: int) -> Optional[Asset]:
        """Parse a single CSV row into an Asset.
        
        Args:
            row: CSV row as dictionary
            file_path: Source file path
            row_num: Row number for error reporting
            
        Returns:
            Parsed asset or None if invalid
        """
        # Extract required fields
        asset_id = self._get_mapped_value(row, "asset_id")
        name = self._get_mapped_value(row, "name")
        asset_type = self._get_mapped_value(row, "asset_type") or self.default_asset_type
        provider = self._get_mapped_value(row, "provider") or self.default_provider
        
        # Generate ID if not provided
        if not asset_id:
            # Use hash of row content
            row_str = json.dumps(row, sort_keys=True)
            asset_id = f"csv-{hash(row_str) & 0x7FFFFFFF}"
        
        # Use ID as name if name not provided
        if not name:
            name = asset_id
        
        # Create asset
        asset = Asset(
            asset_id=asset_id,
            asset_type=asset_type,
            provider=provider,
            name=name
        )
        
        # Extract optional fields
        status = self._get_mapped_value(row, "status")
        if status:
            asset.status = status
        
        # Parse tags
        tags_str = self._get_mapped_value(row, "tags")
        if tags_str:
            asset.tags = self._parse_tags(tags_str)
        
        # Parse properties
        props_str = self._get_mapped_value(row, "properties")
        if props_str:
            asset.properties = self._parse_properties(props_str)
        
        # Add all unmapped columns as properties
        mapped_columns = set()
        for mapping_list in self.column_mapping.values():
            if isinstance(mapping_list, list):
                mapped_columns.update(mapping_list)
            else:
                mapped_columns.add(mapping_list)
        
        for col_name, col_value in row.items():
            if col_name not in mapped_columns and col_value:
                # Clean property name
                prop_name = col_name.lower().replace(" ", "_").replace("-", "_")
                asset.properties[prop_name] = col_value
        
        # Add source metadata
        asset.metadata["source_file"] = file_path
        asset.metadata["source_row"] = row_num
        asset.metadata["collected_at"] = datetime.utcnow().isoformat()
        
        return asset
    
    def _get_mapped_value(self, row: Dict[str, str], field: str) -> Optional[str]:
        """Get value from row using column mapping.
        
        Args:
            row: CSV row
            field: Field name to extract
            
        Returns:
            Mapped value or None
        """
        mapping = self.column_mapping.get(field)
        
        if not mapping:
            return None
        
        # Handle single column name
        if isinstance(mapping, str):
            return row.get(mapping)
        
        # Handle list of possible column names
        if isinstance(mapping, list):
            for col_name in mapping:
                # Case-insensitive matching
                for key, value in row.items():
                    if key.lower() == col_name.lower():
                        return value
        
        return None
    
    def _parse_tags(self, tags_str: str) -> Dict[str, str]:
        """Parse tags from string representation.
        
        Args:
            tags_str: Tags string (e.g., "env=prod,team=infra")
            
        Returns:
            Dictionary of tags
        """
        tags = {}
        
        # Try JSON format first
        if tags_str.startswith("{"):
            try:
                return json.loads(tags_str)
            except json.JSONDecodeError:
                pass
        
        # Parse key=value format
        for tag in tags_str.split(","):
            tag = tag.strip()
            if "=" in tag:
                key, value = tag.split("=", 1)
                tags[key.strip()] = value.strip()
            elif ":" in tag:
                key, value = tag.split(":", 1)
                tags[key.strip()] = value.strip()
            else:
                # Tag without value
                tags[tag] = "true"
        
        return tags
    
    def _parse_properties(self, props_str: str) -> Dict[str, Any]:
        """Parse properties from string representation.
        
        Args:
            props_str: Properties string
            
        Returns:
            Dictionary of properties
        """
        # Try JSON format first
        if props_str.startswith("{"):
            try:
                return json.loads(props_str)
            except json.JSONDecodeError:
                self.logger.warning(f"Failed to parse properties as JSON: {props_str}")
        
        # Fall back to simple key=value parsing
        return self._parse_tags(props_str)
    
    def collect_streaming(self, asset_types: Optional[List[str]] = None,
                         filters: Optional[Dict[str, Any]] = None) -> Iterator[Asset]:
        """Collect assets using streaming for large datasets.
        
        Args:
            asset_types: Optional list of asset types to collect
            filters: Optional filters to apply
            
        Yields:
            Assets as they are discovered
        """
        for file_path in self.get_file_paths():
            try:
                with open(file_path, 'r', encoding=self.encoding) as f:
                    # Skip header rows
                    for _ in range(self.skip_rows):
                        next(f)
                    
                    reader = csv.DictReader(f, delimiter=self.delimiter)
                    
                    for row_num, row in enumerate(reader, start=1):
                        try:
                            asset = self._parse_row(row, file_path, row_num)
                            
                            if asset and self._should_collect_asset(asset, asset_types, filters):
                                yield asset
                                
                        except Exception as e:
                            self.logger.error(
                                f"Failed to parse row {row_num} in {file_path}: {e}"
                            )
                            if not self.config.get("continue_on_error", True):
                                raise
                                
            except Exception as e:
                self.logger.error(f"Failed to stream CSV file {file_path}: {e}")
                if not self.config.get("continue_on_error", True):
                    raise CollectorError(f"Failed to stream CSV file: {e}")
    
    def _should_collect_asset(self, asset: Asset, 
                            asset_types: Optional[List[str]] = None,
                            filters: Optional[Dict[str, Any]] = None) -> bool:
        """Check if asset should be collected based on filters.
        
        Args:
            asset: Asset to check
            asset_types: Optional asset type filter
            filters: Optional additional filters
            
        Returns:
            True if asset should be collected
        """
        # Check asset type filter
        if asset_types and asset.asset_type not in asset_types:
            return False
        
        # Apply additional filters
        if filters:
            for key, value in filters.items():
                if key == "provider" and asset.provider != value:
                    return False
                elif key == "status" and asset.status != value:
                    return False
                elif key.startswith("tag_"):
                    tag_key = key[4:]  # Remove "tag_" prefix
                    if asset.tags.get(tag_key) != value:
                        return False
                elif key.startswith("property_"):
                    prop_key = key[9:]  # Remove "property_" prefix
                    if asset.properties.get(prop_key) != value:
                        return False
        
        return True
    
    def collect_relationships(self, assets: List[Asset]) -> List[Relationship]:
        """Discover relationships between assets.
        
        Args:
            assets: List of assets to analyze
            
        Returns:
            List of discovered relationships
        """
        relationships = []
        
        # Create asset lookup
        asset_lookup = {asset.asset_id: asset for asset in assets}
        
        # Check for explicit relationships in properties
        for asset in assets:
            # Common relationship properties
            rel_props = [
                ("depends_on", "depends_on"),
                ("connected_to", "connects_to"),
                ("managed_by", "managed_by"),
                ("parent_id", "contained_by"),
                ("vpc_id", "contained_by"),
                ("subnet_id", "contained_by"),
                ("security_group_ids", "uses"),
                ("load_balancer_id", "load_balanced_by")
            ]
            
            for prop_name, rel_type in rel_props:
                if prop_name in asset.properties:
                    target_ids = asset.properties[prop_name]
                    
                    # Handle single ID or list of IDs
                    if isinstance(target_ids, str):
                        target_ids = [target_ids]
                    elif not isinstance(target_ids, list):
                        continue
                    
                    for target_id in target_ids:
                        if target_id in asset_lookup:
                            rel = Relationship(
                                source_id=asset.asset_id,
                                target_id=target_id,
                                relationship_type=rel_type,
                                discovered_by="csv-collector",
                                discovery_method="property"
                            )
                            relationships.append(rel)
        
        self.logger.info(f"Discovered {len(relationships)} relationships")
        return relationships
    
    def test_connectivity(self) -> Dict[str, Any]:
        """Test connectivity to the source."""
        results = {
            "status": "success",
            "files": {},
            "total_files": 0,
            "accessible_files": 0
        }
        
        file_paths = self.get_file_paths()
        results["total_files"] = len(file_paths)
        
        for file_path in file_paths:
            path = Path(file_path)
            file_info = {
                "exists": path.exists(),
                "readable": False,
                "size": 0,
                "error": None
            }
            
            if path.exists():
                try:
                    file_info["readable"] = os.access(file_path, os.R_OK)
                    file_info["size"] = path.stat().st_size
                    
                    if file_info["readable"]:
                        results["accessible_files"] += 1
                        
                except Exception as e:
                    file_info["error"] = str(e)
            else:
                file_info["error"] = "File not found"
            
            results["files"][file_path] = file_info
        
        if results["accessible_files"] == 0:
            results["status"] = "error"
            results["message"] = "No accessible files found"
        elif results["accessible_files"] < results["total_files"]:
            results["status"] = "warning"
            results["message"] = f"Only {results['accessible_files']} of {results['total_files']} files accessible"
        
        return results
