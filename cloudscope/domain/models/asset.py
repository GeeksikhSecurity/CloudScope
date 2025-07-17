#!/usr/bin/env python3
"""
Asset domain model for CloudScope.

This module defines the Asset class, which represents any entity that CloudScope tracks.
Assets can be servers, databases, applications, users, or any other entity that needs to be
tracked in the inventory.
"""
import uuid
from datetime import datetime
from typing import Any, Dict, Optional


class AssetValidationError(Exception):
    """Exception raised for validation errors in the Asset class."""

    pass


class Asset:
    """
    Asset domain model.

    Represents any entity that CloudScope tracks. Assets can be servers, databases,
    applications, users, or any other entity that needs to be tracked in the inventory.

    Attributes:
        id: Unique identifier for the asset
        name: Human-readable name of the asset
        asset_type: Type of asset (e.g., server, database, application)
        source: Source of the asset data (e.g., aws_collector, azure_collector)
        metadata: Additional metadata about the asset
        tags: Key-value pairs for categorizing the asset
        risk_score: Risk score of the asset (0-100)
        created_at: Timestamp when the asset was created
        updated_at: Timestamp when the asset was last updated
    """

    def __init__(
        self,
        id: Optional[str],
        name: str,
        asset_type: str,
        source: str,
        metadata: Optional[Dict[str, Any]] = None,
        tags: Optional[Dict[str, str]] = None,
        risk_score: int = 0,
        created_at: Optional[datetime] = None,
        updated_at: Optional[datetime] = None,
    ):
        """
        Initialize an Asset.

        Args:
            id: Unique identifier for the asset. If None, a UUID will be generated.
            name: Human-readable name of the asset
            asset_type: Type of asset (e.g., server, database, application)
            source: Source of the asset data (e.g., aws_collector, azure_collector)
            metadata: Additional metadata about the asset
            tags: Key-value pairs for categorizing the asset
            risk_score: Risk score of the asset (0-100)
            created_at: Timestamp when the asset was created
            updated_at: Timestamp when the asset was last updated

        Raises:
            AssetValidationError: If any of the required parameters are invalid
        """
        # Validate required parameters
        if not name:
            raise AssetValidationError("Asset name cannot be empty")
        if not asset_type:
            raise AssetValidationError("Asset type cannot be empty")
        if not source:
            raise AssetValidationError("Asset source cannot be empty")

        # Set attributes
        self.id = id if id is not None else str(uuid.uuid4())
        self.name = name
        self.asset_type = asset_type
        self.source = source
        self.metadata = metadata or {}
        self.tags = tags or {}
        self.risk_score = risk_score
        self.created_at = created_at or datetime.now()
        self.updated_at = updated_at or self.created_at

    def add_metadata(self, key: str, value: Any) -> None:
        """
        Add metadata to the asset.

        Args:
            key: Metadata key
            value: Metadata value
        """
        self.metadata[key] = value
        self.updated_at = datetime.now()

    def add_tag(self, key: str, value: str) -> None:
        """
        Add a tag to the asset.

        Args:
            key: Tag key
            value: Tag value
        """
        self.tags[key] = value
        self.updated_at = datetime.now()

    def set_risk_score(self, score: int) -> None:
        """
        Set the risk score of the asset.

        Args:
            score: Risk score (0-100)

        Raises:
            AssetValidationError: If the score is not between 0 and 100
        """
        if not 0 <= score <= 100:
            raise AssetValidationError("Risk score must be between 0 and 100")
        self.risk_score = score
        self.updated_at = datetime.now()

    def to_dict(self) -> Dict[str, Any]:
        """
        Convert the asset to a dictionary.

        Returns:
            Dictionary representation of the asset
        """
        return {
            "id": self.id,
            "name": self.name,
            "asset_type": self.asset_type,
            "source": self.source,
            "metadata": self.metadata,
            "tags": self.tags,
            "risk_score": self.risk_score,
            "created_at": self.created_at.isoformat(),
            "updated_at": self.updated_at.isoformat(),
        }

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "Asset":
        """
        Create an Asset from a dictionary.

        Args:
            data: Dictionary containing asset data

        Returns:
            Asset instance
        """
        # Convert ISO format strings to datetime objects
        created_at = (
            datetime.fromisoformat(data["created_at"])
            if isinstance(data.get("created_at"), str)
            else data.get("created_at")
        )
        updated_at = (
            datetime.fromisoformat(data["updated_at"])
            if isinstance(data.get("updated_at"), str)
            else data.get("updated_at")
        )

        return cls(
            id=data.get("id"),
            name=data["name"],
            asset_type=data["asset_type"],
            source=data["source"],
            metadata=data.get("metadata", {}),
            tags=data.get("tags", {}),
            risk_score=data.get("risk_score", 0),
            created_at=created_at,
            updated_at=updated_at,
        )