# Compliance as Code for CloudScope Modular Architecture

## Overview

This document outlines how CloudScope implements Compliance as Code (CaC) principles within its modular architecture. Compliance as Code treats compliance requirements as software artifacts that can be versioned, tested, and automatically enforced, reducing the manual effort required for compliance activities and ensuring consistent application of compliance controls.

## Compliance Framework Integration

CloudScope's modular architecture integrates compliance requirements directly into the development workflow through Kiro rules, automated checks, and code annotations. This approach ensures that compliance is not an afterthought but is built into the system from the beginning.

## Regulatory Frameworks Supported

The compliance as code implementation supports the following regulatory frameworks:

### 1. GDPR (General Data Protection Regulation)

```python
# Example domain model with GDPR compliance annotations
from cloudscope.compliance import data_classification

class User:
    """User domain model with GDPR compliance."""
    
    @data_classification("personal")
    def __init__(self, user_id: str, name: str, email: str):
        self.user_id = user_id
        self.name = name  # Personal data
        self.email = email  # Personal data
        self.preferences = {}
    
    @data_classification("personal")
    def update_contact_info(self, email: str, phone: str = None):
        """Update user contact information."""
        self.email = email
        if phone:
            self.phone = phone
    
    def get_data_export(self) -> dict:
        """
        Get all user data for GDPR data portability requirements.
        """
        return {
            "user_id": self.user_id,
            "name": self.name,
            "email": self.email,
            "preferences": self.preferences,
            **getattr(self, "__dict__", {})
        }
```

### 2. PCI DSS (Payment Card Industry Data Security Standard)

```python
# Example domain model with PCI DSS compliance annotations
from cloudscope.compliance import encrypted, pci_scope

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
    
    @encrypted
    def set_card_number(self, card_number: str):
        """Set encrypted card number."""
        self._card_number = card_number
    
    @encrypted
    def set_cvv(self, cvv: str):
        """Set encrypted CVV."""
        self._cvv = cvv
    
    def get_masked_card_number(self) -> str:
        """Get masked card number for display (PCI DSS compliant)."""
        if not self._card_number:
            return ""
        # Only show last 4 digits
        return "****-****-****-" + self._card_number[-4:]
```

### 3. HIPAA (Health Insurance Portability and Accountability Act)

```python
# Example domain model with HIPAA compliance annotations
from cloudscope.compliance import data_classification, audit_access

class MedicalRecord:
    """Medical record domain model with HIPAA compliance."""
    
    @data_classification("health")
    def __init__(self, record_id: str, patient_id: str):
        self.record_id = record_id
        self.patient_id = patient_id
        self.diagnoses = []
        self.treatments = []
        self.medications = []
    
    @data_classification("health")
    @audit_access
    def add_diagnosis(self, diagnosis: str, doctor_id: str):
        """Add diagnosis to medical record."""
        self.diagnoses.append({
            "diagnosis": diagnosis,
            "doctor_id": doctor_id,
            "timestamp": datetime.now().isoformat()
        })
    
    @data_classification("health")
    @audit_access
    def add_treatment(self, treatment: str, doctor_id: str):
        """Add treatment to medical record."""
        self.treatments.append({
            "treatment": treatment,
            "doctor_id": doctor_id,
            "timestamp": datetime.now().isoformat()
        })
```

### 4. SOC 2 (Service Organization Control 2)

```python
# Example domain model with SOC 2 compliance annotations
from cloudscope.compliance import audit_log, access_control

class SystemConfiguration:
    """System configuration domain model with SOC 2 compliance."""
    
    def __init__(self, config_id: str):
        self.config_id = config_id
        self.settings = {}
        self.last_modified = datetime.now().isoformat()
        self.modified_by = None
    
    @audit_log
    @access_control(["admin"])
    def update_setting(self, key: str, value: str, user_id: str):
        """Update system configuration setting."""
        self.settings[key] = value
        self.last_modified = datetime.now().isoformat()
        self.modified_by = user_id
    
    @audit_log
    def get_change_history(self) -> List[dict]:
        """Get configuration change history for audit purposes."""
        # Implementation would retrieve from audit log
        pass
```

## Compliance Controls Implementation

### 1. Data Classification

The data classification system categorizes data based on sensitivity and regulatory requirements:

```python
# Implementation of data classification decorator
def data_classification(classification_type: str):
    """
    Decorator for classifying data according to compliance requirements.
    
    Args:
        classification_type: Type of data classification (personal, health, financial, etc.)
    """
    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            # Log access to classified data
            logger.info(
                f"Accessing {classification_type} data",
                extra={
                    "classification": classification_type,
                    "function": func.__name__,
                    "timestamp": datetime.now().isoformat()
                }
            )
            
            # Execute function
            result = func(*args, **kwargs)
            
            # Apply additional controls based on classification
            if classification_type == "personal":
                # Apply GDPR controls
                pass
            elif classification_type == "health":
                # Apply HIPAA controls
                pass
            elif classification_type == "financial":
                # Apply PCI DSS controls
                pass
            
            return result
        
        # Add metadata to function for static analysis
        wrapper.__compliance_classification__ = classification_type
        return wrapper
    
    return decorator
```

### 2. Encryption

The encryption system ensures that sensitive data is properly encrypted:

```python
# Implementation of encryption decorator
def encrypted(func):
    """
    Decorator for encrypting sensitive data.
    """
    @wraps(func)
    def wrapper(self, value, *args, **kwargs):
        # Get encryption key from secure storage
        encryption_key = get_encryption_key()
        
        # Encrypt value
        encrypted_value = encrypt(value, encryption_key)
        
        # Call original function with encrypted value
        return func(self, encrypted_value, *args, **kwargs)
    
    # Add metadata to function for static analysis
    wrapper.__encrypted__ = True
    return wrapper
```

### 3. Audit Logging

The audit logging system records all security-relevant events:

```python
# Implementation of audit logging decorator
def audit_log(func):
    """
    Decorator for audit logging of security-relevant operations.
    """
    @wraps(func)
    def wrapper(*args, **kwargs):
        # Get current user from context
        current_user = get_current_user()
        
        # Log operation start
        audit_logger.info(
            f"Operation started: {func.__name__}",
            extra={
                "operation": func.__name__,
                "user_id": current_user.id if current_user else "system",
                "timestamp": datetime.now().isoformat(),
                "status": "started"
            }
        )
        
        try:
            # Execute function
            result = func(*args, **kwargs)
            
            # Log operation success
            audit_logger.info(
                f"Operation completed: {func.__name__}",
                extra={
                    "operation": func.__name__,
                    "user_id": current_user.id if current_user else "system",
                    "timestamp": datetime.now().isoformat(),
                    "status": "completed"
                }
            )
            
            return result
        except Exception as e:
            # Log operation failure
            audit_logger.error(
                f"Operation failed: {func.__name__}",
                extra={
                    "operation": func.__name__,
                    "user_id": current_user.id if current_user else "system",
                    "timestamp": datetime.now().isoformat(),
                    "status": "failed",
                    "error": str(e)
                }
            )
            raise
    
    # Add metadata to function for static analysis
    wrapper.__audit_logged__ = True
    return wrapper
```

### 4. Access Control

The access control system enforces proper authorization:

```python
# Implementation of access control decorator
def access_control(required_roles: List[str]):
    """
    Decorator for enforcing access control based on user roles.
    
    Args:
        required_roles: List of roles that are allowed to access the function
    """
    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            # Get current user from context
            current_user = get_current_user()
            
            # Check if user has required role
            if not current_user:
                raise UnauthorizedError("Authentication required")
            
            if not any(role in current_user.roles for role in required_roles):
                raise ForbiddenError(f"Required roles: {', '.join(required_roles)}")
            
            # Execute function
            return func(*args, **kwargs)
        
        # Add metadata to function for static analysis
        wrapper.__required_roles__ = required_roles
        return wrapper
    
    return decorator
```

## Compliance Verification

### 1. Static Analysis

Static analysis tools verify compliance requirements during development:

```python
# Example static analysis for compliance
def check_gdpr_compliance(module_path: str) -> List[str]:
    """
    Check GDPR compliance in a module.
    
    Args:
        module_path: Path to the module to check
    
    Returns:
        List of compliance issues found
    """
    issues = []
    
    # Parse module AST
    with open(module_path, 'r') as f:
        tree = ast.parse(f.read())
    
    # Check for personal data without classification
    for node in ast.walk(tree):
        if isinstance(node, ast.ClassDef):
            # Check class attributes
            for attr in node.body:
                if isinstance(attr, ast.AnnAssign):
                    attr_name = attr.target.id
                    if any(personal_data in attr_name.lower() for personal_data in ["name", "email", "address", "phone"]):
                        # Check if attribute has data classification
                        if not has_data_classification(attr, "personal"):
                            issues.append(f"Personal data '{attr_name}' in class '{node.name}' is not classified")
    
    return issues
```

### 2. Runtime Verification

Runtime verification ensures compliance during system operation:

```python
# Example runtime verification for compliance
class ComplianceMonitor:
    """Monitor for runtime compliance verification."""
    
    def __init__(self):
        self.violations = []
    
    def check_data_access(self, data_type: str, user_id: str, operation: str):
        """
        Check if data access complies with regulations.
        
        Args:
            data_type: Type of data being accessed
            user_id: ID of user accessing the data
            operation: Operation being performed (read, write, delete)
        
        Returns:
            True if access is compliant, False otherwise
        """
        # Check if user has permission to access data type
        user_permissions = get_user_permissions(user_id)
        
        if data_type == "personal" and "access_personal_data" not in user_permissions:
            self.violations.append({
                "user_id": user_id,
                "data_type": data_type,
                "operation": operation,
                "timestamp": datetime.now().isoformat(),
                "reason": "User does not have permission to access personal data"
            })
            return False
        
        # Log compliant access
        audit_logger.info(
            f"Compliant data access: {data_type}",
            extra={
                "user_id": user_id,
                "data_type": data_type,
                "operation": operation,
                "timestamp": datetime.now().isoformat()
            }
        )
        
        return True
```

### 3. Compliance Reports

Automated compliance reports provide evidence of compliance:

```python
# Example compliance report generation
def generate_compliance_report(start_date: str, end_date: str, framework: str) -> dict:
    """
    Generate compliance report for a specific framework.
    
    Args:
        start_date: Start date for the report period (ISO format)
        end_date: End date for the report period (ISO format)
        framework: Compliance framework (GDPR, PCI, HIPAA, SOC2)
    
    Returns:
        Compliance report data
    """
    report = {
        "framework": framework,
        "period": {
            "start": start_date,
            "end": end_date
        },
        "controls": [],
        "violations": [],
        "summary": {}
    }
    
    # Get audit logs for the period
    audit_logs = get_audit_logs(start_date, end_date)
    
    # Get compliance controls for the framework
    controls = get_compliance_controls(framework)
    
    # Check each control
    for control in controls:
        control_status = check_control_compliance(control, audit_logs)
        report["controls"].append({
            "id": control.id,
            "name": control.name,
            "status": control_status.status,
            "evidence": control_status.evidence
        })
        
        if control_status.status == "violation":
            report["violations"].append({
                "control_id": control.id,
                "description": control_status.description,
                "severity": control_status.severity
            })
    
    # Generate summary
    total_controls = len(controls)
    compliant_controls = sum(1 for c in report["controls"] if c["status"] == "compliant")
    report["summary"] = {
        "total_controls": total_controls,
        "compliant_controls": compliant_controls,
        "compliance_percentage": (compliant_controls / total_controls) * 100 if total_controls > 0 else 0,
        "violation_count": len(report["violations"])
    }
    
    return report
```

## Kiro Rules for Compliance

Kiro rules enforce compliance requirements during development:

```yaml
# Example Kiro rules for compliance
rules:
  - name: "gdpr-personal-data"
    description: "Ensures personal data is properly classified"
    check:
      type: "content-check"
      pattern: "cloudscope/domain/models/**/*.py"
      content-pattern: "@data_classification\\(['\"]personal['\"]\\)"
      condition: "must-contain-for-matches"
      match-pattern: ".*name.*|.*email.*|.*address.*|.*phone.*"
    message: "Personal data must be classified according to GDPR requirements"
    severity: "error"
  
  - name: "pci-card-data"
    description: "Ensures payment card data is encrypted"
    check:
      type: "content-check"
      pattern: "cloudscope/domain/models/**/*.py"
      content-pattern: "@encrypted"
      condition: "must-contain-for-matches"
      match-pattern: ".*card.*|.*payment.*|.*credit.*|.*cvv.*"
    message: "Payment card data must be encrypted according to PCI DSS requirements"
    severity: "error"
  
  - name: "hipaa-health-data"
    description: "Ensures health data is properly classified"
    check:
      type: "content-check"
      pattern: "cloudscope/domain/models/**/*.py"
      content-pattern: "@data_classification\\(['\"]health['\"]\\)"
      condition: "must-contain-for-matches"
      match-pattern: ".*health.*|.*medical.*|.*patient.*|.*diagnosis.*"
    message: "Health data must be classified according to HIPAA requirements"
    severity: "error"
```

## Compliance Documentation

### 1. Control Mapping

The control mapping document maps compliance controls to code implementations:

```markdown
# GDPR Control Mapping

| Control ID | Control Description | Implementation | Evidence |
|------------|---------------------|----------------|----------|
| GDPR-1     | Right to Access     | `User.get_data_export()` | Audit logs of data export requests |
| GDPR-2     | Right to be Forgotten | `UserRepository.delete_user()` | Audit logs of user deletion requests |
| GDPR-3     | Data Minimization   | `@data_classification` decorator | Static analysis reports |
| GDPR-4     | Consent Management  | `ConsentManager` class | Consent records in database |

# PCI DSS Control Mapping

| Control ID | Control Description | Implementation | Evidence |
|------------|---------------------|----------------|----------|
| PCI-1      | Protect Cardholder Data | `@encrypted` decorator | Encryption verification reports |
| PCI-2      | Restrict Access     | `@access_control` decorator | Access control logs |
| PCI-3      | Maintain Secure Systems | CI/CD pipeline security checks | Build logs and security scan reports |
| PCI-4      | Monitor and Test    | Automated security testing | Test results and monitoring logs |
```

### 2. Evidence Collection

The evidence collection process automatically gathers compliance evidence:

```python
# Example evidence collection
def collect_compliance_evidence(control_id: str, period_start: str, period_end: str) -> dict:
    """
    Collect evidence for a specific compliance control.
    
    Args:
        control_id: ID of the compliance control
        period_start: Start date for the evidence period (ISO format)
        period_end: End date for the evidence period (ISO format)
    
    Returns:
        Evidence data for the control
    """
    evidence = {
        "control_id": control_id,
        "period": {
            "start": period_start,
            "end": period_end
        },
        "items": []
    }
    
    # Get control implementation details
    control = get_compliance_control(control_id)
    
    # Collect evidence based on control type
    if control.type == "access_control":
        # Collect access control logs
        access_logs = get_access_logs(period_start, period_end, control.resource_type)
        evidence["items"].extend([
            {
                "timestamp": log.timestamp,
                "user_id": log.user_id,
                "action": log.action,
                "resource": log.resource,
                "result": log.result
            }
            for log in access_logs
        ])
    elif control.type == "encryption":
        # Collect encryption verification logs
        encryption_logs = get_encryption_logs(period_start, period_end, control.data_type)
        evidence["items"].extend([
            {
                "timestamp": log.timestamp,
                "data_type": log.data_type,
                "encryption_status": log.status,
                "verification_result": log.result
            }
            for log in encryption_logs
        ])
    
    return evidence
```

## Conclusion

CloudScope's Compliance as Code approach integrates compliance requirements directly into the development process, ensuring that compliance is built into the system from the beginning. By treating compliance requirements as code, CloudScope reduces the manual effort required for compliance activities and ensures consistent application of compliance controls across the system.

The combination of code annotations, automated checks, and compliance reporting provides a comprehensive framework for maintaining compliance with various regulatory requirements, including GDPR, PCI DSS, HIPAA, and SOC 2.