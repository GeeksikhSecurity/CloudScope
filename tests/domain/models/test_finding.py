"""
Tests for the Finding domain model.
"""
import pytest
from datetime import datetime, timedelta, timezone, timezone
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
            "discovered_at": datetime.now(timezone.utc).isoformat(),
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
            due_date=datetime.now(timezone.utc) + timedelta(days=30),
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
