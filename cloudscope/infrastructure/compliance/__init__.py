"""
CloudScope Compliance Infrastructure

This module provides compliance-as-code functionality for CloudScope,
including decorators for data classification, encryption, audit logging,
and access control.
"""

from .decorators import (
    data_classification,
    encrypted,
    audit_log,
    access_control,
    pci_scope,
)
from .monitoring import ComplianceMonitor
from .analysis import ComplianceStaticAnalyzer
from .exceptions import (
    ComplianceViolationError,
    UnauthorizedError,
    ForbiddenError,
)

__all__ = [
    "data_classification",
    "encrypted", 
    "audit_log",
    "access_control",
    "pci_scope",
    "ComplianceMonitor",
    "ComplianceStaticAnalyzer",
    "ComplianceViolationError",
    "UnauthorizedError", 
    "ForbiddenError",
]
