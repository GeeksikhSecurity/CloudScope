"""
Compliance-related exceptions for CloudScope.
"""


class ComplianceViolationError(Exception):
    """Raised when a compliance violation is detected."""
    
    def __init__(self, message: str, violation_type: str = None):
        super().__init__(message)
        self.violation_type = violation_type


class UnauthorizedError(ComplianceViolationError):
    """Raised when authentication is required but not provided."""
    
    def __init__(self, message: str = "Authentication required"):
        super().__init__(message, "authentication")


class ForbiddenError(ComplianceViolationError):
    """Raised when user lacks required permissions."""
    
    def __init__(self, message: str = "Insufficient permissions"):
        super().__init__(message, "authorization")


class EncryptionError(ComplianceViolationError):
    """Raised when encryption operations fail."""
    
    def __init__(self, message: str = "Encryption operation failed"):
        super().__init__(message, "encryption")


class DataClassificationError(ComplianceViolationError):
    """Raised when data classification is violated."""
    
    def __init__(self, message: str = "Data classification violation"):
        super().__init__(message, "data_classification")
