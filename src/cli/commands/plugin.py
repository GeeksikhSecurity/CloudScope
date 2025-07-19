"""Plugin management commands for CloudScope CLI."""

import sys
import json
import click
from pathlib import Path
from typing import Optional

from ..utils import get_plugin_manager


@click.group()
def plugin():
    """Manage CloudScope plugins."""
    pass


@plugin.command()
@click.option(
    '--available',
    is_flag=True,
    help='Show available plugins to install'
)
@click.option(
    '--installed',
    is_flag=True,
    help='Show only installed plugins'
)
@click.option(
    '--format', '-f',
    type=click.Choice(['table', 'json']),
    default='table',
    help='Output format'
)
@click.pass_context
def list(ctx, available, installed, format):
    """List plugins."""
    config = ctx.obj.config
    plugin_manager = get_plugin_manager(config)
    
    if available:
        click.echo("Available plugins feature not yet implemented")
        return
    
    # Get installed plugins
    plugins = plugin_manager.list_plugins()
    
    if not plugins:
        click.echo("No plugins installed")
        return
    
    # Get plugin details
    plugin_info = []
    for plugin_name in plugins:
        info = plugin_manager.get_plugin_info(plugin_name)
        if info:
            plugin_info.append(info)
    
    # Display results
    if format == 'json':
        click.echo(json.dumps(plugin_info, indent=2))
    else:
        click.echo("\nInstalled Plugins:")
        click.echo("-" * 80)
        click.echo("{:<20} {:<10} {:<30} {:<10}".format(
            "Name", "Version", "Description", "Status"
        ))
        click.echo("-" * 80)
        
        for info in plugin_info:
            status = "Active" if info.get('initialized') else "Inactive"
            description = info.get('description', 'No description')[:30]
            
            click.echo("{:<20} {:<10} {:<30} {:<10}".format(
                info['name'][:20],
                info['version'],
                description,
                status
            ))


@plugin.command()
@click.argument('plugin_path')
@click.option(
    '--force', '-f',
    is_flag=True,
    help='Force install even if plugin exists'
)
@click.pass_context
def install(ctx, plugin_path, force):
    """Install a plugin.
    
    PLUGIN_PATH can be:
    - Local directory path
    - Git repository URL
    - Plugin name from registry (not yet implemented)
    """
    config = ctx.obj.config
    plugin_manager = get_plugin_manager(config)
    
    try:
        plugin_path = Path(plugin_path)
        
        if not plugin_path.exists():
            click.echo(f"Plugin path not found: {plugin_path}", err=True)
            sys.exit(1)
        
        # Validate plugin directory
        validation = plugin_manager.validate_plugin_directory(plugin_path)
        
        if not validation['valid']:
            click.echo("Plugin validation failed:")
            for error in validation['errors']:
                click.echo(f"  - {error}")
            sys.exit(1)
        
        # Show warnings
        if validation['warnings']:
            click.echo("Warnings:")
            for warning in validation['warnings']:
                click.echo(f"  - {warning}")
        
        # Copy plugin to plugins directory
        plugin_name = plugin_path.name
        target_dir = Path(config.get('plugins', {}).get('directory', './plugins')) / plugin_name
        
        if target_dir.exists() and not force:
            click.echo(f"Plugin '{plugin_name}' already exists. Use --force to overwrite.")
            sys.exit(1)
        
        # Copy plugin files
        import shutil
        if target_dir.exists():
            shutil.rmtree(target_dir)
        shutil.copytree(plugin_path, target_dir)
        
        # Discover and load the plugin
        plugin_manager.discover_plugins(target_dir.parent)
        
        click.echo(f"Plugin '{plugin_name}' installed successfully")
        
        # Show plugin info
        info = validation.get('info', {}).get('metadata', {})
        if info:
            click.echo(f"  Name: {info.get('name', plugin_name)}")
            click.echo(f"  Version: {info.get('version', 'unknown')}")
            click.echo(f"  Description: {info.get('description', 'No description')}")
    
    except Exception as e:
        click.echo(f"Plugin installation failed: {e}", err=True)
        sys.exit(1)


@plugin.command()
@click.argument('plugin_name')
@click.option(
    '--yes', '-y',
    is_flag=True,
    help='Skip confirmation prompt'
)
@click.pass_context
def uninstall(ctx, plugin_name, yes):
    """Uninstall a plugin."""
    config = ctx.obj.config
    plugin_manager = get_plugin_manager(config)
    
    # Check if plugin exists
    if plugin_name not in plugin_manager.list_plugins():
        click.echo(f"Plugin '{plugin_name}' not found", err=True)
        sys.exit(1)
    
    # Confirm
    if not yes:
        if not click.confirm(f"Uninstall plugin '{plugin_name}'?"):
            click.echo("Uninstall cancelled")
            return
    
    try:
        # Unregister plugin
        plugin_manager.unregister_plugin(plugin_name)
        
        # Remove plugin directory
        plugin_dir = Path(config.get('plugins', {}).get('directory', './plugins')) / plugin_name
        if plugin_dir.exists():
            import shutil
            shutil.rmtree(plugin_dir)
        
        click.echo(f"Plugin '{plugin_name}' uninstalled successfully")
    
    except Exception as e:
        click.echo(f"Plugin uninstall failed: {e}", err=True)
        sys.exit(1)


@plugin.command()
@click.argument('plugin_name')
@click.pass_context
def info(ctx, plugin_name):
    """Show detailed plugin information."""
    config = ctx.obj.config
    plugin_manager = get_plugin_manager(config)
    
    # Get plugin
    plugin = plugin_manager.get_plugin(plugin_name)
    if not plugin:
        click.echo(f"Plugin '{plugin_name}' not found", err=True)
        sys.exit(1)
    
    # Get plugin info
    info = plugin.get_info()
    
    click.echo(f"\nPlugin: {info['name']}")
    click.echo("=" * 40)
    click.echo(f"Version: {info['version']}")
    click.echo(f"Description: {info['description']}")
    click.echo(f"Author: {info['author']}")
    click.echo(f"API Version: {info['api_version']}")
    click.echo(f"Status: {'Active' if info['initialized'] else 'Inactive'}")
    
    # Dependencies
    if info['dependencies']:
        click.echo(f"\nDependencies:")
        for dep in info['dependencies']:
            dep_status = "✓" if dep in plugin_manager.list_plugins() else "✗"
            click.echo(f"  {dep_status} {dep}")
    
    # Rate limit status
    rate_limiter = plugin_manager.rate_limiters.get(plugin_name)
    if rate_limiter:
        status = rate_limiter.get_status()
        click.echo(f"\nRate Limiting:")
        click.echo(f"  Requests/minute: {status['requests_per_minute']}")
        click.echo(f"  Tokens available: {status['tokens_available']}/{status['bucket_size']}")
        if status['wait_time_seconds'] > 0:
            click.echo(f"  Wait time: {status['wait_time_seconds']:.1f}s")
    
    # Plugin type
    from ...plugins.base import CollectorPlugin, ExporterPlugin, TransformerPlugin, AnalyzerPlugin
    
    plugin_types = []
    if isinstance(plugin, CollectorPlugin):
        plugin_types.append("Collector")
    if isinstance(plugin, ExporterPlugin):
        plugin_types.append("Exporter")
    if isinstance(plugin, TransformerPlugin):
        plugin_types.append("Transformer")
    if isinstance(plugin, AnalyzerPlugin):
        plugin_types.append("Analyzer")
    
    if plugin_types:
        click.echo(f"\nPlugin Types: {', '.join(plugin_types)}")


@plugin.command()
@click.argument('plugin_name')
@click.pass_context
def reload(ctx, plugin_name):
    """Reload a plugin."""
    config = ctx.obj.config
    plugin_manager = get_plugin_manager(config)
    
    try:
        plugin_manager.reload_plugin(plugin_name)
        click.echo(f"Plugin '{plugin_name}' reloaded successfully")
    except Exception as e:
        click.echo(f"Plugin reload failed: {e}", err=True)
        sys.exit(1)


@plugin.command()
@click.argument('plugin_name')
@click.option(
    '--config-file', '-c',
    type=click.Path(exists=True),
    help='Plugin configuration file (JSON)'
)
@click.pass_context
def configure(ctx, plugin_name, config_file):
    """Configure and initialize a plugin."""
    config = ctx.obj.config
    plugin_manager = get_plugin_manager(config)
    
    # Get plugin
    plugin = plugin_manager.get_plugin(plugin_name)
    if not plugin:
        click.echo(f"Plugin '{plugin_name}' not found", err=True)
        sys.exit(1)
    
    # Load plugin configuration
    if config_file:
        try:
            with open(config_file, 'r') as f:
                plugin_config = json.load(f)
        except Exception as e:
            click.echo(f"Failed to load configuration file: {e}", err=True)
            sys.exit(1)
    else:
        # Interactive configuration
        click.echo(f"Configuring plugin: {plugin_name}")
        click.echo("Enter configuration (JSON format):")
        
        config_str = click.edit('{}')
        if not config_str:
            click.echo("Configuration cancelled")
            return
        
        try:
            plugin_config = json.loads(config_str)
        except json.JSONDecodeError as e:
            click.echo(f"Invalid JSON: {e}", err=True)
            sys.exit(1)
    
    # Initialize plugin
    try:
        plugin_manager.initialize_plugin(plugin_name, plugin_config)
        click.echo(f"Plugin '{plugin_name}' configured and initialized successfully")
    except Exception as e:
        click.echo(f"Plugin initialization failed: {e}", err=True)
        sys.exit(1)


@plugin.command()
@click.argument('plugin_name')
@click.argument('args', nargs=-1)
@click.pass_context
def execute(ctx, plugin_name, args):
    """Execute a plugin directly."""
    config = ctx.obj.config
    plugin_manager = get_plugin_manager(config)
    
    try:
        # Parse arguments as key=value pairs
        kwargs = {}
        for arg in args:
            if '=' in arg:
                key, value = arg.split('=', 1)
                # Try to parse value as JSON
                try:
                    kwargs[key] = json.loads(value)
                except json.JSONDecodeError:
                    kwargs[key] = value
        
        # Execute plugin
        result = plugin_manager.execute_plugin(plugin_name, **kwargs)
        
        # Display result
        if result is not None:
            if isinstance(result, (dict, list)):
                click.echo(json.dumps(result, indent=2, default=str))
            else:
                click.echo(result)
    
    except Exception as e:
        click.echo(f"Plugin execution failed: {e}", err=True)
        sys.exit(1)
