"""Relationship domain model.

This module defines the Relationship entity for connecting assets.
Requirements: 5.3, 5.4
"""

from datetime import datetime
from typing import Dict, Any, Optional
from dataclasses import dataclass, field
import uuid


@dataclass
class Relationship:
    """Domain model for relationships between assets.
    
    Represents directed relationships between assets with typed connections
    and confidence scoring.
    """
    
    # Required fields
    source_id: str
    target_id: str
    relationship_type: str
    
    # Optional fields with defaults
    relationship_id: str = ""
    properties: Dict[str, Any] = field(default_factory=dict)
    confidence: float = 1.0
    
    # Timestamps
    created_at: datetime = field(default_factory=datetime.utcnow)
    updated_at: datetime = field(default_factory=datetime.utcnow)
    
    # Discovery metadata
    discovered_by: str = "manual"
    discovery_method: str = "explicit"
    
    def __post_init__(self):
        """Initialize and validate relationship."""
        # Generate ID if not provided
        if not self.relationship_id:
            self.relationship_id = self._generate_id()
        
        # Validate
        self.validate()
    
    def _generate_id(self) -> str:
        """Generate a unique relationship ID."""
        return f"rel-{uuid.uuid4().hex[:12]}"
    
    def validate(self) -> bool:
        """Validate relationship according to business rules.
        
        Raises:
            ValueError: If validation fails
        """
        # Required field validation
        if not self.source_id:
            raise ValueError("Source ID is required")
        
        if not self.target_id:
            raise ValueError("Target ID is required")
        
        if not self.relationship_type:
            raise ValueError("Relationship type is required")
        
        # Self-relationship check
        if self.source_id == self.target_id:
            raise ValueError("Self-relationships are not allowed")
        
        # Type validation
        allowed_types = [
            "depends_on",
            "connects_to",
            "contains",
            "contained_by",
            "uses",
            "used_by",
            "manages",
            "managed_by",
            "secures",
            "secured_by",
            "backs_up",
            "backed_up_by",
            "replicates_to",
            "replicated_from",
            "load_balances",
            "load_balanced_by",
            "monitors",
            "monitored_by",
            "owns",
            "owned_by"
        ]
        
        if self.relationship_type not in allowed_types:
            raise ValueError(f"Invalid relationship type: {self.relationship_type}")
        
        # Confidence validation
        if not 0 <= self.confidence <= 1:
            raise ValueError("Confidence must be between 0 and 1")
        
        # Discovery method validation
        allowed_methods = ["explicit", "implicit", "inferred", "discovered"]
        if self.discovery_method not in allowed_methods:
            raise ValueError(f"Invalid discovery method: {self.discovery_method}")
        
        return True
    
    def is_inverse_of(self, other: 'Relationship') -> bool:
        """Check if this relationship is the inverse of another.
        
        Args:
            other: Another relationship to compare
            
        Returns:
            True if relationships are inverses
        """
        inverse_types = {
            "depends_on": "used_by",
            "uses": "used_by",
            "contains": "contained_by",
            "manages": "managed_by",
            "secures": "secured_by",
            "backs_up": "backed_up_by",
            "replicates_to": "replicated_from",
            "load_balances": "load_balanced_by",
            "monitors": "monitored_by",
            "owns": "owned_by"
        }
        
        # Check if source/target are swapped and type is inverse
        if (self.source_id == other.target_id and 
            self.target_id == other.source_id):
            
            # Check direct inverse
            if inverse_types.get(self.relationship_type) == other.relationship_type:
                return True
            
            # Check reverse inverse
            if inverse_types.get(other.relationship_type) == self.relationship_type:
                return True
        
        return False
    
    def update_confidence(self, new_confidence: float) -> None:
        """Update the confidence score.
        
        Args:
            new_confidence: New confidence value (0-1)
        """
        if not 0 <= new_confidence <= 1:
            raise ValueError("Confidence must be between 0 and 1")
        
        self.confidence = new_confidence
        self.updated_at = datetime.utcnow()
    
    def add_property(self, key: str, value: Any) -> None:
        """Add or update a property.
        
        Args:
            key: Property key
            value: Property value
        """
        self.properties[key] = value
        self.updated_at = datetime.utcnow()
    
    def remove_property(self, key: str) -> bool:
        """Remove a property.
        
        Args:
            key: Property key to remove
            
        Returns:
            True if removed, False if not found
        """
        if key in self.properties:
            del self.properties[key]
            self.updated_at = datetime.utcnow()
            return True
        return False
    
    def get_direction(self) -> str:
        """Get the relationship direction type.
        
        Returns:
            Direction type: 'outbound', 'inbound', or 'bidirectional'
        """
        directional_types = {
            "depends_on": "outbound",
            "uses": "outbound",
            "contains": "outbound",
            "manages": "outbound",
            "secures": "outbound",
            "backs_up": "outbound",
            "replicates_to": "outbound",
            "load_balances": "outbound",
            "monitors": "outbound",
            "owns": "outbound",
            "used_by": "inbound",
            "contained_by": "inbound",
            "managed_by": "inbound",
            "secured_by": "inbound",
            "backed_up_by": "inbound",
            "replicated_from": "inbound",
            "load_balanced_by": "inbound",
            "monitored_by": "inbound",
            "owned_by": "inbound",
            "connects_to": "bidirectional"
        }
        
        return directional_types.get(self.relationship_type, "unknown")
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert relationship to dictionary representation.
        
        Returns:
            Dictionary representation of the relationship
        """
        return {
            "relationship_id": self.relationship_id,
            "source_id": self.source_id,
            "target_id": self.target_id,
            "relationship_type": self.relationship_type,
            "properties": self.properties,
            "confidence": self.confidence,
            "created_at": self.created_at.isoformat(),
            "updated_at": self.updated_at.isoformat(),
            "discovered_by": self.discovered_by,
            "discovery_method": self.discovery_method,
            "direction": self.get_direction()
        }
    
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'Relationship':
        """Create relationship from dictionary representation.
        
        Args:
            data: Dictionary containing relationship data
            
        Returns:
            Relationship instance
        """
        # Parse timestamps
        for field in ['created_at', 'updated_at']:
            if field in data and isinstance(data[field], str):
                data[field] = datetime.fromisoformat(data[field])
        
        # Remove computed fields
        data.pop('direction', None)
        
        return cls(**data)
    
    def __str__(self) -> str:
        """String representation of the relationship."""
        return (f"Relationship({self.source_id} -{self.relationship_type}-> "
                f"{self.target_id})")
    
    def __repr__(self) -> str:
        """Detailed string representation."""
        return (f"Relationship(id={self.relationship_id}, "
                f"type={self.relationship_type}, "
                f"confidence={self.confidence})")
    
    def __eq__(self, other: object) -> bool:
        """Check equality based on key fields."""
        if not isinstance(other, Relationship):
            return False
        
        return (self.source_id == other.source_id and
                self.target_id == other.target_id and
                self.relationship_type == other.relationship_type)
    
    def __hash__(self) -> int:
        """Hash based on key fields."""
        return hash((self.source_id, self.target_id, self.relationship_type))
