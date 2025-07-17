#!/bin/bash
# Next steps for CloudScope compliance implementation

echo "=== CloudScope Compliance Implementation - Next Steps ==="
echo ""

# 1. First, let's check Python command
echo "Checking Python installation..."
if command -v python3 &> /dev/null; then
    echo "✅ Found python3"
    PYTHON_CMD="python3"
elif command -v python &> /dev/null; then
    echo "✅ Found python"
    PYTHON_CMD="python"
else
    echo "❌ Python not found! Please install Python 3.8+"
    exit 1
fi

# 2. Update the gap analyzer to use correct Python command
echo ""
echo "Updating compliance_gap_analyzer.py shebang..."
sed -i '' '1s/.*/#!\/usr\/bin\/env python3/' compliance_gap_analyzer.py 2>/dev/null || \
sed -i '1s/.*/#!\/usr\/bin\/env python3/' compliance_gap_analyzer.py

# 3. Commit the gap analyzer and related files
echo ""
echo "=== Committing Gap Analyzer Files ==="
git add compliance_gap_analyzer.py
git add compliance_implementation_checklist.md
git add save_gap_analyzer.sh
git commit -m "feat: Add compliance gap analyzer and implementation checklist

- Add Python script to analyze compliance gaps
- Generate implementation checklist with 29 identified gaps
- Prioritize implementation tasks across 6 categories
- Include bash script for easy setup"

# 4. Show current status
echo ""
echo "=== Current Status ==="
git status --short
echo ""
git log --oneline -3

# 5. Create Priority 1 directories
echo ""
echo "=== Creating Priority 1 Compliance Directories ==="
mkdir -p cloudscope/ports/compliance
mkdir -p tests/domain/services
mkdir -p tests/adapters/compliance

# 6. Start implementing the first compliance model
echo ""
echo "=== Starting Priority 1 Implementation ==="
echo "Creating Finding model (Priority 1, Item 1)..."

cat > cloudscope/domain/models/finding.py << 'EOF'
"""
Finding model for compliance violations and security issues.
Part of CloudScope's compliance-as-code implementation.
"""
from dataclasses import dataclass, field
from datetime import datetime
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
        self.resolved_at = datetime.utcnow()
        self.resolved_by = resolved_by
        self.resolution_notes = resolution_notes
        
    def accept_risk(self, accepted_by: str, justification: str):
        """Accept the risk associated with this finding."""
        self.status = FindingStatus.ACCEPTED
        self.resolved_at = datetime.utcnow()
        self.resolved_by = accepted_by
        self.resolution_notes = f"Risk accepted: {justification}"
        
    def mark_false_positive(self, marked_by: str, reason: str):
        """Mark the finding as a false positive."""
        self.status = FindingStatus.FALSE_POSITIVE
        self.resolved_at = datetime.utcnow()
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
EOF

echo "✅ Created cloudscope/domain/models/finding.py"

# 7. Create the test for Finding model
echo ""
echo "Creating test for Finding model..."

cat > tests/domain/models/test_finding.py << 'EOF'
"""
Tests for the Finding domain model.
"""
import pytest
from datetime import datetime, timedelta
from cloudscope.domain.models.finding import Finding, Severity, FindingStatus


class TestFinding:
    """Test cases for the Finding model."""
    
    def test_finding_creation(self):
        """Test creating a finding with required fields."""
        finding = Finding(
            asset_id="asset-123",
            title="SQL Injection Vulnerability",
            description="User input not properly sanitized in login form",
            severity=Severity.CRITICAL,
            framework="OWASP_ASVS",
            control_id="V5.3.3"
        )
        
        assert finding.asset_id == "asset-123"
        assert finding.title == "SQL Injection Vulnerability"
        assert finding.severity == Severity.CRITICAL
        assert finding.status == FindingStatus.OPEN
        assert finding.framework == "OWASP_ASVS"
        assert finding.control_id == "V5.3.3"
        assert finding.id  # Auto-generated UUID
        assert isinstance(finding.discovered_at, datetime)
        
    def test_finding_creation_with_optional_fields(self):
        """Test creating a finding with optional fields."""
        evidence = {"screenshot": "sqli_evidence.png", "request": "POST /login"}
        tags = ["web", "authentication", "high-priority"]
        
        finding = Finding(
            asset_id="asset-123",
            title="SQL Injection",
            description="Critical vulnerability",
            severity=Severity.CRITICAL,
            framework="OWASP_ASVS",
            control_id="V5.3.3",
            evidence=evidence,
            remediation="Use parameterized queries",
            tags=tags,
            assignee="security-team"
        )
        
        assert finding.evidence == evidence
        assert finding.remediation == "Use parameterized queries"
        assert finding.tags == tags
        assert finding.assignee == "security-team"
        
    def test_finding_validation(self):
        """Test that required fields are validated."""
        with pytest.raises(ValueError, match="asset_id is required"):
            Finding(
                asset_id="",
                title="Test",
                description="Test",
                severity=Severity.LOW,
                framework="OWASP_ASVS",
                control_id="V1.1.1"
            )
            
        with pytest.raises(ValueError, match="title is required"):
            Finding(
                asset_id="asset-123",
                title="",
                description="Test",
                severity=Severity.LOW,
                framework="OWASP_ASVS",
                control_id="V1.1.1"
            )
            
    def test_severity_to_risk_score(self):
        """Test severity to risk score conversion."""
        assert Severity.CRITICAL.to_risk_score() == 100
        assert Severity.HIGH.to_risk_score() == 80
        assert Severity.MEDIUM.to_risk_score() == 60
        assert Severity.LOW.to_risk_score() == 30
        assert Severity.INFO.to_risk_score() == 10
        
    def test_resolve_finding(self):
        """Test resolving a finding."""
        finding = Finding(
            asset_id="asset-123",
            title="Test Finding",
            description="Test",
            severity=Severity.HIGH,
            framework="SOC2",
            control_id="CC6.1"
        )
        
        assert finding.status == FindingStatus.OPEN
        assert finding.resolved_at is None
        
        finding.resolve("john.doe", "Applied security patch v1.2.3")
        
        assert finding.status == FindingStatus.RESOLVED
        assert finding.resolved_by == "john.doe"
        assert finding.resolution_notes == "Applied security patch v1.2.3"
        assert isinstance(finding.resolved_at, datetime)
        
    def test_cannot_resolve_already_resolved_finding(self):
        """Test that resolved findings cannot be resolved again."""
        finding = Finding(
            asset_id="asset-123",
            title="Test",
            description="Test",
            severity=Severity.LOW,
            framework="ISO27001",
            control_id="A.12.1"
        )
        
        finding.resolve("user1", "Fixed")
        
        with pytest.raises(ValueError, match="Finding is already resolved"):
            finding.resolve("user2", "Fixed again")
            
    def test_accept_risk(self):
        """Test accepting risk for a finding."""
        finding = Finding(
            asset_id="asset-123",
            title="Legacy System Vulnerability",
            description="Old system with known vulnerabilities",
            severity=Severity.MEDIUM,
            framework="OWASP_ASVS",
            control_id="V1.2.3"
        )
        
        finding.accept_risk("ciso", "System scheduled for decommission in 30 days")
        
        assert finding.status == FindingStatus.ACCEPTED
        assert finding.resolved_by == "ciso"
        assert "Risk accepted" in finding.resolution_notes
        assert "decommission in 30 days" in finding.resolution_notes
        
    def test_mark_false_positive(self):
        """Test marking a finding as false positive."""
        finding = Finding(
            asset_id="asset-123",
            title="Potential XSS",
            description="Scanner detected possible XSS",
            severity=Severity.HIGH,
            framework="OWASP_ASVS",
            control_id="V5.1.1"
        )
        
        finding.mark_false_positive("security-analyst", "Input is already sanitized by WAF")
        
        assert finding.status == FindingStatus.FALSE_POSITIVE
        assert finding.resolved_by == "security-analyst"
        assert "False positive" in finding.resolution_notes
        assert "already sanitized by WAF" in finding.resolution_notes
        
    def test_to_dict(self):
        """Test converting finding to dictionary."""
        finding = Finding(
            asset_id="asset-123",
            title="Test Finding",
            description="Test description",
            severity=Severity.HIGH,
            framework="SOC2",
            control_id="CC7.2",
            tags=["test", "compliance"],
            evidence={"key": "value"}
        )
        
        finding_dict = finding.to_dict()
        
        assert finding_dict["asset_id"] == "asset-123"
        assert finding_dict["title"] == "Test Finding"
        assert finding_dict["severity"] == "HIGH"
        assert finding_dict["status"] == "OPEN"
        assert finding_dict["framework"] == "SOC2"
        assert finding_dict["risk_score"] == 80
        assert finding_dict["tags"] == ["test", "compliance"]
        assert finding_dict["evidence"] == {"key": "value"}
        
    def test_from_dict(self):
        """Test creating finding from dictionary."""
        data = {
            "id": "finding-123",
            "asset_id": "asset-456",
            "title": "Test Finding",
            "description": "Test description",
            "severity": "MEDIUM",
            "status": "IN_PROGRESS",
            "framework": "ISO27001",
            "control_id": "A.9.1.2",
            "discovered_at": datetime.utcnow().isoformat(),
            "tags": ["iso", "access-control"],
            "risk_score": 60  # This should be ignored
        }
        
        finding = Finding.from_dict(data)
        
        assert finding.id == "finding-123"
        assert finding.asset_id == "asset-456"
        assert finding.severity == Severity.MEDIUM
        assert finding.status == FindingStatus.IN_PROGRESS
        assert finding.framework == "ISO27001"
        assert finding.tags == ["iso", "access-control"]
        
    def test_round_trip_serialization(self):
        """Test that to_dict and from_dict are symmetric."""
        original = Finding(
            asset_id="asset-789",
            title="Round Trip Test",
            description="Testing serialization",
            severity=Severity.LOW,
            framework="OWASP_ASVS",
            control_id="V13.1.1",
            due_date=datetime.utcnow() + timedelta(days=30),
            assignee="team-lead"
        )
        
        # Convert to dict and back
        finding_dict = original.to_dict()
        restored = Finding.from_dict(finding_dict)
        
        assert restored.id == original.id
        assert restored.asset_id == original.asset_id
        assert restored.title == original.title
        assert restored.severity == original.severity
        assert restored.assignee == original.assignee
        # Due date might have microsecond differences due to ISO format
        assert restored.due_date.date() == original.due_date.date()
EOF

echo "✅ Created tests/domain/models/test_finding.py"

# 8. Run the test to verify implementation
echo ""
echo "=== Running Finding Model Tests ==="
$PYTHON_CMD -m pytest tests/domain/models/test_finding.py -v

echo ""
echo "=== Summary ==="
echo "✅ Committed gap analyzer and checklist"
echo "✅ Created Finding model (Priority 1, Item 1)"
echo "✅ Created comprehensive tests for Finding model"
echo ""
echo "=== Next Priority 1 Items ==="
echo "1. Create cloudscope/domain/models/compliance.py"
echo "2. Create cloudscope/ports/compliance/__init__.py"
echo "3. Create cloudscope/ports/compliance/compliance_checker.py"
echo ""
echo "Run this to continue:"
echo "$PYTHON_CMD create_compliance_model.py"