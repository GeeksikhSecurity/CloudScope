"""
Compliance domain model for managing compliance requirements and assessments.
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
    BASIC = "BASIC"
    STANDARD = "STANDARD"
    ADVANCED = "ADVANCED"
    ASVS_L1 = "ASVS_L1"
    ASVS_L2 = "ASVS_L2"
    ASVS_L3 = "ASVS_L3"


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
    id: str
    framework: ComplianceFramework
    category: ControlCategory
    title: str
    description: str
    level: ComplianceLevel
    automated: bool = False
    enabled: bool = True
    tags: List[str] = field(default_factory=list)
    references: List[str] = field(default_factory=list)


@dataclass
class ComplianceAssessment:
    """Results of a compliance assessment for an asset."""
    id: str
    asset_id: str
    framework: ComplianceFramework
    level: ComplianceLevel
    assessed_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))
    assessed_by: Optional[str] = None
    
    total_controls: int = 0
    passed_controls: int = 0
    failed_controls: int = 0
    not_applicable_controls: int = 0
    
    control_results: Dict[str, Dict[str, Any]] = field(default_factory=dict)
    findings: List[str] = field(default_factory=list)
    
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
