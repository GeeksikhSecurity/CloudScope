"""Asset domain model.

This module defines the core Asset entity following DDD principles.
Requirements: 5.3, 5.4
"""

from datetime import datetime
from typing import Dict, List, Optional, Any
from dataclasses import dataclass, field
import uuid


@dataclass
class Asset:
    """Core asset domain model representing an IT infrastructure asset.
    
    This is a pure domain model with no infrastructure dependencies.
    All business logic related to assets should be implemented here.
    """
    
    # Required fields
    asset_id: str
    asset_type: str
    provider: str
    name: str
    
    # Optional fields with defaults
    properties: Dict[str, Any] = field(default_factory=dict)
    tags: Dict[str, str] = field(default_factory=dict)
    relationships: List['Relationship'] = field(default_factory=list)
    metadata: Dict[str, Any] = field(default_factory=dict)
    
    # Timestamps
    created_at: datetime = field(default_factory=datetime.utcnow)
    updated_at: datetime = field(default_factory=datetime.utcnow)
    discovered_at: datetime = field(default_factory=datetime.utcnow)
    
    # Status fields
    status: str = "active"
    health: str = "healthy"
    compliance_status: str = "unknown"
    
    # Risk and cost
    risk_score: float = 0.0
    estimated_cost: float = 0.0
    
    def __post_init__(self):
        """Validate asset after initialization."""
        self.validate()
        
        # Generate ID if not provided
        if not self.asset_id:
            self.asset_id = self._generate_id()
    
    def _generate_id(self) -> str:
        """Generate a unique asset ID."""
        return f"{self.provider}-{self.asset_type}-{uuid.uuid4().hex[:8]}"
    
    def validate(self) -> bool:
        """Validate asset according to business rules.
        
        Raises:
            ValueError: If validation fails
        """
        # Required field validation
        if not self.asset_type:
            raise ValueError("Asset type is required")
        
        if not self.provider:
            raise ValueError("Provider is required")
        
        if not self.name:
            raise ValueError("Asset name is required")
        
        # Type validation
        allowed_types = [
            "compute", "storage", "network", "database", 
            "container", "function", "identity", "security"
        ]
        if self.asset_type not in allowed_types:
            raise ValueError(f"Invalid asset type: {self.asset_type}")
        
        # Provider validation
        allowed_providers = [
            "aws", "azure", "gcp", "kubernetes", 
            "onprem", "hybrid", "custom"
        ]
        if self.provider not in allowed_providers:
            raise ValueError(f"Invalid provider: {self.provider}")
        
        # Status validation
        allowed_statuses = ["active", "inactive", "terminated", "unknown"]
        if self.status not in allowed_statuses:
            raise ValueError(f"Invalid status: {self.status}")
        
        # Risk score validation
        if not 0 <= self.risk_score <= 100:
            raise ValueError("Risk score must be between 0 and 100")
        
        return True
    
    def add_relationship(self, relationship: 'Relationship') -> None:
        """Add a relationship to another asset.
        
        Args:
            relationship: The relationship to add
        """
        # Validate relationship involves this asset
        if relationship.source_id != self.asset_id and \
           relationship.target_id != self.asset_id:
            raise ValueError("Relationship must involve this asset")
        
        # Check for duplicates
        for existing in self.relationships:
            if (existing.source_id == relationship.source_id and
                existing.target_id == relationship.target_id and
                existing.relationship_type == relationship.relationship_type):
                return  # Already exists
        
        self.relationships.append(relationship)
        self.updated_at = datetime.utcnow()
    
    def remove_relationship(self, relationship_id: str) -> bool:
        """Remove a relationship by ID.
        
        Args:
            relationship_id: The ID of the relationship to remove
            
        Returns:
            True if removed, False if not found
        """
        initial_count = len(self.relationships)
        self.relationships = [
            r for r in self.relationships 
            if r.relationship_id != relationship_id
        ]
        
        if len(self.relationships) < initial_count:
            self.updated_at = datetime.utcnow()
            return True
        return False
    
    def update_properties(self, properties: Dict[str, Any]) -> None:
        """Update asset properties.
        
        Args:
            properties: Dictionary of properties to update
        """
        self.properties.update(properties)
        self.updated_at = datetime.utcnow()
    
    def add_tag(self, key: str, value: str) -> None:
        """Add or update a tag.
        
        Args:
            key: Tag key
            value: Tag value
        """
        self.tags[key] = value
        self.updated_at = datetime.utcnow()
    
    def remove_tag(self, key: str) -> bool:
        """Remove a tag by key.
        
        Args:
            key: Tag key to remove
            
        Returns:
            True if removed, False if not found
        """
        if key in self.tags:
            del self.tags[key]
            self.updated_at = datetime.utcnow()
            return True
        return False
    
    def calculate_risk_score(self) -> float:
        """Calculate risk score based on various factors.
        
        Returns:
            Calculated risk score (0-100)
        """
        score = 0.0
        
        # Age factor
        age_days = (datetime.utcnow() - self.created_at).days
        if age_days > 365:
            score += 10  # Old assets have higher risk
        
        # Missing tags
        if not self.tags:
            score += 15  # Untagged assets are risky
        
        # Compliance status
        compliance_scores = {
            "compliant": 0,
            "non_compliant": 30,
            "unknown": 20
        }
        score += compliance_scores.get(self.compliance_status, 20)
        
        # Health status
        health_scores = {
            "healthy": 0,
            "degraded": 15,
            "unhealthy": 25,
            "unknown": 10
        }
        score += health_scores.get(self.health, 10)
        
        # Relationship complexity
        if len(self.relationships) > 10:
            score += 10  # Highly connected assets
        
        # Ensure score is within bounds
        self.risk_score = min(100, max(0, score))
        return self.risk_score
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert asset to dictionary representation.
        
        Returns:
            Dictionary representation of the asset
        """
        return {
            "asset_id": self.asset_id,
            "asset_type": self.asset_type,
            "provider": self.provider,
            "name": self.name,
            "properties": self.properties,
            "tags": self.tags,
            "metadata": self.metadata,
            "created_at": self.created_at.isoformat(),
            "updated_at": self.updated_at.isoformat(),
            "discovered_at": self.discovered_at.isoformat(),
            "status": self.status,
            "health": self.health,
            "compliance_status": self.compliance_status,
            "risk_score": self.risk_score,
            "estimated_cost": self.estimated_cost,
            "relationship_count": len(self.relationships)
        }
    
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'Asset':
        """Create asset from dictionary representation.
        
        Args:
            data: Dictionary containing asset data
            
        Returns:
            Asset instance
        """
        # Parse timestamps
        for field in ['created_at', 'updated_at', 'discovered_at']:
            if field in data and isinstance(data[field], str):
                data[field] = datetime.fromisoformat(data[field])
        
        # Remove non-field keys
        data.pop('relationship_count', None)
        
        return cls(**data)
    
    def __str__(self) -> str:
        """String representation of the asset."""
        return f"Asset({self.asset_id}, {self.asset_type}, {self.provider})"
    
    def __repr__(self) -> str:
        """Detailed string representation."""
        return (f"Asset(id={self.asset_id}, type={self.asset_type}, "
                f"provider={self.provider}, name={self.name})")
