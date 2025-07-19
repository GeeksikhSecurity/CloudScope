"""Business rules and validation for CloudScope domain models.

This module contains validation logic and business rules that apply
across the domain.
Requirements: 5.3, 5.4, 7.5, 7.6
"""

from typing import List, Dict, Any, Optional, Set
import re
from datetime import datetime, timedelta

from .asset import Asset
from .relationship import Relationship


class ValidationError(Exception):
    """Custom exception for validation errors."""
    pass


class AssetValidator:
    """Validates assets according to business rules."""
    
    # Asset naming patterns by type
    NAMING_PATTERNS = {
        "compute": re.compile(r'^[a-zA-Z0-9\-_]{1,63}$'),
        "storage": re.compile(r'^[a-zA-Z0-9\-_]{1,255}$'),
        "network": re.compile(r'^[a-zA-Z0-9\-_\.]{1,63}$'),
        "database": re.compile(r'^[a-zA-Z0-9\-_]{1,63}$'),
    }
    
    # Required properties by asset type
    REQUIRED_PROPERTIES = {
        "compute": ["instance_type", "region", "availability_zone"],
        "storage": ["storage_type", "size_gb", "region"],
        "network": ["cidr_block", "region", "vpc_id"],
        "database": ["engine", "version", "region"],
    }
    
    # Tag requirements
    REQUIRED_TAGS = ["environment", "owner", "cost-center"]
    
    @classmethod
    def validate_asset(cls, asset: Asset) -> List[str]:
        """Validate an asset and return list of validation errors.
        
        Args:
            asset: Asset to validate
            
        Returns:
            List of validation error messages (empty if valid)
        """
        errors = []
        
        # Name validation
        pattern = cls.NAMING_PATTERNS.get(asset.asset_type)
        if pattern and not pattern.match(asset.name):
            errors.append(f"Invalid name format for {asset.asset_type}: {asset.name}")
        
        # Required properties validation
        required_props = cls.REQUIRED_PROPERTIES.get(asset.asset_type, [])
        for prop in required_props:
            if prop not in asset.properties:
                errors.append(f"Missing required property: {prop}")
        
        # Required tags validation
        for tag in cls.REQUIRED_TAGS:
            if tag not in asset.tags:
                errors.append(f"Missing required tag: {tag}")
        
        # Environment tag validation
        if "environment" in asset.tags:
            valid_envs = ["development", "staging", "production", "dr"]
            if asset.tags["environment"] not in valid_envs:
                errors.append(f"Invalid environment: {asset.tags['environment']}")
        
        # Cost validation
        if asset.estimated_cost < 0:
            errors.append("Estimated cost cannot be negative")
        
        # Date validation
        if asset.created_at > datetime.utcnow():
            errors.append("Created date cannot be in the future")
        
        return errors
    
    @classmethod
    def validate_batch(cls, assets: List[Asset]) -> Dict[str, List[str]]:
        """Validate a batch of assets.
        
        Args:
            assets: List of assets to validate
            
        Returns:
            Dictionary mapping asset IDs to validation errors
        """
        results = {}
        
        for asset in assets:
            errors = cls.validate_asset(asset)
            if errors:
                results[asset.asset_id] = errors
        
        return results


class RelationshipValidator:
    """Validates relationships according to business rules."""
    
    # Valid relationship combinations
    VALID_RELATIONSHIPS = {
        ("compute", "storage"): ["uses", "depends_on"],
        ("compute", "network"): ["connects_to", "contained_by"],
        ("compute", "database"): ["uses", "depends_on"],
        ("network", "network"): ["connects_to"],
        ("storage", "storage"): ["replicates_to", "backs_up"],
        ("database", "storage"): ["uses", "backs_up"],
        ("compute", "compute"): ["load_balances", "replicates_to"],
    }
    
    @classmethod
    def validate_relationship(
        cls,
        relationship: Relationship,
        source_asset: Asset,
        target_asset: Asset
    ) -> List[str]:
        """Validate a relationship between two assets.
        
        Args:
            relationship: Relationship to validate
            source_asset: Source asset
            target_asset: Target asset
            
        Returns:
            List of validation error messages
        """
        errors = []
        
        # Check asset existence
        if relationship.source_id != source_asset.asset_id:
            errors.append("Source ID mismatch")
        
        if relationship.target_id != target_asset.asset_id:
            errors.append("Target ID mismatch")
        
        # Check valid relationship type for asset types
        type_pair = (source_asset.asset_type, target_asset.asset_type)
        reverse_pair = (target_asset.asset_type, source_asset.asset_type)
        
        valid_types = cls.VALID_RELATIONSHIPS.get(type_pair, [])
        valid_types.extend(cls.VALID_RELATIONSHIPS.get(reverse_pair, []))
        
        if relationship.relationship_type not in valid_types:
            errors.append(
                f"Invalid relationship type '{relationship.relationship_type}' "
                f"between {source_asset.asset_type} and {target_asset.asset_type}"
            )
        
        # Provider consistency check
        cross_provider_types = ["connects_to", "replicates_to", "backs_up"]
        if relationship.relationship_type not in cross_provider_types:
            if source_asset.provider != target_asset.provider:
                errors.append(
                    f"Cross-provider relationship '{relationship.relationship_type}' "
                    f"not allowed"
                )
        
        return errors
    
    @classmethod
    def detect_circular_dependencies(
        cls,
        assets: List[Asset],
        relationships: List[Relationship]
    ) -> List[List[str]]:
        """Detect circular dependencies in the asset graph.
        
        Args:
            assets: List of all assets
            relationships: List of all relationships
            
        Returns:
            List of circular dependency chains (asset IDs)
        """
        # Build adjacency list for "depends_on" relationships
        graph = {asset.asset_id: [] for asset in assets}
        
        for rel in relationships:
            if rel.relationship_type == "depends_on":
                graph[rel.source_id].append(rel.target_id)
        
        # DFS to detect cycles
        def find_cycle(node: str, visited: Set[str], 
                      stack: List[str]) -> Optional[List[str]]:
            visited.add(node)
            stack.append(node)
            
            for neighbor in graph.get(node, []):
                if neighbor in stack:
                    # Found cycle
                    cycle_start = stack.index(neighbor)
                    return stack[cycle_start:]
                
                if neighbor not in visited:
                    cycle = find_cycle(neighbor, visited, stack)
                    if cycle:
                        return cycle
            
            stack.pop()
            return None
        
        cycles = []
        visited = set()
        
        for asset_id in graph:
            if asset_id not in visited:
                cycle = find_cycle(asset_id, visited, [])
                if cycle:
                    cycles.append(cycle)
        
        return cycles


class ComplianceValidator:
    """Validates assets for compliance requirements."""
    
    @classmethod
    def validate_security_compliance(cls, asset: Asset) -> List[str]:
        """Validate asset security compliance.
        
        Args:
            asset: Asset to validate
            
        Returns:
            List of compliance violations
        """
        violations = []
        
        # Encryption requirements
        if asset.asset_type == "storage":
            if not asset.properties.get("encryption_enabled", False):
                violations.append("Storage encryption is required")
        
        if asset.asset_type == "database":
            if not asset.properties.get("encryption_at_rest", False):
                violations.append("Database encryption at rest is required")
            if not asset.properties.get("encryption_in_transit", False):
                violations.append("Database encryption in transit is required")
        
        # Network security
        if asset.asset_type == "compute":
            if asset.properties.get("public_ip") and \
               asset.tags.get("environment") == "production":
                violations.append("Production compute instances should not have public IPs")
        
        # Backup requirements
        if asset.asset_type in ["database", "storage"]:
            if not asset.properties.get("backup_enabled", False):
                violations.append("Backup is required for data assets")
        
        # Tagging compliance
        if asset.tags.get("environment") == "production":
            required_prod_tags = ["data-classification", "recovery-tier", "compliance-scope"]
            for tag in required_prod_tags:
                if tag not in asset.tags:
                    violations.append(f"Production assets require tag: {tag}")
        
        return violations
    
    @classmethod
    def validate_lifecycle_compliance(cls, asset: Asset) -> List[str]:
        """Validate asset lifecycle compliance.
        
        Args:
            asset: Asset to validate
            
        Returns:
            List of compliance violations
        """
        violations = []
        
        # Age-based compliance
        age = datetime.utcnow() - asset.created_at
        
        # Old resources check
        if age > timedelta(days=365):
            if "lifecycle-review-date" not in asset.tags:
                violations.append("Assets older than 1 year require lifecycle review")
        
        # Terminated resources
        if asset.status == "terminated":
            retention_days = asset.properties.get("retention_days", 30)
            if age > timedelta(days=retention_days):
                violations.append("Terminated asset exceeds retention period")
        
        # Unused resources
        if asset.properties.get("last_used_date"):
            last_used = datetime.fromisoformat(asset.properties["last_used_date"])
            unused_days = (datetime.utcnow() - last_used).days
            
            if unused_days > 90:
                violations.append("Asset unused for more than 90 days")
        
        return violations


def validate_asset_collection(assets: List[Asset]) -> Dict[str, Any]:
    """Perform comprehensive validation on a collection of assets.
    
    Args:
        assets: List of assets to validate
        
    Returns:
        Validation results including errors, warnings, and statistics
    """
    results = {
        "total_assets": len(assets),
        "valid_assets": 0,
        "invalid_assets": 0,
        "errors": {},
        "warnings": {},
        "statistics": {
            "by_type": {},
            "by_provider": {},
            "compliance_violations": 0
        }
    }
    
    for asset in assets:
        # Basic validation
        errors = AssetValidator.validate_asset(asset)
        
        # Security compliance
        security_violations = ComplianceValidator.validate_security_compliance(asset)
        errors.extend(security_violations)
        
        # Lifecycle compliance
        lifecycle_violations = ComplianceValidator.validate_lifecycle_compliance(asset)
        
        # Update results
        if errors:
            results["invalid_assets"] += 1
            results["errors"][asset.asset_id] = errors
        else:
            results["valid_assets"] += 1
        
        if lifecycle_violations:
            results["warnings"][asset.asset_id] = lifecycle_violations
        
        # Update statistics
        results["statistics"]["by_type"][asset.asset_type] = \
            results["statistics"]["by_type"].get(asset.asset_type, 0) + 1
        
        results["statistics"]["by_provider"][asset.provider] = \
            results["statistics"]["by_provider"].get(asset.provider, 0) + 1
        
        if security_violations:
            results["statistics"]["compliance_violations"] += 1
    
    return results
