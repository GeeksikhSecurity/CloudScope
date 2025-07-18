"""
Runtime compliance monitoring for CloudScope.

This module provides runtime verification and monitoring of compliance
requirements, tracking violations and generating alerts.
"""

import logging
from datetime import datetime, timedelta
from typing import List, Dict, Any, Optional
from dataclasses import dataclass, field
from collections import defaultdict

from .context import get_current_user, get_compliance_context
from .exceptions import ComplianceViolationError


@dataclass
class ComplianceViolation:
    """Represents a compliance violation."""
    id: str
    violation_type: str
    description: str
    user_id: Optional[str]
    timestamp: datetime
    severity: str = "medium"
    framework: Optional[str] = None
    remediation: Optional[str] = None
    metadata: Dict[str, Any] = field(default_factory=dict)


@dataclass
class ComplianceMetrics:
    """Compliance metrics for reporting."""
    total_operations: int = 0
    compliant_operations: int = 0
    violation_count: int = 0
    violations_by_type: Dict[str, int] = field(default_factory=lambda: defaultdict(int))
    violations_by_user: Dict[str, int] = field(default_factory=lambda: defaultdict(int))
    violations_by_framework: Dict[str, int] = field(default_factory=lambda: defaultdict(int))
    
    @property
    def compliance_rate(self) -> float:
        """Calculate compliance rate as percentage."""
        if self.total_operations == 0:
            return 100.0
        return (self.compliant_operations / self.total_operations) * 100


class ComplianceMonitor:
    """Monitor for runtime compliance verification."""
    
    def __init__(self):
        self.violations: List[ComplianceViolation] = []
        self.metrics = ComplianceMetrics()
        self.logger = logging.getLogger(__name__)
        self.alert_callbacks: List[callable] = []
    
    def add_alert_callback(self, callback: callable) -> None:
        """
        Add a callback function to be called when violations occur.
        
        Args:
            callback: Function to call with violation data
        """
        self.alert_callbacks.append(callback)
    
    def record_operation(self, operation_type: str, is_compliant: bool = True) -> None:
        """
        Record a compliance-related operation.
        
        Args:
            operation_type: Type of operation
            is_compliant: Whether the operation was compliant
        """
        self.metrics.total_operations += 1
        if is_compliant:
            self.metrics.compliant_operations += 1
    
    def check_data_access(
        self, 
        data_type: str, 
        user_id: str, 
        operation: str,
        context: Optional[Dict[str, Any]] = None
    ) -> bool:
        """
        Check if data access complies with regulations.
        
        Args:
            data_type: Type of data being accessed
            user_id: ID of user accessing the data
            operation: Operation being performed (read, write, delete)
            context: Additional context for the operation
        
        Returns:
            True if access is compliant, False otherwise
        """
        user = get_current_user()
        compliance_context = get_compliance_context()
        
        # Record the operation
        self.record_operation(f"data_access_{data_type}")
        
        # Check permissions based on data type
        violation = None
        
        if data_type == "personal":
            violation = self._check_personal_data_access(user, operation, compliance_context)
        elif data_type == "health":
            violation = self._check_health_data_access(user, operation, compliance_context)
        elif data_type == "financial":
            violation = self._check_financial_data_access(user, operation, compliance_context)
        
        if violation:
            self._record_violation(violation)
            return False
        
        # Log compliant access
        self.logger.info(
            f"Compliant data access: {data_type}",
            extra={
                "user_id": user_id,
                "data_type": data_type,
                "operation": operation,
                "timestamp": datetime.now().isoformat(),
                "compliance_status": "compliant"
            }
        )
        
        return True
    
    def check_encryption_compliance(self, data_type: str, is_encrypted: bool) -> bool:
        """
        Check if data encryption complies with requirements.
        
        Args:
            data_type: Type of data
            is_encrypted: Whether the data is encrypted
        
        Returns:
            True if encryption is compliant
        """
        self.record_operation(f"encryption_check_{data_type}")
        
        # Define encryption requirements by data type
        encryption_required = {
            "personal": False,  # Not always required for GDPR
            "health": True,     # Required for HIPAA
            "financial": True,  # Required for PCI DSS
            "payment_card": True,  # Always required
        }
        
        required = encryption_required.get(data_type, False)
        
        if required and not is_encrypted:
            violation = ComplianceViolation(
                id=f"enc_{datetime.now().timestamp()}",
                violation_type="encryption_required",
                description=f"Encryption required for {data_type} data but not found",
                user_id=get_current_user().id if get_current_user() else None,
                timestamp=datetime.now(),
                severity="high",
                framework=self._get_framework_for_data_type(data_type),
                remediation="Encrypt the data using approved encryption methods"
            )
            self._record_violation(violation)
            return False
        
        return True
    
    def check_access_control_compliance(self, resource: str, required_roles: List[str]) -> bool:
        """
        Check if access control is compliant.
        
        Args:
            resource: Resource being accessed
            required_roles: Roles required for access
        
        Returns:
            True if access control is compliant
        """
        user = get_current_user()
        self.record_operation("access_control_check")
        
        if not user:
            violation = ComplianceViolation(
                id=f"auth_{datetime.now().timestamp()}",
                violation_type="authentication_required",
                description=f"Authentication required for accessing {resource}",
                user_id=None,
                timestamp=datetime.now(),
                severity="high",
                remediation="Authenticate user before accessing resource"
            )
            self._record_violation(violation)
            return False
        
        user_roles = getattr(user, 'roles', [])
        if not any(role in user_roles for role in required_roles):
            violation = ComplianceViolation(
                id=f"authz_{datetime.now().timestamp()}",
                violation_type="insufficient_permissions",
                description=f"User {user.id} lacks required roles {required_roles} for {resource}",
                user_id=user.id,
                timestamp=datetime.now(),
                severity="high",
                remediation=f"Grant user one of the required roles: {', '.join(required_roles)}"
            )
            self._record_violation(violation)
            return False
        
        return True
    
    def get_violations(
        self, 
        start_date: Optional[datetime] = None,
        end_date: Optional[datetime] = None,
        violation_type: Optional[str] = None,
        framework: Optional[str] = None
    ) -> List[ComplianceViolation]:
        """
        Get compliance violations based on filters.
        
        Args:
            start_date: Start date for filtering
            end_date: End date for filtering
            violation_type: Type of violation to filter by
            framework: Framework to filter by
        
        Returns:
            List of filtered violations
        """
        violations = self.violations
        
        if start_date:
            violations = [v for v in violations if v.timestamp >= start_date]
        
        if end_date:
            violations = [v for v in violations if v.timestamp <= end_date]
        
        if violation_type:
            violations = [v for v in violations if v.violation_type == violation_type]
        
        if framework:
            violations = [v for v in violations if v.framework == framework]
        
        return violations
    
    def get_metrics(self, period_hours: int = 24) -> ComplianceMetrics:
        """
        Get compliance metrics for a time period.
        
        Args:
            period_hours: Number of hours to look back
        
        Returns:
            ComplianceMetrics object
        """
        cutoff_time = datetime.now() - timedelta(hours=period_hours)
        recent_violations = [v for v in self.violations if v.timestamp >= cutoff_time]
        
        metrics = ComplianceMetrics()
        metrics.total_operations = self.metrics.total_operations
        metrics.compliant_operations = self.metrics.compliant_operations
        metrics.violation_count = len(recent_violations)
        
        for violation in recent_violations:
            metrics.violations_by_type[violation.violation_type] += 1
            if violation.user_id:
                metrics.violations_by_user[violation.user_id] += 1
            if violation.framework:
                metrics.violations_by_framework[violation.framework] += 1
        
        return metrics
    
    def clear_violations(self, older_than_days: int = 30) -> int:
        """
        Clear old violations.
        
        Args:
            older_than_days: Remove violations older than this many days
        
        Returns:
            Number of violations removed
        """
        cutoff_time = datetime.now() - timedelta(days=older_than_days)
        old_violations = [v for v in self.violations if v.timestamp < cutoff_time]
        self.violations = [v for v in self.violations if v.timestamp >= cutoff_time]
        
        return len(old_violations)
    
    def _check_personal_data_access(self, user, operation, compliance_context) -> Optional[ComplianceViolation]:
        """Check GDPR compliance for personal data access."""
        if not compliance_context.gdpr_lawful_basis:
            return ComplianceViolation(
                id=f"gdpr_{datetime.now().timestamp()}",
                violation_type="missing_lawful_basis",
                description="GDPR requires lawful basis for personal data processing",
                user_id=user.id if user else None,
                timestamp=datetime.now(),
                severity="high",
                framework="GDPR",
                remediation="Specify lawful basis for personal data processing"
            )
        return None
    
    def _check_health_data_access(self, user, operation, compliance_context) -> Optional[ComplianceViolation]:
        """Check HIPAA compliance for health data access."""
        if not compliance_context.hipaa_minimum_necessary:
            return ComplianceViolation(
                id=f"hipaa_{datetime.now().timestamp()}",
                violation_type="minimum_necessary_not_verified",
                description="HIPAA requires minimum necessary standard for health data access",
                user_id=user.id if user else None,
                timestamp=datetime.now(),
                severity="high",
                framework="HIPAA",
                remediation="Verify minimum necessary standard is met"
            )
        return None
    
    def _check_financial_data_access(self, user, operation, compliance_context) -> Optional[ComplianceViolation]:
        """Check PCI DSS compliance for financial data access."""
        if not compliance_context.pci_authorized_access:
            return ComplianceViolation(
                id=f"pci_{datetime.now().timestamp()}",
                violation_type="unauthorized_cardholder_access",
                description="PCI DSS requires authorized access to cardholder data",
                user_id=user.id if user else None,
                timestamp=datetime.now(),
                severity="critical",
                framework="PCI_DSS",
                remediation="Ensure user is authorized for cardholder data access"
            )
        return None
    
    def _get_framework_for_data_type(self, data_type: str) -> str:
        """Get the primary compliance framework for a data type."""
        framework_mapping = {
            "personal": "GDPR",
            "health": "HIPAA",
            "financial": "PCI_DSS",
            "payment_card": "PCI_DSS",
        }
        return framework_mapping.get(data_type, "GENERAL")
    
    def _record_violation(self, violation: ComplianceViolation) -> None:
        """Record a compliance violation."""
        self.violations.append(violation)
        self.metrics.violation_count += 1
        self.metrics.violations_by_type[violation.violation_type] += 1
        
        if violation.user_id:
            self.metrics.violations_by_user[violation.user_id] += 1
        
        if violation.framework:
            self.metrics.violations_by_framework[violation.framework] += 1
        
        # Update compliance rate
        if self.metrics.total_operations > 0:
            self.metrics.compliant_operations = (
                self.metrics.total_operations - self.metrics.violation_count
            )
        
        # Log the violation
        self.logger.warning(
            f"Compliance violation recorded: {violation.violation_type}",
            extra={
                "violation_id": violation.id,
                "violation_type": violation.violation_type,
                "user_id": violation.user_id,
                "framework": violation.framework,
                "severity": violation.severity,
                "timestamp": violation.timestamp.isoformat()
            }
        )
        
        # Trigger alert callbacks
        for callback in self.alert_callbacks:
            try:
                callback(violation)
            except Exception as e:
                self.logger.error(f"Error in alert callback: {str(e)}")


# Global compliance monitor instance
_global_monitor = ComplianceMonitor()


def get_compliance_monitor() -> ComplianceMonitor:
    """Get the global compliance monitor instance."""
    return _global_monitor
