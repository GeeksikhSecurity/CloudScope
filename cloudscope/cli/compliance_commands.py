"""
Compliance CLI commands for CloudScope.

Provides command-line interface for compliance analysis, monitoring,
and reporting functionality.
"""

import argparse
import json
import sys
from pathlib import Path
from typing import List, Optional

from cloudscope.infrastructure.compliance.analysis import (
    ComplianceStaticAnalyzer,
    generate_compliance_report_html
)
from cloudscope.infrastructure.compliance.monitoring import get_compliance_monitor
from cloudscope.infrastructure.compliance.context import User, user_context


class ComplianceCommands:
    """CLI commands for compliance functionality."""
    
    def __init__(self):
        self.analyzer = ComplianceStaticAnalyzer()
        self.monitor = get_compliance_monitor()
    
    def add_compliance_commands(self, parser: argparse.ArgumentParser) -> None:
        """
        Add compliance-related commands to the argument parser.
        
        Args:
            parser: Main argument parser to add commands to
        """
        # Create compliance subparser
        compliance_parser = parser.add_subparser(
            'compliance',
            help='Compliance-as-code operations'
        )
        compliance_subparsers = compliance_parser.add_subparsers(
            dest='compliance_command',
            help='Compliance commands'
        )
        
        # Analyze command
        analyze_parser = compliance_subparsers.add_parser(
            'analyze',
            help='Run static compliance analysis'
        )
        analyze_parser.add_argument(
            'path',
            help='Path to analyze (file or directory)'
        )
        analyze_parser.add_argument(
            '--output', '-o',
            default='compliance_report.html',
            help='Output file for report (default: compliance_report.html)'
        )
        analyze_parser.add_argument(
            '--format', '-f',
            choices=['html', 'json', 'console'],
            default='html',
            help='Output format (default: html)'
        )
        analyze_parser.add_argument(
            '--framework',
            choices=['GDPR', 'PCI_DSS', 'HIPAA', 'SOC2', 'ALL'],
            default='ALL',
            help='Specific framework to analyze (default: ALL)'
        )
        analyze_parser.add_argument(
            '--exclude',
            nargs='*',
            default=['test_*', '*_test.py', '__pycache__', '.git'],
            help='Patterns to exclude from analysis'
        )
        analyze_parser.add_argument(
            '--severity',
            choices=['critical', 'error', 'warning', 'info'],
            help='Minimum severity level to report'
        )
        
        # Monitor command
        monitor_parser = compliance_subparsers.add_parser(
            'monitor',
            help='View compliance monitoring results'
        )
        monitor_parser.add_argument(
            '--period',
            type=int,
            default=24,
            help='Period in hours to analyze (default: 24)'
        )
        monitor_parser.add_argument(
            '--violations-only',
            action='store_true',
            help='Show only violations'
        )
        monitor_parser.add_argument(
            '--framework',
            help='Filter by specific framework'
        )
        monitor_parser.add_argument(
            '--user',
            help='Filter by specific user ID'
        )
        
        # Report command
        report_parser = compliance_subparsers.add_parser(
            'report',
            help='Generate compliance reports'
        )
        report_parser.add_argument(
            '--type',
            choices=['violations', 'metrics', 'evidence'],
            default='metrics',
            help='Type of report to generate (default: metrics)'
        )
        report_parser.add_argument(
            '--output', '-o',
            help='Output file path'
        )
        report_parser.add_argument(
            '--format', '-f',
            choices=['json', 'csv', 'html'],
            default='json',
            help='Output format (default: json)'
        )
        report_parser.add_argument(
            '--period',
            type=int,
            default=30,
            help='Period in days to analyze (default: 30)'
        )
        
        # Check command  
        check_parser = compliance_subparsers.add_parser(
            'check',
            help='Run compliance checks on specific files'
        )
        check_parser.add_argument(
            'files',
            nargs='+',
            help='Files to check for compliance'
        )
        check_parser.add_argument(
            '--fix',
            action='store_true',
            help='Attempt to automatically fix issues'
        )
        check_parser.add_argument(
            '--framework',
            help='Specific framework to check against'
        )
        
        # Config command
        config_parser = compliance_subparsers.add_parser(
            'config',
            help='Configure compliance settings'
        )
        config_parser.add_argument(
            '--set',
            nargs=2,
            metavar=('KEY', 'VALUE'),
            help='Set configuration value'
        )
        config_parser.add_argument(
            '--get',
            help='Get configuration value'
        )
        config_parser.add_argument(
            '--list',
            action='store_true',
            help='List all configuration values'
        )
    
    def handle_compliance_command(self, args) -> int:
        """
        Handle compliance CLI commands.
        
        Args:
            args: Parsed command-line arguments
            
        Returns:
            Exit code (0 for success, non-zero for error)
        """
        try:
            if args.compliance_command == 'analyze':
                return self._handle_analyze(args)
            elif args.compliance_command == 'monitor':
                return self._handle_monitor(args)
            elif args.compliance_command == 'report':
                return self._handle_report(args)
            elif args.compliance_command == 'check':
                return self._handle_check(args)
            elif args.compliance_command == 'config':
                return self._handle_config(args)
            else:
                print(f"Unknown compliance command: {args.compliance_command}")
                return 1
                
        except Exception as e:
            print(f"Error executing compliance command: {str(e)}")
            return 1
    
    def _handle_analyze(self, args) -> int:
        """Handle the analyze command."""
        path = Path(args.path)
        
        if not path.exists():
            print(f"Error: Path '{path}' does not exist")
            return 1
        
        print(f"Analyzing compliance for: {path}")
        
        # Run analysis
        if path.is_file():
            issues = self.analyzer.analyze_file(str(path))
            report = type('Report', (), {
                'total_files_analyzed': 1,
                'issues_found': issues,
                'compliance_score': max(0, (10 - len(issues)) / 10 * 100),
                'framework_scores': self._calculate_framework_scores(issues)
            })()
        else:
            report = self.analyzer.analyze_directory(
                str(path),
                exclude_patterns=args.exclude
            )
        
        # Filter by framework if specified
        if args.framework != 'ALL':
            report.issues_found = [
                issue for issue in report.issues_found 
                if issue.framework == args.framework
            ]
        
        # Filter by severity if specified
        if args.severity:
            severity_order = {'info': 0, 'warning': 1, 'error': 2, 'critical': 3}
            min_level = severity_order.get(args.severity, 0)
            report.issues_found = [
                issue for issue in report.issues_found
                if severity_order.get(issue.severity, 0) >= min_level
            ]
        
        # Output results
        if args.format == 'console':
            self._print_console_report(report)
        elif args.format == 'json':
            self._save_json_report(report, args.output)
        elif args.format == 'html':
            generate_compliance_report_html(report, args.output)
            print(f"HTML report saved to: {args.output}")
        
        # Return appropriate exit code
        critical_issues = [i for i in report.issues_found if i.severity == 'critical']
        error_issues = [i for i in report.issues_found if i.severity == 'error']
        
        if critical_issues:
            return 2  # Critical issues found
        elif error_issues:
            return 1  # Error issues found
        else:
            return 0  # Success
    
    def _handle_monitor(self, args) -> int:
        """Handle the monitor command."""
        print(f"Compliance monitoring for last {args.period} hours")
        
        # Get violations
        violations = self.monitor.get_violations()
        
        # Apply filters
        if args.framework:
            violations = [v for v in violations if v.framework == args.framework]
        
        if args.user:
            violations = [v for v in violations if v.user_id == args.user]
        
        # Get metrics
        metrics = self.monitor.get_metrics(args.period)
        
        if not args.violations_only:
            print("\n=== Compliance Metrics ===")
            print(f"Total operations: {metrics.total_operations}")
            print(f"Compliant operations: {metrics.compliant_operations}")
            print(f"Compliance rate: {metrics.compliance_rate:.1f}%")
            print(f"Violations: {metrics.violation_count}")
            
            if metrics.violations_by_framework:
                print("\nViolations by framework:")
                for framework, count in metrics.violations_by_framework.items():
                    print(f"  {framework}: {count}")
        
        if violations:
            print(f"\n=== Violations ({len(violations)}) ===")
            for violation in violations[-10:]:  # Show last 10 violations
                print(f"\n{violation.timestamp.strftime('%Y-%m-%d %H:%M:%S')} - {violation.severity.upper()}")
                print(f"Type: {violation.violation_type}")
                print(f"User: {violation.user_id or 'System'}")
                print(f"Framework: {violation.framework or 'N/A'}")
                print(f"Description: {violation.description}")
                if violation.remediation:
                    print(f"Remediation: {violation.remediation}")
        
        return 0
    
    def _handle_report(self, args) -> int:
        """Handle the report command."""
        print(f"Generating {args.type} compliance report")
        
        if args.type == 'violations':
            violations = self.monitor.get_violations()
            data = [
                {
                    'id': v.id,
                    'type': v.violation_type,
                    'description': v.description,
                    'user_id': v.user_id,
                    'timestamp': v.timestamp.isoformat(),
                    'severity': v.severity,
                    'framework': v.framework,
                    'remediation': v.remediation
                }
                for v in violations
            ]
        
        elif args.type == 'metrics':
            metrics = self.monitor.get_metrics(args.period * 24)  # Convert days to hours
            data = {
                'total_operations': metrics.total_operations,
                'compliant_operations': metrics.compliant_operations,
                'compliance_rate': metrics.compliance_rate,
                'violation_count': metrics.violation_count,
                'violations_by_type': dict(metrics.violations_by_type),
                'violations_by_user': dict(metrics.violations_by_user),
                'violations_by_framework': dict(metrics.violations_by_framework)
            }
        
        elif args.type == 'evidence':
            # Placeholder for evidence collection
            data = {
                'evidence_collected': True,
                'timestamp': '2025-01-01T00:00:00',
                'period_days': args.period,
                'note': 'Evidence collection feature coming soon'
            }
        
        # Save report
        if args.output:
            if args.format == 'json':
                with open(args.output, 'w') as f:
                    json.dump(data, f, indent=2)
                print(f"Report saved to: {args.output}")
            elif args.format == 'csv':
                self._save_csv_report(data, args.output)
                print(f"CSV report saved to: {args.output}")
            elif args.format == 'html':
                self._save_html_report(data, args.output, args.type)
                print(f"HTML report saved to: {args.output}")
        else:
            print(json.dumps(data, indent=2))
        
        return 0
    
    def _handle_check(self, args) -> int:
        """Handle the check command."""
        print(f"Checking {len(args.files)} files for compliance")
        
        total_issues = 0
        for file_path in args.files:
            if not Path(file_path).exists():
                print(f"Warning: File '{file_path}' does not exist")
                continue
            
            print(f"\nChecking: {file_path}")
            issues = self.analyzer.analyze_file(file_path)
            
            # Filter by framework if specified
            if args.framework:
                issues = [i for i in issues if i.framework == args.framework]
            
            if issues:
                total_issues += len(issues)
                for issue in issues:
                    print(f"  {issue.severity.upper()}: {issue.description}")
                    if args.fix and issue.severity in ['error', 'critical']:
                        print(f"    Suggested fix: {issue.recommendation}")
            else:
                print("  No compliance issues found")
        
        print(f"\nTotal issues found: {total_issues}")
        return 1 if total_issues > 0 else 0
    
    def _handle_config(self, args) -> int:
        """Handle the config command."""
        # Placeholder for configuration management
        if args.set:
            key, value = args.set
            print(f"Setting {key} = {value}")
            # In a real implementation, save to config file
        
        elif args.get:
            print(f"Getting value for: {args.get}")
            # In a real implementation, read from config file
        
        elif args.list:
            print("Compliance configuration:")
            print("  (Configuration management coming soon)")
        
        return 0
    
    def _print_console_report(self, report) -> None:
        """Print compliance report to console."""
        print(f"\n=== Compliance Analysis Report ===")
        print(f"Files analyzed: {report.total_files_analyzed}")
        print(f"Overall compliance score: {report.compliance_score:.1f}%")
        print(f"Issues found: {len(report.issues_found)}")
        
        if report.framework_scores:
            print("\nFramework scores:")
            for framework, score in report.framework_scores.items():
                print(f"  {framework}: {score:.1f}%")
        
        if report.issues_found:
            print(f"\n=== Issues Found ({len(report.issues_found)}) ===")
            
            # Group by severity
            by_severity = {}
            for issue in report.issues_found:
                by_severity.setdefault(issue.severity, []).append(issue)
            
            for severity in ['critical', 'error', 'warning', 'info']:
                if severity in by_severity:
                    print(f"\n{severity.upper()} ({len(by_severity[severity])}):")
                    for issue in by_severity[severity]:
                        print(f"  {issue.file_path}:{issue.line_number}")
                        print(f"    {issue.description}")
                        print(f"    Recommendation: {issue.recommendation}")
    
    def _save_json_report(self, report, output_path: str) -> None:
        """Save compliance report as JSON."""
        data = {
            'total_files_analyzed': report.total_files_analyzed,
            'compliance_score': report.compliance_score,
            'framework_scores': report.framework_scores,
            'issues': [
                {
                    'file_path': issue.file_path,
                    'line_number': issue.line_number,
                    'issue_type': issue.issue_type,
                    'description': issue.description,
                    'severity': issue.severity,
                    'framework': issue.framework,
                    'recommendation': issue.recommendation,
                    'code_snippet': issue.code_snippet
                }
                for issue in report.issues_found
            ]
        }
        
        with open(output_path, 'w') as f:
            json.dump(data, f, indent=2)
    
    def _save_csv_report(self, data, output_path: str) -> None:
        """Save report data as CSV."""
        import csv
        
        if isinstance(data, list):
            # Violations data
            with open(output_path, 'w', newline='') as f:
                if data:
                    writer = csv.DictWriter(f, fieldnames=data[0].keys())
                    writer.writeheader()
                    writer.writerows(data)
        else:
            # Metrics data - flatten for CSV
            flattened = []
            for key, value in data.items():
                if isinstance(value, dict):
                    for subkey, subvalue in value.items():
                        flattened.append({'metric': f"{key}.{subkey}", 'value': subvalue})
                else:
                    flattened.append({'metric': key, 'value': value})
            
            with open(output_path, 'w', newline='') as f:
                writer = csv.DictWriter(f, fieldnames=['metric', 'value'])
                writer.writeheader()
                writer.writerows(flattened)
    
    def _save_html_report(self, data, output_path: str, report_type: str) -> None:
        """Save report data as HTML."""
        html_content = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <title>CloudScope {report_type.title()} Report</title>
            <style>
                body {{ font-family: Arial, sans-serif; margin: 20px; }}
                .header {{ background-color: #f0f0f0; padding: 20px; border-radius: 5px; }}
                table {{ border-collapse: collapse; width: 100%; }}
                th, td {{ border: 1px solid #ddd; padding: 8px; text-align: left; }}
                th {{ background-color: #f2f2f2; }}
            </style>
        </head>
        <body>
            <div class="header">
                <h1>CloudScope {report_type.title()} Report</h1>
                <p>Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}</p>
            </div>
            <pre>{json.dumps(data, indent=2)}</pre>
        </body>
        </html>
        """
        
        with open(output_path, 'w') as f:
            f.write(html_content)
    
    def _calculate_framework_scores(self, issues: List) -> dict:
        """Calculate framework scores from issues list."""
        frameworks = set(issue.framework for issue in issues)
        scores = {}
        
        for framework in frameworks:
            framework_issues = [i for i in issues if i.framework == framework]
            # Simple scoring: start at 100, subtract points for issues
            score = max(0, 100 - (len(framework_issues) * 10))
            scores[framework] = score
        
        return scores


def main():
    """Main CLI entry point for compliance commands."""
    parser = argparse.ArgumentParser(description='CloudScope Compliance CLI')
    commands = ComplianceCommands()
    commands.add_compliance_commands(parser)
    
    args = parser.parse_args()
    
    if hasattr(args, 'compliance_command'):
        exit_code = commands.handle_compliance_command(args)
        sys.exit(exit_code)
    else:
        parser.print_help()
        sys.exit(1)


if __name__ == '__main__':
    main()
