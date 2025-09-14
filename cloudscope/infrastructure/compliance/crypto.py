"""
Cryptographic functions for CloudScope compliance features.

This module provides encryption and decryption functionality
for sensitive data in compliance with various frameworks.
"""

import os
import base64
import hashlib
from typing import Optional
from cryptography.fernet import Fernet
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC

from .exceptions import EncryptionError


# Global encryption key cache (in production, use proper key management)
_encryption_key_cache: Optional[bytes] = None


def get_encryption_key() -> bytes:
    """
    Get the encryption key for sensitive data.
    
    In production, this should integrate with a proper key management
    service like AWS KMS, Azure Key Vault, or HashiCorp Vault.
    
    Returns:
        Encryption key as bytes
        
    Raises:
        EncryptionError: If key cannot be retrieved
    """
    global _encryption_key_cache
    
    if _encryption_key_cache is not None:
        return _encryption_key_cache
    
    try:
        # Try to get key from environment variable
        key_string = os.getenv('CLOUDSCOPE_ENCRYPTION_KEY')
        
        if key_string:
            # Decode base64 key from environment
            _encryption_key_cache = base64.urlsafe_b64decode(key_string)
        else:
            # Generate a new key (not recommended for production)
            # In production, keys should be managed externally
            _encryption_key_cache = Fernet.generate_key()
            
            # Log warning about key generation
            import logging
            logger = logging.getLogger(__name__)
            logger.warning(
                "Generated new encryption key - this should not happen in production. "
                "Set CLOUDSCOPE_ENCRYPTION_KEY environment variable."
            )
        
        return _encryption_key_cache
        
    except Exception as e:
        raise EncryptionError(f"Failed to retrieve encryption key: {str(e)}")


def derive_key_from_password(password: str, salt: Optional[bytes] = None) -> tuple[bytes, bytes]:
    """
    Derive an encryption key from a password using PBKDF2.
    
    Args:
        password: Password to derive key from
        salt: Salt for key derivation (generates new if None)
        
    Returns:
        Tuple of (derived_key, salt)
    """
    if salt is None:
        salt = os.urandom(16)
    
    kdf = PBKDF2HMAC(
        algorithm=hashes.SHA256(),
        length=32,
        salt=salt,
        iterations=100000,
    )
    
    key = kdf.derive(password.encode())
    return key, salt


def encrypt_value(value: str, key: Optional[bytes] = None) -> str:
    """
    Encrypt a string value.
    
    Args:
        value: String value to encrypt
        key: Encryption key (uses default if None)
        
    Returns:
        Base64-encoded encrypted value
        
    Raises:
        EncryptionError: If encryption fails
    """
    try:
        if key is None:
            key = get_encryption_key()
        
        cipher_suite = Fernet(key)
        encrypted_value = cipher_suite.encrypt(value.encode())
        
        # Return base64-encoded string for easy storage
        return base64.urlsafe_b64encode(encrypted_value).decode()
        
    except Exception as e:
        raise EncryptionError(f"Failed to encrypt value: {str(e)}")


def decrypt_value(encrypted_value: str, key: Optional[bytes] = None) -> str:
    """
    Decrypt a string value.
    
    Args:
        encrypted_value: Base64-encoded encrypted value
        key: Encryption key (uses default if None)
        
    Returns:
        Decrypted string value
        
    Raises:
        EncryptionError: If decryption fails
    """
    try:
        if key is None:
            key = get_encryption_key()
        
        cipher_suite = Fernet(key)
        
        # Decode base64 and decrypt
        encrypted_bytes = base64.urlsafe_b64decode(encrypted_value.encode())
        decrypted_value = cipher_suite.decrypt(encrypted_bytes)
        
        return decrypted_value.decode()
        
    except Exception as e:
        raise EncryptionError(f"Failed to decrypt value: {str(e)}")


def hash_value(value: str, salt: Optional[str] = None) -> str:
    """
    Create a hash of a value for comparison purposes.
    
    Args:
        value: Value to hash
        salt: Salt for hashing (generates new if None)
        
    Returns:
        Hexadecimal hash string
    """
    if salt is None:
        salt = os.urandom(16).hex()
    
    # Combine value and salt
    salted_value = f"{value}{salt}"
    
    # Create SHA-256 hash
    hash_object = hashlib.sha256(salted_value.encode())
    return hash_object.hexdigest()


def generate_key_string() -> str:
    """
    Generate a new base64-encoded encryption key string.
    
    This is useful for generating keys for the CLOUDSCOPE_ENCRYPTION_KEY
    environment variable.
    
    Returns:
        Base64-encoded key string
    """
    key = Fernet.generate_key()
    return base64.urlsafe_b64encode(key).decode()


def mask_sensitive_data(value: str, visible_chars: int = 4) -> str:
    """
    Mask sensitive data for display purposes.
    
    Args:
        value: Value to mask
        visible_chars: Number of characters to show at end
        
    Returns:
        Masked string
    """
    if len(value) <= visible_chars:
        return "*" * len(value)
    
    mask_length = len(value) - visible_chars
    return "*" * mask_length + value[-visible_chars:]


def is_encrypted_value(value: str) -> bool:
    """
    Check if a string appears to be an encrypted value.
    
    Args:
        value: String to check
        
    Returns:
        True if value appears to be encrypted
    """
    try:
        # Try to decode as base64
        decoded = base64.urlsafe_b64decode(value.encode())
        
        # Check if it's the right length for Fernet tokens
        # Fernet tokens are typically 60+ bytes
        return len(decoded) >= 60
        
    except Exception:
        return False
