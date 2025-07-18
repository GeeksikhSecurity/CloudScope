"""Unit tests for Relationship domain model."""

import pytest
from datetime import datetime

from src.domain.models.relationship import Relationship


class TestRelationship:
    """Test cases for Relationship model."""
    
    def test_relationship_creation(self):
        """Test basic relationship creation."""
        rel = Relationship(
            source_id="asset-001",
            target_id="asset-002",
            relationship_type="depends_on"
        )
        
        assert rel.source_id == "asset-001"
        assert rel.target_id == "asset-002"
        assert rel.relationship_type == "depends_on"
        assert rel.confidence == 1.0
        assert rel.discovered_by == "manual"
        assert rel.discovery_method == "explicit"
        assert rel.relationship_id.startswith("rel-")
    
    def test_relationship_validation_success(self):
        """Test successful relationship validation."""
        rel = Relationship(
            source_id="asset-001",
            target_id="asset-002",
            relationship_type="connects_to"
        )
        
        assert rel.validate() is True
    
    def test_relationship_validation_missing_source(self):
        """Test validation with missing source ID."""
        with pytest.raises(ValueError, match="Source ID is required"):
            Relationship(
                source_id="",
                target_id="asset-002",
                relationship_type="depends_on"
            )
    
    def test_relationship_validation_missing_target(self):
        """Test validation with missing target ID."""
        with pytest.raises(ValueError, match="Target ID is required"):
            Relationship(
                source_id="asset-001",
                target_id="",
                relationship_type="depends_on"
            )
    
    def test_relationship_validation_missing_type(self):
        """Test validation with missing relationship type."""
        with pytest.raises(ValueError, match="Relationship type is required"):
            Relationship(
                source_id="asset-001",
                target_id="asset-002",
                relationship_type=""
            )
    
    def test_relationship_validation_self_relationship(self):
        """Test validation preventing self-relationships."""
        with pytest.raises(ValueError, match="Self-relationships are not allowed"):
            Relationship(
                source_id="asset-001",
                target_id="asset-001",
                relationship_type="depends_on"
            )
    
    def test_relationship_validation_invalid_type(self):
        """Test validation with invalid relationship type."""
        with pytest.raises(ValueError, match="Invalid relationship type"):
            Relationship(
                source_id="asset-001",
                target_id="asset-002",
                relationship_type="invalid_type"
            )
    
    def test_relationship_validation_invalid_confidence(self):
        """Test validation with invalid confidence score."""
        with pytest.raises(ValueError, match="Confidence must be between 0 and 1"):
            rel = Relationship(
                source_id="asset-001",
                target_id="asset-002",
                relationship_type="depends_on"
            )
            rel.confidence = 1.5
            rel.validate()
    
    def test_is_inverse_of(self):
        """Test checking if relationships are inverses."""
        rel1 = Relationship(
            source_id="asset-001",
            target_id="asset-002",
            relationship_type="depends_on"
        )
        
        rel2 = Relationship(
            source_id="asset-002",
            target_id="asset-001",
            relationship_type="used_by"
        )
        
        assert rel1.is_inverse_of(rel2) is True
        assert rel2.is_inverse_of(rel1) is True
        
        # Non-inverse relationship
        rel3 = Relationship(
            source_id="asset-003",
            target_id="asset-004",
            relationship_type="contains"
        )
        
        assert rel1.is_inverse_of(rel3) is False
    
    def test_update_confidence(self):
        """Test updating confidence score."""
        rel = Relationship(
            source_id="asset-001",
            target_id="asset-002",
            relationship_type="depends_on"
        )
        
        original_updated_at = rel.updated_at
        
        rel.update_confidence(0.8)
        assert rel.confidence == 0.8
        assert rel.updated_at > original_updated_at
        
        # Test invalid confidence
        with pytest.raises(ValueError, match="Confidence must be between 0 and 1"):
            rel.update_confidence(1.5)
    
    def test_property_management(self):
        """Test adding and removing properties."""
        rel = Relationship(
            source_id="asset-001",
            target_id="asset-002",
            relationship_type="depends_on"
        )
        
        # Add properties
        rel.add_property("latency_ms", 25)
        rel.add_property("bandwidth_mbps", 1000)
        
        assert rel.properties["latency_ms"] == 25
        assert rel.properties["bandwidth_mbps"] == 1000
        
        # Remove property
        removed = rel.remove_property("bandwidth_mbps")
        assert removed is True
        assert "bandwidth_mbps" not in rel.properties
        
        # Remove non-existent property
        removed = rel.remove_property("nonexistent")
        assert removed is False
    
    def test_get_direction(self):
        """Test getting relationship direction."""
        # Outbound relationship
        rel1 = Relationship(
            source_id="asset-001",
            target_id="asset-002",
            relationship_type="depends_on"
        )
        assert rel1.get_direction() == "outbound"
        
        # Inbound relationship
        rel2 = Relationship(
            source_id="asset-001",
            target_id="asset-002",
            relationship_type="used_by"
        )
        assert rel2.get_direction() == "inbound"
        
        # Bidirectional relationship
        rel3 = Relationship(
            source_id="asset-001",
            target_id="asset-002",
            relationship_type="connects_to"
        )
        assert rel3.get_direction() == "bidirectional"
    
    def test_to_dict(self):
        """Test converting relationship to dictionary."""
        rel = Relationship(
            source_id="asset-001",
            target_id="asset-002",
            relationship_type="depends_on"
        )
        rel.properties = {"key": "value"}
        rel.confidence = 0.9
        
        data = rel.to_dict()
        
        assert data["source_id"] == "asset-001"
        assert data["target_id"] == "asset-002"
        assert data["relationship_type"] == "depends_on"
        assert data["properties"] == {"key": "value"}
        assert data["confidence"] == 0.9
        assert data["direction"] == "outbound"
        assert "created_at" in data
        assert "updated_at" in data
    
    def test_from_dict(self):
        """Test creating relationship from dictionary."""
        data = {
            "relationship_id": "rel-123",
            "source_id": "asset-001",
            "target_id": "asset-002",
            "relationship_type": "contains",
            "properties": {"capacity": 100},
            "confidence": 0.95,
            "discovered_by": "auto",
            "discovery_method": "inferred",
            "created_at": "2024-01-01T10:00:00",
            "updated_at": "2024-01-01T10:00:00"
        }
        
        rel = Relationship.from_dict(data)
        
        assert rel.relationship_id == "rel-123"
        assert rel.source_id == "asset-001"
        assert rel.target_id == "asset-002"
        assert rel.relationship_type == "contains"
        assert rel.properties == {"capacity": 100}
        assert rel.confidence == 0.95
        assert rel.discovered_by == "auto"
        assert isinstance(rel.created_at, datetime)
    
    def test_equality_and_hash(self):
        """Test relationship equality and hashing."""
        rel1 = Relationship(
            source_id="asset-001",
            target_id="asset-002",
            relationship_type="depends_on"
        )
        
        rel2 = Relationship(
            source_id="asset-001",
            target_id="asset-002",
            relationship_type="depends_on"
        )
        
        rel3 = Relationship(
            source_id="asset-001",
            target_id="asset-003",
            relationship_type="depends_on"
        )
        
        # Test equality
        assert rel1 == rel2
        assert rel1 != rel3
        
        # Test hash
        assert hash(rel1) == hash(rel2)
        assert hash(rel1) != hash(rel3)
        
        # Test in set
        rel_set = {rel1, rel2, rel3}
        assert len(rel_set) == 2  # rel1 and rel2 are considered the same
