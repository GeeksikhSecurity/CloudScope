# AI Coding Assistants: Compliance Integration Comparison

## Quick Comparison Matrix

| Aspect | AWS Kiro | Claude Code | AWS Q Developer | GitHub Copilot |
|--------|----------|-------------|-----------------|----------------|
| **Compliance Config Location** | `.kiro/steering/*.md` | `.claude/*.md` | `.q/*.json` | `.github/copilot/` |
| **Integration Method** | Native steering | Context files | Security profiles | Custom instructions |
| **Enforcement** | Automatic via hooks | Manual via prompts | Real-time suggestions | Post-generation |
| **Best For** | Full automation | Flexible guidance | Quick fixes | General coding |
| **Setup Complexity** | Medium | Low | Low | Medium |
| **Customization** | High | Very High | Medium | Low |

## Implementation Effort

### Time to Implement (from scratch)
- **Kiro**: 2-3 hours (steering + hooks)
- **Claude**: 30 minutes (context files)
- **Q Developer**: 45 minutes (profiles)
- **Replication**: 5 minutes with script

### Maintenance Overhead
- **Kiro**: Low (automated)
- **Claude**: Medium (prompt discipline)
- **Q Developer**: Low (profile updates)

## Effectiveness Ratings

### Violation Detection
- **Kiro**: ⭐⭐⭐⭐⭐ (hooks catch everything)
- **Claude**: ⭐⭐⭐ (depends on prompts)
- **Q Developer**: ⭐⭐⭐⭐ (real-time)

### Developer Experience
- **Kiro**: ⭐⭐⭐⭐ (invisible when compliant)
- **Claude**: ⭐⭐⭐⭐⭐ (flexible, conversational)
- **Q Developer**: ⭐⭐⭐⭐ (inline suggestions)

### Remediation Support
- **Kiro**: ⭐⭐⭐⭐ (AI suggests fixes)
- **Claude**: ⭐⭐⭐⭐⭐ (explains and fixes)
- **Q Developer**: ⭐⭐⭐⭐ (auto-fix option)

## Key Takeaways

1. **Kiro** is best for teams wanting full automation
2. **Claude** excels at explaining compliance requirements
3. **Q Developer** provides the smoothest inline experience
4. All three can use the same underlying compliance models

## Recommended Approach

1. Start with Claude (easiest, most flexible)
2. Add Q Developer profiles (better real-time feedback)
3. Graduate to Kiro for full automation
4. Use the same compliance models across all tools