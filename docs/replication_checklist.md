# ✅ Compliance-as-Code Replication Checklist

## Prerequisites
- [ ] CloudScope repository with compliance implementation
- [ ] Target repository ready
- [ ] Python 3.8+ installed
- [ ] Git configured

## Step 1: Initial Replication
```bash
# Clone the replication script
curl -O https://raw.githubusercontent.com/your-org/compliance-tools/main/replicate-cloudscope-compliance.sh
chmod +x replicate-cloudscope-compliance.sh

# Run replication
./replicate-cloudscope-compliance.sh /path/to/CloudScope /path/to/target-repo
```

## Step 2: Customize for Your Stack

### For Python Projects
- [ ] Update `.compliance/check_compliance.py` with Python-specific checks
- [ ] Add `bandit` and `safety` to requirements.txt
- [ ] Configure `pyproject.toml` with security settings

### For JavaScript/TypeScript Projects
- [ ] Install ESLint security plugins
- [ ] Update compliance checker for JS patterns
- [ ] Add security scripts to package.json

### For Go Projects
- [ ] Install `gosec` for security scanning
- [ ] Update compliance patterns for Go
- [ ] Add to Makefile

## Step 3: Tool-Specific Setup

### AWS Kiro
- [ ] Verify `.kiro/steering/` files are created
- [ ] Test hooks with: `kiro sync`
- [ ] Verify compliance rules appear in Kiro UI

### Claude Code
- [ ] Add `.claude/` folder to project
- [ ] Test by asking: "Show me the compliance requirements"
- [ ] Include in system prompt: "Follow compliance rules in .claude/"

### AWS Q Developer
- [ ] Verify `.q/security-profile.json` exists
- [ ] Open project in Q-enabled IDE
- [ ] Test by writing non-compliant code (should get warnings)

## Step 4: CI/CD Integration
- [ ] Add `.github/workflows/compliance.yml`
- [ ] Configure branch protection rules
- [ ] Set up status checks for compliance

## Step 5: Team Onboarding
- [ ] Document compliance requirements in README
- [ ] Create team training materials
- [ ] Set up Slack/email notifications for violations

## Step 6: Verification
```bash
# Run initial compliance check
python .compliance/check_compliance.py

# Check Git hooks
git commit -m "test" --dry-run

# Verify CI/CD
git push origin feature/test-compliance
```

## Step 7: Customization

### Add New OWASP ASVS Controls
1. [ ] Edit `.compliance/frameworks/owasp-asvs/asvs-v5-controls.yaml`
2. [ ] Update checker script with new patterns
3. [ ] Add to Kiro steering files
4. [ ] Update Claude context
5. [ ] Update Q security profile

### Add New Frameworks
1. [ ] Create `.compliance/frameworks/[framework-name]/`
2. [ ] Define controls in YAML
3. [ ] Implement checker functions
4. [ ] Add to CI/CD pipeline

## Troubleshooting

### Common Issues
- **"Module not found"**: Install Python dependencies
- **"Permission denied"**: Check file permissions
- **"Hooks not running"**: Ensure Git hooks are executable

### Debug Commands
```bash
# Test compliance checker directly
python -m pdb .compliance/check_compliance.py

# Verify Kiro steering
cat .kiro/steering/*.md

# Check Claude context
cat .claude/*.md

# Validate Q profile
jq . .q/security-profile.json
```

## Maintenance Schedule
- [ ] Weekly: Review compliance reports
- [ ] Monthly: Update control definitions
- [ ] Quarterly: Review and update frameworks
- [ ] Annually: Major framework upgrades

## Resources
- [OWASP ASVS 5.0](https://owasp.org/www-project-application-security-verification-standard/)
- [SOC2 Compliance Guide](https://www.aicpa.org/resources/landing/system-and-organization-controls-soc-suite-of-services)
- [CloudScope Compliance Docs](.compliance/README.md)

## Success Metrics
- [ ] 0 critical violations in production
- [ ] 100% of PRs pass compliance checks
- [ ] <5% false positive rate
- [ ] 90%+ developer satisfaction with tooling