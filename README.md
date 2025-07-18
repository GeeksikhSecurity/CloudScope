# CloudScope - Comprehensive IT Asset Inventory System

<p align="center">
  <img src="docs/assets/cloudscope-logo.png" alt="CloudScope Logo" width="200">
</p>

<p align="center">
  <a href="https://github.com/your-org/cloudscope/actions"><img src="https://github.com/your-org/cloudscope/workflows/CI/badge.svg" alt="CI Status"></a>
  <a href="https://codecov.io/gh/your-org/cloudscope"><img src="https://codecov.io/gh/your-org/cloudscope/branch/main/graph/badge.svg" alt="Coverage"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License"></a>
  <a href="https://github.com/your-org/cloudscope/releases"><img src="https://img.shields.io/github/v/release/your-org/cloudscope" alt="Release"></a>
</p>

## Overview

CloudScope is a modern, extensible IT asset inventory system designed to discover, track, and manage infrastructure assets across multiple cloud providers and on-premises environments. Built with a plugin-based architecture, it provides comprehensive visibility into your IT landscape while maintaining flexibility and scalability.

### Key Features

- 🔍 **Multi-Cloud Discovery**: Automatic discovery of assets across AWS, Azure, GCP, and Kubernetes
- 🔌 **Plugin Architecture**: Extensible design supporting custom collectors and exporters
- 📊 **Multiple Storage Backends**: File-based, SQLite, and Memgraph (graph database) support
- 📈 **Rich Reporting**: Generate reports in JSON, CSV, HTML, PDF, and Markdown formats
- 🤖 **LLM-Optimized Export**: Special CSV format optimized for Large Language Model analysis
- 🔒 **Enterprise Security**: JWT authentication, RBAC, encryption at rest and in transit
- 📡 **Comprehensive Monitoring**: Built-in metrics, tracing, and health checks
- 🔄 **Resilience Patterns**: Circuit breakers, retry logic, and graceful degradation
- 🎯 **Risk Analysis**: Automated risk scoring and compliance checking
- 🔗 **Third-Party Integrations**: Slack, Teams, Jira, ServiceNow, PagerDuty, and more

## Quick Start

### Prerequisites

- Python 3.8 or higher
- Docker and Docker Compose (for containerized deployment)
- Cloud provider credentials (AWS, Azure, GCP) for asset discovery

### Installation

#### Option 1: Docker (Recommended)

```bash
# Clone the repository
git clone https://github.com/your-org/cloudscope.git
cd cloudscope

# Copy and configure environment variables
cp .env.example .env
# Edit .env with your configuration

# Start CloudScope with Docker Compose
docker-compose up -d

# Verify installation
docker-compose exec cloudscope cloudscope health-check
```

#### Option 2: Native Installation

```bash
# Clone the repository
git clone https://github.com/your-org/cloudscope.git
cd cloudscope

# Create virtual environment
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install CloudScope
pip install -r requirements.txt
pip install -e .

# Initialize configuration
cloudscope config init

# Run initial collection
cloudscope collect --dry-run
```

### Basic Usage

#### Collect Assets
```bash
# Collect from all configured providers
cloudscope collect

# Collect from specific provider
cloudscope collect --provider aws --regions us-east-1,us-west-2

# Collect specific asset types
cloudscope collect --types compute,storage
```

#### Generate Reports
```bash
# Generate JSON report
cloudscope report generate --format json

# Generate LLM-optimized CSV
cloudscope report generate --format csv --llm-optimized

# Generate HTML report with charts
cloudscope report generate --format html --include-charts
```

#### Risk Analysis
```bash
# Run risk analysis
cloudscope risk analyze

# Generate risk report
cloudscope risk report --format pdf
```

## Architecture

CloudScope follows a hexagonal architecture pattern with clear separation between business logic and infrastructure concerns:

```
┌─────────────────┐
│ External Systems│
└────────┬────────┘
         │
┌────────▼────────┐
│  Plugin Layer   │
├─────────────────┤
│  Domain Layer   │
├─────────────────┤
│ Port Interfaces │
├─────────────────┤
│ Adapter Layer   │
├─────────────────┤
│ Infrastructure  │
└─────────────────┘
```

For detailed architecture information, see [Architecture Documentation](docs/ARCHITECTURE.md).

## Configuration

CloudScope uses a flexible configuration system supporting JSON files, environment variables, and command-line arguments. 

Example configuration:
```json
{
  "storage": {
    "type": "sqlite",
    "connection": {
      "path": "./data/cloudscope.db"
    }
  },
  "collectors": {
    "enabled": ["aws", "azure", "gcp"],
    "schedule": "0 * * * *"
  },
  "reporting": {
    "default_format": "json",
    "output_directory": "./reports"
  }
}
```

See [Configuration Guide](docs/CONFIGURATION_GUIDE.md) for detailed configuration options.

## Scripts and Utilities

CloudScope includes comprehensive shell scripts for various operations:

- **Reporting**: `scripts/reporting/generate-report.sh`
- **Risk Analysis**: `scripts/risk-analysis/risk-scoring.sh`
- **Troubleshooting**: `scripts/troubleshooting/diagnose-issues.sh`
- **Utilities**: `scripts/utilities/cloudscope-utils.sh`
- **Integrations**: `scripts/integrations/external-integrations.sh`

See [Scripts Documentation](docs/SCRIPTS_DOCUMENTATION.md) for detailed usage.

## Monitoring and Observability

CloudScope provides comprehensive monitoring through:

- **Structured Logging**: JSON-formatted logs with trace correlation
- **Metrics**: Prometheus-compatible metrics endpoint
- **Distributed Tracing**: OpenTelemetry integration
- **Health Checks**: Comprehensive health check endpoints

Example Prometheus query for asset count:
```promql
sum(cloudscope_assets_total) by (type, provider)
```

See [Monitoring Guide](docs/MONITORING_GUIDE.md) for dashboard setup and alerting.

## Plugin Development

Create custom plugins to extend CloudScope functionality:

```python
from cloudscope.plugin import Plugin

class MyCustomCollector(Plugin):
    name = "my-collector"
    version = "1.0.0"
    
    def collect(self):
        # Your collection logic here
        return assets
```

See [Plugin Development Guide](docs/PLUGIN_DEVELOPMENT.md) for detailed instructions.

## Security

CloudScope implements multiple security layers:

- **Authentication**: JWT-based authentication
- **Authorization**: Role-based access control (RBAC)
- **Encryption**: At-rest and in-transit encryption
- **Input Validation**: Comprehensive input validation and sanitization
- **Audit Logging**: Detailed audit trail of all operations

See [Security Guide](docs/SECURITY_GUIDE.md) for security best practices.

## Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details on:

- Code style and standards
- Development workflow
- Testing requirements
- Pull request process

## Documentation

- [Installation Guide](docs/INSTALLATION_GUIDE.md)
- [Configuration Guide](docs/CONFIGURATION_GUIDE.md)
- [Architecture Documentation](docs/ARCHITECTURE.md)
- [Scripts Documentation](docs/SCRIPTS_DOCUMENTATION.md)
- [Monitoring Guide](docs/MONITORING_GUIDE.md)
- [API Reference](docs/API_REFERENCE.md)
- [Troubleshooting Guide](docs/TROUBLESHOOTING.md)

## Roadmap

### Current Release (v1.4.0)
- ✅ Multi-cloud asset discovery
- ✅ Plugin system
- ✅ Multiple storage backends
- ✅ Comprehensive reporting
- ✅ Risk analysis
- ✅ External integrations

### Upcoming Features (v2.0.0)
- 🔄 Machine Learning anomaly detection
- 🔄 Multi-tenancy support
- 🔄 GraphQL API
- 🔄 Real-time asset updates
- 🔄 Advanced relationship detection

See [ROADMAP.md](ROADMAP.md) for detailed feature plans.

## Support

- **Documentation**: [https://docs.cloudscope.io](https://docs.cloudscope.io)
- **Issues**: [GitHub Issues](https://github.com/your-org/cloudscope/issues)
- **Discussions**: [GitHub Discussions](https://github.com/your-org/cloudscope/discussions)
- **Security**: security@cloudscope.io

## License

CloudScope is licensed under the MIT License. See [LICENSE](LICENSE) for details.

## Acknowledgments

- Built with Python and love ❤️
- Inspired by cloud-native principles
- Thanks to all [contributors](CONTRIBUTORS.md)

---

<p align="center">
  Made with ☁️ by the CloudScope Team
</p>