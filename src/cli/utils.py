"""Utilities for CloudScope CLI."""

import sys
import json
import logging
from pathlib import Path
from typing import Dict, Any, Optional
from datetime import datetime

import click


class CloudScopeContext:
    """Context object passed between CLI commands."""
    
    def __init__(self, config: Dict[str, Any], config_path: str):
        """Initialize context.
        
        Args:
            config: Loaded configuration dictionary
            config_path: Path to configuration file
        """
        self.config = config
        self.config_path = config_path
        self._repository = None
        self._plugin_manager = None


def setup_logging(level: str, log_file: Optional[str] = None):
    """Setup logging configuration.
    
    Args:
        level: Logging level (DEBUG, INFO, WARNING, ERROR)
        log_file: Optional log file path
    """
    # Create formatter
    formatter = logging.Formatter(
        '%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )
    
    # Setup root logger
    root_logger = logging.getLogger()
    root_logger.setLevel(getattr(logging, level))
    
    # Remove existing handlers
    for handler in root_logger.handlers[:]:
        root_logger.removeHandler(handler)
    
    # Add console handler
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setFormatter(formatter)
    root_logger.addHandler(console_handler)
    
    # Add file handler if specified
    if log_file:
        file_handler = logging.FileHandler(log_file)
        file_handler.setFormatter(formatter)
        root_logger.addHandler(file_handler)
    
    # Set CloudScope logger
    cloudscope_logger = logging.getLogger('cloudscope')
    cloudscope_logger.setLevel(getattr(logging, level))


def load_config(config_path: str) -> Dict[str, Any]:
    """Load configuration from file.
    
    Args:
        config_path: Path to configuration file
        
    Returns:
        Configuration dictionary
        
    Raises:
        Exception: If configuration cannot be loaded
    """
    config_path = Path(config_path)
    
    if not config_path.exists():
        raise FileNotFoundError(f"Configuration file not found: {config_path}")
    
    try:
        with open(config_path, 'r') as f:
            config = json.load(f)
        
        # Expand environment variables
        config = _expand_env_vars(config)
        
        return config
    
    except json.JSONDecodeError as e:
        raise ValueError(f"Invalid JSON in configuration file: {e}")
    except Exception as e:
        raise Exception(f"Failed to load configuration: {e}")


def save_config(config: Dict[str, Any], config_path: str):
    """Save configuration to file.
    
    Args:
        config: Configuration dictionary
        config_path: Path to save configuration
    """
    config_path = Path(config_path)
    
    # Create backup
    if config_path.exists():
        backup_dir = config_path.parent / '.backups'
        backup_dir.mkdir(exist_ok=True)
        
        timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
        backup_path = backup_dir / f"config_backup_{timestamp}.json"
        
        import shutil
        shutil.copy2(config_path, backup_path)
    
    # Update metadata
    if 'metadata' not in config:
        config['metadata'] = {}
    config['metadata']['modified'] = datetime.utcnow().isoformat()
    
    # Save configuration
    with open(config_path, 'w') as f:
        json.dump(config, f, indent=2)


def _expand_env_vars(obj: Any) -> Any:
    """Recursively expand environment variables in configuration.
    
    Args:
        obj: Configuration object (dict, list, or string)
        
    Returns:
        Object with environment variables expanded
    """
    import os
    import re
    
    if isinstance(obj, dict):
        return {key: _expand_env_vars(value) for key, value in obj.items()}
    elif isinstance(obj, list):
        return [_expand_env_vars(item) for item in obj]
    elif isinstance(obj, str):
        # Replace ${VAR} or ${VAR:-default} patterns
        def replacer(match):
            var_expr = match.group(1)
            if ':-' in var_expr:
                var_name, default = var_expr.split(':-', 1)
                return os.environ.get(var_name, default)
            else:
                return os.environ.get(var_expr, match.group(0))
        
        return re.sub(r'\$\{([^}]+)\}', replacer, obj)
    else:
        return obj


def get_repository(config: Dict[str, Any]):
    """Get repository instance based on configuration.
    
    Args:
        config: Configuration dictionary
        
    Returns:
        Repository instance
        
    Raises:
        Exception: If repository cannot be initialized
    """
    from ..adapters.storage import (
        FileBasedAssetRepository,
        SQLiteAssetRepository,
        MemgraphAssetRepository
    )
    
    storage_config = config.get('storage', {})
    storage_type = storage_config.get('type', 'file')
    
    try:
        if storage_type == 'file':
            return FileBasedAssetRepository(
                base_path=storage_config.get('path', './data/assets'),
                compress=storage_config.get('compression', True)
            )
        
        elif storage_type == 'sqlite':
            connection_config = storage_config.get('connection', {})
            return SQLiteAssetRepository(
                db_path=connection_config.get('path', './data/cloudscope.db'),
                pragmas=connection_config.get('pragmas')
            )
        
        elif storage_type == 'memgraph':
            connection_config = storage_config.get('connection', {})
            fallback_config = storage_config.get('fallback')
            
            return MemgraphAssetRepository(
                connection_config=connection_config,
                fallback_config=fallback_config
            )
        
        else:
            raise ValueError(f"Unsupported storage type: {storage_type}")
    
    except Exception as e:
        raise Exception(f"Failed to initialize repository: {e}")


def get_plugin_manager(config: Dict[str, Any]):
    """Get plugin manager instance.
    
    Args:
        config: Configuration dictionary
        
    Returns:
        Plugin manager instance
    """
    from ..plugins import PluginManager
    
    plugin_config = config.get('plugins', {})
    
    if not plugin_config.get('enabled', True):
        raise Exception("Plugin system is disabled")
    
    plugin_dir = plugin_config.get('directory', './plugins')
    auto_discover = plugin_config.get('auto_discover', True)
    rate_limits = plugin_config.get('rate_limits', {})
    
    manager = PluginManager(
        plugin_dir=plugin_dir,
        auto_discover=auto_discover,
        rate_limit_config=rate_limits
    )
    
    return manager


def format_table(headers: list, rows: list, max_width: Optional[int] = None) -> str:
    """Format data as a text table.
    
    Args:
        headers: List of column headers
        rows: List of row data (list of lists)
        max_width: Maximum width for each column
        
    Returns:
        Formatted table string
    """
    # Calculate column widths
    widths = [len(h) for h in headers]
    
    for row in rows:
        for i, cell in enumerate(row):
            widths[i] = max(widths[i], len(str(cell)))
    
    # Apply max width if specified
    if max_width:
        widths = [min(w, max_width) for w in widths]
    
    # Build format string
    format_str = " | ".join(f"{{:<{w}}}" for w in widths)
    
    # Build table
    lines = []
    
    # Header
    lines.append(format_str.format(*headers))
    lines.append("-" * (sum(widths) + 3 * (len(headers) - 1)))
    
    # Rows
    for row in rows:
        # Truncate cells if needed
        cells = []
        for i, cell in enumerate(row):
            cell_str = str(cell)
            if len(cell_str) > widths[i]:
                cell_str = cell_str[:widths[i]-3] + "..."
            cells.append(cell_str)
        
        lines.append(format_str.format(*cells))
    
    return "\n".join(lines)


def confirm_action(message: str, default: bool = False) -> bool:
    """Prompt user for confirmation.
    
    Args:
        message: Confirmation message
        default: Default response if user presses enter
        
    Returns:
        True if confirmed, False otherwise
    """
    return click.confirm(message, default=default)


def format_size(bytes: int) -> str:
    """Format byte size as human-readable string.
    
    Args:
        bytes: Size in bytes
        
    Returns:
        Formatted size string
    """
    for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
        if bytes < 1024.0:
            return f"{bytes:.2f} {unit}"
        bytes /= 1024.0
    
    return f"{bytes:.2f} PB"


def format_duration(seconds: float) -> str:
    """Format duration as human-readable string.
    
    Args:
        seconds: Duration in seconds
        
    Returns:
        Formatted duration string
    """
    if seconds < 1:
        return f"{seconds*1000:.0f}ms"
    elif seconds < 60:
        return f"{seconds:.1f}s"
    elif seconds < 3600:
        minutes = int(seconds / 60)
        secs = int(seconds % 60)
        return f"{minutes}m {secs}s"
    else:
        hours = int(seconds / 3600)
        minutes = int((seconds % 3600) / 60)
        return f"{hours}h {minutes}m"


def parse_key_value_pairs(pairs: list) -> dict:
    """Parse list of key=value strings into dictionary.
    
    Args:
        pairs: List of key=value strings
        
    Returns:
        Dictionary of parsed pairs
    """
    result = {}
    
    for pair in pairs:
        if '=' not in pair:
            raise ValueError(f"Invalid key=value pair: {pair}")
        
        key, value = pair.split('=', 1)
        
        # Try to parse value as JSON
        try:
            result[key] = json.loads(value)
        except json.JSONDecodeError:
            # Keep as string
            result[key] = value
    
    return result


def get_asset_summary(asset) -> str:
    """Get a one-line summary of an asset.
    
    Args:
        asset: Asset object
        
    Returns:
        Summary string
    """
    tags_str = ""
    if asset.tags:
        tags = [f"{k}={v}" for k, v in list(asset.tags.items())[:3]]
        tags_str = f" [{', '.join(tags)}]"
    
    return f"{asset.asset_id}: {asset.name} ({asset.asset_type}/{asset.provider}){tags_str}"
