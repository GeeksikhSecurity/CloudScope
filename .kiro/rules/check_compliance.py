#!/usr/bin/env python3
"""
Kiro compliance rule processor for CloudScope.

This script processes the compliance Kiro rules and integrates with
CloudScope's compliance analysis tools to provide automated enforcement
of compliance requirements during development and CI/CD.
"""

import yaml
import os
import re
import sys
import argparse
from pathlib import Path
from typing import List, Dict, Any, Tuple
from dataclasses import dataclass

# Import CloudScope compliance tools
try:
    from cloudscope.infrastructure.compliance.analysis import ComplianceStaticAnalyzer
    from cloudscope.cli.compliance_commands import ComplianceCommands
except ImportError:
    print("Warning: CloudScope compliance modules not found. Some features may be limited.")
    ComplianceStaticAnalyzer = None
    ComplianceCommands = None


@dataclass
class KiroRule:
    """Represents a Kiro compliance rule."""
    name: str
    description: str
    check: Dict[str, Any]
    message: str
    severity: str
    framework: str
    documentation: str = ""


@dataclass
class KiroViolation:
    """Represents a violation found by Kiro rules."""
    rule_name: str
    file_path: str
    line_number: int
    message: str
    severity: str
    framework: str
    matched_content: str = ""


class KiroComplianceProcessor:
    """Processes Kiro compliance rules and checks code for violations."""
    
    def __init__(self, rules_file: str = None):
        """
        Initialize the Kiro compliance processor.
        
        Args:
            rules_file: Path to the YAML rules file
        """
        if rules_file is None:
            # Default to the compliance rules in the .kiro directory
            rules_file = Path(__file__).parent / "compliance.yaml"
        
        self.rules_file = Path(rules_file)
        self.rules: List[KiroRule] = []
        self.violations: List[KiroViolation] = []
        
        if self.rules_file.exists():
            self._load_rules()
        else:
            print(f"Warning: Rules file not found: {self.rules_file}")
    
    def _load_rules(self) -> None:
        """Load rules from the YAML file."""
        try:
            with open(self.rules_file, 'r') as f:
                rules_data = yaml.safe_load(f)
            
            for rule_data in rules_data.get('rules', []):
                rule = KiroRule(
                    name=rule_data['name'],
                    description=rule_data['description'],
                    check=rule_data['check'],
                    message=rule_data['message'],
                    severity=rule_data['severity'],
                    framework=rule_data['framework'],
                    documentation=rule_data.get('documentation', '')
                )
                self.rules.append(rule)
            
            print(f"Loaded {len(self.rules)} compliance rules")
            
        except Exception as e:
            print(f"Error loading rules: {str(e)}")
            sys.exit(1)
    
    def check_directory(self, directory: str, exclude_patterns: List[str] = None) -> List[KiroViolation]:
        """
        Check a directory against all compliance rules.
        
        Args:
            directory: Directory to check
            exclude_patterns: Patterns to exclude from checking
            
        Returns:
            List of violations found
        """
        if exclude_patterns is None:
            exclude_patterns = ['test_*', '__pycache__', '.git', '*.pyc']
        
        self.violations = []
        directory_path = Path(directory)
        
        if not directory_path.exists():
            print(f"Error: Directory '{directory}' does not exist")
            return self.violations
        
        # Find all Python files
        python_files = []
        for root, dirs, files in os.walk(directory_path):
            # Filter out excluded directories
            dirs[:] = [d for d in dirs if not self._matches_exclude_patterns(d, exclude_patterns)]
            
            for file in files:
                if file.endswith('.py') and not self._matches_exclude_patterns(file, exclude_patterns):
                    file_path = Path(root) / file
                    python_files.append(file_path)
        
        print(f"Checking {len(python_files)} Python files against {len(self.rules)} rules...")
        
        # Check each file against each rule
        for file_path in python_files:
            for rule in self.rules:
                violations = self._check_file_against_rule(file_path, rule)
                self.violations.extend(violations)
        
        return self.violations
    
    def check_file(self, file_path: str) -> List[KiroViolation]:
        """
        Check a single file against all compliance rules.
        
        Args:
            file_path: Path to the file to check
            
        Returns:
            List of violations found
        """
        self.violations = []
        file_path = Path(file_path)
        
        if not file_path.exists():
            print(f"Error: File '{file_path}' does not exist")
            return self.violations
        
        # Check file against each rule
        for rule in self.rules:
            violations = self._check_file_against_rule(file_path, rule)
            self.violations.extend(violations)
        
        return self.violations
    
    def _check_file_against_rule(self, file_path: Path, rule: KiroRule) -> List[KiroViolation]:
        """Check a single file against a single rule."""
        violations = []
        
        # Check if rule pattern matches the file
        pattern = rule.check.get('pattern', '**/*.py')
        if not self._file_matches_pattern(file_path, pattern):
            return violations
        
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            check_type = rule.check.get('type')
            
            if check_type == 'content-check':
                violations.extend(self._check_content_rule(file_path, content, rule))
            elif check_type == 'file-pattern':
                violations.extend(self._check_file_pattern_rule(file_path, rule))
            elif check_type == 'file-exists':
                violations.extend(self._check_file_exists_rule(file_path, rule))
            
        except UnicodeDecodeError:
            # Skip binary files
            pass
        except Exception as e:
            print(f"Warning: Error checking {file_path} against rule {rule.name}: {str(e)}")
        
        return violations
    
    def _check_content_rule(self, file_path: Path, content: str, rule: KiroRule) -> List[KiroViolation]:
        """Check content-based rules."""
        violations = []
        lines = content.split('\n')
        
        content_pattern = rule.check.get('content-pattern', '')
        match_pattern = rule.check.get('match-pattern', '')
        condition = rule.check.get('condition', 'must-contain')
        
        if condition == 'must-contain':
            if not re.search(content_pattern, content, re.IGNORECASE | re.MULTILINE):
                violations.append(KiroViolation(
                    rule_name=rule.name,
                    file_path=str(file_path),
                    line_number=1,
                    message=rule.message,
                    severity=rule.severity,
                    framework=rule.framework
                ))
        
        elif condition == 'must-not-contain':
            matches = list(re.finditer(content_pattern, content, re.IGNORECASE | re.MULTILINE))
            for match in matches:
                line_number = content[:match.start()].count('\n') + 1
                violations.append(KiroViolation(
                    rule_name=rule.name,
                    file_path=str(file_path),
                    line_number=line_number,
                    message=rule.message,
                    severity=rule.severity,
                    framework=rule.framework,
                    matched_content=match.group()
                ))
        
        elif condition == 'must-contain-for-matches':
            # Check if file contains match pattern
            if re.search(match_pattern, content, re.IGNORECASE | re.MULTILINE):
                # If it does, it must also contain the content pattern
                if not re.search(content_pattern, content, re.IGNORECASE | re.MULTILINE):
                    # Find the line with the match pattern
                    match_lines = []
                    for i, line in enumerate(lines, 1):
                        if re.search(match_pattern, line, re.IGNORECASE):
                            match_lines.append(i)
                    
                    for line_number in match_lines:
                        violations.append(KiroViolation(
                            rule_name=rule.name,
                            file_path=str(file_path),
                            line_number=line_number,
                            message=rule.message,
                            severity=rule.severity,
                            framework=rule.framework,
                            matched_content=lines[line_number - 1] if line_number <= len(lines) else ""
                        ))
        
        elif condition == 'must-contain-for-classes-with':
            # Find classes that contain the match pattern
            class_pattern = r'class\s+(\w+).*?:'
            current_class = None
            class_start_line = 0
            in_class = False
            indent_level = 0
            
            for i, line in enumerate(lines, 1):
                stripped_line = line.strip()
                if not stripped_line or stripped_line.startswith('#'):
                    continue
                
                # Calculate indentation
                line_indent = len(line) - len(line.lstrip())
                
                # Check for class definition
                class_match = re.match(class_pattern, stripped_line)
                if class_match:
                    current_class = class_match.group(1)
                    class_start_line = i
                    in_class = True
                    indent_level = line_indent
                    continue
                
                # If we're in a class and hit a line at the same or lower indentation, we've left the class
                if in_class and line_indent <= indent_level and stripped_line and not stripped_line.startswith('@'):
                    in_class = False
                    current_class = None
                
                # Check if this line in the class matches our pattern
                if in_class and re.search(match_pattern, line, re.IGNORECASE):
                    # Now check if the class has the required content pattern
                    class_content = '\n'.join(lines[class_start_line - 1:i])
                    if not re.search(content_pattern, class_content, re.IGNORECASE | re.MULTILINE):
                        violations.append(KiroViolation(
                            rule_name=rule.name,
                            file_path=str(file_path),
                            line_number=class_start_line,
                            message=f"{rule.message} (Class: {current_class})",
                            severity=rule.severity,
                            framework=rule.framework,
                            matched_content=line.strip()
                        ))
                    break  # Only report once per class
        
        return violations
    
    def _check_file_pattern_rule(self, file_path: Path, rule: KiroRule) -> List[KiroViolation]:
        """Check file pattern rules (e.g., requiring corresponding test files)."""
        violations = []
        
        requires_test = rule.check.get('requires-corresponding-test')
        if requires_test:
            # Generate expected test file path
            test_pattern = requires_test.replace('*', file_path.stem)
            project_root = self._find_project_root(file_path)
            test_path = project_root / test_pattern
            
            if not test_path.exists():
                violations.append(KiroViolation(
                    rule_name=rule.name,
                    file_path=str(file_path),
                    line_number=1,
                    message=f"{rule.message} (Expected: {test_path})",
                    severity=rule.severity,
                    framework=rule.framework
                ))
        
        return violations
    
    def _check_file_exists_rule(self, file_path: Path, rule: KiroRule) -> List[KiroViolation]:
        """Check file existence rules."""
        violations = []
        
        required_pattern = rule.check.get('pattern')
        if required_pattern:
            project_root = self._find_project_root(file_path)
            required_path = project_root / required_pattern
            
            if not required_path.exists():
                violations.append(KiroViolation(
                    rule_name=rule.name,
                    file_path=str(file_path),
                    line_number=1,
                    message=f"{rule.message} (Missing: {required_path})",
                    severity=rule.severity,
                    framework=rule.framework
                ))
        
        return violations
    
    def _file_matches_pattern(self, file_path: Path, pattern: str) -> bool:
        """Check if a file matches a glob pattern."""
        from fnmatch import fnmatch
        return fnmatch(str(file_path), pattern) or fnmatch(file_path.name, pattern)
    
    def _matches_exclude_patterns(self, name: str, exclude_patterns: List[str]) -> bool:
        """Check if a name matches any exclude patterns."""
        from fnmatch import fnmatch
        return any(fnmatch(name, pattern) for pattern in exclude_patterns)
    
    def _find_project_root(self, file_path: Path) -> Path:
        """Find the project root directory."""
        current = file_path.parent
        while current.parent != current:
            if (current / 'pyproject.toml').exists() or (current / '.git').exists():
                return current
            current = current.parent
        return file_path.parent
    
    def generate_report(self, output_format: str = 'text') -> str:
        """
        Generate a report of compliance violations.
        
        Args:
            output_format: Format for the report ('text', 'json', 'html')
            
        Returns:
            Report content as string
        """
        if output_format == 'json':
            return self._generate_json_report()
        elif output_format == 'html':
            return self._generate_html_report()
        else:
            return self._generate_text_report()
    
    def _generate_text_report(self) -> str:
        """Generate a text report."""
        if not self.violations:
            return "✅ No compliance violations found!"
        
        report = f"📋 Compliance Report - {len(self.violations)} violations found\n"
        report += "=" * 60 + "\n\n"
        
        # Group by severity
        by_severity = {}
        for violation in self.violations:
            by_severity.setdefault(violation.severity, []).append(violation)
        
        # Sort by severity (critical first)
        severity_order = ['critical', 'error', 'warning', 'info']
        
        for severity in severity_order:
            if severity not in by_severity:
                continue
            
            violations = by_severity[severity]
            icon = {'critical': '🚨', 'error': '❌', 'warning': '⚠️', 'info': 'ℹ️'}[severity]
            
            report += f"{icon} {severity.upper()} ({len(violations)})\n"
            report += "-" * 40 + "\n"
            
            for violation in violations:
                report += f"File: {violation.file_path}:{violation.line_number}\n"
                report += f"Rule: {violation.rule_name} ({violation.framework})\n"
                report += f"Message: {violation.message}\n"
                if violation.matched_content:
                    report += f"Code: {violation.matched_content}\n"
                report += "\n"
        
        return report
    
    def _generate_json_report(self) -> str:
        """Generate a JSON report."""
        import json
        
        data = {
            'summary': {
                'total_violations': len(self.violations),
                'by_severity': {},
                'by_framework': {}
            },
            'violations': []
        }
        
        # Calculate summaries
        for violation in self.violations:
            data['summary']['by_severity'][violation.severity] = \
                data['summary']['by_severity'].get(violation.severity, 0) + 1
            data['summary']['by_framework'][violation.framework] = \
                data['summary']['by_framework'].get(violation.framework, 0) + 1
            
            data['violations'].append({
                'rule_name': violation.rule_name,
                'file_path': violation.file_path,
                'line_number': violation.line_number,
                'message': violation.message,
                'severity': violation.severity,
                'framework': violation.framework,
                'matched_content': violation.matched_content
            })
        
        return json.dumps(data, indent=2)
    
    def _generate_html_report(self) -> str:
        """Generate an HTML report."""
        if not self.violations:
            return """
            <html><body>
            <h1>✅ Compliance Report</h1>
            <p>No compliance violations found!</p>
            </body></html>
            """
        
        html = f"""
        <html>
        <head>
            <title>CloudScope Compliance Report</title>
            <style>
                body {{ font-family: Arial, sans-serif; margin: 20px; }}
                .header {{ background-color: #f0f0f0; padding: 20px; border-radius: 5px; }}
                .violation {{ margin: 10px 0; padding: 15px; border-left: 4px solid; }}
                .critical {{ border-left-color: #d32f2f; background-color: #ffebee; }}
                .error {{ border-left-color: #f57c00; background-color: #fff3e0; }}
                .warning {{ border-left-color: #fbc02d; background-color: #fffde7; }}
                .info {{ border-left-color: #1976d2; background-color: #e3f2fd; }}
                .code {{ background-color: #f5f5f5; padding: 5px; font-family: monospace; }}
            </style>
        </head>
        <body>
            <div class="header">
                <h1>📋 CloudScope Compliance Report</h1>
                <p>{len(self.violations)} violations found</p>
            </div>
        """
        
        # Group and display violations
        by_severity = {}
        for violation in self.violations:
            by_severity.setdefault(violation.severity, []).append(violation)
        
        for severity in ['critical', 'error', 'warning', 'info']:
            if severity not in by_severity:
                continue
            
            violations = by_severity[severity]
            html += f"<h2>{severity.upper()} ({len(violations)})</h2>"
            
            for violation in violations:
                html += f"""
                <div class="violation {severity}">
                    <h4>{violation.rule_name} ({violation.framework})</h4>
                    <p><strong>File:</strong> {violation.file_path}:{violation.line_number}</p>
                    <p><strong>Message:</strong> {violation.message}</p>
                """
                
                if violation.matched_content:
                    html += f'<div class="code">{violation.matched_content}</div>'
                
                html += "</div>"
        
        html += "</body></html>"
        return html


def main():
    """Main CLI entry point for Kiro compliance checking."""
    parser = argparse.ArgumentParser(description='CloudScope Kiro Compliance Checker')
    parser.add_argument('path', help='Path to check (file or directory)')
    parser.add_argument('--rules', help='Path to rules YAML file')
    parser.add_argument('--format', choices=['text', 'json', 'html'], 
                        default='text', help='Output format')
    parser.add_argument('--output', '-o', help='Output file (default: stdout)')
    parser.add_argument('--severity', choices=['critical', 'error', 'warning', 'info'],
                        help='Minimum severity level to report')
    parser.add_argument('--framework', help='Filter by specific framework')
    parser.add_argument('--exclude', nargs='*', 
                        default=['test_*', '__pycache__', '.git'],
                        help='Patterns to exclude')
    parser.add_argument('--fail-on-violations', action='store_true',
                        help='Exit with error code if violations found')
    
    args = parser.parse_args()
    
    # Initialize processor
    processor = KiroComplianceProcessor(args.rules)
    
    # Check the specified path
    path = Path(args.path)
    if path.is_file():
        violations = processor.check_file(str(path))
    elif path.is_dir():
        violations = processor.check_directory(str(path), args.exclude)
    else:
        print(f"Error: Path '{path}' does not exist")
        sys.exit(1)
    
    # Filter violations
    if args.severity:
        severity_order = {'info': 0, 'warning': 1, 'error': 2, 'critical': 3}
        min_level = severity_order.get(args.severity, 0)
        violations = [
            v for v in violations 
            if severity_order.get(v.severity, 0) >= min_level
        ]
    
    if args.framework:
        violations = [v for v in violations if v.framework == args.framework]
    
    processor.violations = violations
    
    # Generate report
    report = processor.generate_report(args.format)
    
    # Output report
    if args.output:
        with open(args.output, 'w') as f:
            f.write(report)
        print(f"Report saved to: {args.output}")
    else:
        print(report)
    
    # Exit with appropriate code
    if args.fail_on_violations and violations:
        critical_count = len([v for v in violations if v.severity == 'critical'])
        error_count = len([v for v in violations if v.severity == 'error'])
        
        if critical_count > 0:
            sys.exit(2)  # Critical violations
        elif error_count > 0:
            sys.exit(1)  # Error violations
    
    sys.exit(0)


if __name__ == '__main__':
    main()
