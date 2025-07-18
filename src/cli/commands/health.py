"""Health check commands for CloudScope CLI."""

import sys
import json
import click
from datetime import datetime
from typing import Dict, Any

from ..utils import get_repository, get_plugin_manager


@click.command()
@click.option(
    '--detailed',
    is_flag=True,
    help='Show detailed health information'
)
@click.option(
    '--format', '-f',
    type=click.Choice(['text', 'json']),
    default='text',
    help='Output format'
)
@click.option(
    '--component', '-c',
    multiple=True,
    help='Check specific components only'
)
@click.pass_context
def health(ctx, detailed, format, component):
    """Check CloudScope system health.
    
    Performs health checks on various system components including:
    - Storage backend
    - Plugin system
    - Collectors
    - Configuration
    """
    config = ctx.obj.config
    
    # Initialize health check results
    health_status = {
        'status': 'healthy',
        'timestamp': datetime.utcnow().isoformat(),
        'version': '1.4.0',
        'checks': {}
    }
    
    # Components to check
    components_to_check = list(component) if component else [
        'storage', 'plugins', 'collectors', 'configuration'
    ]
    
    # Check storage health
    if 'storage' in components_to_check:
        health_status['checks']['storage'] = _check_storage_health(config)
    
    # Check plugin system health
    if 'plugins' in components_to_check:
        health_status['checks']['plugins'] = _check_plugin_health(config)
    
    # Check collectors health
    if 'collectors' in components_to_check:
        health_status['checks']['collectors'] = _check_collectors_health(config)
    
    # Check configuration health
    if 'configuration' in components_to_check:
        health_status['checks']['configuration'] = _check_config_health(config)
    
    # Determine overall status
    for check_name, check_result in health_status['checks'].items():
        if check_result['status'] == 'unhealthy':
            health_status['status'] = 'unhealthy'
            break
        elif check_result['status'] == 'degraded' and health_status['status'] != 'unhealthy':
            health_status['status'] = 'degraded'
    
    # Display results
    if format == 'json':
        click.echo(json.dumps(health_status, indent=2))
    else:
        _display_health_text(health_status, detailed)
    
    # Exit with appropriate code
    if health_status['status'] == 'unhealthy':
        sys.exit(1)
    elif health_status['status'] == 'degraded':
        sys.exit(2)


def _check_storage_health(config: Dict[str, Any]) -> Dict[str, Any]:
    """Check storage backend health."""
    result = {
        'status': 'healthy',
        'message': 'Storage is accessible',
        'details': {}
    }
    
    try:
        from ...adapters.storage import FileBasedAssetRepository, SQLiteAssetRepository
        
        storage_config = config.get('storage', {})
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
            result['status'] = 'unhealthy'
            result['message'] = f'Unsupported storage type: {storage_type}'
            return result
        
        # Test basic operations
        start_time = datetime.utcnow()
        
        # Test count operation
        count = repo.count()
        
        # Test statistics
        stats = repo.get_statistics()
        
        latency_ms = int((datetime.utcnow() - start_time).total_seconds() * 1000)
        
        result['details'] = {
            'type': storage_type,
            'asset_count': count,
            'latency_ms': latency_ms
        }
        
        if storage_type == 'sqlite':
            result['details']['database_size_mb'] = stats.get('storage', {}).get('size_mb', 0)
        
    except Exception as e:
        result['status'] = 'unhealthy'
        result['message'] = f'Storage check failed: {str(e)}'
    
    return result


def _check_plugin_health(config: Dict[str, Any]) -> Dict[str, Any]:
    """Check plugin system health."""
    result = {
        'status': 'healthy',
        'message': 'Plugin system operational',
        'details': {}
    }
    
    try:
        plugin_config = config.get('plugins', {})
        
        if not plugin_config.get('enabled', True):
            result['status'] = 'disabled'
            result['message'] = 'Plugin system is disabled'
            return result
        
        plugin_manager = get_plugin_manager(config)
        
        # Get plugin statistics
        plugins = plugin_manager.list_plugins()
        plugin_count = len(plugins)
        
        # Check for initialized plugins
        initialized_count = 0
        for plugin_name in plugins:
            info = plugin_manager.get_plugin_info(plugin_name)
            if info and info.get('initialized'):
                initialized_count += 1
        
        result['details'] = {
            'total_plugins': plugin_count,
            'initialized_plugins': initialized_count,
            'plugin_directory': str(plugin_manager.plugin_dir)
        }
        
        if plugin_count == 0:
            result['status'] = 'degraded'
            result['message'] = 'No plugins installed'
        
    except Exception as e:
        result['status'] = 'unhealthy'
        result['message'] = f'Plugin system check failed: {str(e)}'
    
    return result


def _check_collectors_health(config: Dict[str, Any]) -> Dict[str, Any]:
    """Check collectors health."""
    result = {
        'status': 'healthy',
        'message': 'Collectors are configured',
        'details': {
            'collectors': {}
        }
    }
    
    try:
        collector_config = config.get('collectors', {})
        enabled_collectors = collector_config.get('enabled', [])
        
        if not enabled_collectors:
            result['status'] = 'degraded'
            result['message'] = 'No collectors enabled'
            return result
        
        # Check each collector
        for collector_name in enabled_collectors:
            collector_status = {
                'enabled': True,
                'configured': collector_name in collector_config
            }
            
            # Check if it's a built-in collector
            if collector_name == 'csv':
                collector_status['type'] = 'built-in'
            else:
                collector_status['type'] = 'plugin'
                
                # Check if plugin exists
                try:
                    plugin_manager = get_plugin_manager(config)
                    plugin = plugin_manager.get_plugin(f"{collector_name}-collector")
                    collector_status['available'] = plugin is not None
                except:
                    collector_status['available'] = False
            
            result['details']['collectors'][collector_name] = collector_status
        
        # Check if any collectors are unavailable
        unavailable = [
            name for name, status in result['details']['collectors'].items()
            if status.get('type') == 'plugin' and not status.get('available')
        ]
        
        if unavailable:
            result['status'] = 'degraded'
            result['message'] = f'Some collectors unavailable: {", ".join(unavailable)}'
    
    except Exception as e:
        result['status'] = 'unhealthy'
        result['message'] = f'Collector check failed: {str(e)}'
    
    return result


def _check_config_health(config: Dict[str, Any]) -> Dict[str, Any]:
    """Check configuration health."""
    result = {
        'status': 'healthy',
        'message': 'Configuration is valid',
        'details': {}
    }
    
    try:
        # Check required fields
        required_fields = ['storage', 'collectors']
        missing_fields = [field for field in required_fields if field not in config]
        
        if missing_fields:
            result['status'] = 'unhealthy'
            result['message'] = f'Missing required fields: {", ".join(missing_fields)}'
            return result
        
        # Check for deprecated options
        deprecated_fields = []
        if 'legacy_mode' in config:
            deprecated_fields.append('legacy_mode')
        
        result['details'] = {
            'version': config.get('version', 'unknown'),
            'has_metadata': 'metadata' in config,
            'deprecated_fields': deprecated_fields
        }
        
        if deprecated_fields:
            result['status'] = 'degraded'
            result['message'] = 'Configuration contains deprecated fields'
    
    except Exception as e:
        result['status'] = 'unhealthy'
        result['message'] = f'Configuration check failed: {str(e)}'
    
    return result


def _display_health_text(health_status: Dict[str, Any], detailed: bool):
    """Display health status in text format."""
    # Overall status with color
    status = health_status['status']
    if status == 'healthy':
        status_display = click.style('HEALTHY', fg='green', bold=True)
    elif status == 'degraded':
        status_display = click.style('DEGRADED', fg='yellow', bold=True)
    else:
        status_display = click.style('UNHEALTHY', fg='red', bold=True)
    
    click.echo(f"\nCloudScope Health Status: {status_display}")
    click.echo(f"Timestamp: {health_status['timestamp']}")
    click.echo(f"Version: {health_status['version']}")
    click.echo()
    
    # Component status
    click.echo("Component Health:")
    click.echo("-" * 60)
    
    for component, check in health_status['checks'].items():
        # Component status indicator
        if check['status'] == 'healthy':
            indicator = click.style('✓', fg='green')
        elif check['status'] == 'degraded':
            indicator = click.style('!', fg='yellow')
        elif check['status'] == 'disabled':
            indicator = click.style('-', fg='cyan')
        else:
            indicator = click.style('✗', fg='red')
        
        # Display component status
        click.echo(f"{indicator} {component.capitalize():<15} {check['message']}")
        
        # Show details if requested
        if detailed and check.get('details'):
            for key, value in check['details'].items():
                if isinstance(value, dict):
                    click.echo(f"    {key}:")
                    for sub_key, sub_value in value.items():
                        click.echo(f"      {sub_key}: {sub_value}")
                else:
                    click.echo(f"    {key}: {value}")
    
    click.echo()
