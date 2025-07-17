#!/bin/bash
# Quick script to create compliance models and fix warnings

echo "=== Creating Compliance Models ==="

# First, fix the datetime deprecation warnings
echo "Fixing datetime deprecation warnings..."
sed -i '' 's/from datetime import datetime/from datetime import datetime, timezone/g' cloudscope/domain/models/finding.py
sed -i '' 's/datetime.utcnow()/datetime.now(timezone.utc)/g' cloudscope/domain/models/finding.py

sed -i '' 's/from datetime import datetime, timedelta/from datetime import datetime, timedelta, timezone/g' tests/domain/models/test_finding.py
sed -i '' 's/datetime.utcnow()/datetime.now(timezone.utc)/g' tests/domain/models/test_finding.py

# Create the compliance model
cat > cloudscope/domain/models/compliance.py << 'EOF'
"""
Compliance domain model for managing compliance requirements and assessments.
Part of CloudScope's compliance-as-code implementation.
"""
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import List, Dict, Any, Optional
from enum import Enum


class ComplianceFramework(Enum):
    """Supported compliance frameworks."""
    OWASP_ASVS = "OWASP_ASVS"
    SOC2 = "SOC2"
    ISO27001 = "ISO27001"
    PCI_DSS = "PCI_DSS"
    HIPAA = "HIPAA"
    NIST = "NIST"
    CIS = "CIS"
    CUSTOM = "CUSTOM"


class ComplianceLevel(Enum):
    """Compliance maturity levels."""
    NONE = "NONE"
    BASIC = "BASIC"  # Minimum compliance
    STANDARD = "STANDARD"  # Industry standard
    ADVANCED = "ADVANCED"  # Above standard
    
    # OWASP ASVS specific levels
    ASVS_L1 = "ASVS_L1"  # Opportunistic
    ASVS_L2 = "ASVS_L2"  # Standard
    ASVS_L3 = "ASVS_L3"  # Advanced


class ControlCategory(Enum):
    """Categories of security controls."""
    AUTHENTICATION = "AUTHENTICATION"
    AUTHORIZATION = "AUTHORIZATION"
    SESSION_MANAGEMENT = "SESSION_MANAGEMENT"
    INPUT_VALIDATION = "INPUT_VALIDATION"
    CRYPTOGRAPHY = "CRYPTOGRAPHY"
    ERROR_HANDLING = "ERROR_HANDLING"
    LOGGING = "LOGGING"
    DATA_PROTECTION = "DATA_PROTECTION"
    COMMUNICATION = "COMMUNICATION"
    CONFIGURATION = "CONFIGURATION"
    MALICIOUS_CODE = "MALICIOUS_CODE"
    BUSINESS_LOGIC = "BUSINESS_LOGIC"
    FILES_RESOURCES = "FILES_RESOURCES"
    API_WEB_SERVICE = "API_WEB_SERVICE"


@dataclass
class Control:
    """Represents a single compliance control."""
    id: str  # e.g., "V1.1.1" for OWASP ASVS, "CC6.1" for SOC2
    framework: ComplianceFramework
    category: ControlCategory
    title: str
    description: str
    level: ComplianceLevel
    automated: bool = False  # Can this control be automatically checked?
    enabled: bool = True
    tags: List[str] = field(default_factory=list)
    references: List[str] = field(default_factory=list)  # URLs to documentation
    
    def is_applicable_to_asset_type(self, asset_type: str) -> bool:
        """Check if this control applies to a given asset type."""
        # Define asset type mappings
        asset_mappings = {
            "web_application": [
                ControlCategory.AUTHENTICATION,
                ControlCategory.AUTHORIZATION,
                ControlCategory.SESSION_MANAGEMENT,
                ControlCategory.INPUT_VALIDATION,
                ControlCategory.API_WEB_SERVICE,
            ],
            "database": [
                ControlCategory.AUTHENTICATION,
                ControlCategory.AUTHORIZATION,
                ControlCategory.DATA_PROTECTION,
                ControlCategory.CRYPTOGRAPHY,
            ],
            "api": [
                ControlCategory.AUTHENTICATION,
                ControlCategory.AUTHORIZATION,
                ControlCategory.API_WEB_SERVICE,
                ControlCategory.INPUT_VALIDATION,
            ],
            "infrastructure": [
                ControlCategory.CONFIGURATION,
                ControlCategory.LOGGING,
                ControlCategory.COMMUNICATION,
            ],
        }
        
        applicable_categories = asset_mappings.get(asset_type, [])
        return self.category in applicable_categories


@dataclass
class ComplianceRequirement:
    """A specific requirement that must be met for compliance."""
    id: str
    control_id: str
    description: str
    validation_steps: List[str]
    evidence_required: List[str]  # Types of evidence needed
    automated_check: Optional[str] = None  # Name of automated check function
    manual_verification_required: bool = False
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for serialization."""
        return {
            "id": self.id,
            "control_id": self.control_id,
            "description": self.description,
            "validation_steps": self.validation_steps,
            "evidence_required": self.evidence_required,
            "automated_check": self.automated_check,
            "manual_verification_required": self.manual_verification_required,
        }


@dataclass
class ComplianceAssessment:
    """Results of a compliance assessment for an asset."""
    id: str
    asset_id: str
    framework: ComplianceFramework
    level: ComplianceLevel
    assessed_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))
    assessed_by: Optional[str] = None
    
    # Results
    total_controls: int = 0
    passed_controls: int = 0
    failed_controls: int = 0
    not_applicable_controls: int = 0
    
    # Detailed results
    control_results: Dict[str, Dict[str, Any]] = field(default_factory=dict)
    findings: List[str] = field(default_factory=list)  # Finding IDs
    
    # Metadata
    report_url: Optional[str] = None
    expires_at: Optional[datetime] = None
    notes: Optional[str] = None
    
    @property
    def compliance_score(self) -> float:
        """Calculate compliance score as percentage."""
        if self.total_controls == 0:
            return 0.0
        applicable = self.total_controls - self.not_applicable_controls
        if applicable == 0:
            return 100.0
        return (self.passed_controls / applicable) * 100
    
    @property
    def is_compliant(self) -> bool:
        """Check if assessment meets minimum compliance threshold."""
        # Define thresholds per framework/level
        thresholds = {
            ComplianceLevel.BASIC: 70.0,
            ComplianceLevel.STANDARD: 85.0,
            ComplianceLevel.ADVANCED: 95.0,
            ComplianceLevel.ASVS_L1: 80.0,
            ComplianceLevel.ASVS_L2: 90.0,
            ComplianceLevel.ASVS_L3: 95.0,
        }
        threshold = thresholds.get(self.level, 85.0)
        return self.compliance_score >= threshold
    
    def add_control_result(self, control_id: str, passed: bool, 
                          evidence: Dict[str, Any], notes: str = ""):
        """Add result for a specific control."""
        self.control_results[control_id] = {
            "passed": passed,
            "evidence": evidence,
            "notes": notes,
            "assessed_at": datetime.now(timezone.utc).isoformat(),
        }
        
        # Update counters
        if passed:
            self.passed_controls += 1
        else:
            self.failed_controls += 1
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for serialization."""
        return {
            "id": self.id,
            "asset_id": self.asset_id,
            "framework": self.framework.value,
            "level": self.level.value,
            "assessed_at": self.assessed_at.isoformat(),
            "assessed_by": self.assessed_by,
            "total_controls": self.total_controls,
            "passed_controls": self.passed_controls,
            "failed_controls": self.failed_controls,
            "not_applicable_controls": self.not_applicable_controls,
            "compliance_score": self.compliance_score,
            "is_compliant": self.is_compliant,
            "control_results": self.control_results,
            "findings": self.findings,
            "report_url": self.report_url,
            "expires_at": self.expires_at.isoformat() if self.expires_at else None,
            "notes": self.notes,
        }


@dataclass
class ComplianceReport:
    """Aggregated compliance report for multiple assets."""
    id: str
    name: str
    framework: ComplianceFramework
    level: ComplianceLevel
    generated_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))
    generated_by: Optional[str] = None
    
    # Scope
    asset_ids: List[str] = field(default_factory=list)
    assessment_ids: List[str] = field(default_factory=list)
    
    # Aggregate metrics
    total_assets: int = 0
    compliant_assets: int = 0
    non_compliant_assets: int = 0
    overall_score: float = 0.0
    
    # Findings summary
    critical_findings: int = 0
    high_findings: int = 0
    medium_findings: int = 0
    low_findings: int = 0
    
    # Control coverage
    control_coverage: Dict[str, Dict[str, Any]] = field(default_factory=dict)
    
    # Report details
    executive_summary: Optional[str] = None
    recommendations: List[str] = field(default_factory=list)