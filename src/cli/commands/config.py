"""Configuration management commands for CloudScope CLI."""

import sys
import json
import click
from pathlib import Path
from datetime import datetime
import shutil

from ..utils import load_config, save_config


@click.group(name='config')
def config_group():
    """Manage CloudScope configuration."""
    pass


@config_group.command()
@click.option(
    '--output', '-o',
    type=click.Path(),
    help='Output path for configuration file'
)
@click.option(
    '--force', '-f',
    is_flag=True,
    help='Overwrite existing configuration'
)
def init(output, force):
    """Initialize a new configuration file.
    
    Creates a default configuration file with all available options.
    """
    output_path = Path(output) if output else Path('./config/cloudscope-config.json')
    
    if output_path.exists() and not force:
        click.echo(f"Configuration file already exists: {output_path}")
        click.echo("Use --force to overwrite")
        sys.exit(1)
    
    # Create default configuration
    default_config = {
        "version": "1.4.0",
        "metadata": {
            "created": datetime.utcnow().isoformat(),
            "description": "CloudScope configuration"
        },
        "storage": {
            "type": "sqlite",
            "connection": {
                "path": "./data/cloudscope.db"
            }
        },
        "collectors": {
            "enabled": ["aws", "azure", "gcp"],
            "schedule": "0 * * * *",
            "defaults": {
                "timeout": 300,
                "retry_count": 3,
                "rate_limit": {
                    "requests_per_second": 10
                }
            }
        },
        "plugins": {
            "enabled": True,
            "directory": "./plugins",
            "auto_discover": True
        },
        "reporting": {
            "output_directory": "./reports",
            "default_format": "json",
            "formats": {
                "csv": {
                    "delimiter": ",",
                    "include_headers": True
                }
            }
        },
        "security": {
            "input_validation": {
                "enabled": True,
                "strict_mode": True
            }
        },
        "observability": {
            "logging": {
                "level": "INFO",
                "format": "json",
                "outputs": [
                    {
                        "type": "file",
                        "path": "/var/log/cloudscope/app.log"
                    }
                ]
            }
        }
    }
    
    # Create directory if needed
    output_path.parent.mkdir(parents=True, exist_ok=True)
    
    # Write configuration
    with open(output_path, 'w') as f:
        json.dump(default_config, f, indent=2)
    
    click.echo(f"Configuration initialized at: {output_path}")


@config_group.command()
@click.option(
    '--expand-vars',
    is_flag=True,
    help='Expand environment variables'
)
@click.pass_context
def show(ctx, expand_vars):
    """Show current configuration."""
    config = ctx.obj.config
    
    if expand_vars:
        # Expand environment variables in config
        import os
        config_str = json.dumps(config, indent=2)
        for key, value in os.environ.items():
            config_str = config_str.replace(f"${{{key}}}", value)
        click.echo(config_str)
    else:
        click.echo(json.dumps(config, indent=2))


@config_group.command()
@click.argument('key')
@click.argument('value')
@click.pass_context
def set(ctx, key, value):
    """Set a configuration value.
    
    KEY uses dot notation: storage.type, collectors.enabled.0, etc.
    """
    config = ctx.obj.config
    config_path = ctx.obj.config_path
    
    try:
        # Parse value as JSON if possible
        try:
            parsed_value = json.loads(value)
        except json.JSONDecodeError:
            parsed_value = value
        
        # Set nested value
        _set_nested_value(config, key, parsed_value)
        
        # Save configuration
        save_config(config, config_path)
        
        click.echo(f"Set {key} = {json.dumps(parsed_value)}")
    
    except Exception as e:
        click.echo(f"Failed to set configuration: {e}", err=True)
        sys.exit(1)


@config_group.command()
@click.argument('key')
@click.pass_context
def get(ctx, key):
    """Get a configuration value.
    
    KEY uses dot notation: storage.type, collectors.enabled.0, etc.
    """
    config = ctx.obj.config
    
    try:
        value = _get_nested_value(config, key)
        click.echo(json.dumps(value, indent=2))
    except KeyError:
        click.echo(f"Key not found: {key}", err=True)
        sys.exit(1)


@config_group.command()
@click.option(
    '--verbose', '-v',
    is_flag=True,
    help='Show detailed validation errors'
)
@click.pass_context
def validate(ctx, verbose):
    """Validate current configuration."""
    config = ctx.obj.config
    
    errors = []
    warnings = []
    
    # Check required fields
    required_fields = ['storage', 'collectors']
    for field in required_fields:
        if field not in config:
            errors.append(f"Missing required field: {field}")
    
    # Validate storage configuration
    if 'storage' in config:
        storage_type = config['storage'].get('type')
        if storage_type not in ['file', 'sqlite', 'memgraph']:
            errors.append(f"Invalid storage type: {storage_type}")
    
    # Validate collector configuration
    if 'collectors' in config:
        enabled = config['collectors'].get('enabled', [])
        if not isinstance(enabled, list):
            errors.append("collectors.enabled must be a list")
    
    # Check for deprecated options
    if 'legacy_mode' in config:
        warnings.append("'legacy_mode' is deprecated and will be removed")
    
    # Display results
    if errors:
        click.echo("Configuration validation FAILED")
        click.echo(f"\nErrors ({len(errors)}):")
        for error in errors:
            click.echo(f"  - {error}")
    else:
        click.echo("Configuration validation PASSED")
    
    if warnings:
        click.echo(f"\nWarnings ({len(warnings)}):")
        for warning in warnings:
            click.echo(f"  - {warning}")
    
    if errors:
        sys.exit(1)


@config_group.command()
@click.pass_context
def history(ctx):
    """Show configuration history."""
    config_path = Path(ctx.obj.config_path)
    backup_dir = config_path.parent / '.backups'
    
    if not backup_dir.exists():
        click.echo("No configuration history found")
        return
    
    # Find backup files
    backups = sorted(backup_dir.glob('*.json'), reverse=True)
    
    if not backups:
        click.echo("No configuration backups found")
        return
    
    click.echo("Configuration History:")
    click.echo("-" * 60)
    
    for i, backup_path in enumerate(backups[:10]):  # Show last 10
        # Extract timestamp from filename
        timestamp = backup_path.stem.split('_')[-1]
        
        # Get file size
        size = backup_path.stat().st_size
        
        click.echo(f"{i+1}. {timestamp} ({size} bytes) - {backup_path.name}")
    
    if len(backups) > 10:
        click.echo(f"\n... and {len(backups) - 10} more backups")


@config_group.command()
@click.option(
    '--version',
    type=int,
    help='Specific version to rollback to'
)
@click.option(
    '--confirm',
    is_flag=True,
    help='Skip confirmation prompt'
)
@click.pass_context
def rollback(ctx, version, confirm):
    """Rollback to a previous configuration version."""
    config_path = Path(ctx.obj.config_path)
    backup_dir = config_path.parent / '.backups'
    
    if not backup_dir.exists():
        click.echo("No configuration backups found")
        sys.exit(1)
    
    # Find backup files
    backups = sorted(backup_dir.glob('*.json'), reverse=True)
    
    if not backups:
        click.echo("No configuration backups found")
        sys.exit(1)
    
    # Select backup
    if version:
        if version < 1 or version > len(backups):
            click.echo(f"Invalid version number. Choose between 1 and {len(backups)}")
            sys.exit(1)
        backup_path = backups[version - 1]
    else:
        # Use most recent backup
        backup_path = backups[0]
    
    # Show what will be rolled back
    click.echo(f"Rolling back to: {backup_path.name}")
    
    # Confirm
    if not confirm:
        if not click.confirm("Continue with rollback?"):
            click.echo("Rollback cancelled")
            return
    
    try:
        # Backup current config first
        timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
        current_backup = backup_dir / f"config_backup_{timestamp}.json"
        shutil.copy2(config_path, current_backup)
        
        # Restore from backup
        shutil.copy2(backup_path, config_path)
        
        click.echo("Configuration rolled back successfully")
        click.echo(f"Previous configuration backed up to: {current_backup.name}")
    
    except Exception as e:
        click.echo(f"Rollback failed: {e}", err=True)
        sys.exit(1)


@config_group.command()
@click.pass_context
def env(ctx):
    """Show environment variables used in configuration."""
    config_str = json.dumps(ctx.obj.config, indent=2)
    
    # Find all environment variable references
    import re
    env_vars = re.findall(r'\$\{([^}]+)\}', config_str)
    
    if not env_vars:
        click.echo("No environment variables referenced in configuration")
        return
    
    click.echo("Environment Variables Referenced:")
    click.echo("-" * 60)
    
    import os
    for var in sorted(set(env_vars)):
        value = os.environ.get(var)
        if value:
            # Mask sensitive values
            if any(sensitive in var.lower() for sensitive in ['password', 'secret', 'key', 'token']):
                display_value = '*' * 8
            else:
                display_value = value[:50] + '...' if len(value) > 50 else value
            
            click.echo(f"{var}: {display_value}")
        else:
            click.echo(f"{var}: <not set>")


def _get_nested_value(data, key):
    """Get nested value using dot notation."""
    keys = key.split('.')
    value = data
    
    for k in keys:
        if k.isdigit():
            # Array index
            value = value[int(k)]
        else:
            value = value[k]
    
    return value


def _set_nested_value(data, key, value):
    """Set nested value using dot notation."""
    keys = key.split('.')
    current = data
    
    for i, k in enumerate(keys[:-1]):
        if k.isdigit():
            # Array index
            k = int(k)
        
        if k not in current:
            # Create nested structure
            if isinstance(keys[i+1], str) and keys[i+1].isdigit():
                current[k] = []
            else:
                current[k] = {}
        
        current = current[k]
    
    # Set the final value
    final_key = keys[-1]
    if final_key.isdigit():
        final_key = int(final_key)
    
    current[final_key] = value
