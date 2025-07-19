"""Plugin manager for CloudScope.

Manages plugin lifecycle, discovery, and execution.
Requirements: 3.3, 3.4, 3.5, 3.6, 3.9
"""

import os
import sys
import json
import importlib
import importlib.util
from pathlib import Path
from typing import Dict, List, Any, Optional, Type, Set
import logging
from collections import defaultdict
import threading

from .base import Plugin, PluginError, PluginInitializationError
from .rate_limiter import RateLimiter


class PluginManager:
    """Manages plugin lifecycle and execution."""
    
    def __init__(self, plugin_dir: Optional[str] = None,
                 auto_discover: bool = True,
                 rate_limit_config: Optional[Dict[str, Any]] = None):
        """Initialize plugin manager.
        
        Args:
            plugin_dir: Directory to search for plugins
            auto_discover: Automatically discover plugins on init
            rate_limit_config: Rate limiting configuration
        """
        self.logger = logging.getLogger(self.__class__.__name__)
        self.plugin_dir = Path(plugin_dir) if plugin_dir else Path("./plugins")
        self.plugins: Dict[str, Plugin] = {}
        self.rate_limiters: Dict[str, RateLimiter] = {}
        self.plugin_metadata: Dict[str, Dict[str, Any]] = {}
        self._lock = threading.Lock()
        
        # Rate limiting configuration
        self.rate_limit_config = rate_limit_config or {
            "default": {
                "requests_per_minute": 60,
                "requests_per_hour": 1000
            }
        }
        
        # Plugin registry for approved plugins
        self.registry_url = None
        self.verify_signatures = False
        
        if auto_discover and self.plugin_dir.exists():
            self.discover_plugins()
    
    def discover_plugins(self, plugin_dir: Optional[Path] = None) -> None:
        """Discover and load plugins from directory.
        
        Args:
            plugin_dir: Directory to search (uses default if not provided)
        """
        search_dir = plugin_dir or self.plugin_dir
        
        if not search_dir.exists():
            self.logger.warning(f"Plugin directory does not exist: {search_dir}")
            return
        
        self.logger.info(f"Discovering plugins in {search_dir}")
        
        # Look for plugin directories
        for item in search_dir.iterdir():
            if item.is_dir() and not item.name.startswith("_"):
                self._load_plugin_from_directory(item)
        
        # Look for individual plugin files
        for item in search_dir.glob("*.py"):
            if not item.name.startswith("_"):
                self._load_plugin_from_file(item)
        
        self.logger.info(f"Discovered {len(self.plugins)} plugins")
    
    def _load_plugin_from_directory(self, plugin_dir: Path) -> None:
        """Load plugin from a directory.
        
        Args:
            plugin_dir: Plugin directory path
        """
        # Look for plugin.py or __init__.py
        plugin_file = plugin_dir / "plugin.py"
        if not plugin_file.exists():
            plugin_file = plugin_dir / "__init__.py"
        
        if not plugin_file.exists():
            self.logger.debug(f"No plugin file found in {plugin_dir}")
            return
        
        # Load metadata if available
        metadata_file = plugin_dir / "plugin.json"
        metadata = {}
        if metadata_file.exists():
            try:
                with open(metadata_file, 'r') as f:
                    metadata = json.load(f)
            except Exception as e:
                self.logger.warning(f"Failed to load metadata from {metadata_file}: {e}")
        
        # Load plugin
        self._load_plugin_from_file(plugin_file, metadata)
    
    def _load_plugin_from_file(self, plugin_file: Path, 
                              metadata: Optional[Dict[str, Any]] = None) -> None:
        """Load plugin from a Python file.
        
        Args:
            plugin_file: Path to plugin Python file
            metadata: Optional plugin metadata
        """
        try:
            # Load module
            module_name = f"cloudscope_plugin_{plugin_file.stem}"
            spec = importlib.util.spec_from_file_location(module_name, plugin_file)
            
            if not spec or not spec.loader:
                self.logger.error(f"Failed to load plugin spec from {plugin_file}")
                return
            
            module = importlib.util.module_from_spec(spec)
            sys.modules[module_name] = module
            spec.loader.exec_module(module)
            
            # Find plugin classes
            plugin_classes = []
            for attr_name in dir(module):
                attr = getattr(module, attr_name)
                if (isinstance(attr, type) and 
                    issubclass(attr, Plugin) and 
                    attr is not Plugin and
                    not attr.__name__.startswith("_")):
                    plugin_classes.append(attr)
            
            # Load each plugin class
            for plugin_class in plugin_classes:
                try:
                    plugin = plugin_class()
                    
                    # Apply metadata if available
                    if metadata:
                        plugin._metadata = metadata
                    
                    # Register plugin
                    self.register_plugin(plugin)
                    
                except Exception as e:
                    self.logger.error(f"Failed to instantiate plugin {plugin_class.__name__}: {e}")
            
        except Exception as e:
            self.logger.error(f"Failed to load plugin from {plugin_file}: {e}")
    
    def register_plugin(self, plugin: Plugin) -> None:
        """Register a plugin instance.
        
        Args:
            plugin: Plugin instance to register
            
        Raises:
            PluginError: If plugin with same name already exists
        """
        with self._lock:
            if plugin.name in self.plugins:
                raise PluginError(f"Plugin {plugin.name} already registered")
            
            # Validate API version compatibility
            if not self._is_api_compatible(plugin.api_version):
                raise PluginError(
                    f"Plugin {plugin.name} requires API version {plugin.api_version}"
                )
            
            # Store plugin
            self.plugins[plugin.name] = plugin
            
            # Create rate limiter
            rate_config = self.rate_limit_config.get(
                plugin.name,
                self.rate_limit_config["default"]
            )
            self.rate_limiters[plugin.name] = RateLimiter(**rate_config)
            
            # Store metadata
            self.plugin_metadata[plugin.name] = plugin.get_info()
            
            self.logger.info(f"Registered plugin: {plugin.name} v{plugin.version}")
    
    def unregister_plugin(self, name: str) -> bool:
        """Unregister a plugin.
        
        Args:
            name: Plugin name
            
        Returns:
            True if plugin was unregistered
        """
        with self._lock:
            if name not in self.plugins:
                return False
            
            # Cleanup plugin
            try:
                plugin = self.plugins[name]
                if hasattr(plugin, '_initialized') and plugin._initialized:
                    plugin.cleanup()
            except Exception as e:
                self.logger.error(f"Error during plugin cleanup: {e}")
            
            # Remove plugin
            del self.plugins[name]
            del self.rate_limiters[name]
            del self.plugin_metadata[name]
            
            self.logger.info(f"Unregistered plugin: {name}")
            return True
    
    def get_plugin(self, name: str) -> Optional[Plugin]:
        """Get plugin by name.
        
        Args:
            name: Plugin name
            
        Returns:
            Plugin instance or None
        """
        return self.plugins.get(name)
    
    def list_plugins(self, plugin_type: Optional[Type[Plugin]] = None) -> List[str]:
        """List registered plugins.
        
        Args:
            plugin_type: Optional filter by plugin type
            
        Returns:
            List of plugin names
        """
        if plugin_type:
            return [
                name for name, plugin in self.plugins.items()
                if isinstance(plugin, plugin_type)
            ]
        return list(self.plugins.keys())
    
    def get_plugin_info(self, name: str) -> Optional[Dict[str, Any]]:
        """Get plugin information.
        
        Args:
            name: Plugin name
            
        Returns:
            Plugin metadata or None
        """
        return self.plugin_metadata.get(name)
    
    def initialize_plugin(self, name: str, config: Dict[str, Any]) -> None:
        """Initialize a plugin with configuration.
        
        Args:
            name: Plugin name
            config: Plugin configuration
            
        Raises:
            PluginError: If plugin not found or initialization fails
        """
        plugin = self.get_plugin(name)
        if not plugin:
            raise PluginError(f"Plugin {name} not found")
        
        # Check dependencies
        self._check_dependencies(plugin)
        
        try:
            plugin.initialize(config)
            self.plugin_metadata[name]["initialized"] = True
            self.logger.info(f"Initialized plugin: {name}")
        except Exception as e:
            raise PluginInitializationError(f"Failed to initialize {name}: {e}")
    
    def execute_plugin(self, name: str, **kwargs) -> Any:
        """Execute plugin with rate limiting.
        
        Args:
            name: Plugin name
            **kwargs: Plugin-specific arguments
            
        Returns:
            Plugin execution result
            
        Raises:
            PluginError: If plugin not found or execution fails
        """
        plugin = self.get_plugin(name)
        if not plugin:
            raise PluginError(f"Plugin {name} not found")
        
        # Check rate limit
        limiter = self.rate_limiters[name]
        if not limiter.allow_request():
            raise PluginError(f"Rate limit exceeded for plugin {name}")
        
        # Execute plugin
        try:
            self.logger.debug(f"Executing plugin: {name}")
            result = plugin.execute(**kwargs)
            self.logger.debug(f"Plugin {name} executed successfully")
            return result
        except Exception as e:
            self.logger.error(f"Plugin {name} execution failed: {e}")
            raise PluginError(f"Plugin execution failed: {e}")
    
    def reload_plugin(self, name: str) -> None:
        """Reload a plugin.
        
        Args:
            name: Plugin name to reload
            
        Raises:
            PluginError: If reload fails
        """
        # Get current plugin info
        plugin = self.get_plugin(name)
        if not plugin:
            raise PluginError(f"Plugin {name} not found")
        
        # Save current configuration
        config = getattr(plugin, '_config', {})
        
        # Unregister plugin
        self.unregister_plugin(name)
        
        # Re-discover plugins
        self.discover_plugins()
        
        # Re-initialize if it was initialized
        new_plugin = self.get_plugin(name)
        if new_plugin and config:
            self.initialize_plugin(name, config)
    
    def _check_dependencies(self, plugin: Plugin) -> None:
        """Check if plugin dependencies are satisfied.
        
        Args:
            plugin: Plugin to check
            
        Raises:
            PluginError: If dependencies not satisfied
        """
        for dep in plugin.dependencies:
            if dep not in self.plugins:
                raise PluginError(
                    f"Plugin {plugin.name} requires {dep} which is not available"
                )
            
            # Check if dependency is initialized
            dep_plugin = self.plugins[dep]
            if not getattr(dep_plugin, '_initialized', False):
                raise PluginError(
                    f"Plugin {plugin.name} requires {dep} to be initialized"
                )
    
    def _is_api_compatible(self, required_version: str) -> bool:
        """Check if required API version is compatible.
        
        Args:
            required_version: Required API version
            
        Returns:
            True if compatible
        """
        # Simple version check - in production use semantic versioning
        current_version = "1.0"
        return required_version <= current_version
    
    def get_dependency_graph(self) -> Dict[str, List[str]]:
        """Get plugin dependency graph.
        
        Returns:
            Dictionary mapping plugin names to their dependencies
        """
        graph = {}
        for name, plugin in self.plugins.items():
            graph[name] = plugin.dependencies
        return graph
    
    def get_execution_order(self, plugins: List[str]) -> List[str]:
        """Get execution order respecting dependencies.
        
        Args:
            plugins: List of plugin names to order
            
        Returns:
            Ordered list of plugin names
            
        Raises:
            PluginError: If circular dependency detected
        """
        # Build dependency graph
        graph = self.get_dependency_graph()
        
        # Topological sort
        visited = set()
        stack = []
        
        def visit(plugin: str, visiting: Set[str]):
            if plugin in visiting:
                raise PluginError(f"Circular dependency detected involving {plugin}")
            
            if plugin in visited:
                return
            
            visiting.add(plugin)
            
            # Visit dependencies first
            for dep in graph.get(plugin, []):
                if dep in plugins:
                    visit(dep, visiting)
            
            visiting.remove(plugin)
            visited.add(plugin)
            stack.append(plugin)
        
        # Visit all requested plugins
        for plugin in plugins:
            if plugin not in visited:
                visit(plugin, set())
        
        return stack
    
    def validate_plugin_directory(self, plugin_dir: Path) -> Dict[str, Any]:
        """Validate a plugin directory structure.
        
        Args:
            plugin_dir: Plugin directory to validate
            
        Returns:
            Validation results
        """
        results = {
            "valid": True,
            "errors": [],
            "warnings": [],
            "info": {}
        }
        
        # Check for plugin file
        plugin_file = plugin_dir / "plugin.py"
        if not plugin_file.exists():
            plugin_file = plugin_dir / "__init__.py"
            if not plugin_file.exists():
                results["valid"] = False
                results["errors"].append("No plugin.py or __init__.py found")
        
        # Check for metadata
        metadata_file = plugin_dir / "plugin.json"
        if metadata_file.exists():
            try:
                with open(metadata_file, 'r') as f:
                    metadata = json.load(f)
                    results["info"]["metadata"] = metadata
                    
                    # Validate metadata fields
                    required_fields = ["name", "version", "description"]
                    for field in required_fields:
                        if field not in metadata:
                            results["warnings"].append(f"Missing metadata field: {field}")
                            
            except Exception as e:
                results["errors"].append(f"Invalid plugin.json: {e}")
        else:
            results["warnings"].append("No plugin.json found")
        
        # Check for README
        readme_file = plugin_dir / "README.md"
        if not readme_file.exists():
            results["warnings"].append("No README.md found")
        
        # Check for tests
        test_file = plugin_dir / "test_plugin.py"
        if not test_file.exists():
            results["warnings"].append("No test file found")
        
        return results
