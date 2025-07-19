#!/bin/bash
# Save the compliance gap analyzer and run it

# Create the compliance gap analyzer script
cat > compliance_gap_analyzer.py << 'EOF'
#!/usr/bin/env python3
"""
CloudScope Compliance Gap Analyzer
Identifies missing compliance components based on Kiro steering rules
"""

import os
from pathlib import Path
from typing import List, Dict, Tuple
import json

class ComplianceGapAnalyzer:
    def __init__(self, project_root: str = "."):
        self.project_root = Path(project_root)
        self.cloudscope_dir = self.project_root / "cloudscope"
        self.kiro_dir = self.project_root / ".kiro"
        self.tests_dir = self.project_root / "tests"
        
    def analyze_gaps(self) -> Dict[str, List[str]]:
        """Analyze compliance gaps in the current implementation"""
        gaps = {
            "missing_models": [],
            "missing_services": [],
            "missing_ports": [],
            "missing_adapters": [],
            "missing_configs": [],
            "missing_tests": [],
            "model_updates_needed": []
        }
        
        # Check for compliance models
        compliance_models = [
            "cloudscope/domain/models/compliance.py",
            "cloudscope/domain/models/finding.py",
            "cloudscope/domain/models/control.py",
            "cloudscope/domain/models/compliance_report.py"
        ]
        
        for model in compliance_models:
            if not (self.project_root / model).exists():
                gaps["missing_models"].append(model)
        
        # Check for compliance services
        compliance_services = [
            "cloudscope/domain/services/compliance_service.py",
            "cloudscope/domain/services/assessment_service.py",
            "cloudscope/domain/services/reporting_service.py"
        ]
        
        for service in compliance_services:
            if not (self.project_root / service).exists():
                gaps["missing_services"].append(service)
        
        # Check for compliance ports
        compliance_ports = [
            "cloudscope/ports/compliance/__init__.py",
            "cloudscope/ports/compliance/compliance_checker.py",
            "cloudscope/ports/compliance/framework_checker.py",
            "cloudscope/ports/compliance/report_generator.py"
        ]
        
        for port in compliance_ports:
            if not (self.project_root / port).exists():
                gaps["missing_ports"].append(port)
        
        # Check for compliance adapters
        compliance_adapters = [
            "cloudscope/adapters/compliance/__init__.py",
            "cloudscope/adapters/compliance/owasp_asvs_checker.py",
            "cloudscope/adapters/compliance/soc2_checker.py",
            "cloudscope/adapters/compliance/iso27001_checker.py"
        ]
        
        for adapter in compliance_adapters:
            if not (self.project_root / adapter).exists():
                gaps["missing_adapters"].append(adapter)
        
        # Check for Kiro configuration files
        kiro_configs = [
            ".kiro/config/owasp_asvs_mapping.yaml",
            ".kiro/config/soc2_mapping.yaml",
            ".kiro/config/compliance_rules.yaml",
            ".kiro/config/control_mappings.yaml"
        ]
        
        for config in kiro_configs:
            if not (self.project_root / config).exists():
                gaps["missing_configs"].append(config)
        
        # Check for compliance tests
        compliance_tests = [
            "tests/domain/models/test_compliance.py",
            "tests/domain/models/test_finding.py",
            "tests/domain/services/test_compliance_service.py",
            "tests/adapters/compliance/test_owasp_asvs_checker.py",
            "tests/adapters/compliance/test_soc2_checker.py"
        ]
        
        for test in compliance_tests:
            if not (self.project_root / test).exists():
                gaps["missing_tests"].append(test)
        
        # Check Asset model for compliance fields
        asset_file = self.cloudscope_dir / "domain" / "models" / "asset.py"
        if asset_file.exists():
            with open(asset_file, 'r') as f:
                content = f.read()
                required_fields = [
                    "compliance_level",
                    "soc2_controls",
                    "last_compliance_check",
                    "compliance_findings",
                    "compliance_status"
                ]
                for field in required_fields:
                    if field not in content:
                        gaps["model_updates_needed"].append(f"Asset model missing: {field}")
        
        return gaps
    
    def generate_implementation_plan(self, gaps: Dict[str, List[str]]) -> List[Tuple[int, str, List[str]]]:
        """Generate prioritized implementation plan based on gaps"""
        plan = []
        
        # Priority 1: Core compliance infrastructure
        priority_1_items = []
        if gaps["missing_models"]:
            priority_1_items.extend([f"Create {m}" for m in gaps["missing_models"][:2]])
        if gaps["missing_ports"]:
            priority_1_items.extend([f"Create {p}" for p in gaps["missing_ports"][:2]])
        if priority_1_items:
            plan.append((1, "Core Compliance Infrastructure", priority_1_items))
        
        # Priority 2: Update existing models
        if gaps["model_updates_needed"]:
            plan.append((2, "Update Existing Models", gaps["model_updates_needed"]))
        
        # Priority 3: Compliance services
        if gaps["missing_services"]:
            plan.append((3, "Implement Compliance Services", 
                        [f"Create {s}" for s in gaps["missing_services"]]))
        
        # Priority 4: Framework-specific adapters
        if gaps["missing_adapters"]:
            plan.append((4, "Implement Compliance Framework Adapters", 
                        [f"Create {a}" for a in gaps["missing_adapters"]]))
        
        # Priority 5: Configuration files
        if gaps["missing_configs"]:
            plan.append((5, "Create Configuration Files", 
                        [f"Create {c}" for c in gaps["missing_configs"]]))
        
        # Priority 6: Tests
        if gaps["missing_tests"]:
            plan.append((6, "Implement Compliance Tests", 
                        [f"Create {t}" for t in gaps["missing_tests"]]))
        
        return plan
    
    def create_compliance_checklist(self) -> str:
        """Generate a markdown checklist for compliance implementation"""
        gaps = self.analyze_gaps()
        plan = self.generate_implementation_plan(gaps)
        
        checklist = "# CloudScope Compliance Implementation Checklist\n\n"
        checklist += "## Gap Analysis Summary\n\n"
        
        total_gaps = sum(len(items) for items in gaps.values())
        checklist += f"Total gaps identified: **{total_gaps}**\n\n"
        
        for priority, category, items in plan:
            checklist += f"### Priority {priority}: {category}\n\n"
            for item in items:
                checklist += f"- [ ] {item}\n"
            checklist += "\n"
        
        checklist += "## Next Steps\n\n"
        checklist += "1. Review and commit current changes\n"
        checklist += "2. Start with Priority 1 items\n"
        checklist += "3. Implement TDD approach for all new components\n"
        checklist += "4. Update documentation as you progress\n"
        
        return checklist
    
    def generate_report(self):
        """Generate comprehensive gap analysis report"""
        gaps = self.analyze_gaps()
        plan = self.generate_implementation_plan(gaps)
        
        print("=" * 60)
        print("CloudScope Compliance Gap Analysis Report")
        print("=" * 60)
        print()
        
        # Summary
        total_gaps = sum(len(items) for items in gaps.values())
        print(f"Total compliance gaps found: {total_gaps}")
        print()
        
        # Detailed gaps
        print("Detailed Gap Analysis:")
        print("-" * 40)
        for category, items in gaps.items():
            if items:
                print(f"\n{category.replace('_', ' ').title()}:")
                for item in items:
                    print(f"  ❌ {item}")
        
        print("\n" + "=" * 60)
        print("Implementation Plan")
        print("=" * 60)
        
        for priority, category, items in plan:
            print(f"\nPriority {priority}: {category}")
            print("-" * 40)
            for item in items:
                print(f"  • {item}")
        
        # Save checklist
        checklist_path = self.project_root / "compliance_implementation_checklist.md"
        with open(checklist_path, 'w') as f:
            f.write(self.create_compliance_checklist())
        print(f"\n✅ Checklist saved to: {checklist_path}")
        
        # Git commands
        print("\n" + "=" * 60)
        print("Recommended Git Commands")
        print("=" * 60)
        print("""
# Check current status
git status

# Add untracked project files
git add cloudscope/
git add tests/
git add pytest.ini pyproject.toml .flake8 .pre-commit-config.yaml
git commit -m "chore: Add project structure and configuration files"

# Continue with compliance implementation
echo "Ready to implement compliance features!"
        """)

if __name__ == "__main__":
    analyzer = ComplianceGapAnalyzer()
    analyzer.generate_report()
EOF

# Make it executable
chmod +x compliance_gap_analyzer.py

echo "✅ Compliance gap analyzer created!"
echo ""

# Run the analyzer
echo "Running compliance gap analysis..."
echo ""
python compliance_gap_analyzer.py

# Show current git status
echo ""
echo "=== Current Git Status ==="
git status -s

echo ""
echo "=== Next Steps ==="
echo "1. Review the compliance gap analysis above"
echo "2. Add and commit the untracked files:"
echo "   git add cloudscope/ tests/ pytest.ini pyproject.toml .flake8 .pre-commit-config.yaml"
echo "   git commit -m 'chore: Add project structure and configuration files'"
echo "3. Start implementing Priority 1 compliance items"