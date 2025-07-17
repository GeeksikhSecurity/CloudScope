---
inclusion: always
---

## Security Control Requirements

### Authentication & Access Control
- All admin endpoints require MFA
- Implement rate limiting on all APIs
- Use JWT with short expiration times (15 minutes)
- Log all authentication attempts

### Required Security Headers
```typescript
// Every API response must include:
const securityHeaders = {
  'X-Content-Type-Options': 'nosniff',
  'X-Frame-Options': 'DENY',
  'X-XSS-Protection': '1; mode=block',
  'Strict-Transport-Security': 'max-age=31536000; includeSubDomains',
  'Content-Security-Policy': "default-src 'self'"
};
```