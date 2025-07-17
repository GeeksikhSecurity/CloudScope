"""
Finding model for compliance violations and security issues.
Part of CloudScope's compliance-as-code implementation.
"""
from dataclasses import dataclass, field
from datetime import datetime, timezone, timezone
from typing import Optional, Dict, Any
from enum import Enum
import uuid


class Severity(Enum):
    """Severity levels for compliance findings."""
    CRITICAL = "CRITICAL"
    HIGH = "HIGH"
    MEDIUM = "MEDIUM"
    LOW = "LOW"
    INFO = "INFO"

    def to_risk_score(self) -> int:
        """Convert severity to risk score (0-100)."""
        mapping = {
            self.CRITICAL: 100,
            self.HIGH: 80,
            self.MEDIUM: 60,
            self.LOW: 30,
            self.INFO: 10
        }
        return mapping[self]


class FindingStatus(Enum):
    """Status of a compliance finding."""
    OPEN = "OPEN"
    IN_PROGRESS = "IN_PROGRESS"
    RESOLVED = "RESOLVED"
    ACCEPTED = "ACCEPTED"  # Risk accepted
    FALSE_POSITIVE = "FALSE_POSITIVE"


@dataclass
class Finding:
    """
    Represents a compliance or security finding.
    
    This model captures violations of compliance frameworks (OWASP ASVS, SOC2, etc.)
    and tracks their lifecycle from discovery to resolution.
    """
    # Required fields
    asset_id: str
    title: str
    description: str
    severity: Severity
    framework: str  # "OWASP_ASVS", "SOC2", "ISO27001", etc.
    control_id: str  # "V1.1.1", "CC6.1", etc.
    
    # Auto-generated fields
    id: str = field(default_factory=lambda: str(uuid.uuid4()))
    status: FindingStatus = field(default=FindingStatus.OPEN)
    discovered_at: datetime = field(default_factory=datetime.utcnow)
    
    # Optional fields
    evidence: Dict[str, Any] = field(default_factory=dict)
    remediation: Optional[str] = None
    resolved_at: Optional[datetime] = None
    resolved_by: Optional[str] = None
    resolution_notes: Optional[str] = None
    due_date: Optional[datetime] = None
    assignee: Optional[str] = None
    
    # Metadata
    tags: list[str] = field(default_factory=list)
    references: list[str] = field(default_factory=list)  # URLs, ticket IDs, etc.
    
    def __post_init__(self):
        """Validate finding after initialization."""
        if not self.asset_id:
            raise ValueError("asset_id is required")
        if not self.title:
            raise ValueError("title is required")
        if not self.description:
            raise ValueError("description is required")
        if not self.framework:
            raise ValueError("framework is required")
        if not self.control_id:
            raise ValueError("control_id is required")
            
    def resolve(self, resolved_by: str, resolution_notes: str = ""):
        """Mark the finding as resolved."""
        if self.status == FindingStatus.RESOLVED:
            raise ValueError("Finding is already resolved")
            
        self.status = FindingStatus.RESOLVED
        self.resolved_at = datetime.now(timezone.utc)
        self.resolved_by = resolved_by
        self.resolution_notes = resolution_notes
        
    def accept_risk(self, accepted_by: str, justification: str):
        """Accept the risk associated with this finding."""
        self.status = FindingStatus.ACCEPTED
        self.resolved_at = datetime.now(timezone.utc)
        self.resolved_by = accepted_by
        self.resolution_notes = f"Risk accepted: {justification}"
        
    def mark_false_positive(self, marked_by: str, reason: str):
        """Mark the finding as a false positive."""
        self.status = FindingStatus.FALSE_POSITIVE
        self.resolved_at = datetime.now(timezone.utc)
        self.resolved_by = marked_by
        self.resolution_notes = f"False positive: {reason}"
        
    def to_dict(self) -> Dict[str, Any]:
        """Convert finding to dictionary for serialization."""
        return {
            "id": self.id,
            "asset_id": self.asset_id,
            "title": self.title,
            "description": self.description,
            "severity": self.severity.value,
            "status": self.status.value,
            "framework": self.framework,
            "control_id": self.control_id,
            "discovered_at": self.discovered_at.isoformat(),
            "resolved_at": self.resolved_at.isoformat() if self.resolved_at else None,
            "resolved_by": self.resolved_by,
            "resolution_notes": self.resolution_notes,
            "due_date": self.due_date.isoformat() if self.due_date else None,
            "assignee": self.assignee,
            "evidence": self.evidence,
            "remediation": self.remediation,
            "tags": self.tags,
            "references": self.references,
            "risk_score": self.severity.to_risk_score()
        }
        
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "Finding":
        """Create a Finding from a dictionary."""
        # Convert string values back to enums
        if isinstance(data.get("severity"), str):
            data["severity"] = Severity(data["severity"])
        if isinstance(data.get("status"), str):
            data["status"] = FindingStatus(data["status"])
            
        # Convert ISO format strings back to datetime
        if data.get("discovered_at") and isinstance(data["discovered_at"], str):
            data["discovered_at"] = datetime.fromisoformat(data["discovered_at"])
        if data.get("resolved_at") and isinstance(data["resolved_at"], str):
            data["resolved_at"] = datetime.fromisoformat(data["resolved_at"])
        if data.get("due_date") and isinstance(data["due_date"], str):
            data["due_date"] = datetime.fromisoformat(data["due_date"])
            
        # Remove any extra fields not in the dataclass
        valid_fields = {
            "id", "asset_id", "title", "description", "severity", "status",
            "framework", "control_id", "discovered_at", "resolved_at",
            "resolved_by", "resolution_notes", "due_date", "assignee",
            "evidence", "remediation", "tags", "references"
        }
        
        filtered_data = {k: v for k, v in data.items() if k in valid_fields}
        return cls(**filtered_data)
