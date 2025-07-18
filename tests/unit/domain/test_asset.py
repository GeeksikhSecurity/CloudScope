"""Unit tests for Asset domain model."""

import pytest
from datetime import datetime, timedelta

from src.domain.models.asset import Asset
from src.domain.models.relationship import Relationship


class TestAsset:
    """Test cases for Asset model."""
    
    def test_asset_creation(self):
        """Test basic asset creation."""
        asset = Asset(
            asset_id="test-001",
            asset_type="compute",
            provider="aws",
            name="Test Instance"
        )
        
        assert asset.asset_id == "test-001"
        assert asset.asset_type == "compute"
        assert asset.provider == "aws"
        assert asset.name == "Test Instance"
        assert asset.status == "active"
        assert asset.health == "healthy"
        assert asset.risk_score == 0.0
        assert isinstance(asset.created_at, datetime)
    
    def test_asset_auto_id_generation(self):
        """Test automatic ID generation when not provided."""
        asset = Asset(
            asset_id="",
            asset_type="storage",
            provider="azure",
            name="Test Storage"
        )
        
        assert asset.asset_id.startswith("azure-storage-")
        assert len(asset.asset_id) > 15
    
    def test_asset_validation_success(self):
        """Test successful asset validation."""
        asset = Asset(
            asset_id="test-002",
            asset_type="network",
            provider="gcp",
            name="Test Network"
        )
        
        # Should not raise any exception
        assert asset.validate() is True
    
    def test_asset_validation_invalid_type(self):
        """Test asset validation with invalid type."""
        with pytest.raises(ValueError, match="Invalid asset type"):
            Asset(
                asset_id="test-003",
                asset_type="invalid_type",
                provider="aws",
                name="Test"
            )
    
    def test_asset_validation_invalid_provider(self):
        """Test asset validation with invalid provider."""
        with pytest.raises(ValueError, match="Invalid provider"):
            Asset(
                asset_id="test-004",
                asset_type="compute",
                provider="invalid_provider",
                name="Test"
            )
    
    def test_asset_validation_missing_name(self):
        """Test asset validation with missing name."""
        with pytest.raises(ValueError, match="Asset name is required"):
            Asset(
                asset_id="test-005",
                asset_type="compute",
                provider="aws",
                name=""
            )
    
    def test_add_relationship(self):
        """Test adding relationships to asset."""
        asset = Asset(
            asset_id="test-006",
            asset_type="compute",
            provider="aws",
            name="Test Instance"
        )
        
        rel = Relationship(
            source_id="test-006",
            target_id="test-007",
            relationship_type="depends_on"
        )
        
        asset.add_relationship(rel)
        assert len(asset.relationships) == 1
        assert asset.relationships[0] == rel
    
    def test_add_relationship_not_involving_asset(self):
        """Test adding relationship that doesn't involve the asset."""
        asset = Asset(
            asset_id="test-008",
            asset_type="compute",
            provider="aws",
            name="Test Instance"
        )
        
        rel = Relationship(
            source_id="other-001",
            target_id="other-002",
            relationship_type="depends_on"
        )
        
        with pytest.raises(ValueError, match="Relationship must involve this asset"):
            asset.add_relationship(rel)
    
    def test_remove_relationship(self):
        """Test removing relationships from asset."""
        asset = Asset(
            asset_id="test-009",
            asset_type="compute",
            provider="aws",
            name="Test Instance"
        )
        
        rel = Relationship(
            source_id="test-009",
            target_id="test-010",
            relationship_type="depends_on"
        )
        
        asset.add_relationship(rel)
        assert len(asset.relationships) == 1
        
        removed = asset.remove_relationship(rel.relationship_id)
        assert removed is True
        assert len(asset.relationships) == 0
    
    def test_update_properties(self):
        """Test updating asset properties."""
        asset = Asset(
            asset_id="test-011",
            asset_type="compute",
            provider="aws",
            name="Test Instance"
        )
        
        original_updated_at = asset.updated_at
        
        asset.update_properties({
            "instance_type": "t2.micro",
            "region": "us-east-1"
        })
        
        assert asset.properties["instance_type"] == "t2.micro"
        assert asset.properties["region"] == "us-east-1"
        assert asset.updated_at > original_updated_at
    
    def test_tag_management(self):
        """Test adding and removing tags."""
        asset = Asset(
            asset_id="test-012",
            asset_type="compute",
            provider="aws",
            name="Test Instance"
        )
        
        # Add tags
        asset.add_tag("environment", "production")
        asset.add_tag("team", "devops")
        
        assert asset.tags["environment"] == "production"
        assert asset.tags["team"] == "devops"
        
        # Remove tag
        removed = asset.remove_tag("team")
        assert removed is True
        assert "team" not in asset.tags
        
        # Remove non-existent tag
        removed = asset.remove_tag("nonexistent")
        assert removed is False
    
    def test_calculate_risk_score(self):
        """Test risk score calculation."""
        # New asset with no issues
        asset1 = Asset(
            asset_id="test-013",
            asset_type="compute",
            provider="aws",
            name="New Instance"
        )
        asset1.tags = {"environment": "dev"}
        score1 = asset1.calculate_risk_score()
        assert score1 == 0.0
        
        # Old asset with issues
        asset2 = Asset(
            asset_id="test-014",
            asset_type="compute",
            provider="aws",
            name="Old Instance"
        )
        asset2.created_at = datetime.utcnow() - timedelta(days=400)
        asset2.compliance_status = "non_compliant"
        asset2.health = "unhealthy"
        
        score2 = asset2.calculate_risk_score()
        assert score2 > 50  # Should have high risk score
    
    def test_to_dict(self):
        """Test converting asset to dictionary."""
        asset = Asset(
            asset_id="test-015",
            asset_type="compute",
            provider="aws",
            name="Test Instance"
        )
        asset.tags = {"env": "prod"}
        asset.properties = {"size": "large"}
        
        data = asset.to_dict()
        
        assert data["asset_id"] == "test-015"
        assert data["asset_type"] == "compute"
        assert data["provider"] == "aws"
        assert data["name"] == "Test Instance"
        assert data["tags"] == {"env": "prod"}
        assert data["properties"] == {"size": "large"}
        assert "created_at" in data
        assert "updated_at" in data
    
    def test_from_dict(self):
        """Test creating asset from dictionary."""
        data = {
            "asset_id": "test-016",
            "asset_type": "storage",
            "provider": "azure",
            "name": "Test Storage",
            "tags": {"env": "staging"},
            "properties": {"size_gb": 100},
            "status": "active",
            "health": "healthy",
            "compliance_status": "compliant",
            "risk_score": 15.5,
            "estimated_cost": 25.0,
            "created_at": "2024-01-01T10:00:00",
            "updated_at": "2024-01-01T10:00:00",
            "discovered_at": "2024-01-01T10:00:00"
        }
        
        asset = Asset.from_dict(data)
        
        assert asset.asset_id == "test-016"
        assert asset.asset_type == "storage"
        assert asset.provider == "azure"
        assert asset.name == "Test Storage"
        assert asset.tags == {"env": "staging"}
        assert asset.properties == {"size_gb": 100}
        assert asset.risk_score == 15.5
        assert isinstance(asset.created_at, datetime)
