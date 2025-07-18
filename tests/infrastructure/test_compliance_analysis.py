"""
Tests for CloudScope compliance static analysis.
"""

import unittest
import tempfile
import os
from pathlib import Path

from cloudscope.infrastructure.compliance.analysis import (
    ComplianceStaticAnalyzer,
    ComplianceIssue,
    ComplianceReport,
)


class TestComplianceStaticAnalyzer(unittest.TestCase):
    """Test compliance static analysis functionality."""
    
    def setUp(self):
        """Set up test fixtures."""
        self.analyzer = ComplianceStaticAnalyzer()
        self.temp_dir = tempfile.mkdtemp()
    
    def tearDown(self):
        """Clean up test fixtures."""
        # Clean up temporary files
        import shutil
        shutil.rmtree(self.temp_dir, ignore_errors=True)
    
    def _create_test_file(self, filename: str, content: str) -> str:
        """Create a test file with the given content."""
        file_path = os.path.join(self.temp_dir, filename)
        with open(file_path, 'w') as f:
            f.write(content)
        return file_path
    
    def test_analyze_gdpr_compliance_issues(self):
        """Test detection of GDPR compliance issues."""
        code_content = '''
class User:
    def __init__(self, name: str, email: str):
        self.name = name  # Personal data without classification
        self.email = email  # Personal data without classification
    
    def update_email(self, email: str):
        """Update user email - handles personal data."""
        self.email = email
'''
        
        file_path = self._create_test_file("user_model.py", code_content)
        issues = self.analyzer.analyze_file(file_path)
        
        # Should find issues for unclassified personal data
        gdpr_issues = [issue for issue in issues if issue.framework == "GDPR"]
        self.assertGreater(len(gdpr_issues), 0)
        
        # Check specific issue types
        classification_issues = [
            issue for issue in gdpr_issues 
            if issue.issue_type == "missing_data_classification"
        ]
        self.assertGreater(len(classification_issues), 0)
    
    def test_analyze_pci_compliance_issues(self):
        """Test detection of PCI DSS compliance issues."""
        code_content = '''
class PaymentMethod:
    def __init__(self, card_number: str):
        self.card_number = card_number  # Card data without encryption
    
    def set_cvv(self, cvv: str):
        self.cvv = cvv  # CVV without encryption
'''
        
        file_path = self._create_test_file("payment_model.py", code_content)
        issues = self.analyzer.analyze_file(file_path)
        
        # Should find PCI DSS issues
        pci_issues = [issue for issue in issues if issue.framework == "PCI_DSS"]
        self.assertGreater(len(pci_issues), 0)
        
        # Check for missing PCI scope decorator
        scope_issues = [
            issue for issue in pci_issues 
            if issue.issue_type == "missing_pci_scope"
        ]
        self.assertGreater(len(scope_issues), 0)
    
    def test_analyze_hipaa_compliance_issues(self):
        """Test detection of HIPAA compliance issues."""
        code_content = '''
class MedicalRecord:
    def __init__(self, patient_id: str, diagnosis: str):
        self.patient_id = patient_id
        self.diagnosis = diagnosis  # Health data without classification
    
    def add_medical_history(self, history: str):
        """Add medical history - handles health data."""
        self.medical_history = history
'''
        
        file_path = self._create_test_file("medical_model.py", code_content)
        issues = self.analyzer.analyze_file(file_path)
        
        # Should find HIPAA issues
        hipaa_issues = [issue for issue in issues if issue.framework == "HIPAA"]
        self.assertGreater(len(hipaa_issues), 0)
        
        # Check for missing health data classification
        classification_issues = [
            issue for issue in hipaa_issues 
            if issue.issue_type == "missing_health_classification"
        ]
        self.assertGreater(len(classification_issues), 0)
    
    def test_analyze_general_security_issues(self):
        """Test detection of general security issues."""
        code_content = '''
class SystemConfig:
    def __init__(self):
        self.api_key = "hardcoded_secret_key"  # Hardcoded secret
        self.password = "admin123"  # Hardcoded password
    
    def delete_all_data(self):
        """Delete all data - admin function without access control."""
        pass
    
    def admin_reset(self):
        """Reset system - admin function without access control.""" 
        pass
'''
        
        file_path = self._create_test_file("config_model.py", code_content)
        issues = self.analyzer.analyze_file(file_path)
        
        # Should find general security issues
        security_issues = [
            issue for issue in issues 
            if issue.framework in ["GENERAL", "SOC2"]
        ]
        self.assertGreater(len(security_issues), 0)
        
        # Check for hardcoded secrets
        secret_issues = [
            issue for issue in security_issues
            if issue.issue_type == "hardcoded_secret"
        ]
        self.assertGreater(len(secret_issues), 0)
        
        # Check for missing access control
        access_issues = [
            issue for issue in security_issues
            if issue.issue_type == "missing_access_control"
        ]
        self.assertGreater(len(access_issues), 0)
    
    def test_analyze_compliant_code(self):
        """Test analysis of properly compliant code."""
        code_content = '''
from cloudscope.infrastructure.compliance import (
    data_classification, encrypted, audit_log, access_control, pci_scope
)

@pci_scope
class PaymentMethod:
    def __init__(self, payment_id: str):
        self.payment_id = payment_id
        self._card_number = None
    
    @encrypted
    @audit_log
    def set_card_number(self, card_number: str):
        self._card_number = card_number

class User:
    def __init__(self, user_id: str):
        self.user_id = user_id
        self._email = None
    
    @data_classification("personal")
    @audit_log
    def set_email(self, email: str):
        self._email = email
    
    @access_control(["admin"])
    @audit_log
    def delete_user_data(self):
        pass
'''
        
        file_path = self._create_test_file("compliant_model.py", code_content)
        issues = self.analyzer.analyze_file(file_path)
        
        # Should find minimal or no issues in compliant code
        critical_issues = [
            issue for issue in issues if issue.severity == "critical"
        ]
        self.assertEqual(len(critical_issues), 0)
        
        error_issues = [
            issue for issue in issues if issue.severity == "error"
        ]
        # Might have some minor issues, but should be minimal
        self.assertLess(len(error_issues), 3)
    
    def test_analyze_syntax_error_handling(self):
        """Test handling of files with syntax errors."""
        code_content = '''
class BrokenClass:
    def __init__(self
        # Missing closing parenthesis
        self.data = "test"
'''
        
        file_path = self._create_test_file("broken_file.py", code_content)
        issues = self.analyzer.analyze_file(file_path)
        
        # Should have a syntax error issue
        syntax_issues = [
            issue for issue in issues if issue.issue_type == "syntax_error"
        ]
        self.assertEqual(len(syntax_issues), 1)
        self.assertEqual(syntax_issues[0].severity, "error")
    
    def test_analyze_directory(self):
        """Test directory analysis functionality."""
        # Create multiple test files
        files = {
            "user.py": '''
class User:
    def __init__(self, name: str, email: str):
        self.name = name  # Personal data
        self.email = email  # Personal data
''',
            "payment.py": '''
class Payment:
    def __init__(self, card_number: str):
        self.card_number = card_number  # Card data
''',
            "test_file.py": '''
# This is a test file that should be excluded
def test_function():
    pass
''',
            "__pycache__/cached.py": '''
# This should be excluded
'''
        }
        
        # Create subdirectory for cache file
        cache_dir = os.path.join(self.temp_dir, "__pycache__")
        os.makedirs(cache_dir, exist_ok=True)
        
        for filename, content in files.items():
            full_path = os.path.join(self.temp_dir, filename)
            os.makedirs(os.path.dirname(full_path), exist_ok=True)
            with open(full_path, 'w') as f:
                f.write(content)
        
        # Analyze directory
        report = self.analyzer.analyze_directory(
            self.temp_dir,
            exclude_patterns=['test_*', '__pycache__']
        )
        
        # Verify report structure
        self.assertIsInstance(report, ComplianceReport)
        self.assertEqual(report.total_files_analyzed, 2)  # user.py and payment.py
        self.assertGreater(len(report.issues_found), 0)
        self.assertLessEqual(report.compliance_score, 100.0)
        self.assertGreaterEqual(report.compliance_score, 0.0)
        
        # Check framework scores
        self.assertIsInstance(report.framework_scores, dict)
    
    def test_compliance_issue_creation(self):
        """Test ComplianceIssue creation and properties."""
        issue = ComplianceIssue(
            file_path="/test/file.py",
            line_number=10,
            issue_type="test_issue",
            description="Test description",
            severity="error",
            framework="GDPR",
            recommendation="Fix the issue",
            code_snippet="test_code = 'value'"
        )
        
        self.assertEqual(issue.file_path, "/test/file.py")
        self.assertEqual(issue.line_number, 10)
        self.assertEqual(issue.issue_type, "test_issue")
        self.assertEqual(issue.description, "Test description")
        self.assertEqual(issue.severity, "error")
        self.assertEqual(issue.framework, "GDPR")
        self.assertEqual(issue.recommendation, "Fix the issue")
        self.assertEqual(issue.code_snippet, "test_code = 'value'")
    
    def test_compliance_report_filtering(self):
        """Test ComplianceReport filtering methods."""
        issues = [
            ComplianceIssue(
                file_path="test1.py", line_number=1, issue_type="type1",
                description="desc1", severity="critical", framework="GDPR",
                recommendation="fix1"
            ),
            ComplianceIssue(
                file_path="test2.py", line_number=2, issue_type="type2",
                description="desc2", severity="error", framework="PCI_DSS",
                recommendation="fix2"
            ),
            ComplianceIssue(
                file_path="test3.py", line_number=3, issue_type="type3",
                description="desc3", severity="warning", framework="GDPR",
                recommendation="fix3"
            ),
        ]
        
        report = ComplianceReport(
            total_files_analyzed=3,
            issues_found=issues,
            compliance_score=75.0,
            framework_scores={"GDPR": 80.0, "PCI_DSS": 70.0}
        )
        
        # Test filtering by severity
        critical_issues = report.get_issues_by_severity("critical")
        self.assertEqual(len(critical_issues), 1)
        self.assertEqual(critical_issues[0].severity, "critical")
        
        # Test filtering by framework
        gdpr_issues = report.get_issues_by_framework("GDPR")
        self.assertEqual(len(gdpr_issues), 2)
        for issue in gdpr_issues:
            self.assertEqual(issue.framework, "GDPR")
    
    def test_pattern_matching(self):
        """Test that pattern matching works correctly."""
        # Test personal data patterns
        personal_patterns = self.analyzer.personal_data_patterns
        
        test_cases = [
            ("user_name", True),
            ("email_address", True),
            ("home_address", True),
            ("phone_number", True),
            ("random_data", False),
            ("config_value", False),
        ]
        
        import re
        for field_name, should_match in test_cases:
            matches = any(
                re.match(pattern, field_name.lower()) 
                for pattern in personal_patterns
            )
            if should_match:
                self.assertTrue(matches, f"'{field_name}' should match personal data patterns")
            else:
                self.assertFalse(matches, f"'{field_name}' should not match personal data patterns")


if __name__ == '__main__':
    unittest.main()
