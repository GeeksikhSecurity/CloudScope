"""
Tests for CloudScope compliance monitoring.
"""

import unittest
from datetime import datetime, timedelta
from unittest.mock import patch, MagicMock

from cloudscope.infrastructure.compliance.monitoring import (
    ComplianceMonitor,
    ComplianceViolation,
    ComplianceMetrics,
    get_compliance_monitor,
)
from cloudscope.infrastructure.compliance.context import (
    User,
    set_current_user,
    set_compliance_context,
    ComplianceContext,
    clear_context,
)


class TestComplianceMonitor(unittest.TestCase):
    """Test compliance monitoring functionality."""
    
    def setUp(self):
        """Set up test fixtures."""
        self.monitor = ComplianceMonitor()
        clear_context()
        
        # Create test users
        self.admin_user = User(id="admin123", roles=["admin"], email="admin@test.com")
        self.regular_user = User(id="user456", roles=["user"], email="user@test.com")
    
    def tearDown(self):
        """Clean up after tests."""
        clear_context()
    
    def test_record_operation(self):
        """Test operation recording functionality."""
        initial_total = self.monitor.metrics.total_operations
        initial_compliant = self.monitor.metrics.compliant_operations
        
        # Record compliant operation
        self.monitor.record_operation("test_operation", True)
        
        self.assertEqual(self.monitor.metrics.total_operations, initial_total + 1)
        self.assertEqual(self.monitor.metrics.compliant_operations, initial_compliant + 1)
        
        # Record non-compliant operation
        self.monitor.record_operation("test_operation", False)
        
        self.assertEqual(self.monitor.metrics.total_operations, initial_total + 2)
        self.assertEqual(self.monitor.metrics.compliant_operations, initial_compliant + 1)
    
    def test_check_data_access_compliant(self):
        """Test compliant data access checking."""
        set_current_user(self.admin_user)
        context = ComplianceContext(gdpr_lawful_basis="consent")
        set_compliance_context(context)
        
        # Test compliant personal data access
        result = self.monitor.check_data_access("personal", "admin123", "read")
        self.assertTrue(result)
        
        # Verify operation was recorded
        self.assertGreater(self.monitor.metrics.total_operations, 0)
    
    def test_check_data_access_violation(self):
        """Test data access violation detection."""
        set_current_user(self.regular_user)
        # No compliance context set (missing lawful basis)
        
        # Test personal data access without proper context
        result = self.monitor.check_data_access("personal", "user456", "read")
        self.assertFalse(result)
        
        # Verify violation was recorded
        self.assertGreater(len(self.monitor.violations), 0)
        self.assertGreater(self.monitor.metrics.violation_count, 0)
        
        # Check violation details
        violation = self.monitor.violations[-1]
        self.assertEqual(violation.violation_type, "missing_lawful_basis")
        self.assertEqual(violation.framework, "GDPR")
        self.assertEqual(violation.user_id, "user456")
    
    def test_check_encryption_compliance(self):
        """Test encryption compliance checking."""
        # Test encrypted financial data (compliant)
        result = self.monitor.check_encryption_compliance("financial", True)
        self.assertTrue(result)
        
        # Test unencrypted financial data (violation)
        result = self.monitor.check_encryption_compliance("financial", False)
        self.assertFalse(result)
        
        # Verify violation was recorded
        encryption_violations = [
            v for v in self.monitor.violations 
            if v.violation_type == "encryption_required"
        ]
        self.assertGreater(len(encryption_violations), 0)
        
        violation = encryption_violations[-1]
        self.assertEqual(violation.severity, "high")
        self.assertEqual(violation.framework, "PCI_DSS")
    
    def test_check_access_control_compliance_unauthorized(self):
        """Test access control with no authentication."""
        # No user set
        result = self.monitor.check_access_control_compliance("admin_resource", ["admin"])
        self.assertFalse(result)
        
        # Verify violation was recorded
        auth_violations = [
            v for v in self.monitor.violations 
            if v.violation_type == "authentication_required"
        ]
        self.assertGreater(len(auth_violations), 0)
        
        violation = auth_violations[-1]
        self.assertEqual(violation.severity, "high")
        self.assertIsNone(violation.user_id)
    
    def test_check_access_control_compliance_forbidden(self):
        """Test access control with insufficient permissions."""
        set_current_user(self.regular_user)
        
        result = self.monitor.check_access_control_compliance("admin_resource", ["admin"])
        self.assertFalse(result)
        
        # Verify violation was recorded
        authz_violations = [
            v for v in self.monitor.violations 
            if v.violation_type == "insufficient_permissions"
        ]
        self.assertGreater(len(authz_violations), 0)
        
        violation = authz_violations[-1]
        self.assertEqual(violation.severity, "high")
        self.assertEqual(violation.user_id, "user456")
    
    def test_check_access_control_compliance_success(self):
        """Test successful access control."""
        set_current_user(self.admin_user)
        
        result = self.monitor.check_access_control_compliance("admin_resource", ["admin"])
        self.assertTrue(result)
        
        # Should not create any violations
        authz_violations = [
            v for v in self.monitor.violations 
            if v.violation_type in ["authentication_required", "insufficient_permissions"]
        ]
        self.assertEqual(len(authz_violations), 0)
    
    def test_get_violations_filtering(self):
        """Test violation filtering functionality."""
        # Create test violations
        now = datetime.now()
        old_violation = ComplianceViolation(
            id="old1",
            violation_type="test_old",
            description="Old violation",
            user_id="user1",
            timestamp=now - timedelta(days=2),
            framework="GDPR"
        )
        
        recent_violation = ComplianceViolation(
            id="recent1",
            violation_type="test_recent",
            description="Recent violation",
            user_id="user2",
            timestamp=now - timedelta(hours=1),
            framework="PCI_DSS"
        )
        
        self.monitor.violations = [old_violation, recent_violation]
        
        # Test date filtering
        recent_violations = self.monitor.get_violations(
            start_date=now - timedelta(days=1)
        )
        self.assertEqual(len(recent_violations), 1)
        self.assertEqual(recent_violations[0].id, "recent1")
        
        # Test type filtering
        type_violations = self.monitor.get_violations(violation_type="test_old")
        self.assertEqual(len(type_violations), 1)
        self.assertEqual(type_violations[0].id, "old1")
        
        # Test framework filtering
        framework_violations = self.monitor.get_violations(framework="PCI_DSS")
        self.assertEqual(len(framework_violations), 1)
        self.assertEqual(framework_violations[0].id, "recent1")
    
    def test_get_metrics(self):
        """Test metrics calculation."""
        # Set up test data
        self.monitor.metrics.total_operations = 100
        self.monitor.metrics.compliant_operations = 85
        
        # Create test violations
        now = datetime.now()
        violations = [
            ComplianceViolation(
                id=f"v{i}",
                violation_type="test_type",
                description="Test violation",
                user_id=f"user{i}",
                timestamp=now - timedelta(hours=i),
                framework="GDPR"
            )
            for i in range(5)
        ]
        self.monitor.violations = violations
        
        # Get metrics for last 24 hours
        metrics = self.monitor.get_metrics(24)
        
        self.assertEqual(metrics.total_operations, 100)
        self.assertEqual(metrics.compliant_operations, 85)
        self.assertEqual(metrics.violation_count, 5)
        self.assertEqual(metrics.compliance_rate, 85.0)
        
        # Check violation counts by category
        self.assertEqual(metrics.violations_by_type["test_type"], 5)
        self.assertEqual(metrics.violations_by_framework["GDPR"], 5)
    
    def test_clear_violations(self):
        """Test violation cleanup functionality."""
        # Create test violations with different ages
        now = datetime.now()
        violations = [
            ComplianceViolation(
                id="old1",
                violation_type="test",
                description="Old violation",
                user_id="user1",
                timestamp=now - timedelta(days=35),  # Older than 30 days
                framework="GDPR"
            ),
            ComplianceViolation(
                id="recent1",
                violation_type="test",
                description="Recent violation",
                user_id="user2",
                timestamp=now - timedelta(days=10),  # Newer than 30 days
                framework="GDPR"
            ),
        ]
        self.monitor.violations = violations
        
        # Clear old violations
        removed_count = self.monitor.clear_violations(older_than_days=30)
        
        self.assertEqual(removed_count, 1)
        self.assertEqual(len(self.monitor.violations), 1)
        self.assertEqual(self.monitor.violations[0].id, "recent1")
    
    def test_alert_callbacks(self):
        """Test alert callback functionality."""
        callback_data = []
        
        def test_callback(violation):
            callback_data.append(violation)
        
        # Add callback
        self.monitor.add_alert_callback(test_callback)
        
        # Create a violation that should trigger callback
        set_current_user(self.regular_user)
        self.monitor.check_data_access("financial", "user456", "read")
        
        # Verify callback was called
        self.assertGreater(len(callback_data), 0)
        self.assertIsInstance(callback_data[0], ComplianceViolation)
    
    def test_alert_callback_error_handling(self):
        """Test that callback errors don't break the monitor."""
        def failing_callback(violation):
            raise Exception("Callback error")
        
        # Add failing callback
        self.monitor.add_alert_callback(failing_callback)
        
        # This should not raise an exception
        set_current_user(self.regular_user)
        result = self.monitor.check_data_access("financial", "user456", "read")
        
        # Operation should still complete
        self.assertFalse(result)  # Should be false due to compliance violation
        
        # Violation should still be recorded
        self.assertGreater(len(self.monitor.violations), 0)


class TestComplianceMetrics(unittest.TestCase):
    """Test compliance metrics functionality."""
    
    def test_compliance_rate_calculation(self):
        """Test compliance rate calculation."""
        metrics = ComplianceMetrics()
        
        # Test with no operations
        self.assertEqual(metrics.compliance_rate, 100.0)
        
        # Test with operations
        metrics.total_operations = 100
        metrics.compliant_operations = 85
        self.assertEqual(metrics.compliance_rate, 85.0)
        
        # Test with all compliant
        metrics.total_operations = 50
        metrics.compliant_operations = 50
        self.assertEqual(metrics.compliance_rate, 100.0)
        
        # Test with none compliant
        metrics.total_operations = 50
        metrics.compliant_operations = 0
        self.assertEqual(metrics.compliance_rate, 0.0)


class TestComplianceViolation(unittest.TestCase):
    """Test compliance violation data structure."""
    
    def test_violation_creation(self):
        """Test violation creation with all fields."""
        timestamp = datetime.now()
        
        violation = ComplianceViolation(
            id="test123",
            violation_type="test_violation",
            description="Test description",
            user_id="user456",
            timestamp=timestamp,
            severity="critical",
            framework="GDPR",
            remediation="Fix the issue",
            metadata={"key": "value"}
        )
        
        self.assertEqual(violation.id, "test123")
        self.assertEqual(violation.violation_type, "test_violation")
        self.assertEqual(violation.description, "Test description")
        self.assertEqual(violation.user_id, "user456")
        self.assertEqual(violation.timestamp, timestamp)
        self.assertEqual(violation.severity, "critical")
        self.assertEqual(violation.framework, "GDPR")
        self.assertEqual(violation.remediation, "Fix the issue")
        self.assertEqual(violation.metadata["key"], "value")
    
    def test_violation_defaults(self):
        """Test violation creation with default values."""
        violation = ComplianceViolation(
            id="test123",
            violation_type="test_violation",
            description="Test description",
            user_id="user456",
            timestamp=datetime.now()
        )
        
        self.assertEqual(violation.severity, "medium")
        self.assertIsNone(violation.framework)
        self.assertIsNone(violation.remediation)
        self.assertEqual(len(violation.metadata), 0)


class TestGlobalComplianceMonitor(unittest.TestCase):
    """Test global compliance monitor functionality."""
    
    def test_get_compliance_monitor_singleton(self):
        """Test that get_compliance_monitor returns the same instance."""
        monitor1 = get_compliance_monitor()
        monitor2 = get_compliance_monitor()
        
        self.assertIs(monitor1, monitor2)
        self.assertIsInstance(monitor1, ComplianceMonitor)


if __name__ == '__main__':
    unittest.main()
