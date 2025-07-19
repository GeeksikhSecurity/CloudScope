# Kiro Steering Rules for Compliance Automation

This directory contains steering rules for Kiro to automate compliance requirements in the CloudScope project.

## Overview

These steering files provide guidance and requirements for various compliance frameworks and security controls. They are designed to be included in the development workflow based on specific conditions (file patterns, manual inclusion, etc.).

## Files

- **pci-compliance.md**: PCI DSS v4.0.1 requirements for handling payment card data
- **soc2-security-controls.md**: SOC 2 security controls for authentication and API security
- **cdfi-integration.md**: Requirements for CDFI (Community Development Financial Institution) partnerships
- **compliance-documentation.md**: Templates and requirements for compliance documentation
- **compliance-phases.md**: Phased approach to implementing compliance requirements
- **shared-responsibility.md**: Matrix defining responsibilities between CloudScope and vendors
- **compliance-testing.md**: Requirements for compliance-focused testing
- **monitoring-alerts.md**: Requirements for security monitoring and alerts
- **compliance-as-code-strategy.md**: Comprehensive strategy for implementing compliance-as-code with Kiro

## Usage

These steering files are automatically included in the development workflow based on their inclusion rules:

- **always**: Always included in the workflow
- **fileMatch**: Included when working on files matching specific patterns
- **manual**: Manually included when needed

## Best Practices

1. **Start with Risk Assessment**: Use steering files to enforce risk-based decision making
2. **Automate Evidence Collection**: Generate audit trails automatically
3. **Version Control Everything**: Including compliance policies and procedures
4. **Regular Reviews**: Set up automated reminders for policy reviews
5. **Clear Ownership**: Define responsibility in code comments and documentation

## Implementation Tips

1. **Use Conditional Includes**: Load compliance rules only when working on relevant files
2. **Reference Live Files**: Link to actual compliance configs and policies
3. **Team Alignment**: Ensure all developers understand compliance requirements through steering
4. **Incremental Adoption**: Start with critical controls, expand coverage over time