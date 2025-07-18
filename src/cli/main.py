"""CloudScope CLI main entry point.

This module provides the command-line interface for CloudScope.
"""

import sys
import logging
from pathlib import Path
from typing import Optional

import click

from .commands import collect, report, config, plugin, health
from .utils import setup_logging, load_config, CloudScopeContext


# Create the main CLI group
@click.group()
@click.option(
    '--config', '-c',
    type=click.Path(exists=True),
    help='Path to configuration file',
    default='./config/cloudscope-config.json'
)
@click.option(
    '--log-level', '-l',
    type=click.Choice(['DEBUG', 'INFO', 'WARNING', 'ERROR']),
    default='INFO',
    help='Set logging level'
)
@click.option(
    '--log-file',
    type=click.Path(),
    help='Log to file instead of console'
)
@click.option(
    '--quiet', '-q',
    is_flag=True,
    help='Suppress output except errors'
)
@click.option(
    '--verbose', '-v',
    is_flag=True,
    help='Enable verbose output'
)
@click.version_option(version='1.4.0', prog_name='CloudScope')
@click.pass_context
def cli(ctx, config, log_level, log_file, quiet, verbose):
    """CloudScope - Comprehensive IT Asset Inventory System
    
    CloudScope discovers, tracks, and manages infrastructure assets across
    multiple cloud providers and on-premises environments.
    """
    # Setup logging
    if verbose:
        log_level = 'DEBUG'
    elif quiet:
        log_level = 'ERROR'
    
    setup_logging(log_level, log_file)
    
    # Load configuration
    try:
        config_data = load_config(config)
    except Exception as e:
        click.echo(f"Error loading configuration: {e}", err=True)
        sys.exit(1)
    
    # Create context object
    ctx.obj = CloudScopeContext(config_data, config)
    
    # Log startup
    logger = logging.getLogger('cloudscope.cli')
    logger.info(f"CloudScope CLI started with config: {config}")


# Add command groups
cli.add_command(collect.collect)
cli.add_command(report.report)
cli.add_command(config.config_group)
cli.add_command(plugin.plugin)
cli.add_command(health.health)


# Additional top-level commands
@cli.command()
@click.pass_context
def version(ctx):
    """Show detailed version information."""
    click.echo("CloudScope Asset Inventory System")
    click.echo("Version: 1.4.0")
    click.echo("API Version: 1.0")
    click.echo("Python: " + sys.version.split()[0])
    
    # Show configuration file location
    click.echo(f"\nConfiguration: {ctx.obj.config_path}")
    
    # Show storage type
    storage_type = ctx.obj.config.get('storage', {}).get('type', 'unknown')
    click.echo(f"Storage: {storage_type}")


@cli.command()
@click.option(
    '--format', '-f',
    type=click.Choice(['text', 'json']),
    default='text',
    help='Output format'
)
@click.pass_context
def status(ctx, format):
    """Show CloudScope system status."""
    from ..adapters.storage import FileBasedAssetRepository, SQLiteAssetRepository
    
    try:
        # Get storage configuration
        storage_config = ctx.obj.config.get('storage', {})
        storage_type = storage_config.get('type', 'file')
        
        # Initialize repository based on type
        if storage_type == 'file':
            repo = FileBasedAssetRepository(
                storage_config.get('path', './data/assets')
            )
        elif storage_type == 'sqlite':
            repo = SQLiteAssetRepository(
                storage_config.get('connection', {}).get('path', './data/cloudscope.db')
            )
        else:
            click.echo(f"Unsupported storage type: {storage_type}", err=True)
            return
        
        # Get statistics
        stats = repo.get_statistics()
        
        if format == 'json':
            import json
            click.echo(json.dumps(stats, indent=2))
        else:
            click.echo("CloudScope System Status")
            click.echo("=" * 40)
            click.echo(f"Storage Type: {storage_type}")
            click.echo(f"Total Assets: {stats.get('total_assets', 0)}")
            
            # Asset breakdown
            by_type = stats.get('by_type', {})
            if by_type:
                click.echo("\nAssets by Type:")
                for asset_type, count in sorted(by_type.items()):
                    click.echo(f"  {asset_type}: {count}")
            
            by_provider = stats.get('by_provider', {})
            if by_provider:
                click.echo("\nAssets by Provider:")
                for provider, count in sorted(by_provider.items()):
                    click.echo(f"  {provider}: {count}")
            
            # Storage info
            storage_info = stats.get('storage', {})
            if storage_info:
                click.echo("\nStorage Information:")
                for key, value in storage_info.items():
                    click.echo(f"  {key}: {value}")
    
    except Exception as e:
        click.echo(f"Error getting status: {e}", err=True)
        sys.exit(1)


@cli.command()
@click.argument('query')
@click.option(
    '--limit', '-n',
    type=int,
    default=10,
    help='Maximum number of results'
)
@click.option(
    '--format', '-f',
    type=click.Choice(['table', 'json', 'csv']),
    default='table',
    help='Output format'
)
@click.pass_context
def search(ctx, query, limit, format):
    """Search for assets."""
    from ..adapters.storage import FileBasedAssetRepository, SQLiteAssetRepository
    
    try:
        # Get storage configuration
        storage_config = ctx.obj.config.get('storage', {})
        storage_type = storage_config.get('type', 'file')
        
        # Initialize repository
        if storage_type == 'file':
            repo = FileBasedAssetRepository(
                storage_config.get('path', './data/assets')
            )
        elif storage_type == 'sqlite':
            repo = SQLiteAssetRepository(
                storage_config.get('connection', {}).get('path', './data/cloudscope.db')
            )
        else:
            click.echo(f"Unsupported storage type: {storage_type}", err=True)
            return
        
        # Search for assets
        assets = repo.search(query, limit)
        
        if not assets:
            click.echo(f"No assets found matching '{query}'")
            return
        
        # Display results
        if format == 'json':
            import json
            data = [asset.to_dict() for asset in assets]
            click.echo(json.dumps(data, indent=2))
        
        elif format == 'csv':
            import csv
            import sys
            
            fieldnames = ['asset_id', 'name', 'asset_type', 'provider', 'status']
            writer = csv.DictWriter(sys.stdout, fieldnames=fieldnames)
            writer.writeheader()
            
            for asset in assets:
                writer.writerow({
                    'asset_id': asset.asset_id,
                    'name': asset.name,
                    'asset_type': asset.asset_type,
                    'provider': asset.provider,
                    'status': asset.status
                })
        
        else:  # table format
            click.echo(f"\nFound {len(assets)} assets matching '{query}':\n")
            
            # Print header
            click.echo("{:<20} {:<30} {:<15} {:<10} {:<10}".format(
                "Asset ID", "Name", "Type", "Provider", "Status"
            ))
            click.echo("-" * 85)
            
            # Print assets
            for asset in assets:
                click.echo("{:<20} {:<30} {:<15} {:<10} {:<10}".format(
                    asset.asset_id[:20],
                    asset.name[:30],
                    asset.asset_type,
                    asset.provider,
                    asset.status
                ))
    
    except Exception as e:
        click.echo(f"Error searching assets: {e}", err=True)
        sys.exit(1)


@cli.command()
@click.option(
    '--days', '-d',
    type=int,
    default=30,
    help='Delete assets older than N days'
)
@click.option(
    '--status', '-s',
    help='Delete assets with specific status'
)
@click.option(
    '--dry-run',
    is_flag=True,
    help='Show what would be deleted without deleting'
)
@click.option(
    '--yes', '-y',
    is_flag=True,
    help='Skip confirmation prompt'
)
@click.pass_context
def cleanup(ctx, days, status, dry_run, yes):
    """Clean up old or terminated assets."""
    from datetime import datetime, timedelta
    from ..adapters.storage import FileBasedAssetRepository, SQLiteAssetRepository
    
    try:
        # Get storage configuration
        storage_config = ctx.obj.config.get('storage', {})
        storage_type = storage_config.get('type', 'file')
        
        # Initialize repository
        if storage_type == 'file':
            repo = FileBasedAssetRepository(
                storage_config.get('path', './data/assets')
            )
        elif storage_type == 'sqlite':
            repo = SQLiteAssetRepository(
                storage_config.get('connection', {}).get('path', './data/cloudscope.db')
            )
        else:
            click.echo(f"Unsupported storage type: {storage_type}", err=True)
            return
        
        # Find assets to delete
        all_assets = repo.find_all()
        cutoff_date = datetime.utcnow() - timedelta(days=days)
        
        assets_to_delete = []
        for asset in all_assets:
            # Check age
            if asset.created_at < cutoff_date:
                if not status or asset.status == status:
                    assets_to_delete.append(asset)
        
        if not assets_to_delete:
            click.echo("No assets to clean up")
            return
        
        # Show what will be deleted
        click.echo(f"\nFound {len(assets_to_delete)} assets to delete:")
        click.echo("-" * 60)
        
        for asset in assets_to_delete[:10]:  # Show first 10
            age_days = (datetime.utcnow() - asset.created_at).days
            click.echo(f"{asset.asset_id}: {asset.name} ({asset.status}, {age_days} days old)")
        
        if len(assets_to_delete) > 10:
            click.echo(f"... and {len(assets_to_delete) - 10} more")
        
        if dry_run:
            click.echo("\nDry run - no assets deleted")
            return
        
        # Confirm deletion
        if not yes:
            if not click.confirm(f"\nDelete {len(assets_to_delete)} assets?"):
                click.echo("Cleanup cancelled")
                return
        
        # Delete assets
        asset_ids = [asset.asset_id for asset in assets_to_delete]
        deleted_count = repo.delete_batch(asset_ids)
        
        click.echo(f"\nDeleted {deleted_count} assets")
    
    except Exception as e:
        click.echo(f"Error during cleanup: {e}", err=True)
        sys.exit(1)


def main():
    """Main entry point for the CLI."""
    try:
        cli()
    except KeyboardInterrupt:
        click.echo("\nOperation cancelled by user", err=True)
        sys.exit(130)
    except Exception as e:
        click.echo(f"\nUnexpected error: {e}", err=True)
        logging.getLogger('cloudscope.cli').exception("Unexpected error")
        sys.exit(1)


if __name__ == '__main__':
    main()
