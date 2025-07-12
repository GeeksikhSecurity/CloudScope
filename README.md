# CloudScope: Open Source Unified Asset Inventory 

<div align="center">

![CloudScope Logo](docs/assets/logo.png)

**A community-driven, open-source centralized asset inventory platform for security and operations teams**

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![Security Rating](https://img.shields.io/badge/Security-A+-green.svg)](SECURITY.md)
[![Contributions Welcome](https://img.shields.io/badge/Contributions-Welcome-brightgreen.svg)](CONTRIBUTING.md)
[![Docker](https://img.shields.io/badge/Docker-Ready-blue.svg)](docker-compose.yml)

[Features](#-features) • [Quick Start](#-quick-start) • [Documentation](#-documentation) • [Contributing](#-contributing) • [Community](#-community)

</div>

## 🎯 **Project Vision**

CloudScope combines the graph-based relationship mapping of Cartography with modern PowerShell Microsoft Graph integration to create a comprehensive, SIEM-independent asset inventory solution. Built for the community, by the community.

### **Why CloudScope?**

- 🚫 **No Vendor Lock-in**: Open source alternative to expensive commercial tools
- 🔗 **Relationship Mapping**: Understand asset dependencies and attack paths
- 🔌 **SIEM Agnostic**: Export to any SIEM (CrowdStrike, Splunk, Sentinel, Elastic)
- 🌐 **Multi-Cloud**: Unified view across AWS, Azure, GCP, and on-premises
- ⚡ **High Performance**: Built on Memgraph for lightning-fast graph queries
- 🛡️ **Security First**: Built-in risk scoring and compliance reporting

## ✨ **Features**

### **Asset Discovery & Collection**
- **Microsoft 365**: Users, Groups, Applications, Devices, SharePoint, Teams
- **Azure**: VMs, Storage, Databases, Network Resources, Security Resources
- **AWS**: EC2, S3, RDS, VPC, IAM (via Python collectors)
- **Google Cloud**: Compute, Storage, IAM (via Python collectors)
- **On-Premises**: Active Directory, VMware, Network devices

### **Advanced Analytics**
- **Relationship Mapping**: Automated discovery of asset relationships
- **Risk Scoring**: Built-in security risk assessment
- **Change Detection**: Monitor configuration drift and unauthorized changes
- **Compliance Reporting**: Pre-built reports for SOC2, ISO27001, PCI-DSS

### **Integration & Export**
- **SIEM Connectors**: CrowdStrike, Splunk, Microsoft Sentinel, Elastic
- **APIs**: RESTful and GraphQL interfaces
- **Dashboards**: Grafana, PowerBI, Tableau integration
- **Automation**: Webhook triggers for security events

## 🚀 **Quick Start**

### **Prerequisites**
- Docker & Docker Compose
- PowerShell 7+ (for Microsoft collectors)
- Python 3.9+ (for core engine)

### **1. Clone & Deploy**
```bash
git clone https://github.com/GeeksikhSecurity/CloudScope.git
cd CloudScope
docker-compose up -d
```

### **2. Configure**
```bash
cp config/cloudscope-config.example.json config/cloudscope-config.json
# Edit configuration with your environment details
```

### **3. Run First Collection**
```powershell
# Microsoft 365 Collection
./collectors/powershell/microsoft-365/Get-M365Assets.ps1 -OutputFormat Database
```

### **4. Access Dashboards**
- **Main Dashboard**: http://localhost:3000
- **GraphQL Explorer**: http://localhost:8000/graphql
- **API Documentation**: http://localhost:8000/docs

## 🏗️ **Architecture**

```
┌─────────────────────────────────────────────────────────────────┐
│                        CloudScope Platform                      │
├─────────────────────────────────────────────────────────────────┤
│  Data Collection Layer                                          │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌──────────────┐ │
│  │ PowerShell  │ │   Python    │ │    REST     │ │   Custom     │ │
│  │ Collectors  │ │ Collectors  │ │  Connectors │ │ Integrations │ │
│  └─────────────┘ └─────────────┘ └─────────────┘ └──────────────┘ │
├─────────────────────────────────────────────────────────────────┤
│  Data Processing & Storage Layer                                │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐                │
│  │  Memgraph   │ │  PostgreSQL │ │ Elasticsearch│                │
│  │ (Graph DB)  │ │ (Metadata)  │ │ (Search/Logs)│                │
│  └─────────────┘ └─────────────┘ └─────────────┘                │
├─────────────────────────────────────────────────────────────────┤
│  API & Export Layer                                             │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐                │
│  │ GraphQL API │ │  REST API   │ │  SIEM/CSV   │                │
│  │             │ │             │ │   Exports   │                │
│  └─────────────┘ └─────────────┘ └─────────────┘                │
├─────────────────────────────────────────────────────────────────┤
│  Visualization & Reporting Layer                                │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐                │
│  │   Web UI    │ │  Grafana    │ │ PowerBI/    │                │
│  │  Dashboard  │ │ Dashboards  │ │ Tableau     │                │
│  └─────────────┘ └─────────────┘ └─────────────┘                │
└─────────────────────────────────────────────────────────────────┘
```

## 📚 **Documentation**

- [Installation Guide](docs/installation/README.md)
- [Configuration Reference](docs/configuration/README.md)
- [API Documentation](docs/api-reference/README.md)
- [Collector Development](docs/development/collectors.md)
- [Security Guidelines](docs/security/README.md)
- [Troubleshooting](docs/troubleshooting/README.md)

## 🛡️ **Security**

CloudScope is built with security as a first-class citizen:

- **Secure by Default**: All components use secure configurations
- **Least Privilege**: Minimal permissions required for data collection
- **Encryption**: Data encrypted in transit and at rest
- **Audit Logging**: Comprehensive audit trails for all operations
- **Regular Security Scans**: Automated vulnerability assessments

See our [Security Policy](SECURITY.md) for vulnerability reporting.

## 🤝 **Contributing**

We welcome contributions from the community! Whether you're fixing bugs, adding features, or improving documentation, your help makes CloudScope better for everyone.

- [Contributing Guidelines](CONTRIBUTING.md)
- [Development Setup](docs/development/setup.md)
- [Code of Conduct](CODE_OF_CONDUCT.md)
- [Issue Templates](.github/ISSUE_TEMPLATE/)

## 🌟 **Community**

- **Discussions**: [GitHub Discussions](https://github.com/GeeksikhSecurity/CloudScope/discussions)
- **Issues**: [Bug Reports & Feature Requests](https://github.com/GeeksikhSecurity/CloudScope/issues)
- **Discord**: [CloudScope Community](https://discord.gg/cloudscope)
- **Twitter**: [@CloudScopeOSS](https://twitter.com/CloudScopeOSS)

## 📈 **Roadmap**

### **Phase 1: Foundation (Q1 2025)**
- [x] Core asset collection framework
- [x] Memgraph database integration
- [x] PowerShell Microsoft Graph collectors
- [ ] Basic web interface
- [ ] Docker deployment

### **Phase 2: Enhancement (Q2 2025)**
- [ ] Python collectors for AWS/GCP
- [ ] Advanced relationship detection
- [ ] SIEM export modules
- [ ] Grafana dashboards
- [ ] Performance optimization

### **Phase 3: Advanced Features (Q3-Q4 2025)**
- [ ] Machine learning for anomaly detection
- [ ] Automated compliance checking
- [ ] Advanced security analytics
- [ ] Mobile application
- [ ] Enterprise features

## 📄 **License**

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

## 🙏 **Acknowledgments**

- Inspired by [Cartography](https://github.com/cartography-cncf/cartography) from Lyft
- Built on [Memgraph](https://memgraph.com/) for high-performance graph processing
- Powered by [Microsoft Graph](https://graph.microsoft.com/) for Microsoft 365 integration
- Community-driven development model

---

<div align="center">

**⭐ Star this repository if you find it useful! ⭐**

*Built with ❤️ by the CloudScope Community*

</div>
