---
inclusion: fileMatch
fileMatchPattern: "**/*payment*|**/*card*|**/*checkout*"
---

## PCI DSS v4.0.1 Requirements

### Cardholder Data Handling
- Never store sensitive authentication data (SAD) after authorization
- Use Stripe tokens instead of raw card numbers
- Implement field-level encryption for any stored payment data

### Code Patterns
```javascript
// ✅ Correct: Using Stripe tokenization
const paymentIntent = await stripe.paymentIntents.create({
  amount: 1000,
  currency: 'usd',
  payment_method: paymentMethodId, // Token, not card number
});

// ❌ Incorrect: Storing card data
// NEVER do this:
// const cardNumber = req.body.cardNumber;
```