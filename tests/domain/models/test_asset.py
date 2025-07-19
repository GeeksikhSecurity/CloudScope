#!/usr/bin/env python3
"""
Tests for the Asset domain model.
"""
import unittest
from datetime import datetime
from uuid import UUID

import pytest

from cloudscope.domain.models.asset import Asset, AssetValidationError


class TestAsset(unittest.TestCase):
    """Test cases for the Asset domain model."""

    def test_asset_creation(self):
        """Test creating an Asset with valid parameters."""
        # Arrange
        asset_id = "test-id"
        name = "Test Asset"
        asset_type = "server"
        source = "test-source"

        # Act
        asset = Asset(id=asset_id, name=name, asset_type=asset_type, source=source)

        # Assert
        self.assertEqual(asset.id, asset_id)
        self.assertEqual(asset.name, name)
        self.assertEqual(asset.asset_type, asset_type)
        self.assertEqual(asset.source, source)
        self.assertIsInstance(asset.metadata, dict)
        self.assertIsInstance(asset.tags, dict)
        self.assertEqual(asset.risk_score, 0)
        self.assertIsInstance(asset.created_at, datetime)
        self.assertIsInstance(asset.updated_at, datetime)

    def test_asset_creation_with_uuid(self):
        """Test creating an Asset with a UUID as ID."""
        # Arrange
        import uuid
        asset_id = uuid.uuid4()
        name = "Test Asset"
        asset_type = "server"
        source = "test-source"

        # Act
        asset = Asset(id=str(asset_id), name=name, asset_type=asset_type, source=source)

        # Assert
        self.assertEqual(asset.id, str(asset_id))

    def test_asset_creation_with_empty_id(self):
        """Test creating an Asset with an empty ID generates a UUID."""
        # Arrange
        name = "Test Asset"
        asset_type = "server"
        source = "test-source"

        # Act
        asset = Asset(id=None, name=name, asset_type=asset_type, source=source)

        # Assert
        try:
            UUID(asset.id)
            is_valid_uuid = True
        except ValueError:
            is_valid_uuid = False
        self.assertTrue(is_valid_uuid)

    def test_asset_creation_with_invalid_parameters(self):
        """Test creating an Asset with invalid parameters raises an error."""
        # Test with empty name
        with pytest.raises(AssetValidationError):
            Asset(id="test-id", name="", asset_type="server", source="test-source")

        # Test with empty asset_type
        with pytest.raises(AssetValidationError):
            Asset(id="test-id", name="Test Asset", asset_type="", source="test-source")

        # Test with empty source
        with pytest.raises(AssetValidationError):
            Asset(id="test-id", name="Test Asset", asset_type="server", source="")

    def test_add_metadata(self):
        """Test adding metadata to an Asset."""
        # Arrange
        asset = Asset(id="test-id", name="Test Asset", asset_type="server", source="test-source")
        key = "region"
        value = "us-west-2"

        # Act
        asset.add_metadata(key, value)

        # Assert
        self.assertEqual(asset.metadata[key], value)
        self.assertNotEqual(asset.updated_at, asset.created_at)

    def test_add_tag(self):
        """Test adding a tag to an Asset."""
        # Arrange
        asset = Asset(id="test-id", name="Test Asset", asset_type="server", source="test-source")
        key = "environment"
        value = "production"

        # Act
        asset.add_tag(key, value)

        # Assert
        self.assertEqual(asset.tags[key], value)
        self.assertNotEqual(asset.updated_at, asset.created_at)

    def test_set_risk_score(self):
        """Test setting the risk score of an Asset."""
        # Arrange
        asset = Asset(id="test-id", name="Test Asset", asset_type="server", source="test-source")
        risk_score = 75

        # Act
        asset.set_risk_score(risk_score)

        # Assert
        self.assertEqual(asset.risk_score, risk_score)
        self.assertNotEqual(asset.updated_at, asset.created_at)

    def test_set_invalid_risk_score(self):
        """Test setting an invalid risk score raises an error."""
        # Arrange
        asset = Asset(id="test-id", name="Test Asset", asset_type="server", source="test-source")

        # Act & Assert
        with pytest.raises(AssetValidationError):
            asset.set_risk_score(-1)

        with pytest.raises(AssetValidationError):
            asset.set_risk_score(101)

    def test_to_dict(self):
        """Test converting an Asset to a dictionary."""
        # Arrange
        asset = Asset(id="test-id", name="Test Asset", asset_type="server", source="test-source")
        asset.add_metadata("region", "us-west-2")
        asset.add_tag("environment", "production")
        asset.set_risk_score(75)

        # Act
        asset_dict = asset.to_dict()

        # Assert
        self.assertEqual(asset_dict["id"], asset.id)
        self.assertEqual(asset_dict["name"], asset.name)
        self.assertEqual(asset_dict["asset_type"], asset.asset_type)
        self.assertEqual(asset_dict["source"], asset.source)
        self.assertEqual(asset_dict["metadata"]["region"], "us-west-2")
        self.assertEqual(asset_dict["tags"]["environment"], "production")
        self.assertEqual(asset_dict["risk_score"], 75)
        self.assertIn("created_at", asset_dict)
        self.assertIn("updated_at", asset_dict)

    def test_from_dict(self):
        """Test creating an Asset from a dictionary."""
        # Arrange
        asset_dict = {
            "id": "test-id",
            "name": "Test Asset",
            "asset_type": "server",
            "source": "test-source",
            "metadata": {"region": "us-west-2"},
            "tags": {"environment": "production"},
            "risk_score": 75,
            "created_at": datetime.now().isoformat(),
            "updated_at": datetime.now().isoformat()
        }

        # Act
        asset = Asset.from_dict(asset_dict)

        # Assert
        self.assertEqual(asset.id, asset_dict["id"])
        self.assertEqual(asset.name, asset_dict["name"])
        self.assertEqual(asset.asset_type, asset_dict["asset_type"])
        self.assertEqual(asset.source, asset_dict["source"])
        self.assertEqual(asset.metadata["region"], asset_dict["metadata"]["region"])
        self.assertEqual(asset.tags["environment"], asset_dict["tags"]["environment"])
        self.assertEqual(asset.risk_score, asset_dict["risk_score"])


if __name__ == "__main__":
    unittest.main()