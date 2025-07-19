---
inclusion: fileMatch
fileMatchPattern: "**/cdfi/**|**/partners/**"
---

## CDFI Partnership Requirements

### Data Residency Controls
- Financial data must remain in US regions
- Implement geo-fencing for CDFI partner data
- Use dedicated VPCs for CDFI integrations

### Third-Party Validation
- Verify partner SOC 2 compliance annually
- Request Attestation of Compliance (AoC)
- Implement automated certificate validation

### Revenue Sharing Accuracy
```python
# All revenue calculations must include:
def calculate_revenue_share(transaction_amount: Decimal) -> Dict:
    """Calculate CDFI partner revenue share with audit trail"""
    calculation = {
        'timestamp': datetime.utcnow().isoformat(),
        'transaction_id': generate_unique_id(),
        'gross_amount': transaction_amount,
        'cdfi_share': transaction_amount * Decimal('0.03'),  # 3% example
        'platform_share': transaction_amount * Decimal('0.97'),
        'audit_trail': []
    }
    # Log every calculation step
    log_financial_calculation(calculation)
    return calculation
```