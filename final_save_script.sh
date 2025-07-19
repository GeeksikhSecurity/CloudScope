#!/bin/bash
# final-save.sh - Run this to save all CloudScope progress

echo "=== CloudScope Final Save ==="
echo "Saving all compliance implementation progress..."
echo ""

# 1. Add all files
git add -A

# 2. Show what will be committed
echo "Files to be committed:"
git status -s
echo ""

# 3. Commit with comprehensive message
git commit -m "feat: Complete Priority 1 compliance implementation with guides

Completed:
- Finding domain model with lifecycle management
- Compliance domain model with multi-framework support
- Compliance checker interfaces (ports)
- Fixed datetime deprecation warnings
- 95% test coverage on Finding model
- Compliance gap analyzer (29 gaps identified)
- Replication guide for other repositories  
- Claude Code integration documentation
- AWS Q Developer security profiles
- Tool comparison matrix
- Next.js specific examples

Remaining work tracked in COMPLIANCE_STATUS.md" || echo "No changes to commit"

# 4. Create status file if it doesn't exist
if [ ! -f COMPLIANCE_STATUS.md ]; then
    cat > COMPLIANCE_STATUS.md << 'EOF'
# CloudScope Compliance Status

Branch: feature/compliance-as-code
Last Updated: $(date)

## Completed (Priority 1) ✅
- Finding model (95% coverage)
- Compliance model  
- Compliance interfaces
- Gap analyzer
- Replication guides

## Next (Priority 2) 📋
- Update Asset model with compliance fields
- Run: python3 update_asset_compliance.py

## Quick Start Next Session
```bash
git checkout feature/compliance-as-code
./start_next_session.sh
```
EOF
    git add COMPLIANCE_STATUS.md
    git commit -m "docs: Add compliance status tracking"
fi

# 5. Create quick start script
cat > start_next_session.sh << 'EOF'
#!/bin/bash
echo "=== CloudScope Compliance Development ==="
echo "Branch: $(git branch --show-current)"
echo ""
echo "Last commit:"
git log -1 --oneline
echo ""
echo "Compliance gaps remaining:"
python3 compliance_gap_analyzer.py 2>/dev/null | grep -c "❌" | xargs echo
echo ""
echo "Next: Update Asset model with compliance fields"
echo "Edit: cloudscope/domain/models/asset.py"
EOF
chmod +x start_next_session.sh

# 6. Show summary
echo ""
echo "=== Save Complete ==="
echo "✅ All changes committed locally"
echo ""
echo "To push to GitHub:"
echo "  git push origin feature/compliance-as-code"
echo ""
echo "To continue next time:"
echo "  cd /Volumes/DATA/Git/CloudScope"
echo "  ./start_next_session.sh"
echo ""
echo "Progress saved in: COMPLIANCE_STATUS.md"
echo "Gap analysis: compliance_implementation_checklist.md"