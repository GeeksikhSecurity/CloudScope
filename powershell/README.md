# CloudScope PowerShell Edition

<div align="center">

![CloudScope Logo](https://img.shields.io/badge/CloudScope-PowerShell-0078D4?style=for-the-badge&logo=powershell&logoColor=white)

**Compliance-as-Code for the Microsoft Ecosystem**

[![PowerShell](https://img.shields.io/badge/PowerShell-7.0%2B-blue.svg)](https://github.com/PowerShell/PowerShell)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Azure](https://img.shields.io/badge/Azure-Compatible-0078D4)](https://azure.microsoft.com)
[![Microsoft 365](https://img.shields.io/badge/Microsoft%20365-Ready-red)](https://www.microsoft.com/microsoft-365)

[Installation](#-installation) • [Quick Start](#-quick-start) • [Features](#-features) • [Documentation](#-documentation) • [Contributing](#-contributing)

</div>

## 🎯 Overview

CloudScope PowerShell Edition brings comprehensive compliance-as-code capabilities to the Microsoft ecosystem. Built specifically for PowerShell 7+ and deeply integrated with Microsoft Graph, Azure, and Microsoft 365, it provides automated compliance monitoring, assessment, and remediation for GDPR, PCI DSS, HIPAA, and SOC 2 frameworks.

## ✨ Key Features

### 🛡️ Compliance Frameworks
- **GDPR** - Full personal data protection with automated consent management
- **PCI DSS** - Payment card data security with PAN masking and tokenization
- **HIPAA** - Healthcare data protection with PHI encryption and access controls
- **SOC 2** - Trust service criteria implementation with continuous monitoring

### 🔧 Core Capabilities
- **Automated Data Classification** - Classify and protect sensitive data using Microsoft Information Protection
- **Real-time Monitoring** - Continuous compliance monitoring with Azure Monitor integration
- **Smart Remediation** - Automated fixes for common compliance violations
- **Rich Reporting** - Executive dashboards, detailed assessments, and Power BI integration
- **Microsoft Graph Integration** - Deep integration with Microsoft 365 compliance tools
- **FinOps Integration** - Cost optimization while maintaining compliance
- **Visual Analysis** - Interactive visualizations without third-party dependencies

## 🚀 Installation

### Prerequisites
- PowerShell 7.0 or later
- Microsoft 365 Global Administrator or Compliance Administrator role
- Azure subscription (optional, for advanced monitoring features)
- Windows 10/11, Windows Server 2016+, macOS, or Linux

### Quick Install (Recommended)

```powershell
# Clone the repository
git clone https://github.com/your-org/cloudscope.git
cd cloudscope/powershell

# Run the setup script
./Setup-CloudScope.ps1
```

### Manual Installation

```powershell
# Install required modules
Install-Module -Name Microsoft.Graph -Force
Install-Module -Name Az.Accounts -Force

# Import modules
Import-Module ./CloudScope/Core/CloudScope.Core.psd1
```

## 🎯 Quick Start

### Initialize CloudScope

```powershell
# Import the core module
Import-Module CloudScope.Core

# Initialize CloudScope
Initialize-CloudScope

# Connect to Microsoft services
Connect-CloudScopeServices
```

### Basic Compliance Check

```powershell
# Run a compliance assessment
$assessment = Invoke-ComplianceAssessment -Framework GDPR
Write-Host "Compliance Score: $($assessment.ComplianceScore)%"

# Check for violations
$violations = Get-ComplianceViolations -Recent
if ($violations.Count -gt 0) {
    Write-Warning "Found $($violations.Count) compliance violations"
}
```

### Data Classification

```powershell
# Classify sensitive data
Set-DataClassification -Path "C:\Data\customers.xlsx" -Classification Personal

# Search for unclassified data
$unclassified = Get-SensitiveDataLocations -DataType Personal -Scope All
Write-Host "Found $($unclassified.TotalLocations) locations with personal data"
```

### Visual Analysis

```powershell
# Generate interactive visualization
New-ComplianceVisualization -Data $assessment -Type MindMap -Path "./compliance-map.html"

# Create dashboard
New-ComplianceDashboard -Framework GDPR -Interactive
```

## 📦 Module Structure

CloudScope PowerShell consists of seven main modules:

### CloudScope.Core
Core functionality including authentication, configuration, and logging.

```powershell
Get-Command -Module CloudScope.Core
```

### CloudScope.Compliance
Compliance framework implementations, data classification, encryption, and access controls.

```powershell
Get-Command -Module CloudScope.Compliance
```

### CloudScope.Graph
Microsoft Graph integration for user management, data governance, and security operations.

```powershell
Get-Command -Module CloudScope.Graph
```

### CloudScope.Monitoring
Real-time monitoring with Azure Monitor, Log Analytics, and Application Insights.

```powershell
Get-Command -Module CloudScope.Monitoring
```

### CloudScope.Reports
Comprehensive reporting with HTML, PDF, Excel, and Power BI output formats.

```powershell
Get-Command -Module CloudScope.Reports
```

### CloudScope.FinOps
Cost optimization while maintaining compliance requirements.

```powershell
Get-Command -Module CloudScope.FinOps
```

### CloudScope.Visualization
Interactive visualizations for compliance data analysis.

```powershell
Get-Command -Module CloudScope.Visualization
```

## 📚 Documentation

### Guides
- [Installation Guide](INSTALL.md) - Detailed installation instructions
- [Quick Start Guide](QUICKSTART.md) - Get up and running quickly
- [Configuration Guide](docs/Configuration.md) - Configure CloudScope for your environment
- [API Reference](docs/API.md) - Complete function reference

### Examples
- [GDPR Compliance Check](Examples/Example-GDPRComplianceCheck.ps1)
- [Data Classification](Examples/Example-DataClassification.ps1)
- [Real-time Monitoring](Examples/Example-RealtimeMonitoring.ps1)
- [Cost Optimization](Examples/Example-CostOptimization.ps1)
- [Interactive Visualizations](Examples/Example-Visualizations.ps1)

## 🔧 Configuration

CloudScope uses a JSON configuration file for settings. Create `~/.cloudscope/config.json`:

```json
{
  "Version": "1.0.0",
  "Environment": "Production",
  "TenantId": "your-tenant-id",
  "SubscriptionId": "your-subscription-id",
  "LogLevel": "Information",
  "Monitoring": {
    "Enabled": true,
    "IntervalSeconds": 300
  },
  "Compliance": {
    "DefaultFramework": "GDPR",
    "EnableAutomaticRemediation": false
  },
  "FinOps": {
    "Enabled": true,
    "BudgetAlerts": true
  },
  "Visualization": {
    "DefaultFormat": "HTML",
    "EnableInteractive": true
  }
}
```

## 🧪 Testing

Run the Pester tests to verify your installation:

```powershell
# Run all tests
Invoke-Pester -Path ./CloudScope/*/Tests

# Run specific module tests
Invoke-Pester -Path ./CloudScope/Core/Tests

# Run with code coverage
Invoke-Pester -Path ./CloudScope/*/Tests -CodeCoverage ./CloudScope/*/*.psm1
```

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

### Development Setup

```powershell
# Clone repository
git clone https://github.com/your-org/cloudscope.git
cd cloudscope/powershell

# Install development dependencies
Install-Module -Name Pester, PSScriptAnalyzer -Force

# Run tests
Invoke-Pester -Path ./CloudScope/*/Tests

# Run linter
Invoke-ScriptAnalyzer -Path ./CloudScope -Recurse
```

## 📄 License

CloudScope PowerShell Edition is licensed under the MIT License. See [LICENSE](LICENSE) for details.

## 🆘 Support

- 📧 Email: support@cloudscope.io
- 🐛 Issues: [GitHub Issues](https://github.com/your-org/cloudscope/issues)
- 📖 Docs: [Documentation](https://docs.cloudscope.io)

---

<div align="center">

Made with ❤️ by the CloudScope Team

</div>