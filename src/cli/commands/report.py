"""Report generation commands for CloudScope CLI."""

import sys
import click
from pathlib import Path
from datetime import datetime, timedelta
from typing import Optional, List

from ..utils import get_repository, get_plugin_manager


@click.group()
def report():
    """Generate and manage reports."""
    pass


@report.command()
@click.option(
    '--format', '-f',
    type=click.Choice(['json', 'csv', 'html', 'pdf', 'markdown']),
    default='json',
    help='Report format'
)
@click.option(
    '--output', '-o',
    type=click.Path(),
    help='Output file path'
)
@click.option(
    '--filter',
    multiple=True,
    help='Filter assets (e.g., type=compute, provider=aws)'
)
@click.option(
    '--include-relationships',
    is_flag=True,
    help='Include relationship data in report'
)
@click.option(
    '--llm-optimized',
    is_flag=True,
    help='Optimize CSV output for LLM analysis'
)
@click.option(
    '--date-range',
    help='Date range for report (e.g., 7d, 30d, 2024-01-01:2024-01-31)'
)
@click.option(
    '--limit',
    type=int,
    help='Limit number of assets in report'
)
@click.pass_context
def generate(ctx, format, output, filter, include_relationships, llm_optimized, date_range, limit):
    """Generate asset inventory report.
    
    Examples:
    
        # Generate JSON report to stdout
        cloudscope report generate
        
        # Generate CSV report optimized for LLM
        cloudscope report generate -f csv --llm-optimized -o assets.csv
        
        # Generate report for specific asset types
        cloudscope report generate --filter type=compute --filter provider=aws
        
        # Generate report for last 7 days
        cloudscope report generate --date-range 7d
    """
    config = ctx.obj.config
    
    try:
        # Get repository
        repository = get_repository(config)
        
        # Parse filters
        filters = _parse_filters(filter)
        
        # Add date range filter if specified
        if date_range:
            date_filter = _parse_date_range(date_range)
            filters.update(date_filter)
        
        # Get assets
        assets = repository.find_all(filters=filters, limit=limit)
        
        if not assets:
            click.echo("No assets found matching criteria")
            return
        
        click.echo(f"Found {len(assets)} assets")
        
        # Get relationships if requested
        relationships = []
        if include_relationships:
            # TODO: Get relationships when relationship repository is available
            click.echo("Note: Relationship data not yet implemented")
        
        # Determine output stream
        if output:
            output_path = Path(output)
            output_path.parent.mkdir(parents=True, exist_ok=True)
            output_stream = open(output_path, 'w')
        else:
            output_stream = sys.stdout
        
        try:
            # Get appropriate exporter
            exporter = _get_exporter(config, format, llm_optimized)
            
            # Export data
            metadata = {
                'generated_at': datetime.utcnow().isoformat(),
                'total_assets': len(assets),
                'filters': filters,
                'format': format
            }
            
            exporter.export(assets, output_stream, relationships, metadata)
            
            if output:
                click.echo(f"Report saved to {output}")
            
        finally:
            if output:
                output_stream.close()
    
    except Exception as e:
        click.echo(f"Report generation failed: {e}", err=True)
        sys.exit(1)


@report.command()
@click.option(
    '--days', '-d',
    type=int,
    default=7,
    help='Show reports from last N days'
)
@click.option(
    '--format', '-f',
    type=click.Choice(['table', 'json']),
    default='table',
    help='Output format'
)
@click.pass_context
def list(ctx, days, format):
    """List generated reports."""
    config = ctx.obj.config
    report_dir = Path(config.get('reporting', {}).get('output_directory', './reports'))
    
    if not report_dir.exists():
        click.echo("No reports directory found")
        return
    
    # Find report files
    cutoff_date = datetime.now() - timedelta(days=days)
    reports = []
    
    for file_path in report_dir.rglob('*'):
        if file_path.is_file():
            stat = file_path.stat()
            mtime = datetime.fromtimestamp(stat.st_mtime)
            
            if mtime >= cutoff_date:
                reports.append({
                    'path': str(file_path.relative_to(report_dir)),
                    'size': stat.st_size,
                    'modified': mtime,
                    'format': file_path.suffix.lstrip('.')
                })
    
    # Sort by date
    reports.sort(key=lambda x: x['modified'], reverse=True)
    
    if not reports:
        click.echo(f"No reports found in last {days} days")
        return
    
    # Display results
    if format == 'json':
        import json
        click.echo(json.dumps(reports, default=str, indent=2))
    else:
        click.echo(f"\nReports from last {days} days:\n")
        click.echo("{:<40} {:<10} {:<10} {:<20}".format(
            "File", "Format", "Size", "Modified"
        ))
        click.echo("-" * 80)
        
        for report in reports:
            size_mb = report['size'] / (1024 * 1024)
            click.echo("{:<40} {:<10} {:<10.2f} {:<20}".format(
                report['path'][:40],
                report['format'],
                size_mb,
                report['modified'].strftime("%Y-%m-%d %H:%M:%S")
            ))


@report.command()
@click.option(
    '--format', '-f',
    type=click.Choice(['json', 'csv', 'html']),
    default='json',
    help='Report format'
)
@click.option(
    '--output', '-o',
    type=click.Path(),
    help='Output file path'
)
@click.pass_context
def risk(ctx, format, output):
    """Generate risk analysis report."""
    config = ctx.obj.config
    
    try:
        # Get repository
        repository = get_repository(config)
        
        # Get all assets
        assets = repository.find_all()
        
        if not assets:
            click.echo("No assets found")
            return
        
        # Calculate risk scores
        from ...domain.models.validation import AssetValidator, ComplianceValidator
        
        risk_analysis = {
            'total_assets': len(assets),
            'high_risk_assets': [],
            'compliance_violations': [],
            'validation_errors': {},
            'statistics': {
                'by_risk_level': {'high': 0, 'medium': 0, 'low': 0},
                'by_type': {},
                'average_risk_score': 0
            }
        }
        
        total_risk = 0
        
        for asset in assets:
            # Calculate risk score
            asset.calculate_risk_score()
            total_risk += asset.risk_score
            
            # Categorize risk
            if asset.risk_score >= 70:
                risk_analysis['high_risk_assets'].append({
                    'asset_id': asset.asset_id,
                    'name': asset.name,
                    'type': asset.asset_type,
                    'risk_score': asset.risk_score
                })
                risk_analysis['statistics']['by_risk_level']['high'] += 1
            elif asset.risk_score >= 40:
                risk_analysis['statistics']['by_risk_level']['medium'] += 1
            else:
                risk_analysis['statistics']['by_risk_level']['low'] += 1
            
            # Check compliance
            violations = ComplianceValidator.validate_security_compliance(asset)
            if violations:
                risk_analysis['compliance_violations'].append({
                    'asset_id': asset.asset_id,
                    'violations': violations
                })
            
            # Validation errors
            errors = AssetValidator.validate_asset(asset)
            if errors:
                risk_analysis['validation_errors'][asset.asset_id] = errors
            
            # Count by type
            if asset.asset_type not in risk_analysis['statistics']['by_type']:
                risk_analysis['statistics']['by_type'][asset.asset_type] = {
                    'count': 0,
                    'high_risk': 0,
                    'total_risk': 0
                }
            
            type_stats = risk_analysis['statistics']['by_type'][asset.asset_type]
            type_stats['count'] += 1
            type_stats['total_risk'] += asset.risk_score
            if asset.risk_score >= 70:
                type_stats['high_risk'] += 1
        
        # Calculate averages
        risk_analysis['statistics']['average_risk_score'] = round(total_risk / len(assets), 2)
        
        for type_stats in risk_analysis['statistics']['by_type'].values():
            type_stats['average_risk'] = round(type_stats['total_risk'] / type_stats['count'], 2)
        
        # Output report
        if format == 'json':
            import json
            output_data = json.dumps(risk_analysis, indent=2)
        elif format == 'csv':
            # Simple CSV with high risk assets
            import csv
            import io
            
            csv_buffer = io.StringIO()
            writer = csv.DictWriter(csv_buffer, fieldnames=['asset_id', 'name', 'type', 'risk_score'])
            writer.writeheader()
            writer.writerows(risk_analysis['high_risk_assets'])
            output_data = csv_buffer.getvalue()
        else:  # HTML
            output_data = _generate_risk_html(risk_analysis)
        
        # Write output
        if output:
            with open(output, 'w') as f:
                f.write(output_data)
            click.echo(f"Risk report saved to {output}")
        else:
            click.echo(output_data)
    
    except Exception as e:
        click.echo(f"Risk report generation failed: {e}", err=True)
        sys.exit(1)


def _parse_filters(filter_list: List[str]) -> dict:
    """Parse filter strings into dictionary."""
    filters = {}
    
    for filter_str in filter_list:
        if '=' in filter_str:
            key, value = filter_str.split('=', 1)
            filters[key] = value
    
    return filters


def _parse_date_range(date_range: str) -> dict:
    """Parse date range string into filter."""
    filters = {}
    
    # Handle relative dates (e.g., 7d, 30d)
    if date_range.endswith('d'):
        days = int(date_range[:-1])
        cutoff_date = datetime.utcnow() - timedelta(days=days)
        filters['created_after'] = cutoff_date
    
    # Handle date range (e.g., 2024-01-01:2024-01-31)
    elif ':' in date_range:
        start_str, end_str = date_range.split(':', 1)
        filters['created_after'] = datetime.fromisoformat(start_str)
        filters['created_before'] = datetime.fromisoformat(end_str)
    
    return filters


def _get_exporter(config, format, llm_optimized):
    """Get appropriate exporter instance."""
    from ...adapters.exporters import CSVExporter, LLMOptimizedCSVExporter
    
    if format == 'csv' and llm_optimized:
        return LLMOptimizedCSVExporter(config.get('reporting', {}).get('formats', {}).get('csv', {}))
    elif format == 'csv':
        return CSVExporter(config.get('reporting', {}).get('formats', {}).get('csv', {}))
    else:
        # For other formats, create a simple JSON exporter
        from ...ports.exporter import HierarchicalExporter
        
        class JSONExporter(HierarchicalExporter):
            name = "json-exporter"
            version = "1.0.0"
            format = "json"
            
            def __init__(self, config):
                super().__init__(config)
            
            def export(self, assets, output, relationships=None, metadata=None):
                import json
                data = self.create_export_structure(assets, relationships, metadata)
                json.dump(data, output, indent=2, default=str)
            
            def export_streaming(self, assets, output, relationships=None, metadata=None):
                # Simple non-streaming implementation
                assets_list = list(assets)
                self.export(assets_list, output, relationships, metadata)
            
            def validate_output(self, output):
                return True
        
        return JSONExporter({})


def _generate_risk_html(risk_analysis):
    """Generate HTML risk report."""
    html = f"""
<!DOCTYPE html>
<html>
<head>
    <title>CloudScope Risk Analysis Report</title>
    <style>
        body {{ font-family: Arial, sans-serif; margin: 20px; }}
        h1, h2 {{ color: #333; }}
        .summary {{ background: #f0f0f0; padding: 15px; border-radius: 5px; }}
        .high-risk {{ color: #d32f2f; }}
        .medium-risk {{ color: #f57c00; }}
        .low-risk {{ color: #388e3c; }}
        table {{ border-collapse: collapse; width: 100%; margin-top: 20px; }}
        th, td {{ border: 1px solid #ddd; padding: 8px; text-align: left; }}
        th {{ background-color: #f2f2f2; }}
    </style>
</head>
<body>
    <h1>CloudScope Risk Analysis Report</h1>
    <div class="summary">
        <p>Generated: {datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S UTC")}</p>
        <p>Total Assets: {risk_analysis['total_assets']}</p>
        <p>Average Risk Score: {risk_analysis['statistics']['average_risk_score']}</p>
    </div>
    
    <h2>Risk Distribution</h2>
    <ul>
        <li class="high-risk">High Risk: {risk_analysis['statistics']['by_risk_level']['high']}</li>
        <li class="medium-risk">Medium Risk: {risk_analysis['statistics']['by_risk_level']['medium']}</li>
        <li class="low-risk">Low Risk: {risk_analysis['statistics']['by_risk_level']['low']}</li>
    </ul>
    
    <h2>High Risk Assets</h2>
    <table>
        <tr>
            <th>Asset ID</th>
            <th>Name</th>
            <th>Type</th>
            <th>Risk Score</th>
        </tr>
"""
    
    for asset in risk_analysis['high_risk_assets']:
        html += f"""
        <tr>
            <td>{asset['asset_id']}</td>
            <td>{asset['name']}</td>
            <td>{asset['type']}</td>
            <td class="high-risk">{asset['risk_score']}</td>
        </tr>
"""
    
    html += """
    </table>
</body>
</html>
"""
    
    return html
