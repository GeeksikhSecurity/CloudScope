#!/usr/bin/env python3
"""
Comprehensive CloudScope Compliance Integration Example

This script demonstrates how to integrate all CloudScope compliance features
into a real-world application, showing GDPR, PCI DSS, HIPAA, and SOC 2
compliance in action.
"""

import os
import sys
import json
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Any

# Add the project root to the path so we can import CloudScope modules
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, project_root)

from cloudscope.infrastructure.compliance import (
    data_classification,
    encrypted,
    audit_log, 
    access_control,
    pci_scope,
)
from cloudscope.infrastructure.compliance.context import (
    User,
    user_context,
    gdpr_context,
    pci_context,
    hipaa_context,
    clear_context,
)
from cloudscope.infrastructure.compliance.monitoring import get_compliance_monitor
from cloudscope.infrastructure.compliance.analysis import ComplianceStaticAnalyzer
from cloudscope.infrastructure.compliance.crypto import generate_key_string


class ComplianceIntegrationExample:
    """Demonstrates comprehensive compliance integration."""
    
    def __init__(self):
        """Initialize the compliance integration example."""
        self.setup_logging()
        self.setup_encryption()
        self.monitor = get_compliance_monitor()
        self.setup_alerts()
        
        # Create test users
        self.admin_user = User(
            id="admin001", 
            roles=["admin", "compliance_officer"], 
            email="admin@cloudscope.example.com"
        )
        self.doctor_user = User(
            id="doc001", 
            roles=["doctor", "medical_staff"], 
            email="doctor@hospital.example.com"
        )
        self.payment_processor = User(
            id="pay001", 
            roles=["payment_processor"], 
            email="payments@cloudscope.example.com"
        )
        
        print("🔒 CloudScope Compliance Integration Example")
        print("=" * 50)
    
    def setup_logging(self):
        """Set up structured logging for compliance operations."""
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
        )
        
        # Set up audit logger
        audit_logger = logging.getLogger("cloudscope.audit")
        audit_handler = logging.FileHandler("audit.log")
        audit_formatter = logging.Formatter(
            '%(asctime)s - AUDIT - %(levelname)s - %(message)s'
        )
        audit_handler.setFormatter(audit_formatter)
        audit_logger.addHandler(audit_handler)
        audit_logger.setLevel(logging.INFO)
        
        print("✅ Logging configured")
    
    def setup_encryption(self):
        """Set up encryption key for sensitive data."""
        if not os.getenv('CLOUDSCOPE_ENCRYPTION_KEY'):
            # Generate a key for demonstration purposes
            key = generate_key_string()
            os.environ['CLOUDSCOPE_ENCRYPTION_KEY'] = key
            print(f"🔑 Generated encryption key: {key[:20]}...")
        else:
            print("🔑 Using existing encryption key")
    
    def setup_alerts(self):
        """Set up compliance violation alerts."""
        def compliance_alert(violation):
            """Alert handler for compliance violations."""
            print(f"🚨 COMPLIANCE ALERT: {violation.violation_type}")
            print(f"   Framework: {violation.framework}")
            print(f"   Severity: {violation.severity}")
            print(f"   User: {violation.user_id}")
            print(f"   Description: {violation.description}")
            if violation.remediation:
                print(f"   Remediation: {violation.remediation}")
            print()
        
        self.monitor.add_alert_callback(compliance_alert)
        print("✅ Compliance alerts configured")
    
    def demonstrate_gdpr_compliance(self):
        """Demonstrate GDPR compliance features."""
        print("\n📋 GDPR Compliance Demonstration")
        print("-" * 40)
        
        # GDPR-compliant user model
        class GDPRUser:
            def __init__(self, user_id: str, name: str, email: str):
                self.user_id = user_id
                self._name = name
                self._email = email
                self.preferences = {}
                self.created_at = datetime.now()
            
            @property
            @data_classification("personal")
            def name(self) -> str:
                return self._name
            
            @name.setter
            @data_classification("personal")
            @audit_log
            def name(self, value: str) -> None:
                self._name = value
            
            @property
            @data_classification("personal") 
            def email(self) -> str:
                return self._email
            
            @email.setter
            @data_classification("personal")
            @audit_log
            def email(self, value: str) -> None:
                self._email = value
            
            @data_classification("personal")
            @audit_log
            def update_preferences(self, preferences: Dict[str, Any]) -> None:
                """Update user preferences (personal data)."""
                self.preferences.update(preferences)
            
            @audit_log
            def get_data_export(self) -> Dict[str, Any]:
                """GDPR Article 20 - Right to data portability."""
                return {
                    "user_id": self.user_id,
                    "name": self.name,
                    "email": self.email,
                    "preferences": self.preferences,
                    "created_at": self.created_at.isoformat()
                }
            
            @access_control(["admin", "data_protection_officer"])
            @audit_log
            def delete_personal_data(self) -> None:
                """GDPR Article 17 - Right to erasure (right to be forgotten)."""
                self._name = "[DELETED]"
                self._email = "[DELETED]"
                self.preferences = {}
        
        # Demonstrate GDPR compliance in action
        with user_context(self.admin_user):
            with gdpr_context(lawful_basis="consent"):
                print("Creating GDPR-compliant user...")
                user = GDPRUser("user123", "John Doe", "john@example.com")
                
                print("Updating personal data...")
                user.name = "John Smith"
                user.email = "john.smith@example.com"
                user.update_preferences({"newsletter": True, "language": "en"})
                
                print("Exercising data portability rights...")
                export_data = user.get_data_export()
                print(f"Exported data: {json.dumps(export_data, indent=2)}")
                
                print("Exercising right to be forgotten...")
                user.delete_personal_data()
                print(f"After deletion - Name: {user.name}, Email: {user.email}")
        
        # Check compliance
        is_compliant = self.monitor.check_data_access("personal", "admin001", "update")
        print(f"✅ GDPR compliance check: {'PASSED' if is_compliant else 'FAILED'}")
    
    def demonstrate_pci_compliance(self):
        """Demonstrate PCI DSS compliance features."""
        print("\n💳 PCI DSS Compliance Demonstration")
        print("-" * 40)
        
        @pci_scope
        class PCIPaymentMethod:
            def __init__(self, payment_id: str, user_id: str):
                self.payment_id = payment_id
                self.user_id = user_id
                self._card_number = None
                self._cvv = None
                self.expiry_month = None
                self.expiry_year = None
                self.created_at = datetime.now()
            
            @encrypted
            @audit_log
            @access_control(["payment_processor", "admin"])
            def set_card_number(self, card_number: str) -> None:
                """PCI DSS Requirement 3.4 - Encrypt cardholder data."""
                self._card_number = card_number
            
            @encrypted
            @audit_log
            @access_control(["payment_processor", "admin"])
            def set_cvv(self, cvv: str) -> None:
                """PCI DSS Requirement 3.4 - Encrypt sensitive authentication data."""
                self._cvv = cvv
            
            @audit_log
            def get_masked_card_number(self) -> str:
                """PCI DSS Requirement 3.3 - Mask cardholder data when displayed."""
                if not self._card_number:
                    return ""
                # Show only last 4 digits
                return "****-****-****-" + self._card_number[-4:]
            
            @access_control(["payment_processor"])
            @audit_log
            def process_payment(self, amount: float) -> Dict[str, Any]:
                """Process payment with PCI DSS compliance."""
                return {
                    "payment_id": self.payment_id,
                    "amount": amount,
                    "status": "processed",
                    "timestamp": datetime.now().isoformat(),
                    "masked_card": self.get_masked_card_number()
                }
            
            @access_control(["admin", "compliance_officer"])
            @audit_log
            def secure_delete(self) -> None:
                """PCI DSS Requirement 3.2 - Secure deletion of cardholder data."""
                self._card_number = None
                self._cvv = None
        
        # Demonstrate PCI DSS compliance in action
        with user_context(self.payment_processor):
            with pci_context(authorized_access=True):
                print("Creating PCI DSS-compliant payment method...")
                payment = PCIPaymentMethod("pay123", "user123")
                
                print("Storing encrypted card data...")
                payment.set_card_number("4111111111111111")
                payment.set_cvv("123")
                payment.expiry_month = 12
                payment.expiry_year = 2025
                
                print("Processing payment...")
                result = payment.process_payment(99.99)
                print(f"Payment result: {json.dumps(result, indent=2)}")
                
                print("Displaying masked card number...")
                masked = payment.get_masked_card_number()
                print(f"Masked card: {masked}")
                
                # Switch to admin user for secure deletion
                with user_context(self.admin_user):
                    print("Performing secure deletion...")
                    payment.secure_delete()
        
        # Check PCI compliance
        is_compliant = self.monitor.check_encryption_compliance("financial", True)
        print(f"✅ PCI DSS compliance check: {'PASSED' if is_compliant else 'FAILED'}")
    
    def demonstrate_hipaa_compliance(self):
        """Demonstrate HIPAA compliance features."""
        print("\n🏥 HIPAA Compliance Demonstration")
        print("-" * 40)
        
        class HIPAAMedicalRecord:
            def __init__(self, record_id: str, patient_id: str):
                self.record_id = record_id
                self.patient_id = patient_id
                self.diagnoses = []
                self.treatments = []
                self.medications = []
                self.created_at = datetime.now()
            
            @data_classification("health")
            @audit_log
            @access_control(["doctor", "nurse", "medical_staff"])
            def add_diagnosis(self, diagnosis: str, doctor_id: str) -> None:
                """Add diagnosis with HIPAA compliance."""
                self.diagnoses.append({
                    "diagnosis": diagnosis,
                    "doctor_id": doctor_id,
                    "timestamp": datetime.now().isoformat()
                })
            
            @data_classification("health")
            @audit_log
            @access_control(["doctor", "nurse", "medical_staff"])
            def add_treatment(self, treatment: str, doctor_id: str) -> None:
                """Add treatment with HIPAA compliance."""
                self.treatments.append({
                    "treatment": treatment,
                    "doctor_id": doctor_id,
                    "timestamp": datetime.now().isoformat()
                })
            
            @data_classification("health")
            @audit_log
            @access_control(["doctor", "pharmacist"])
            def prescribe_medication(self, medication: str, dosage: str, doctor_id: str) -> None:
                """Prescribe medication with HIPAA compliance."""
                self.medications.append({
                    "medication": medication,
                    "dosage": dosage,
                    "prescribed_by": doctor_id,
                    "timestamp": datetime.now().isoformat()
                })
            
            @audit_log
            @access_control(["patient", "doctor", "medical_staff"])
            def get_summary(self) -> Dict[str, Any]:
                """Get medical record summary (minimum necessary principle)."""
                return {
                    "record_id": self.record_id,
                    "patient_id": self.patient_id,
                    "diagnosis_count": len(self.diagnoses),
                    "treatment_count": len(self.treatments),
                    "medication_count": len(self.medications),
                    "last_updated": max(
                        [d["timestamp"] for d in self.diagnoses] + 
                        [t["timestamp"] for t in self.treatments] +
                        [m["timestamp"] for m in self.medications],
                        default=self.created_at.isoformat()
                    )
                }
        
        # Demonstrate HIPAA compliance in action
        with user_context(self.doctor_user):
            with hipaa_context(minimum_necessary=True):
                print("Creating HIPAA-compliant medical record...")
                record = HIPAAMedicalRecord("med123", "patient456")
                
                print("Adding medical information...")
                record.add_diagnosis("Type 2 Diabetes", "doc001")
                record.add_treatment("Dietary modification", "doc001")
                record.prescribe_medication("Metformin", "500mg twice daily", "doc001")
                
                print("Getting record summary (minimum necessary)...")
                summary = record.get_summary()
                print(f"Record summary: {json.dumps(summary, indent=2)}")
        
        # Check HIPAA compliance
        is_compliant = self.monitor.check_data_access("health", "doc001", "read")
        print(f"✅ HIPAA compliance check: {'PASSED' if is_compliant else 'FAILED'}")
    
    def demonstrate_soc2_compliance(self):
        """Demonstrate SOC 2 compliance features."""
        print("\n🛡️ SOC 2 Compliance Demonstration")
        print("-" * 40)
        
        class SOC2SystemConfiguration:
            def __init__(self, config_id: str):
                self.config_id = config_id
                self.settings = {}
                self.last_modified = datetime.now()
                self.modified_by = None
                self.version = 1
                self.change_history = []
            
            @audit_log
            @access_control(["admin", "system_operator"])
            def update_setting(self, key: str, value: str, user_id: str) -> None:
                """Update system configuration with SOC 2 controls."""
                old_value = self.settings.get(key)
                self.settings[key] = value
                self.last_modified = datetime.now()
                self.modified_by = user_id
                self.version += 1
                
                # Record change for audit trail
                self.change_history.append({
                    "key": key,
                    "old_value": old_value,
                    "new_value": value,
                    "user_id": user_id,
                    "timestamp": self.last_modified.isoformat(),
                    "version": self.version
                })
            
            @audit_log
            @access_control(["admin"])
            def delete_setting(self, key: str, user_id: str) -> None:
                """Delete configuration setting with proper authorization."""
                if key in self.settings:
                    old_value = self.settings.pop(key)
                    self.last_modified = datetime.now()
                    self.modified_by = user_id
                    self.version += 1
                    
                    self.change_history.append({
                        "key": key,
                        "old_value": old_value,
                        "new_value": None,
                        "action": "delete",
                        "user_id": user_id,
                        "timestamp": self.last_modified.isoformat(),
                        "version": self.version
                    })
            
            @audit_log
            @access_control(["admin", "system_operator", "auditor"])
            def get_audit_trail(self) -> List[Dict[str, Any]]:
                """Get complete audit trail for SOC 2 compliance."""
                return self.change_history
            
            @access_control(["admin", "system_operator", "readonly"])
            def get_configuration(self) -> Dict[str, Any]:
                """Get current configuration (read-only access)."""
                return {
                    "config_id": self.config_id,
                    "settings": self.settings.copy(),
                    "last_modified": self.last_modified.isoformat(),
                    "modified_by": self.modified_by,
                    "version": self.version
                }
        
        # Demonstrate SOC 2 compliance in action
        with user_context(self.admin_user):
            print("Creating SOC 2-compliant system configuration...")
            config = SOC2SystemConfiguration("sys123")
            
            print("Updating system settings...")
            config.update_setting("max_login_attempts", "3", "admin001")
            config.update_setting("session_timeout", "30", "admin001")
            config.update_setting("encryption_enabled", "true", "admin001")
            
            print("Getting current configuration...")
            current_config = config.get_configuration()
            print(f"Configuration: {json.dumps(current_config, indent=2)}")
            
            print("Getting audit trail...")
            audit_trail = config.get_audit_trail()
            print(f"Audit trail entries: {len(audit_trail)}")
            for entry in audit_trail:
                print(f"  {entry['timestamp']}: {entry['key']} changed by {entry['user_id']}")
        
        # Check SOC 2 compliance
        is_compliant = self.monitor.check_access_control_compliance("system_config", ["admin"])
        print(f"✅ SOC 2 compliance check: {'PASSED' if is_compliant else 'FAILED'}")
    
    def generate_compliance_dashboard(self):
        """Generate a comprehensive compliance dashboard."""
        print("\n📊 Compliance Dashboard")
        print("-" * 40)
        
        # Get compliance metrics
        metrics = self.monitor.get_metrics(24)  # Last 24 hours
        
        print(f"Overall compliance rate: {metrics.compliance_rate:.1f}%")
        print(f"Total operations: {metrics.total_operations}")
        print(f"Compliant operations: {metrics.compliant_operations}")
        print(f"Violations: {metrics.violation_count}")
        
        if metrics.violations_by_framework:
            print("\nViolations by framework:")
            for framework, count in metrics.violations_by_framework.items():
                print(f"  {framework}: {count}")
        
        if metrics.violations_by_type:
            print("\nViolations by type:")
            for violation_type, count in metrics.violations_by_type.items():
                print(f"  {violation_type}: {count}")
        
        # Get recent violations
        violations = self.monitor.get_violations()
        if violations:
            print(f"\nRecent violations ({len(violations)}):")
            for violation in violations[-5:]:  # Last 5 violations
                print(f"  {violation.timestamp.strftime('%H:%M:%S')} - "
                      f"{violation.framework} - {violation.violation_type}")
        else:
            print("\n✅ No violations found!")
    
    def run_static_analysis(self):
        """Run static compliance analysis on the codebase."""
        print("\n🔍 Static Compliance Analysis")
        print("-" * 40)
        
        analyzer = ComplianceStaticAnalyzer()
        
        # Analyze the examples directory
        examples_dir = os.path.join(project_root, "examples")
        if os.path.exists(examples_dir):
            print(f"Analyzing {examples_dir}...")
            report = analyzer.analyze_directory(examples_dir)
            
            print(f"Files analyzed: {report.total_files_analyzed}")
            print(f"Compliance score: {report.compliance_score:.1f}%")
            print(f"Issues found: {len(report.issues_found)}")
            
            if report.framework_scores:
                print("\nFramework scores:")
                for framework, score in report.framework_scores.items():
                    print(f"  {framework}: {score:.1f}%")
            
            if report.issues_found:
                print(f"\nTop issues:")
                for issue in report.issues_found[:3]:  # Show top 3 issues
                    print(f"  {issue.severity}: {issue.description}")
                    print(f"    File: {issue.file_path}:{issue.line_number}")
        else:
            print("Examples directory not found, skipping static analysis")
    
    def run_comprehensive_demo(self):
        """Run the comprehensive compliance demonstration."""
        try:
            print("Starting comprehensive compliance demonstration...\n")
            
            # Clear any existing context
            clear_context()
            
            # Run all demonstrations
            self.demonstrate_gdpr_compliance()
            self.demonstrate_pci_compliance()
            self.demonstrate_hipaa_compliance()
            self.demonstrate_soc2_compliance()
            
            # Generate dashboard and analysis
            self.generate_compliance_dashboard()
            self.run_static_analysis()
            
            print("\n🎉 Compliance demonstration completed successfully!")
            print("\nKey achievements:")
            print("✅ GDPR personal data protection demonstrated")
            print("✅ PCI DSS payment card data encryption verified")
            print("✅ HIPAA health information protection validated")
            print("✅ SOC 2 access controls and audit trails confirmed")
            print("✅ Real-time compliance monitoring active")
            print("✅ Static analysis compliance scoring implemented")
            
        except Exception as e:
            print(f"\n❌ Error during compliance demonstration: {str(e)}")
            import traceback
            traceback.print_exc()
            return False
        
        finally:
            # Clean up context
            clear_context()
        
        return True


def main():
    """Main entry point for the compliance integration example."""
    print("CloudScope Compliance-as-Code Integration Example")
    print("================================================")
    print()
    print("This example demonstrates how CloudScope integrates compliance")
    print("requirements directly into code using decorators and runtime")
    print("monitoring for GDPR, PCI DSS, HIPAA, and SOC 2 frameworks.")
    print()
    
    # Check if we're in the right directory
    if not os.path.exists(os.path.join(project_root, "cloudscope")):
        print("❌ Error: Please run this script from the CloudScope project root directory")
        sys.exit(1)
    
    # Run the demonstration
    demo = ComplianceIntegrationExample()
    success = demo.run_comprehensive_demo()
    
    if success:
        print("\n📚 Next steps:")
        print("1. Review the audit.log file for detailed compliance logs")
        print("2. Explore the compliance CLI commands: python -m cloudscope.cli.compliance_commands --help")
        print("3. Run Kiro compliance checks: python .kiro/rules/check_compliance.py .")
        print("4. Integrate compliance monitoring into your production systems")
        print("5. Set up automated compliance reporting and alerting")
        
        return 0
    else:
        return 1


if __name__ == "__main__":
    sys.exit(main())
