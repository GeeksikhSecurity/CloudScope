"""Compliance checker interfaces."""
from abc import ABC, abstractmethod
from typing import List, Dict, Any, Optional
from cloudscope.domain.models.asset import Asset
from cloudscope.domain.models.finding import Finding
from cloudscope.domain.models.compliance import (
    Control, ComplianceAssessment, ComplianceFramework, ComplianceLevel
)


class ComplianceChecker(ABC):
    """Base interface for all compliance checkers."""
    
    @abstractmethod
    def check_compliance(self, asset: Asset) -> List[Finding]:
        """Check an asset for compliance violations."""
        pass
    
    @abstractmethod
    def assess(self, asset: Asset, level: ComplianceLevel) -> ComplianceAssessment:
        """Perform a full compliance assessment."""
        pass


class FrameworkChecker(ABC):
    """Interface for framework-specific compliance checkers."""
    
    def __init__(self, framework: ComplianceFramework):
        self.framework = framework
    
    @abstractmethod
    def get_applicable_controls(self, asset_type: str, level: ComplianceLevel) -> List[Control]:
        """Get controls applicable to an asset type."""
        pass
    
    @abstractmethod
    def check_control(self, asset: Asset, control: Control) -> Dict[str, Any]:
        """Check a specific control against an asset."""
        pass
