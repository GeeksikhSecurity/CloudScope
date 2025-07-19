"""Collection commands for CloudScope CLI."""

import sys
import click
from typing import List, Optional

from ..utils import get_repository, get_plugin_manager


@click.command()
@click.option(
    '--provider', '-p',
    multiple=True,
    help='Cloud provider(s) to collect from'
)
@click.option(
    '--type', '-t',
    'asset_types',
    multiple=True,
    help='Asset type(s) to collect'
)
@click.option(
    '--region', '-r',
    multiple=True,
    help='Region(s) to collect from'
)
@click.option(
    '--dry-run',
    is_flag=True,
    help='Show what would be collected without saving'
)
@click.option(
    '--limit', '-l',
    type=int,
    help='Limit number of assets to collect'
)
@click.option(
    '--continue-on-error',
    is_flag=True,
    help='Continue collection even if some providers fail'
)
@click.option(
    '--plugin',
    help='Use specific collector plugin'
)
@click.pass_context
def collect(ctx, provider, asset_types, region, dry_run, limit, continue_on_error, plugin):
    """Collect assets from cloud providers and other sources.
    
    Examples:
    
        # Collect all assets from all configured providers
        cloudscope collect
        
        # Collect only from AWS in specific regions
        cloudscope collect -p aws -r us-east-1 -r us-west-2
        
        # Collect only compute instances
        cloudscope collect -t compute
        
        # Dry run to see what would be collected
        cloudscope collect --dry-run
    """
    config = ctx.obj.config
    
    try:
        # Get collectors to use
        if plugin:
            # Use specific plugin
            plugin_manager = get_plugin_manager(config)
            collector_plugin = plugin_manager.get_plugin(plugin)
            
            if not collector_plugin:
                click.echo(f"Plugin '{plugin}' not found", err=True)
                sys.exit(1)
            
            collectors = [collector_plugin]
        else:
            # Use configured collectors
            collectors = _get_collectors(config, provider)
        
        if not collectors:
            click.echo("No collectors configured or available", err=True)
            sys.exit(1)
        
        # Prepare filters
        filters = {}
        if region:
            filters['regions'] = list(region)
        
        # Get repository (unless dry run)
        repository = None if dry_run else get_repository(config)
        
        total_collected = 0
        errors = []
        
        # Run collection for each provider
        for collector in collectors:
            try:
                click.echo(f"\nCollecting from {collector.provider}...")
                
                # Initialize collector if needed
                if hasattr(collector, 'initialize') and not getattr(collector, '_initialized', False):
                    collector_config = config.get('collectors', {}).get(collector.provider, {})
                    collector.initialize(collector_config)
                
                # Validate credentials
                if not collector.validate_credentials():
                    raise click.ClickException(f"Invalid credentials for {collector.provider}")
                
                # Collect assets
                assets = collector.collect(
                    asset_types=list(asset_types) if asset_types else None,
                    filters=filters
                )
                
                # Apply limit if specified
                if limit and len(assets) > limit:
                    assets = assets[:limit]
                    click.echo(f"Limited to {limit} assets")
                
                # Display results
                click.echo(f"Collected {len(assets)} assets from {collector.provider}")
                
                if dry_run:
                    # Show sample of what would be collected
                    click.echo("\nSample assets (first 5):")
                    for asset in assets[:5]:
                        click.echo(f"  - {asset.asset_id}: {asset.name} ({asset.asset_type})")
                    if len(assets) > 5:
                        click.echo(f"  ... and {len(assets) - 5} more")
                else:
                    # Save assets
                    saved = repository.save_batch(assets)
                    click.echo(f"Saved {len(saved)} assets to repository")
                    
                    # Collect relationships
                    try:
                        relationships = collector.collect_relationships(assets)
                        if relationships:
                            # TODO: Save relationships when relationship repository is available
                            click.echo(f"Discovered {len(relationships)} relationships")
                    except Exception as e:
                        click.echo(f"Warning: Failed to collect relationships: {e}")
                
                total_collected += len(assets)
                
            except Exception as e:
                error_msg = f"Collection failed for {collector.provider}: {e}"
                errors.append(error_msg)
                click.echo(error_msg, err=True)
                
                if not continue_on_error:
                    sys.exit(1)
        
        # Summary
        click.echo(f"\nCollection complete. Total assets: {total_collected}")
        
        if errors:
            click.echo(f"\nErrors encountered ({len(errors)}):")
            for error in errors:
                click.echo(f"  - {error}")
            
            if not continue_on_error:
                sys.exit(1)
    
    except Exception as e:
        click.echo(f"Collection failed: {e}", err=True)
        sys.exit(1)


def _get_collectors(config, providers):
    """Get collector instances based on configuration."""
    from ...adapters.collectors import CSVCollector
    from ...plugins.base import CollectorPlugin
    
    collectors = []
    
    # Get enabled collectors from config
    collector_config = config.get('collectors', {})
    enabled_collectors = collector_config.get('enabled', [])
    
    # Filter by requested providers if specified
    if providers:
        enabled_collectors = [c for c in enabled_collectors if c in providers]
    
    # Create collector instances
    for collector_name in enabled_collectors:
        if collector_name == 'csv':
            # Built-in CSV collector
            csv_config = collector_config.get('csv', {})
            collectors.append(CSVCollector(csv_config))
        else:
            # Try to load as plugin
            try:
                plugin_manager = get_plugin_manager(config)
                plugin = plugin_manager.get_plugin(f"{collector_name}-collector")
                if plugin and isinstance(plugin, CollectorPlugin):
                    collectors.append(plugin)
            except Exception as e:
                click.echo(f"Warning: Failed to load collector {collector_name}: {e}")
    
    return collectors
