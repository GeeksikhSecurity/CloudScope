"""
Tests for CloudScope compliance decorators.
"""

import unittest
from unittest.mock import patch, MagicMock
from datetime import datetime

from cloudscope.infrastructure.compliance.decorators import (
    data_classification,
    encrypted,
    audit_log,
    access_control,
    pci_scope,
)
from cloudscope.infrastructure.compliance.context import (
    User,
    set_current_user,
    clear_context,
    user_context,
    gdpr_context,
)
from cloudscope.infrastructure.compliance.exceptions import (
    UnauthorizedError,
    ForbiddenError,
    EncryptionError,
)


class TestComplianceDecorators(unittest.TestCase):
    """Test compliance decorator functionality."""
    
    def setUp(self):
        """Set up test fixtures."""
        clear_context()
        
        # Create test users
        self.admin_user = User(id="admin123", roles=["admin"], email="admin@test.com")
        self.regular_user = User(id="user456", roles=["user"], email="user@test.com")
        self.doctor_user = User(id="doc789", roles=["doctor"], email="doctor@test.com")
    
    def tearDown(self):
        """Clean up after tests."""
        clear_context()
    
    def test_data_classification_decorator(self):
        """Test data classification decorator functionality."""
        
        class TestModel:
            def __init__(self):
                self._email = None
            
            @data_classification("personal")
            def set_email(self, email: str):
                self._email = email
            
            def get_email(self):
                return self._email
        
        # Test with user context
        with user_context(self.regular_user):
            with gdpr_context(lawful_basis="consent"):
                model = TestModel()
                
                # Should work with proper context
                model.set_email("test@example.com")
                self.assertEqual(model.get_email(), "test@example.com")
        
        # Test that function has metadata
        self.assertTrue(hasattr(model.set_email, '__compliance_classification__'))
        self.assertEqual(model.set_email.__compliance_classification__, "personal")
    
    @patch('cloudscope.infrastructure.compliance.crypto.get_encryption_key')
    @patch('cloudscope.infrastructure.compliance.crypto.encrypt_value')
    def test_encrypted_decorator(self, mock_encrypt, mock_get_key):
        """Test encrypted decorator functionality."""
        mock_get_key.return_value = b'test_key'
        mock_encrypt.return_value = 'encrypted_value'
        
        class TestModel:
            def __init__(self):
                self._card_number = None
            
            @encrypted
            def set_card_number(self, card_number: str):
                self._card_number = card_number
        
        with user_context(self.admin_user):
            model = TestModel()
            model.set_card_number("4111111111111111")
            
            # Verify encryption was called
            mock_encrypt.assert_called_once_with("4111111111111111", b'test_key')
            self.assertEqual(model._card_number, "encrypted_value")
        
        # Test that function has metadata
        self.assertTrue(hasattr(model.set_card_number, '__encrypted__'))
    
    @patch('cloudscope.infrastructure.compliance.crypto.get_encryption_key')
    def test_encrypted_decorator_failure(self, mock_get_key):
        """Test encrypted decorator handles failures."""
        mock_get_key.side_effect = Exception("Key not found")
        
        class TestModel:
            @encrypted
            def set_data(self, data: str):
                self._data = data
        
        with user_context(self.admin_user):
            model = TestModel()
            
            with self.assertRaises(EncryptionError):
                model.set_data("sensitive_data")
    
    def test_audit_log_decorator(self):
        """Test audit log decorator functionality."""
        
        class TestModel:
            @audit_log
            def sensitive_operation(self, data: str):
                return f"processed_{data}"
        
        with patch('cloudscope.infrastructure.compliance.decorators.audit_logger') as mock_logger:
            with user_context(self.admin_user):
                model = TestModel()
                result = model.sensitive_operation("test_data")
                
                # Verify result is correct
                self.assertEqual(result, "processed_test_data")
                
                # Verify audit logging
                self.assertEqual(mock_logger.info.call_count, 2)  # Start and completion
                
                # Check that start log was called
                start_call = mock_logger.info.call_args_list[0]
                self.assertIn("Operation started", start_call[0][0])
                
                # Check that completion log was called
                completion_call = mock_logger.info.call_args_list[1]
                self.assertIn("Operation completed", completion_call[0][0])
        
        # Test that function has metadata
        self.assertTrue(hasattr(model.sensitive_operation, '__audit_logged__'))
    
    def test_audit_log_decorator_with_exception(self):
        """Test audit log decorator handles exceptions."""
        
        class TestModel:
            @audit_log
            def failing_operation(self):
                raise ValueError("Test error")
        
        with patch('cloudscope.infrastructure.compliance.decorators.audit_logger') as mock_logger:
            with user_context(self.admin_user):
                model = TestModel()
                
                with self.assertRaises(ValueError):
                    model.failing_operation()
                
                # Verify error was logged
                mock_logger.error.assert_called_once()
                error_call = mock_logger.error.call_args_list[0]
                self.assertIn("Operation failed", error_call[0][0])
    
    def test_access_control_decorator_success(self):
        """Test access control decorator with proper permissions."""
        
        class TestModel:
            @access_control(["admin", "operator"])
            def admin_operation(self):
                return "admin_result"
        
        with user_context(self.admin_user):
            model = TestModel()
            result = model.admin_operation()
            self.assertEqual(result, "admin_result")
        
        # Test that function has metadata
        self.assertTrue(hasattr(model.admin_operation, '__required_roles__'))
        self.assertEqual(model.admin_operation.__required_roles__, ["admin", "operator"])
    
    def test_access_control_decorator_unauthorized(self):
        """Test access control decorator without authentication."""
        
        class TestModel:
            @access_control(["admin"])
            def admin_operation(self):
                return "admin_result"
        
        # No user context
        model = TestModel()
        with self.assertRaises(UnauthorizedError):
            model.admin_operation()
    
    def test_access_control_decorator_forbidden(self):
        """Test access control decorator with insufficient permissions."""
        
        class TestModel:
            @access_control(["admin"])
            def admin_operation(self):
                return "admin_result"
        
        with user_context(self.regular_user):  # Regular user, not admin
            model = TestModel()
            with self.assertRaises(ForbiddenError):
                model.admin_operation()
    
    def test_pci_scope_decorator(self):
        """Test PCI scope class decorator."""
        
        @pci_scope
        class PaymentModel:
            def __init__(self):
                self.data = "payment_data"
        
        # Check that class has metadata
        self.assertTrue(hasattr(PaymentModel, '__pci_scope__'))
        self.assertTrue(PaymentModel.__pci_scope__)
        self.assertIn('PCI_DSS', PaymentModel.__compliance_frameworks__)
    
    def test_combined_decorators(self):
        """Test multiple decorators on the same function."""
        
        class TestModel:
            def __init__(self):
                self._sensitive_data = None
            
            @data_classification("personal")
            @audit_log
            @access_control(["admin"])
            def set_sensitive_data(self, data: str):
                self._sensitive_data = data
        
        with user_context(self.admin_user):
            with gdpr_context(lawful_basis="consent"):
                with patch('cloudscope.infrastructure.compliance.decorators.audit_logger'):
                    model = TestModel()
                    model.set_sensitive_data("sensitive_info")
                    self.assertEqual(model._sensitive_data, "sensitive_info")
        
        # Verify all decorators added metadata
        func = model.set_sensitive_data
        self.assertTrue(hasattr(func, '__compliance_classification__'))
        self.assertTrue(hasattr(func, '__audit_logged__'))
        self.assertTrue(hasattr(func, '__required_roles__'))
    
    def test_decorator_preserves_function_metadata(self):
        """Test that decorators preserve original function metadata."""
        
        class TestModel:
            @data_classification("personal")
            @audit_log
            def documented_function(self, param: str) -> str:
                """This is a documented function.
                
                Args:
                    param: A parameter
                    
                Returns:
                    A string result
                """
                return f"result_{param}"
        
        model = TestModel()
        func = model.documented_function
        
        # Check that original function is accessible
        self.assertTrue(hasattr(func, '__original_function__'))
        
        # Check that function name is preserved
        self.assertEqual(func.__name__, 'documented_function')


class TestComplianceContext(unittest.TestCase):
    """Test compliance context management."""
    
    def setUp(self):
        """Set up test fixtures."""
        clear_context()
        self.test_user = User(id="test123", roles=["user"], email="test@example.com")
    
    def tearDown(self):
        """Clean up after tests."""
        clear_context()
    
    def test_user_context_manager(self):
        """Test user context manager functionality."""
        
        # Initially no user
        from cloudscope.infrastructure.compliance.context import get_current_user
        self.assertIsNone(get_current_user())
        
        # Use context manager
        with user_context(self.test_user):
            current_user = get_current_user()
            self.assertIsNotNone(current_user)
            self.assertEqual(current_user.id, "test123")
        
        # After context, should be None again
        self.assertIsNone(get_current_user())
    
    def test_gdpr_context_manager(self):
        """Test GDPR context manager functionality."""
        from cloudscope.infrastructure.compliance.context import get_compliance_context
        
        with gdpr_context(lawful_basis="consent"):
            context = get_compliance_context()
            self.assertEqual(context.gdpr_lawful_basis, "consent")
        
        # After context, should be default
        context = get_compliance_context()
        self.assertIsNone(context.gdpr_lawful_basis)
    
    def test_nested_contexts(self):
        """Test nested context managers."""
        from cloudscope.infrastructure.compliance.context import (
            get_current_user, get_compliance_context
        )
        
        with user_context(self.test_user):
            with gdpr_context(lawful_basis="legitimate_interest"):
                user = get_current_user()
                context = get_compliance_context()
                
                self.assertEqual(user.id, "test123")
                self.assertEqual(context.gdpr_lawful_basis, "legitimate_interest")


if __name__ == '__main__':
    unittest.main()
