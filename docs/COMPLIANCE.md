# CloudScope Compliance-as-Code Documentation

## Overview

CloudScope implements Compliance-as-Code (CaC) principles to ensure regulatory requirements are built into the software development process. This approach treats compliance requirements as software artifacts that can be versioned, tested, and automatically enforced.

## Supported Frameworks

CloudScope supports the following regulatory frameworks through code annotations and automated checks:

- **GDPR** (General Data Protection Regulation)
- **PCI DSS** (Payment Card Industry Data Security Standard)
- **HIPAA** (Health Insurance Portability and Accountability Act)
- **SOC 2** (Service Organization Control 2)

## Compliance Decorators

### Data Classification

The `@data_classification` decorator marks functions that handle sensitive data:

```python
from cloudscope.infrastructure.compliance import data_classification

class User:
    @data_classification("personal")
    def update_email(self, email: str):
        """Update user email (personal data)."""
        self.email = email
```

**Supported Classifications:**
- `"personal"` - GDPR personal data
- `"health"` - HIPAA protected health information
- `"financial"` - Financial/payment data

### Encryption

The `@encrypted` decorator ensures sensitive data is encrypted:

```python
from cloudscope.infrastructure.compliance import encrypted

@pci_scope
class PaymentMethod:
    @encrypted
    def set_card_number(self, card_number: str):
        """Store encrypted card number."""
        self._card_number = card_number
```

### Audit Logging

The `@audit_log` decorator logs security-relevant operations:

```python
from cloudscope.infrastructure.compliance import audit_log

class MedicalRecord:
    @audit_log
    def add_diagnosis(self, diagnosis: str, doctor_id: str):
        """Add diagnosis with audit trail."""
        self.diagnoses.append({
            "diagnosis": diagnosis,
            "doctor_id": doctor_id,
            "timestamp": datetime.now()
        })
```

### Access Control

The `@access_control` decorator enforces role-based access:

```python
from cloudscope.infrastructure.compliance import access_control

class SystemConfig:
    @access_control(["admin", "system_operator"])
    def update_setting(self, key: str, value: str):
        """Update system configuration."""
        self.settings[key] = value
```

### PCI Scope

The `@pci_scope` class decorator marks classes in PCI DSS scope:

```python
from cloudscope.infrastructure.compliance import pci_scope

@pci_scope
class PaymentProcessor:
    """Payment processing class in PCI DSS scope."""
    pass
```

## Context Management

### User Context

Set the current user for compliance operations:

```python
from cloudscope.infrastructure.compliance.context import user_context, User

admin_user = User(id="admin123", roles=["admin"], email="admin@example.com")

with user_context(admin_user):
    # Operations will be logged with admin user context
    payment.process_transaction(amount)
```

### Compliance Context

Set framework-specific compliance context:

```python
from cloudscope.infrastructure.compliance.context import gdpr_context, pci_context

# GDPR context with lawful basis
with gdpr_context(lawful_basis="consent"):
    user.update_personal_data(data)

# PCI DSS context for authorized access
with pci_context(authorized_access=True):
    payment.process_card_data(card_info)
```

## Runtime Monitoring

### Compliance Monitor

The compliance monitor tracks violations and metrics:

```python
from cloudscope.infrastructure.compliance.monitoring import get_compliance_monitor

monitor = get_compliance_monitor()

# Check data access compliance
is_compliant = monitor.check_data_access("personal", "user123", "read")

# Get compliance metrics
metrics = monitor.get_metrics(period_hours=24)
print(f"Compliance rate: {metrics.compliance_rate:.1f}%")

# Get violations
violations = monitor.get_violations(framework="GDPR")
```

### Alert Callbacks

Register callbacks for compliance violations:

```python
def send_alert(violation):
    """Send alert for compliance violation."""
    print(f"ALERT: {violation.description}")
    # Send to monitoring system

monitor.add_alert_callback(send_alert)
```

## Static Analysis

### Compliance Analyzer

Run static analysis to find compliance issues:

```python
from cloudscope.infrastructure.compliance.analysis import ComplianceStaticAnalyzer

analyzer = ComplianceStaticAnalyzer()

# Analyze a single file
issues = analyzer.analyze_file("path/to/model.py")

# Analyze entire directory
report = analyzer.analyze_directory("cloudscope/", exclude_patterns=['test_*'])

print(f"Compliance score: {report.compliance_score:.1f}%")
for issue in report.issues_found:
    print(f"{issue.severity}: {issue.description}")
```

### HTML Reports

Generate HTML compliance reports:

```python
from cloudscope.infrastructure.compliance.analysis import generate_compliance_report_html

generate_compliance_report_html(report, "compliance_report.html")
```

## CLI Commands

### Analyze Command

Run compliance analysis from command line:

```bash
# Analyze current directory
python -m cloudscope.cli.compliance_commands compliance analyze .

# Analyze specific file with JSON output
cloudscope compliance analyze user_model.py --format json --output report.json

# Filter by framework and severity
cloudscope compliance analyze . --framework GDPR --severity error
```

### Monitor Command

View compliance monitoring results:

```bash
# View violations for last 24 hours
cloudscope compliance monitor --period 24

# Filter by framework
cloudscope compliance monitor --framework PCI_DSS --violations-only
```

### Report Command

Generate compliance reports:

```bash
# Generate metrics report
cloudscope compliance report --type metrics --format json

# Generate violations report
cloudscope compliance report --type violations --format csv --output violations.csv
```

### Check Command

Check specific files for compliance:

```bash
# Check specific files
cloudscope compliance check payment_model.py user_model.py

# Check with auto-fix suggestions
cloudscope compliance check *.py --fix --framework GDPR
```

## Kiro Rules Integration

### Automated Enforcement

CloudScope includes Kiro rules for automated compliance enforcement:

```bash
# Run Kiro compliance checks
python .kiro/rules/check_compliance.py cloudscope/

# Generate HTML report
python .kiro/rules/check_compliance.py . --format html --output compliance.html

# Fail on violations (for CI/CD)
python .kiro/rules/check_compliance.py . --fail-on-violations --severity error
```

### Rule Configuration

Kiro rules are defined in `.kiro/rules/compliance.yaml`:

```yaml
rules:
  - name: "gdpr-personal-data-classification"
    description: "Ensures personal data is properly classified"
    check:
      type: "content-check"
      pattern: "cloudscope/**/*.py"
      content-pattern: "@data_classification\\(['\"]personal['\"]\\)"
      condition: "must-contain-for-matches"
      match-pattern: ".*name.*|.*email.*|.*address.*"
    message: "Personal data must be classified according to GDPR"
    severity: "error"
    framework: "GDPR"
```

## Framework-Specific Guidance

### GDPR Compliance

**Key Requirements:**
- Lawful basis for processing
- Data subject rights (access, rectification, erasure)
- Accountability and documentation
- Data protection by design

**Implementation:**
```python
class User:
    @data_classification("personal")
    @audit_log
    def update_email(self, email: str):
        self.email = email
    
    @audit_log
    def get_data_export(self) -> dict:
        """GDPR data portability."""
        return {"email": self.email, "name": self.name}
    
    @access_control(["admin", "data_protection_officer"])
    @audit_log
    def delete_personal_data(self):
        """GDPR right to be forgotten."""
        self.email = "[DELETED]"
        self.name = "[DELETED]"
```

### PCI DSS Compliance

**Key Requirements:**
- Protect cardholder data
- Encrypt transmission and storage
- Restrict access on need-to-know basis
- Monitor and test networks regularly

**Implementation:**
```python
@pci_scope
class PaymentMethod:
    @encrypted
    @audit_log
    def set_card_number(self, card_number: str):
        self._card_number = card_number
    
    @access_control(["payment_processor"])
    @audit_log
    def process_payment(self, amount: float):
        # Payment processing logic
        pass
    
    def get_masked_card_number(self) -> str:
        """PCI DSS compliant display."""
        return "****-****-****-" + self._card_number[-4:]
```

### HIPAA Compliance

**Key Requirements:**
- Protect health information
- Minimum necessary access
- Audit trails for all access
- Business associate agreements

**Implementation:**
```python
class MedicalRecord:
    @data_classification("health")
    @audit_log
    @access_control(["doctor", "nurse"])
    def add_diagnosis(self, diagnosis: str, doctor_id: str):
        self.diagnoses.append({
            "diagnosis": diagnosis,
            "doctor_id": doctor_id,
            "timestamp": datetime.now()
        })
    
    @access_control(["patient", "doctor"])
    def get_summary(self) -> dict:
        """Minimum necessary information."""
        return {
            "patient_id": self.patient_id,
            "diagnosis_count": len(self.diagnoses)
        }
```

### SOC 2 Compliance

**Key Requirements:**
- Security controls
- System monitoring
- Access controls
- Change management

**Implementation:**
```python
class SystemConfiguration:
    @audit_log
    @access_control(["admin"])
    def update_setting(self, key: str, value: str, user_id: str):
        old_value = self.settings.get(key)
        self.settings[key] = value
        self.version += 1
        # Audit log automatically captures the change
```

## CI/CD Integration

### GitHub Actions

Example workflow for compliance checking:

```yaml
name: Compliance Check
on: [push, pull_request]

jobs:
  compliance:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.9'
      
      - name: Install dependencies
        run: |
          pip install -r requirements.txt
          pip install -e .
      
      - name: Run compliance analysis
        run: |
          python .kiro/rules/check_compliance.py . \
            --format json \
            --output compliance-report.json \
            --fail-on-violations \
            --severity error
      
      - name: Upload compliance report
        uses: actions/upload-artifact@v3
        if: always()
        with:
          name: compliance-report
          path: compliance-report.json
```

### Pre-commit Hooks

Add to `.pre-commit-config.yaml`:

```yaml
repos:
  - repo: local
    hooks:
      - id: compliance-check
        name: CloudScope Compliance Check
        entry: python .kiro/rules/check_compliance.py
        language: system
        args: [--fail-on-violations, --severity, critical]
        files: \.py$
```

## Best Practices

### Development Workflow

1. **Design Phase**: Identify compliance requirements
2. **Implementation**: Use appropriate decorators
3. **Testing**: Verify compliance with tests
4. **Review**: Run static analysis
5. **Deployment**: Monitor runtime compliance

### Code Organization

```
project/
├── domain/
│   └── models/
│       ├── user.py           # @data_classification("personal")
│       ├── payment.py        # @pci_scope, @encrypted
│       └── medical.py        # @data_classification("health")
├── compliance/
│   ├── policies/            # Compliance policies
│   ├── reports/            # Generated reports
│   └── evidence/           # Compliance evidence
└── tests/
    └── compliance/         # Compliance tests
```

### Testing Compliance

```python
import unittest
from cloudscope.infrastructure.compliance.context import user_context, gdpr_context
from cloudscope.infrastructure.compliance.monitoring import get_compliance_monitor

class TestUserCompliance(unittest.TestCase):
    def test_gdpr_personal_data_access(self):
        """Test GDPR compliant personal data access."""
        monitor = get_compliance_monitor()
        admin_user = User(id="admin", roles=["admin"])
        
        with user_context(admin_user):
            with gdpr_context(lawful_basis="consent"):
                user = User("test", "test@example.com")
                user.update_email("new@example.com")
                
                # Verify compliance
                self.assertTrue(monitor.check_data_access("personal", "admin", "update"))
                
                # Verify audit log
                violations = monitor.get_violations()
                self.assertEqual(len(violations), 0)
```

### Error Handling

```python
from cloudscope.infrastructure.compliance.exceptions import (
    UnauthorizedError, 
    ForbiddenError, 
    EncryptionError
)

try:
    payment.process_card_data(card_info)
except UnauthorizedError:
    # Handle authentication failure
    logger.error("Unauthorized payment access attempt")
except ForbiddenError:
    # Handle insufficient permissions
    logger.error("Insufficient permissions for payment processing")
except EncryptionError:
    # Handle encryption failure
    logger.error("Failed to encrypt payment data")
```

## Troubleshooting

### Common Issues

**Issue**: `ImportError: No module named 'cloudscope.infrastructure.compliance'`
**Solution**: Ensure CloudScope is properly installed: `pip install -e .`

**Issue**: Decorators not working
**Solution**: Check that context is properly set:
```python
from cloudscope.infrastructure.compliance.context import set_current_user
set_current_user(User(id="test", roles=["user"]))
```

**Issue**: Encryption key not found
**Solution**: Set the encryption key environment variable:
```bash
export CLOUDSCOPE_ENCRYPTION_KEY=$(python -c "from cloudscope.infrastructure.compliance.crypto import generate_key_string; print(generate_key_string())")
```

### Debug Mode

Enable debug logging for compliance operations:

```python
import logging
logging.getLogger('cloudscope.compliance').setLevel(logging.DEBUG)
logging.getLogger('cloudscope.audit').setLevel(logging.DEBUG)
```

### Compliance Dashboard

For operational monitoring, integrate with your monitoring system:

```python
# Prometheus metrics example
from prometheus_client import Counter, Histogram, Gauge

compliance_violations = Counter('cloudscope_compliance_violations_total', 
                              'Total compliance violations', ['framework', 'severity'])
compliance_rate = Gauge('cloudscope_compliance_rate', 
                       'Current compliance rate percentage')

def update_metrics():
    monitor = get_compliance_monitor()
    metrics = monitor.get_metrics(24)
    
    compliance_rate.set(metrics.compliance_rate)
    
    for framework, count in metrics.violations_by_framework.items():
        compliance_violations.labels(framework=framework, severity='total').inc(count)
```

## Support and Resources

- **Documentation**: [CloudScope Docs](https://docs.cloudscope.io/compliance)
- **Examples**: See `examples/compliance_models.py`
- **Issues**: [GitHub Issues](https://github.com/your-org/cloudscope/issues)
- **Security**: security@cloudscope.io

---

For more information on specific compliance frameworks, consult the official documentation:
- [GDPR.eu](https://gdpr.eu/)
- [PCI Security Standards](https://www.pcisecuritystandards.org/)
- [HHS HIPAA](https://www.hhs.gov/hipaa/)
- [AICPA SOC 2](https://www.aicpa.org/interestareas/frc/assuranceadvisoryservices/aicpasoc2report.html)
