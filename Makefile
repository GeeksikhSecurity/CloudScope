# CloudScope Development Commands

## Quick Start
make setup          # Initial setup and configuration
make dev             # Start development environment
make test            # Run all tests
make clean           # Clean up development environment

## Development
make install         # Install dependencies
make format          # Format code (black, isort)
make lint            # Run linters (flake8, mypy)
make security        # Run security scans
make docs            # Generate documentation

## Testing
make test-unit       # Run unit tests
make test-integration # Run integration tests
make test-performance # Run performance tests
make test-security   # Run security tests
make coverage        # Generate coverage report

## Docker
make build           # Build Docker images
make up              # Start all services
make down            # Stop all services
make logs            # View service logs
make shell           # Open shell in API container

## Database
make db-migrate      # Run database migrations
make db-seed         # Seed database with sample data
make db-reset        # Reset database

## Deployment
make deploy-dev      # Deploy to development
make deploy-staging  # Deploy to staging
make deploy-prod     # Deploy to production

## Utilities
make backup          # Create backup
make restore         # Restore from backup
make monitor         # Open monitoring dashboard

.PHONY: setup dev test clean install format lint security docs test-unit test-integration test-performance test-security coverage build up down logs shell db-migrate db-seed db-reset deploy-dev deploy-staging deploy-prod backup restore monitor

# Variables
DOCKER_COMPOSE = docker-compose
PYTHON = python3
PIP = pip3

# Setup and initialization
setup:
	@echo "🚀 Setting up CloudScope development environment..."
	@chmod +x setup.sh
	@./setup.sh
	@$(MAKE) install

# Development environment
dev: up
	@echo "🔗 Development URLs:"
	@echo "  API Documentation: http://localhost:8000/docs"
	@echo "  GraphQL Playground: http://localhost:8000/graphql"
	@echo "  Grafana Dashboard: http://localhost:3001 (admin/admin123)"
	@echo "  Kibana Logs: http://localhost:5601"

install:
	@echo "📦 Installing Python dependencies..."
	@$(PIP) install -r requirements.txt
	@$(PIP) install -r requirements-dev.txt

# Code quality
format:
	@echo "🎨 Formatting code..."
	@black .
	@isort .

lint:
	@echo "🔍 Running linters..."
	@flake8 . --count --select=E9,F63,F7,F82 --show-source --statistics
	@flake8 . --count --exit-zero --max-complexity=10 --max-line-length=127 --statistics
	@mypy core/ --ignore-missing-imports --no-strict-optional

security:
	@echo "🔒 Running security scans..."
	@bandit -r . -f json -o bandit-report.json || true
	@safety check --json --output safety-report.json || true
	@echo "Security reports generated: bandit-report.json, safety-report.json"

# Testing
test: test-unit test-integration

test-unit:
	@echo "🧪 Running unit tests..."
	@pytest tests/unit/ -v --cov=core --cov-report=html --cov-report=term

test-integration:
	@echo "🔗 Running integration tests..."
	@$(DOCKER_COMPOSE) -f docker-compose.test.yml up -d
	@sleep 30
	@pytest tests/integration/ -v
	@$(DOCKER_COMPOSE) -f docker-compose.test.yml down -v

test-performance:
	@echo "⚡ Running performance tests..."
	@$(DOCKER_COMPOSE) up -d
	@sleep 60
	@locust -f tests/performance/locustfile.py --headless -u 10 -r 2 -t 60s --host http://localhost:8000
	@$(DOCKER_COMPOSE) down

test-security:
	@echo "🛡️ Running security tests..."
	@pytest tests/security/ -v

coverage:
	@echo "📊 Generating coverage report..."
	@pytest --cov=core --cov-report=html --cov-report=term
	@echo "Coverage report: htmlcov/index.html"

# Docker operations
build:
	@echo "🏗️ Building Docker images..."
	@$(DOCKER_COMPOSE) build

up:
	@echo "🚀 Starting CloudScope services..."
	@$(DOCKER_COMPOSE) up -d
	@echo "Waiting for services to be ready..."
	@sleep 30

down:
	@echo "🛑 Stopping CloudScope services..."
	@$(DOCKER_COMPOSE) down

logs:
	@echo "📋 Viewing service logs..."
	@$(DOCKER_COMPOSE) logs -f

shell:
	@echo "🐚 Opening shell in API container..."
	@$(DOCKER_COMPOSE) exec api bash

# Database operations
db-migrate:
	@echo "🗃️ Running database migrations..."
	@$(DOCKER_COMPOSE) exec api python -m alembic upgrade head

db-seed:
	@echo "🌱 Seeding database with sample data..."
	@$(DOCKER_COMPOSE) exec api python scripts/seed_database.py

db-reset:
	@echo "🔄 Resetting database..."
	@$(DOCKER_COMPOSE) down -v
	@$(DOCKER_COMPOSE) up -d memgraph postgres
	@sleep 10
	@$(MAKE) db-migrate
	@$(MAKE) db-seed

# Documentation
docs:
	@echo "📚 Generating documentation..."
	@mkdocs build
	@echo "Documentation generated: site/index.html"

docs-serve:
	@echo "📖 Serving documentation..."
	@mkdocs serve

# Deployment
deploy-dev:
	@echo "🚢 Deploying to development..."
	@kubectl apply -f deployment/kubernetes/dev/

deploy-staging:
	@echo "🚢 Deploying to staging..."
	@kubectl apply -f deployment/kubernetes/staging/

deploy-prod:
	@echo "🚢 Deploying to production..."
	@kubectl apply -f deployment/kubernetes/prod/

# Utilities
backup:
	@echo "💾 Creating backup..."
	@mkdir -p backups
	@$(DOCKER_COMPOSE) exec memgraph mg_dump > backups/memgraph-$(shell date +%Y%m%d_%H%M%S).cypher
	@$(DOCKER_COMPOSE) exec postgres pg_dump -U cloudscope cloudscope > backups/postgres-$(shell date +%Y%m%d_%H%M%S).sql

restore:
	@echo "🔄 Restoring from backup..."
	@read -p "Enter backup file path: " backup_file; \
	$(DOCKER_COMPOSE) exec -T memgraph mg_load < $$backup_file

monitor:
	@echo "📊 Opening monitoring dashboard..."
	@open http://localhost:3001 || xdg-open http://localhost:3001 || echo "Visit http://localhost:3001"

clean:
	@echo "🧹 Cleaning up development environment..."
	@$(DOCKER_COMPOSE) down -v --remove-orphans
	@docker system prune -f
	@rm -rf __pycache__ .pytest_cache .coverage htmlcov/
	@rm -f *.log bandit-report.json safety-report.json

# Help
help:
	@echo "CloudScope Development Commands"
	@echo "==============================="
	@echo ""
	@echo "Quick Start:"
	@echo "  make setup          - Initial setup and configuration"
	@echo "  make dev            - Start development environment"
	@echo "  make test           - Run all tests"
	@echo "  make clean          - Clean up development environment"
	@echo ""
	@echo "Development:"
	@echo "  make install        - Install dependencies"
	@echo "  make format         - Format code (black, isort)"
	@echo "  make lint           - Run linters (flake8, mypy)"
	@echo "  make security       - Run security scans"
	@echo "  make docs           - Generate documentation"
	@echo ""
	@echo "Testing:"
	@echo "  make test-unit      - Run unit tests"
	@echo "  make test-integration - Run integration tests"
	@echo "  make test-performance - Run performance tests"
	@echo "  make coverage       - Generate coverage report"
	@echo ""
	@echo "Docker:"
	@echo "  make build          - Build Docker images"
	@echo "  make up             - Start all services"
	@echo "  make down           - Stop all services"
	@echo "  make logs           - View service logs"
	@echo "  make shell          - Open shell in API container"
	@echo ""
	@echo "For more information, see README.md"
