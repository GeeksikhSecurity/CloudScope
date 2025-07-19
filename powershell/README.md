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
- **PowerShell DSC** - Desired State Configuration for compliance settings
- **Azure Automation** - Scalable cloud-based compliance operations

## 🚀 Installation

### Prerequisites
- PowerShell 7.0 or later
- Microsoft 365 Global Administrator or Compliance Administrator role
- Azure subscription (for monitoring features)
- Windows 10/11, Windows Server 2016+, macOS, or Linux

### Quick Install (Recommended)

```powershell
# Install all CloudScope modules from PowerShell Gallery
Install-Module -Name CloudScope.Compliance, CloudScope.Graph, CloudScope.Monitoring, CloudScope.Reports -Force

# Import modules
Import-Module CloudScope.Compliance, CloudScope.Graph, CloudScope.Monitoring, CloudScope.Reports
```

### Manual Installation

```powershell
# Clone repository
git clone https://github.com/your-org/cloudscope.git
cd cloudscope/powershell

# Run deployment script
.\Scripts\Deployment\Deploy-CloudScope.ps1 -DeploymentType Local
```

### Azure Automation Deployment

```powershell
# Deploy to Azure Automation
.\Scripts\Deployment\Deploy-CloudScope.ps1 -DeploymentType AzureAutomation `
    -ResourceGroup "rg-compliance" `
    -AutomationAccount "CloudScope-Automation"
```

For detailed installation instructions, see the [Installation Guide](INSTALL.md).

## 🎯 Quick Start

### Interactive Mode

Simply run the main CloudScope script for an interactive menu:

```powershell
.\CloudScope.ps1
```

### Basic Compliance Check

```powershell
# Initialize CloudScope
Initialize-CloudScopeCompliance -Framework GDPR
Connect-CloudScopeGraph

# Run compliance assessment
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

### Real-time Monitoring

```powershell
# Set up monitoring
Initialize-ComplianceMonitoring -WorkspaceName "CloudScope-Monitoring" `
    -ResourceGroup "rg-compliance" -CreateIfNotExists

# Configure alerts
Set-AlertingRules -RuleName "ComplianceScore" -Threshold 80 -Operator "LessThan"

# Start monitoring
Start-RealtimeMonitoring -IntervalSeconds 300
```

For more examples, see the [Quick Start Guide](QUICKSTART.md).

## 📦 Module Structure

CloudScope PowerShell consists of four main modules:

### CloudScope.Compliance
Core compliance functionality including framework implementations, data classification, encryption, and access controls.

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

## 📚 Documentation

### Guides
- [Installation Guide](INSTALL.md) - Detailed installation instructions
- [Quick Start Guide](QUICKSTART.md) - Get up and running quickly
- [Configuration Guide](docs/Configuration.md) - Configure CloudScope for your environment
- [API Reference](docs/API.md) - Complete function reference

### Examples
- [GDPR Compliance Check](Scripts/Examples/Example-GDPRComplianceCheck.ps1)
- [Data Classification](Scripts/Examples/Example-DataClassification.ps1)
- [Real-time Monitoring](Scripts/Examples/Example-RealtimeMonitoring.ps1)

### Automation
- [Azure Automation Runbook](Scripts/Automation/Monitor-ComplianceRunbook.ps1)
- [Automated Remediation](Scripts/Automation/Invoke-ComplianceRemediation.ps1)

### DSC Configurations
- [GDPR Configuration](Scripts/Configuration/GDPRCompliance.ps1)
- [PCI DSS Configuration](Scripts/Configuration/PCIDSSCompliance.ps1)

## 🔧 Configuration

CloudScope uses a JSON configuration file for settings. Create `~/.cloudscope/config.json`:

```json
{
  "cloudScope": {
    "defaultFramework": "GDPR",
    "environment": "Production"
  },
  "azure": {
    "tenantId": "your-tenant-id",
    "subscriptionId": "your-subscription-id"
  },
  "monitoring": {
    "enabled": true,
    "workspaceName": "CloudScope-LogAnalytics"
  }
}
```

See [config.template.json](config.template.json) for a complete configuration example.

## 🧪 Testing

Run the Pester tests to verify your installation:

```powershell
# Run all tests
Invoke-Pester -Path .\Tests

# Run specific module tests
Invoke-Pester -Path .\Tests\CloudScope.Compliance.Tests.ps1

# Run with code coverage
Invoke-Pester -Path .\Tests -CodeCoverage .\Modules\**\*.psm1
```

## 🚀 CI/CD

CloudScope includes CI/CD pipelines for both Azure DevOps and GitHub Actions:

- [Azure DevOps Pipeline](Pipelines/azure-pipelines.yml)
- [GitHub Actions Workflow](Pipelines/github-actions.yml)

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

### Development Setup

```powershell
# Clone repository
git clone https://github.com/your-org/cloudscope.git
cd cloudscope/powershell

# Install development dependencies
Install-Module -Name Pester, PSScriptAnalyzer, platyPS -Force

# Run tests
Invoke-Pester

# Run linter
Invoke-ScriptAnalyzer -Path .\Modules -Recurse
```

## 📄 License

CloudScope PowerShell Edition is licensed under the MIT License. See [LICENSE](LICENSE) for details.

## 🆘 Support

- 📧 Email: support@cloudscope.io
- 💬 Slack: [CloudScope Community](https://cloudscope.slack.com)
- 🐛 Issues: [GitHub Issues](https://github.com/your-org/cloudscope/issues)
- 📖 Docs: [Documentation](https://docs.cloudscope.io)

## 🌟 Acknowledgments

CloudScope PowerShell Edition is built on top of these excellent technologies:

- [PowerShell 7](https://github.com/PowerShell/PowerShell)
- [Microsoft Graph PowerShell SDK](https://github.com/microsoftgraph/msgraph-sdk-powershell)
- [Azure PowerShell](https://github.com/Azure/azure-powershell)
- [Pester](https://github.com/pester/Pester)

## 🚦 Status

![Build Status](https://img.shields.io/github/workflow/status/your-org/cloudscope/CI)
![Tests](https://img.shields.io/badge/tests-passing-brightgreen)
![Coverage](https://img.shields.io/badge/coverage-85%25-green)
![PowerShell Gallery](https://img.shields.io/powershellgallery/v/CloudScope.Compliance)

---

<div align="center">

**[Website](https://cloudscope.io)** • **[Documentation](https://docs.cloudscope.io)** • **[Blog](https://blog.cloudscope.io)**

Made with ❤️ by the CloudScope Team

</div>
