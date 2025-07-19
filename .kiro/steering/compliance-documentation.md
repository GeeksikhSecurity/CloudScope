---
inclusion: manual
---

## Documentation Requirements

### Every New Feature Must Include:
1. Security impact assessment
2. Data flow diagram
3. Compliance mapping (SOC 2 criteria affected)
4. Test coverage requirements

### Template for Security Assessment:
```markdown
## Security Assessment: [Feature Name]

### Data Handling
- [ ] No PII stored unnecessarily
- [ ] Encryption at rest implemented
- [ ] Encryption in transit (TLS 1.3)
- [ ] Access controls defined

### Compliance Impact
- SOC 2 Criteria Affected: [List criteria]
- PCI DSS Requirements: [List if applicable]
- CDFI Partner Impact: [Yes/No, details]
```