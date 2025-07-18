"""
Example domain models demonstrating CloudScope compliance-as-code features.

These examples show how to use compliance decorators for different regulatory
frameworks including GDPR, PCI DSS, HIPAA, and SOC 2.
"""

from datetime import datetime
from typing import List, Dict, Any, Optional

from cloudscope.infrastructure.compliance import (
    data_classification,
    encrypted,
    audit_log,
    access_control,
    pci_scope,
)


# GDPR Example - User domain model with personal data handling
class User:
    """User domain model with GDPR compliance."""
    
    def __init__(self, user_id: str, name: str, email: str):
        self.user_id = user_id
        self._name = name
        self._email = email
        self.preferences = {}
        self.created_at = datetime.now()
    
    @property
    @data_classification("personal")
    def name(self) -> str:
        """Get user name (personal data)."""
        return self._name
    
    @name.setter
    @data_classification("personal") 
    @audit_log
    def name(self, value: str) -> None:
        """Set user name (personal data)."""
        self._name = value
    
    @property
    @data_classification("personal")
    def email(self) -> str:
        """Get user email (personal data)."""
        return self._email
    
    @email.setter
    @data_classification("personal")
    @audit_log
    def email(self, value: str) -> None:
        """Set user email (personal data)."""
        self._email = value
    
    @data_classification("personal")
    @audit_log
    def update_contact_info(self, email: str, phone: str = None) -> None:
        """Update user contact information."""
        self.email = email
        if phone:
            self.phone = phone
    
    @audit_log
    def get_data_export(self) -> Dict[str, Any]:
        """
        Get all user data for GDPR data portability requirements.
        """
        return {
            "user_id": self.user_id,
            "name": self.name,
            "email": self.email,
            "preferences": self.preferences,
            "created_at": self.created_at.isoformat()
        }
    
    @audit_log
    @access_control(["admin", "user_manager"])
    def delete_personal_data(self) -> None:
        """
        Delete personal data for GDPR right to be forgotten.
        """
        self._name = "[DELETED]"
        self._email = "[DELETED]"
        self.preferences = {}


# PCI DSS Example - Payment method with card data encryption
@pci_scope
class PaymentMethod:
    """Payment method domain model with PCI DSS compliance."""
    
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
    def set_card_number(self, card_number: str) -> None:
        """Set encrypted card number."""
        self._card_number = card_number
    
    @encrypted
    @audit_log
    def set_cvv(self, cvv: str) -> None:
        """Set encrypted CVV."""
        self._cvv = cvv
    
    @audit_log
    def get_masked_card_number(self) -> str:
        """Get masked card number for display (PCI DSS compliant)."""
        if not self._card_number:
            return ""
        # Only show last 4 digits
        return "****-****-****-" + self._card_number[-4:]
    
    @access_control(["payment_processor", "admin"])
    @audit_log
    def process_payment(self, amount: float) -> Dict[str, Any]:
        """Process payment using stored card data."""
        # Payment processing logic would go here
        return {
            "payment_id": self.payment_id,
            "amount": amount,
            "status": "processed",
            "timestamp": datetime.now().isoformat()
        }
    
    @access_control(["admin", "compliance_officer"])
    @audit_log
    def delete_card_data(self) -> None:
        """Securely delete card data."""
        self._card_number = None
        self._cvv = None


# HIPAA Example - Medical record with health data protection
class MedicalRecord:
    """Medical record domain model with HIPAA compliance."""
    
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
        """Add diagnosis to medical record."""
        self.diagnoses.append({
            "diagnosis": diagnosis,
            "doctor_id": doctor_id,
            "timestamp": datetime.now().isoformat()
        })
    
    @data_classification("health")
    @audit_log
    @access_control(["doctor", "nurse", "medical_staff"])
    def add_treatment(self, treatment: str, doctor_id: str) -> None:
        """Add treatment to medical record."""
        self.treatments.append({
            "treatment": treatment,
            "doctor_id": doctor_id,
            "timestamp": datetime.now().isoformat()
        })
    
    @data_classification("health")
    @audit_log
    @access_control(["doctor", "pharmacist"])
    def add_medication(self, medication: str, dosage: str, doctor_id: str) -> None:
        """Add medication to medical record."""
        self.medications.append({
            "medication": medication,
            "dosage": dosage,
            "prescribed_by": doctor_id,
            "timestamp": datetime.now().isoformat()
        })
    
    @audit_log
    @access_control(["patient", "doctor", "medical_staff"])
    def get_summary(self) -> Dict[str, Any]:
        """Get medical record summary for authorized access."""
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


# SOC 2 Example - System configuration with access controls
class SystemConfiguration:
    """System configuration domain model with SOC 2 compliance."""
    
    def __init__(self, config_id: str):
        self.config_id = config_id
        self.settings = {}
        self.last_modified = datetime.now()
        self.modified_by = None
        self.version = 1
    
    @audit_log
    @access_control(["admin", "system_operator"])
    def update_setting(self, key: str, value: str, user_id: str) -> None:
        """Update system configuration setting."""
        old_value = self.settings.get(key)
        self.settings[key] = value
        self.last_modified = datetime.now()
        self.modified_by = user_id
        self.version += 1
        
        # Log the change for audit purposes
        import logging
        audit_logger = logging.getLogger("cloudscope.audit")
        audit_logger.info(
            f"Configuration changed: {key}",
            extra={
                "config_id": self.config_id,
                "setting_key": key,
                "old_value": old_value,
                "new_value": value,
                "user_id": user_id,
                "timestamp": self.last_modified.isoformat()
            }
        )
    
    @audit_log
    @access_control(["admin"])
    def delete_setting(self, key: str, user_id: str) -> None:
        """Delete a configuration setting."""
        if key in self.settings:
            old_value = self.settings.pop(key)
            self.last_modified = datetime.now()
            self.modified_by = user_id
            self.version += 1
    
    @audit_log
    def get_change_history(self) -> List[Dict[str, Any]]:
        """Get configuration change history for audit purposes."""
        # In a real implementation, this would retrieve from audit logs
        # This is a simplified example
        return [
            {
                "config_id": self.config_id,
                "version": self.version,
                "modified_by": self.modified_by,
                "modified_at": self.last_modified.isoformat(),
                "settings_count": len(self.settings)
            }
        ]
    
    @access_control(["admin", "system_operator", "auditor"])
    def get_configuration(self) -> Dict[str, Any]:
        """Get current configuration (read-only access)."""
        return {
            "config_id": self.config_id,
            "settings": self.settings.copy(),
            "last_modified": self.last_modified.isoformat(),
            "modified_by": self.modified_by,
            "version": self.version
        }


# Example usage and context managers
def example_usage():
    """Demonstrate usage of compliance-enabled domain models."""
    from cloudscope.infrastructure.compliance.context import (
        user_context, gdpr_context, pci_context, hipaa_context, User
    )
    
    # Create example user
    admin_user = User(id="admin123", roles=["admin"], email="admin@example.com")
    doctor_user = User(id="doc456", roles=["doctor"], email="doctor@example.com")
    
    # GDPR Example
    print("=== GDPR Example ===")
    with user_context(admin_user):
        with gdpr_context(lawful_basis="legitimate_interest"):
            user = User("user123", "John Doe", "john@example.com")
            
            # Update user data (will be logged and classified)
            user.update_contact_info("john.doe@example.com")
            
            # Export user data (GDPR data portability)
            user_data = user.get_data_export()
            print(f"User data export: {user_data}")
            
            # Delete personal data (GDPR right to be forgotten)
            user.delete_personal_data()
    
    # PCI DSS Example
    print("\n=== PCI DSS Example ===")
    with user_context(admin_user):
        with pci_context(authorized_access=True):
            payment = PaymentMethod("pay123", "user123")
            
            # Set encrypted card data
            payment.set_card_number("4111111111111111")
            payment.set_cvv("123")
            
            # Get masked card number for display
            masked = payment.get_masked_card_number()
            print(f"Masked card: {masked}")
            
            # Process payment (requires proper authorization)
            result = payment.process_payment(99.99)
            print(f"Payment result: {result}")
    
    # HIPAA Example
    print("\n=== HIPAA Example ===")
    with user_context(doctor_user):
        with hipaa_context(minimum_necessary=True):
            record = MedicalRecord("med123", "patient456")
            
            # Add medical data (will be classified and audited)
            record.add_diagnosis("Common cold", "doc456")
            record.add_treatment("Rest and fluids", "doc456")
            record.add_medication("Acetaminophen", "500mg", "doc456")
            
            # Get summary (access controlled)
            summary = record.get_summary()
            print(f"Medical record summary: {summary}")
    
    # SOC 2 Example
    print("\n=== SOC 2 Example ===")
    with user_context(admin_user):
        config = SystemConfiguration("sys123")
        
        # Update configuration (audited and access controlled)
        config.update_setting("max_users", "1000", "admin123")
        config.update_setting("session_timeout", "30", "admin123")
        
        # Get configuration
        current_config = config.get_configuration()
        print(f"Current config: {current_config}")
        
        # Get change history for audit
        history = config.get_change_history()
        print(f"Change history: {history}")


if __name__ == "__main__":
    example_usage()
