"""
Compliance decorators for CloudScope compliance-as-code implementation.

This module provides decorators that enforce compliance requirements directly
in the code, supporting frameworks like GDPR, PCI DSS, HIPAA, and SOC 2.
"""

import logging
from datetime import datetime
from functools import wraps
from typing import List, Any, Callable, Optional
from contextlib import contextmanager

from .exceptions import UnauthorizedError, ForbiddenError, EncryptionError
from .context import get_current_user, get_compliance_context
from .crypto import encrypt_value, decrypt_value, get_encryption_key

# Set up logging
logger = logging.getLogger(__name__)
audit_logger = logging.getLogger("cloudscope.audit")


def data_classification(classification_type: str):
    """
    Decorator for classifying data according to compliance requirements.
    
    This decorator logs access to classified data and applies appropriate
    controls based on the classification type.
    
    Args:
        classification_type: Type of data classification 
                           (personal, health, financial, etc.)
    
    Example:
        @data_classification("personal")
        def update_user_email(self, email: str):
            self.email = email
    """
    def decorator(func: Callable) -> Callable:
        @wraps(func)
        def wrapper(*args, **kwargs):
            # Get current context
            current_user = get_current_user()
            compliance_context = get_compliance_context()
            
            # Log access to classified data
            logger.info(
                f"Accessing {classification_type} data: {func.__name__}",
                extra={
                    "classification": classification_type,
                    "function": func.__name__,
                    "user_id": current_user.id if current_user else "system",
                    "timestamp": datetime.now().isoformat(),
                    "module": func.__module__,
                    "class": args[0].__class__.__name__ if args else None,
                }
            )
            
            # Apply classification-specific controls
            if classification_type == "personal":
                _apply_gdpr_controls(func, args, kwargs, current_user)
            elif classification_type == "health": 
                _apply_hipaa_controls(func, args, kwargs, current_user)
            elif classification_type == "financial":
                _apply_pci_controls(func, args, kwargs, current_user)
            
            # Execute function
            result = func(*args, **kwargs)
            
            # Log successful access
            audit_logger.info(
                f"Data classification access completed: {classification_type}",
                extra={
                    "classification": classification_type,
                    "function": func.__name__,
                    "user_id": current_user.id if current_user else "system",
                    "timestamp": datetime.now().isoformat(),
                    "status": "success"
                }
            )
            
            return result
        
        # Add metadata to function for static analysis
        wrapper.__compliance_classification__ = classification_type
        wrapper.__original_function__ = func
        return wrapper
    
    return decorator


def encrypted(func: Callable) -> Callable:
    """
    Decorator for encrypting sensitive data.
    
    This decorator automatically encrypts values passed to functions
    that handle sensitive data like payment card information.
    
    Example:
        @encrypted
        def set_card_number(self, card_number: str):
            self._card_number = card_number
    """
    @wraps(func)
    def wrapper(self, value, *args, **kwargs):
        current_user = get_current_user()
        
        try:
            # Get encryption key from secure storage
            encryption_key = get_encryption_key()
            
            # Encrypt value
            encrypted_value = encrypt_value(value, encryption_key)
            
            # Log encryption operation
            audit_logger.info(
                f"Data encrypted: {func.__name__}",
                extra={
                    "function": func.__name__,
                    "user_id": current_user.id if current_user else "system",
                    "timestamp": datetime.now().isoformat(),
                    "data_type": "encrypted",
                    "status": "success"
                }
            )
            
            # Call original function with encrypted value
            return func(self, encrypted_value, *args, **kwargs)
            
        except Exception as e:
            # Log encryption failure
            audit_logger.error(
                f"Encryption failed: {func.__name__}",
                extra={
                    "function": func.__name__,
                    "user_id": current_user.id if current_user else "system",
                    "timestamp": datetime.now().isoformat(),
                    "error": str(e),
                    "status": "failed"
                }
            )
            raise EncryptionError(f"Failed to encrypt data for {func.__name__}: {str(e)}")
    
    # Add metadata to function for static analysis
    wrapper.__encrypted__ = True
    wrapper.__original_function__ = func
    return wrapper


def audit_log(func: Callable) -> Callable:
    """
    Decorator for audit logging of security-relevant operations.
    
    This decorator logs all security-relevant operations including
    their start, completion, and any failures.
    
    Example:
        @audit_log
        def delete_user_data(self, user_id: str):
            # Delete user data
            pass
    """
    @wraps(func)
    def wrapper(*args, **kwargs):
        # Get current user from context
        current_user = get_current_user()
        operation_id = f"{func.__name__}_{datetime.now().timestamp()}"
        
        # Log operation start
        audit_logger.info(
            f"Operation started: {func.__name__}",
            extra={
                "operation_id": operation_id,
                "operation": func.__name__,
                "user_id": current_user.id if current_user else "system",
                "timestamp": datetime.now().isoformat(),
                "status": "started",
                "module": func.__module__,
                "args_count": len(args),
                "kwargs_keys": list(kwargs.keys()) if kwargs else []
            }
        )
        
        try:
            # Execute function
            result = func(*args, **kwargs)
            
            # Log operation success
            audit_logger.info(
                f"Operation completed: {func.__name__}",
                extra={
                    "operation_id": operation_id,
                    "operation": func.__name__,
                    "user_id": current_user.id if current_user else "system",
                    "timestamp": datetime.now().isoformat(),
                    "status": "completed",
                    "result_type": type(result).__name__ if result is not None else "None"
                }
            )
            
            return result
            
        except Exception as e:
            # Log operation failure
            audit_logger.error(
                f"Operation failed: {func.__name__}",
                extra={
                    "operation_id": operation_id,
                    "operation": func.__name__,
                    "user_id": current_user.id if current_user else "system",
                    "timestamp": datetime.now().isoformat(),
                    "status": "failed",
                    "error": str(e),
                    "error_type": type(e).__name__
                }
            )
            raise
    
    # Add metadata to function for static analysis
    wrapper.__audit_logged__ = True
    wrapper.__original_function__ = func
    return wrapper


def access_control(required_roles: List[str]):
    """
    Decorator for enforcing access control based on user roles.
    
    This decorator checks if the current user has the required roles
    before allowing access to the decorated function.
    
    Args:
        required_roles: List of roles that are allowed to access the function
    
    Example:
        @access_control(["admin", "data_processor"])
        def process_sensitive_data(self, data):
            # Process data
            pass
    """
    def decorator(func: Callable) -> Callable:
        @wraps(func)
        def wrapper(*args, **kwargs):
            # Get current user from context
            current_user = get_current_user()
            
            # Check if user is authenticated
            if not current_user:
                audit_logger.warning(
                    f"Unauthorized access attempt: {func.__name__}",
                    extra={
                        "operation": func.__name__,
                        "timestamp": datetime.now().isoformat(),
                        "status": "unauthorized",
                        "required_roles": required_roles
                    }
                )
                raise UnauthorizedError("Authentication required")
            
            # Check if user has required role
            user_roles = getattr(current_user, 'roles', [])
            if not any(role in user_roles for role in required_roles):
                audit_logger.warning(
                    f"Insufficient permissions: {func.__name__}",
                    extra={
                        "operation": func.__name__,
                        "user_id": current_user.id,
                        "user_roles": user_roles,
                        "required_roles": required_roles,
                        "timestamp": datetime.now().isoformat(),
                        "status": "forbidden"
                    }
                )
                raise ForbiddenError(f"Required roles: {', '.join(required_roles)}")
            
            # Log successful authorization
            audit_logger.info(
                f"Access granted: {func.__name__}",
                extra={
                    "operation": func.__name__,
                    "user_id": current_user.id,
                    "user_roles": user_roles,
                    "timestamp": datetime.now().isoformat(),
                    "status": "authorized"
                }
            )
            
            # Execute function
            return func(*args, **kwargs)
        
        # Add metadata to function for static analysis
        wrapper.__required_roles__ = required_roles
        wrapper.__original_function__ = func
        return wrapper
    
    return decorator


def pci_scope(cls):
    """
    Class decorator for marking classes as being in PCI DSS scope.
    
    This decorator adds PCI DSS compliance metadata to classes
    and enables additional monitoring for PCI DSS compliance.
    
    Example:
        @pci_scope
        class PaymentMethod:
            pass
    """
    # Add PCI scope metadata
    cls.__pci_scope__ = True
    cls.__compliance_frameworks__ = getattr(cls, '__compliance_frameworks__', []) + ['PCI_DSS']
    
    # Log PCI scope registration
    logger.info(
        f"Class registered in PCI scope: {cls.__name__}",
        extra={
            "class_name": cls.__name__,
            "module": cls.__module__,
            "timestamp": datetime.now().isoformat(),
            "compliance_framework": "PCI_DSS"
        }
    )
    
    return cls


# Helper functions for applying framework-specific controls

def _apply_gdpr_controls(func: Callable, args: tuple, kwargs: dict, current_user):
    """Apply GDPR-specific controls."""
    # Check for data processing lawful basis
    compliance_context = get_compliance_context()
    if not compliance_context.get('gdpr_lawful_basis'):
        logger.warning(
            f"GDPR: No lawful basis specified for personal data processing: {func.__name__}",
            extra={
                "function": func.__name__,
                "user_id": current_user.id if current_user else "system",
                "timestamp": datetime.now().isoformat(),
                "compliance_issue": "missing_lawful_basis"
            }
        )


def _apply_hipaa_controls(func: Callable, args: tuple, kwargs: dict, current_user):
    """Apply HIPAA-specific controls."""
    # Check for minimum necessary access
    compliance_context = get_compliance_context()
    if not compliance_context.get('hipaa_minimum_necessary'):
        logger.warning(
            f"HIPAA: Minimum necessary not verified for health data access: {func.__name__}",
            extra={
                "function": func.__name__,
                "user_id": current_user.id if current_user else "system",
                "timestamp": datetime.now().isoformat(),
                "compliance_issue": "minimum_necessary_not_verified"
            }
        )


def _apply_pci_controls(func: Callable, args: tuple, kwargs: dict, current_user):
    """Apply PCI DSS-specific controls."""
    # Check for cardholder data access
    compliance_context = get_compliance_context()
    if not compliance_context.get('pci_authorized_access'):
        logger.warning(
            f"PCI DSS: Unauthorized cardholder data access attempt: {func.__name__}",
            extra={
                "function": func.__name__,
                "user_id": current_user.id if current_user else "system",
                "timestamp": datetime.now().isoformat(),
                "compliance_issue": "unauthorized_cardholder_access"
            }
        )
