---
inclusion: fileMatch
fileMatchPattern: "**/*.test.*|**/*.spec.*"
---

## Compliance Test Requirements

### Security Test Cases
```typescript
describe('Authentication Security', () => {
  it('should enforce MFA for admin endpoints', async () => {
    // Test implementation
  });
  
  it('should rate limit authentication attempts', async () => {
    // Verify 5 attempts max per 15 minutes
  });
  
  it('should log all authentication events', async () => {
    // Verify audit logging
  });
});

describe('PCI Compliance', () => {
  it('should never log sensitive card data', async () => {
    // Verify no card numbers in logs
  });
  
  it('should use tokenization for all payments', async () => {
    // Verify Stripe token usage
  });
});
```