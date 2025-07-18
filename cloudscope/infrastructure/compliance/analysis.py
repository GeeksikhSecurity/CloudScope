"""
Static analysis for compliance verification in CloudScope.

This module provides static analysis tools to verify compliance
requirements during development and CI/CD pipelines.
"""

import ast
import os
import re
from typing import List, Dict, Any, Optional, Set
from dataclasses import dataclass
from pathlib import Path

from .exceptions import ComplianceViolationError


@dataclass
class ComplianceIssue:
    """Represents a compliance issue found during static analysis."""
    file_path: str
    line_number: int
    issue_type: str
    description: str
    severity: str
    framework: str
    recommendation: str
    code_snippet: Optional[str] = None


@dataclass
class ComplianceReport:
    """Compliance analysis report."""
    total_files_analyzed: int
    issues_found: List[ComplianceIssue]
    compliance_score: float
    framework_scores: Dict[str, float]
    
    def get_issues_by_severity(self, severity: str) -> List[ComplianceIssue]:
        """Get issues filtered by severity."""
        return [issue for issue in self.issues_found if issue.severity == severity]
    
    def get_issues_by_framework(self, framework: str) -> List[ComplianceIssue]:
        """Get issues filtered by framework."""
        return [issue for issue in self.issues_found if issue.framework == framework]


class ComplianceStaticAnalyzer:
    """Static analyzer for compliance requirements."""
    
    def __init__(self):
        self.personal_data_patterns = [
            r'.*name.*', r'.*email.*', r'.*address.*', r'.*phone.*',
            r'.*ssn.*', r'.*social.*', r'.*birth.*', r'.*dob.*'
        ]
        
        self.health_data_patterns = [
            r'.*health.*', r'.*medical.*', r'.*patient.*', r'.*diagnosis.*',
            r'.*treatment.*', r'.*medication.*', r'.*symptom.*'
        ]
        
        self.financial_data_patterns = [
            r'.*card.*', r'.*payment.*', r'.*credit.*', r'.*cvv.*',
            r'.*account.*', r'.*bank.*', r'.*financial.*'
        ]
    
    def analyze_file(self, file_path: str) -> List[ComplianceIssue]:
        """
        Analyze a single Python file for compliance issues.
        
        Args:
            file_path: Path to the Python file to analyze
        
        Returns:
            List of compliance issues found
        """
        issues = []
        
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Parse the AST
            tree = ast.parse(content, filename=file_path)
            
            # Run various compliance checks
            issues.extend(self._check_gdpr_compliance(tree, file_path, content))
            issues.extend(self._check_pci_compliance(tree, file_path, content))
            issues.extend(self._check_hipaa_compliance(tree, file_path, content))
            issues.extend(self._check_general_security(tree, file_path, content))
            
        except SyntaxError as e:
            issues.append(ComplianceIssue(
                file_path=file_path,
                line_number=e.lineno or 0,
                issue_type="syntax_error",
                description=f"Syntax error prevents compliance analysis: {str(e)}",
                severity="error",
                framework="GENERAL",
                recommendation="Fix syntax errors before compliance analysis"
            ))
        except Exception as e:
            issues.append(ComplianceIssue(
                file_path=file_path,
                line_number=0,
                issue_type="analysis_error",
                description=f"Error during compliance analysis: {str(e)}",
                severity="warning",
                framework="GENERAL",
                recommendation="Review file manually for compliance issues"
            ))
        
        return issues
    
    def analyze_directory(self, directory_path: str, exclude_patterns: List[str] = None) -> ComplianceReport:
        """
        Analyze all Python files in a directory for compliance issues.
        
        Args:
            directory_path: Path to directory to analyze
            exclude_patterns: Patterns to exclude from analysis
        
        Returns:
            ComplianceReport with analysis results
        """
        if exclude_patterns is None:
            exclude_patterns = ['test_*', '*_test.py', '__pycache__', '.git']
        
        all_issues = []
        files_analyzed = 0
        
        for root, dirs, files in os.walk(directory_path):
            # Filter out excluded directories
            dirs[:] = [d for d in dirs if not any(re.match(pattern.replace('*', '.*'), d) for pattern in exclude_patterns)]
            
            for file in files:
                if file.endswith('.py'):
                    file_path = os.path.join(root, file)
                    
                    # Check if file should be excluded
                    if any(re.match(pattern.replace('*', '.*'), file) for pattern in exclude_patterns):
                        continue
                    
                    files_analyzed += 1
                    issues = self.analyze_file(file_path)
                    all_issues.extend(issues)
        
        # Calculate compliance scores
        total_checks = files_analyzed * 10  # Assume 10 checks per file
        issues_count = len(all_issues)
        compliance_score = max(0, (total_checks - issues_count) / total_checks * 100) if total_checks > 0 else 100
        
        # Calculate framework-specific scores
        framework_scores = {}
        frameworks = set(issue.framework for issue in all_issues)
        
        for framework in frameworks:
            framework_issues = [issue for issue in all_issues if issue.framework == framework]
            framework_checks = files_analyzed * 3  # Assume 3 checks per framework per file
            framework_score = max(0, (framework_checks - len(framework_issues)) / framework_checks * 100) if framework_checks > 0 else 100
            framework_scores[framework] = framework_score
        
        return ComplianceReport(
            total_files_analyzed=files_analyzed,
            issues_found=all_issues,
            compliance_score=compliance_score,
            framework_scores=framework_scores
        )
    
    def _check_gdpr_compliance(self, tree: ast.AST, file_path: str, content: str) -> List[ComplianceIssue]:
        """Check GDPR compliance requirements."""
        issues = []
        lines = content.split('\n')
        
        for node in ast.walk(tree):
            if isinstance(node, ast.ClassDef):
                # Check class attributes for personal data
                for attr_node in node.body:
                    if isinstance(attr_node, ast.AnnAssign) and hasattr(attr_node.target, 'id'):
                        attr_name = attr_node.target.id
                        
                        # Check if attribute contains personal data patterns
                        if any(re.match(pattern, attr_name.lower()) for pattern in self.personal_data_patterns):
                            # Check if attribute has data classification
                            if not self._has_data_classification(attr_node, content, "personal"):
                                issues.append(ComplianceIssue(
                                    file_path=file_path,
                                    line_number=attr_node.lineno,
                                    issue_type="missing_data_classification",
                                    description=f"Personal data '{attr_name}' in class '{node.name}' is not classified",
                                    severity="error",
                                    framework="GDPR",
                                    recommendation="Add @data_classification('personal') decorator",
                                    code_snippet=lines[attr_node.lineno - 1] if attr_node.lineno <= len(lines) else None
                                ))
            
            elif isinstance(node, ast.FunctionDef):
                # Check functions that handle personal data
                func_name = node.name.lower()
                if any(pattern in func_name for pattern in ['email', 'name', 'address', 'personal']):
                    if not self._has_gdpr_decorator(node, content):
                        issues.append(ComplianceIssue(
                            file_path=file_path,
                            line_number=node.lineno,
                            issue_type="missing_gdpr_controls",
                            description=f"Function '{node.name}' handles personal data but lacks GDPR controls",
                            severity="warning",
                            framework="GDPR",
                            recommendation="Add @data_classification('personal') or @audit_log decorator",
                            code_snippet=lines[node.lineno - 1] if node.lineno <= len(lines) else None
                        ))
        
        return issues
    
    def _check_pci_compliance(self, tree: ast.AST, file_path: str, content: str) -> List[ComplianceIssue]:
        """Check PCI DSS compliance requirements."""
        issues = []
        lines = content.split('\n')
        
        for node in ast.walk(tree):
            if isinstance(node, ast.ClassDef):
                # Check if class handles payment data
                class_name = node.name.lower()
                if any(pattern in class_name for pattern in ['payment', 'card', 'credit']):
                    if not self._has_pci_scope_decorator(node, content):
                        issues.append(ComplianceIssue(
                            file_path=file_path,
                            line_number=node.lineno,
                            issue_type="missing_pci_scope",
                            description=f"Class '{node.name}' handles payment data but is not marked as PCI scope",
                            severity="error",
                            framework="PCI_DSS",
                            recommendation="Add @pci_scope decorator to class",
                            code_snippet=lines[node.lineno - 1] if node.lineno <= len(lines) else None
                        ))
                
                # Check for card data attributes
                for attr_node in node.body:
                    if isinstance(attr_node, ast.AnnAssign) and hasattr(attr_node.target, 'id'):
                        attr_name = attr_node.target.id
                        
                        if any(re.match(pattern, attr_name.lower()) for pattern in self.financial_data_patterns):
                            if not self._has_encryption_decorator(attr_node, content):
                                issues.append(ComplianceIssue(
                                    file_path=file_path,
                                    line_number=attr_node.lineno,
                                    issue_type="missing_encryption",
                                    description=f"Payment data '{attr_name}' is not encrypted",
                                    severity="critical",
                                    framework="PCI_DSS",
                                    recommendation="Add @encrypted decorator to sensitive data setters",
                                    code_snippet=lines[attr_node.lineno - 1] if attr_node.lineno <= len(lines) else None
                                ))
        
        return issues
    
    def _check_hipaa_compliance(self, tree: ast.AST, file_path: str, content: str) -> List[ComplianceIssue]:
        """Check HIPAA compliance requirements."""
        issues = []
        lines = content.split('\n')
        
        for node in ast.walk(tree):
            if isinstance(node, ast.ClassDef):
                # Check class attributes for health data
                for attr_node in node.body:
                    if isinstance(attr_node, ast.AnnAssign) and hasattr(attr_node.target, 'id'):
                        attr_name = attr_node.target.id
                        
                        if any(re.match(pattern, attr_name.lower()) for pattern in self.health_data_patterns):
                            if not self._has_data_classification(attr_node, content, "health"):
                                issues.append(ComplianceIssue(
                                    file_path=file_path,
                                    line_number=attr_node.lineno,
                                    issue_type="missing_health_classification",
                                    description=f"Health data '{attr_name}' in class '{node.name}' is not classified",
                                    severity="error",
                                    framework="HIPAA",
                                    recommendation="Add @data_classification('health') decorator",
                                    code_snippet=lines[attr_node.lineno - 1] if attr_node.lineno <= len(lines) else None
                                ))
            
            elif isinstance(node, ast.FunctionDef):
                # Check functions that handle health data
                func_name = node.name.lower()
                if any(pattern in func_name for pattern in ['medical', 'health', 'patient', 'diagnosis']):
                    if not self._has_audit_decorator(node, content):
                        issues.append(ComplianceIssue(
                            file_path=file_path,
                            line_number=node.lineno,
                            issue_type="missing_audit_log",
                            description=f"Function '{node.name}' handles health data but is not audit logged",
                            severity="error",
                            framework="HIPAA",
                            recommendation="Add @audit_log decorator to function",
                            code_snippet=lines[node.lineno - 1] if node.lineno <= len(lines) else None
                        ))
        
        return issues
    
    def _check_general_security(self, tree: ast.AST, file_path: str, content: str) -> List[ComplianceIssue]:
        """Check general security requirements."""
        issues = []
        lines = content.split('\n')
        
        for node in ast.walk(tree):
            if isinstance(node, ast.FunctionDef):
                # Check for administrative functions
                func_name = node.name.lower()
                if any(admin_pattern in func_name for admin_pattern in ['delete', 'admin', 'config', 'system']):
                    if not self._has_access_control_decorator(node, content):
                        issues.append(ComplianceIssue(
                            file_path=file_path,
                            line_number=node.lineno,
                            issue_type="missing_access_control",
                            description=f"Administrative function '{node.name}' lacks access control",
                            severity="warning",
                            framework="SOC2",
                            recommendation="Add @access_control(['admin']) decorator",
                            code_snippet=lines[node.lineno - 1] if node.lineno <= len(lines) else None
                        ))
            
            # Check for hardcoded secrets
            if isinstance(node, ast.Assign):
                for target in node.targets:
                    if isinstance(target, ast.Name):
                        var_name = target.id.lower()
                        if any(secret_pattern in var_name for secret_pattern in ['password', 'secret', 'key', 'token']):
                            if isinstance(node.value, ast.Constant) and isinstance(node.value.value, str):
                                issues.append(ComplianceIssue(
                                    file_path=file_path,
                                    line_number=node.lineno,
                                    issue_type="hardcoded_secret",
                                    description=f"Hardcoded secret detected in variable '{target.id}'",
                                    severity="critical",
                                    framework="GENERAL",
                                    recommendation="Move secrets to environment variables or secure storage",
                                    code_snippet=lines[node.lineno - 1] if node.lineno <= len(lines) else None
                                ))
        
        return issues
    
    def _has_data_classification(self, node: ast.AST, content: str, classification: str) -> bool:
        """Check if a node has data classification decorator."""
        # Look for @data_classification decorator in surrounding context
        # This is a simplified check - in practice, you'd need more sophisticated AST analysis
        context_lines = self._get_context_lines(node, content, 5)
        pattern = rf"@data_classification\(['\"]?{classification}['\"]?\)"
        return any(re.search(pattern, line) for line in context_lines)
    
    def _has_encryption_decorator(self, node: ast.AST, content: str) -> bool:
        """Check if a node has encryption decorator."""
        context_lines = self._get_context_lines(node, content, 10)
        return any('@encrypted' in line for line in context_lines)
    
    def _has_audit_decorator(self, node: ast.AST, content: str) -> bool:
        """Check if a node has audit log decorator."""
        context_lines = self._get_context_lines(node, content, 5)
        return any('@audit_log' in line for line in context_lines)
    
    def _has_access_control_decorator(self, node: ast.AST, content: str) -> bool:
        """Check if a node has access control decorator."""
        context_lines = self._get_context_lines(node, content, 5)
        return any('@access_control' in line for line in context_lines)
    
    def _has_pci_scope_decorator(self, node: ast.AST, content: str) -> bool:
        """Check if a class has PCI scope decorator."""
        context_lines = self._get_context_lines(node, content, 5)
        return any('@pci_scope' in line for line in context_lines)
    
    def _has_gdpr_decorator(self, node: ast.AST, content: str) -> bool:
        """Check if a node has GDPR-related decorators."""
        context_lines = self._get_context_lines(node, content, 5)
        gdpr_decorators = ['@data_classification', '@audit_log']
        return any(decorator in line for line in context_lines for decorator in gdpr_decorators)
    
    def _get_context_lines(self, node: ast.AST, content: str, context_size: int = 5) -> List[str]:
        """Get lines around a node for context analysis."""
        lines = content.split('\n')
        start_line = max(0, node.lineno - context_size - 1)
        end_line = min(len(lines), node.lineno + context_size)
        return lines[start_line:end_line]


def generate_compliance_report_html(report: ComplianceReport, output_path: str) -> None:
    """
    Generate an HTML compliance report.
    
    Args:
        report: ComplianceReport to generate HTML for
        output_path: Path to save HTML report
    """
    html_template = """
    <!DOCTYPE html>
    <html>
    <head>
        <title>CloudScope Compliance Report</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 20px; }
            .header { background-color: #f0f0f0; padding: 20px; border-radius: 5px; }
            .summary { display: flex; justify-content: space-around; margin: 20px 0; }
            .metric { text-align: center; padding: 10px; border: 1px solid #ddd; border-radius: 5px; }
            .issues { margin-top: 20px; }
            .issue { margin: 10px 0; padding: 15px; border-left: 4px solid; }
            .critical { border-left-color: #d32f2f; background-color: #ffebee; }
            .error { border-left-color: #f57c00; background-color: #fff3e0; }
            .warning { border-left-color: #fbc02d; background-color: #fffde7; }
            .info { border-left-color: #1976d2; background-color: #e3f2fd; }
            .code { background-color: #f5f5f5; padding: 5px; border-radius: 3px; font-family: monospace; }
        </style>
    </head>
    <body>
        <div class="header">
            <h1>CloudScope Compliance Report</h1>
            <p>Generated on: {timestamp}</p>
        </div>
        
        <div class="summary">
            <div class="metric">
                <h3>Overall Score</h3>
                <h2>{compliance_score:.1f}%</h2>
            </div>
            <div class="metric">
                <h3>Files Analyzed</h3>
                <h2>{files_analyzed}</h2>
            </div>
            <div class="metric">
                <h3>Issues Found</h3>
                <h2>{total_issues}</h2>
            </div>
        </div>
        
        <div class="framework-scores">
            <h2>Framework Scores</h2>
            {framework_scores_html}
        </div>
        
        <div class="issues">
            <h2>Issues Found</h2>
            {issues_html}
        </div>
    </body>
    </html>
    """
    
    # Generate framework scores HTML
    framework_scores_html = ""
    for framework, score in report.framework_scores.items():
        framework_scores_html += f"""
        <div class="metric">
            <h4>{framework}</h4>
            <p>{score:.1f}%</p>
        </div>
        """
    
    # Generate issues HTML
    issues_html = ""
    for issue in report.issues_found:
        severity_class = issue.severity.lower()
        code_snippet = f'<div class="code">{issue.code_snippet}</div>' if issue.code_snippet else ''
        
        issues_html += f"""
        <div class="issue {severity_class}">
            <h4>{issue.issue_type} ({issue.severity.upper()})</h4>
            <p><strong>File:</strong> {issue.file_path}:{issue.line_number}</p>
            <p><strong>Framework:</strong> {issue.framework}</p>
            <p><strong>Description:</strong> {issue.description}</p>
            <p><strong>Recommendation:</strong> {issue.recommendation}</p>
            {code_snippet}
        </div>
        """
    
    html_content = html_template.format(
        timestamp=datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        compliance_score=report.compliance_score,
        files_analyzed=report.total_files_analyzed,
        total_issues=len(report.issues_found),
        framework_scores_html=framework_scores_html,
        issues_html=issues_html
    )
    
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(html_content)
