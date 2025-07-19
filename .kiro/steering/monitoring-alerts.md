---
inclusion: fileMatch
fileMatchPattern: "**/monitoring/**|**/alerts/**"
---

## Automated Monitoring Requirements

### Security Event Alerts
- Failed authentication attempts > 5 in 15 minutes
- Unauthorized API access attempts
- Unusual data access patterns
- Certificate expiration warnings (30 days)

### Compliance Metrics
```javascript
const complianceMetrics = {
  mfaAdoption: "Percentage of users with MFA enabled",
  patchCompliance: "Systems patched within 30 days",
  accessReviews: "Quarterly access reviews completed",
  incidentResponse: "Average response time < 4 hours"
};
```