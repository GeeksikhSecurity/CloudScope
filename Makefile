# CloudScope Makefile
.PHONY: help install install-dev test test-unit test-integration lint format type-check \
        clean build docker-build docker-up docker-down docs serve migrate backup

# Default target
.DEFAULT_GOAL := help

# Variables
PYTHON := python3
PIP := $(PYTHON) -m pip
PYTEST := $(PYTHON) -m pytest
BLACK := $(PYTHON) -m black
ISORT := $(PYTHON) -m isort
FLAKE8 := $(PYTHON) -m flake8
MYPY := $(PYTHON) -m mypy
DOCKER_COMPOSE := docker-compose
CLOUDSCOPE := cloudscope

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m # No Color

help: ## Show this help message
	@echo "$(BLUE)CloudScope Development Commands$(NC)"
	@echo "================================"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "$(GREEN)%-20s$(NC) %s\n", $$1, $$2}'

install: ## Install CloudScope in production mode
	$(PIP) install --upgrade pip setuptools wheel
	$(PIP) install -r requirements.txt
	$(PIP) install -e .
	@echo "$(GREEN)CloudScope installed successfully!$(NC)"

install-dev: ## Install CloudScope with development dependencies
	$(PIP) install --upgrade pip setuptools wheel
	$(PIP) install -r requirements-dev.txt
	$(PIP) install -e ".[dev]"
	pre-commit install
	@echo "$(GREEN)Development environment ready!$(NC)"

test: ## Run all tests
	$(PYTEST) -v --cov=src --cov-report=term-missing --cov-report=html

test-unit: ## Run unit tests only
	$(PYTEST) -v tests/unit --cov=src --cov-report=term-missing -m "not integration"

test-integration: ## Run integration tests only
	$(PYTEST) -v tests/integration -m integration

test-watch: ## Run tests in watch mode
	$(PYTEST) -v --cov=src --cov-report=term-missing --watch

lint: ## Run linting checks
	@echo "$(BLUE)Running flake8...$(NC)"
	$(FLAKE8) src tests
	@echo "$(BLUE)Running pylint...$(NC)"
	$(PYTHON) -m pylint src
	@echo "$(GREEN)Linting passed!$(NC)"

format: ## Format code with black and isort
	@echo "$(BLUE)Running isort...$(NC)"
	$(ISORT) src tests
	@echo "$(BLUE)Running black...$(NC)"
	$(BLACK) src tests
	@echo "$(GREEN)Code formatted!$(NC)"

format-check: ## Check code formatting without changes
	$(ISORT) --check-only src tests
	$(BLACK) --check src tests

type-check: ## Run type checking with mypy
	$(MYPY) src

security-check: ## Run security checks
	@echo "$(BLUE)Running bandit...$(NC)"
	$(PYTHON) -m bandit -r src
	@echo "$(BLUE)Checking dependencies...$(NC)"
	$(PYTHON) -m pip_audit

clean: ## Clean build artifacts and cache
	rm -rf build dist *.egg-info
	rm -rf .coverage htmlcov .pytest_cache
	rm -rf .mypy_cache .ruff_cache
	find . -type d -name __pycache__ -exec rm -rf {} +
	find . -type f -name "*.pyc" -delete
	@echo "$(GREEN)Cleaned build artifacts!$(NC)"

build: clean ## Build distribution packages
	$(PYTHON) -m build
	@echo "$(GREEN)Build complete! Check dist/ directory$(NC)"

docker-build: ## Build Docker image
	$(DOCKER_COMPOSE) build
	@echo "$(GREEN)Docker image built!$(NC)"

docker-up: ## Start services with docker-compose
	$(DOCKER_COMPOSE) up -d
	@echo "$(GREEN)Services started!$(NC)"
	@echo "CloudScope: http://localhost:8080"
	@echo "Prometheus: http://localhost:9090"
	@echo "Grafana: http://localhost:3000"

docker-down: ## Stop docker-compose services
	$(DOCKER_COMPOSE) down
	@echo "$(GREEN)Services stopped!$(NC)"

docker-logs: ## View docker-compose logs
	$(DOCKER_COMPOSE) logs -f

docs: ## Build documentation
	cd docs && $(MAKE) clean && $(MAKE) html
	@echo "$(GREEN)Documentation built! Open docs/_build/html/index.html$(NC)"

docs-serve: ## Serve documentation with live reload
	cd docs && $(PYTHON) -m sphinx_autobuild . _build/html

serve: ## Run CloudScope in development mode
	$(CLOUDSCOPE) --config config/cloudscope-config.json serve

collect: ## Run asset collection
	$(CLOUDSCOPE) collect --dry-run

report: ## Generate sample report
	$(CLOUDSCOPE) report generate --format json --output reports/sample-report.json

migrate: ## Run database migrations
	$(CLOUDSCOPE) db migrate

backup: ## Backup CloudScope data
	@mkdir -p backups
	@timestamp=$$(date +%Y%m%d_%H%M%S); \
	tar -czf backups/cloudscope_backup_$$timestamp.tar.gz data config
	@echo "$(GREEN)Backup created in backups/$(NC)"

init-config: ## Initialize configuration
	$(CLOUDSCOPE) config init --output config/cloudscope-config.json

plugin-list: ## List installed plugins
	$(CLOUDSCOPE) plugin list

health-check: ## Check system health
	$(CLOUDSCOPE) health --detailed

dev-setup: install-dev ## Complete development environment setup
	@echo "$(BLUE)Setting up development environment...$(NC)"
	mkdir -p data logs reports plugins config
	cp .env.example .env
	$(MAKE) init-config
	@echo "$(GREEN)Development setup complete!$(NC)"
	@echo "Edit .env and config/cloudscope-config.json to configure CloudScope"

quality: lint type-check test ## Run all quality checks
	@echo "$(GREEN)All quality checks passed!$(NC)"

release: quality build ## Prepare for release
	@echo "$(YELLOW)Ready for release!$(NC)"
	@echo "1. Update version in setup.py and pyproject.toml"
	@echo "2. Update CHANGELOG.md"
	@echo "3. Create git tag"
	@echo "4. Run: twine upload dist/*"

# Database targets
db-shell: ## Open database shell
	@if [ -f "data/cloudscope.db" ]; then \
		sqlite3 data/cloudscope.db; \
	else \
		echo "$(RED)Database not found. Run 'make migrate' first.$(NC)"; \
	fi

db-backup: ## Backup database
	@mkdir -p backups
	@if [ -f "data/cloudscope.db" ]; then \
		cp data/cloudscope.db backups/cloudscope_$$(date +%Y%m%d_%H%M%S).db; \
		echo "$(GREEN)Database backed up!$(NC)"; \
	else \
		echo "$(RED)Database not found!$(NC)"; \
	fi

# Plugin development
plugin-new: ## Create a new plugin template
	@read -p "Plugin name: " plugin_name; \
	mkdir -p plugins/$$plugin_name; \
	echo "Creating plugin: $$plugin_name"; \
	touch plugins/$$plugin_name/plugin.py; \
	touch plugins/$$plugin_name/plugin.json; \
	touch plugins/$$plugin_name/README.md; \
	echo "$(GREEN)Plugin template created in plugins/$$plugin_name$(NC)"

# CI/CD helpers
ci-test: ## Run tests for CI
	$(PYTEST) -v --cov=src --cov-report=xml --cov-report=term

ci-lint: ## Run linting for CI
	$(FLAKE8) src tests --format=junit-xml --output-file=lint-report.xml || true
	$(BLACK) --check src tests || true

# Development helpers
watch: ## Watch for file changes and run tests
	@command -v watchmedo >/dev/null 2>&1 || { echo "Installing watchdog..."; pip install watchdog[watchmedo]; }
	watchmedo shell-command \
		--patterns="*.py" \
		--recursive \
		--command='clear && make test-unit' \
		src tests

profile: ## Profile CloudScope performance
	$(PYTHON) -m cProfile -o profile.stats $(CLOUDSCOPE) collect --limit 100
	$(PYTHON) -m pstats profile.stats

# Utility functions
check-env: ## Check environment variables
	@echo "$(BLUE)Checking environment variables...$(NC)"
	@$(PYTHON) -c "from dotenv import load_dotenv; load_dotenv(); import os; print('\n'.join([f'{k}={v[:10]}...' if len(v)>10 else f'{k}={v}' for k,v in os.environ.items() if k.startswith('CLOUDSCOPE_') or k.startswith('AWS_') or k.startswith('AZURE_')]))"

version: ## Show CloudScope version
	@$(CLOUDSCOPE) --version

stats: ## Show project statistics
	@echo "$(BLUE)CloudScope Project Statistics$(NC)"
	@echo "=============================="
	@echo "Lines of Python code: $$(find src -name '*.py' | xargs wc -l | tail -1 | awk '{print $$1}')"
	@echo "Number of tests: $$(find tests -name 'test_*.py' | xargs grep -E 'def test_' | wc -l)"
	@echo "Number of source files: $$(find src -name '*.py' | wc -l)"
	@echo "Number of test files: $$(find tests -name 'test_*.py' | wc -l)"
