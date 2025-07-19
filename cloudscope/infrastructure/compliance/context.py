"""
Compliance context management for CloudScope.

This module provides context management for compliance operations,
including user context and compliance settings.
"""

import threading
from typing import Optional, Dict, Any
from dataclasses import dataclass


@dataclass
class User:
    """Simple user model for compliance context."""
    id: str
    roles: list
    email: Optional[str] = None
    name: Optional[str] = None


@dataclass 
class ComplianceContext:
    """Compliance context for operations."""
    gdpr_lawful_basis: Optional[str] = None
    hipaa_minimum_necessary: bool = False
    pci_authorized_access: bool = False
    framework_specific: Dict[str, Any] = None
    
    def __post_init__(self):
        if self.framework_specific is None:
            self.framework_specific = {}


# Thread-local storage for context
_context = threading.local()


def set_current_user(user: Optional[User]) -> None:
    """
    Set the current user in thread-local context.
    
    Args:
        user: User object or None to clear context
    """
    _context.current_user = user


def get_current_user() -> Optional[User]:
    """
    Get the current user from thread-local context.
    
    Returns:
        Current user or None if not set
    """
    return getattr(_context, 'current_user', None)


def set_compliance_context(context: ComplianceContext) -> None:
    """
    Set the compliance context in thread-local storage.
    
    Args:
        context: ComplianceContext object
    """
    _context.compliance_context = context


def get_compliance_context() -> ComplianceContext:
    """
    Get the compliance context from thread-local storage.
    
    Returns:
        ComplianceContext object (creates default if not set)
    """
    if not hasattr(_context, 'compliance_context'):
        _context.compliance_context = ComplianceContext()
    return _context.compliance_context


def clear_context() -> None:
    """Clear all context from thread-local storage."""
    _context.current_user = None
    _context.compliance_context = ComplianceContext()


# Context managers for compliance operations

class user_context:
    """Context manager for setting user context."""
    
    def __init__(self, user: User):
        self.user = user
        self.previous_user = None
    
    def __enter__(self):
        self.previous_user = get_current_user()
        set_current_user(self.user)
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        set_current_user(self.previous_user)


class compliance_context:
    """Context manager for setting compliance context."""
    
    def __init__(self, **kwargs):
        self.context = ComplianceContext(**kwargs)
        self.previous_context = None
    
    def __enter__(self):
        self.previous_context = get_compliance_context()
        set_compliance_context(self.context)
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        set_compliance_context(self.previous_context)


class gdpr_context(compliance_context):
    """Context manager specifically for GDPR operations."""
    
    def __init__(self, lawful_basis: str):
        super().__init__(gdpr_lawful_basis=lawful_basis)


class hipaa_context(compliance_context):
    """Context manager specifically for HIPAA operations."""
    
    def __init__(self, minimum_necessary: bool = True):
        super().__init__(hipaa_minimum_necessary=minimum_necessary)


class pci_context(compliance_context):
    """Context manager specifically for PCI DSS operations."""
    
    def __init__(self, authorized_access: bool = True):
        super().__init__(pci_authorized_access=authorized_access)
