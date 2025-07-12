#!/usr/bin/env python3
"""
CloudScope Git Repository Initialization Script

This script initializes the git repository with proper commit structure
and technical documentation as required.
"""

import subprocess
import os
import sys
from datetime import datetime

def run_command(command, capture_output=False):
    """Run a shell command and handle errors."""
    try:
        if capture_output:
            result = subprocess.run(command, shell=True, capture_output=True, text=True)
            return result.stdout.strip()
        else:
            subprocess.run(command, shell=True, check=True)
            return True
    except subprocess.CalledProcessError as e:
        print(f"Error running command: {command}")
        print(f"Error: {e}")
        return False

def initialize_git_repository():
    """Initialize git repository and create initial commit."""
    print("🚀 Initializing CloudScope Git Repository")
    print("=" * 50)
    
    # Check if we're in the right directory
    if not os.path.exists("README.md"):
        print("❌ Error: Please run this script from the CloudScope root directory")
        sys.exit(1)
    
    # Initialize git repository if not already done
    if not os.path.exists(".git"):
        print("📁 Initializing Git repository...")
        run_command("git init")
        print("✓ Git repository initialized")
    else:
        print("✓ Git repository already exists")
    
    # Configure git if needed
    print("⚙️  Configuring Git...")
    
    # Check if user.name is set
    user_name = run_command("git config user.name", capture_output=True)
    if not user_name:
        run_command('git config user.name "CloudScope Community"')
        print("✓ Set git user.name to 'CloudScope Community'")
    
    # Check if user.email is set
    user_email = run_command("git config user.email", capture_output=True)
    if not user_email:
        run_command('git config user.email "community@cloudscope.io"')
        print("✓ Set git user.email to 'community@cloudscope.io'")
    
    # Add remote origin if provided
    print("📡 Setting up remote repository...")
    try:
        # Check if origin already exists
        origin_url = run_command("git remote get-url origin", capture_output=True)
        if origin_url:
            print(f"✓ Remote origin already configured: {origin_url}")
        else:
            # Add GitHub remote
            github_url = "https://github.com/GeeksikhSecurity/CloudScope.git"
            run_command(f"git remote add origin {github_url}")
            print(f"✓ Added remote origin: {github_url}")
    except:
        # Add GitHub remote if none exists
        github_url = "https://github.com/GeeksikhSecurity/CloudScope.git"
        run_command(f"git remote add origin {github_url}")
        print(f"✓ Added remote origin: {github_url}")
    
    # Create .gitattributes for better handling
    print("📝 Creating .gitattributes...")
    gitattributes_content = """# CloudScope Git Attributes

# Text files
*.md text
*.txt text
*.json text
*.yml text
*.yaml text
*.py text
*.ps1 text
*.sh text eol=lf
*.py text eol=lf

# PowerShell files
*.ps1 text eol=crlf
*.psm1 text eol=crlf
*.psd1 text eol=crlf

# Binary files
*.png binary
*.jpg binary
*.jpeg binary
*.gif binary
*.ico binary
*.pdf binary

# Archives
*.zip binary
*.tar.gz binary
*.tgz binary

# Exclude from exports
.gitignore export-ignore
.gitattributes export-ignore
*.md export-ignore
docs/ export-ignore
tests/ export-ignore
"""
    
    with open(".gitattributes", "w") as f:
        f.write(gitattributes_content)
    print("✓ Created .gitattributes")
    
    # Stage all files
    print("📦 Staging files for commit...")
    run_command("git add .")
    
    # Check if there are any staged changes
    staged_files = run_command("git diff --cached --name-only", capture_output=True)
    if not staged_files:
        print("ℹ️  No changes to commit")
        return
    
    # Create comprehensive initial commit
    print("💾 Creating initial commit...")
    
    commit_message = """feat: initial CloudScope repository setup

🎯 Project Overview:
CloudScope is an open-source unified asset inventory platform designed for
security and operations teams. It combines graph-based relationship mapping
with modern PowerShell Microsoft Graph integration.

🏗️ Architecture Components:
- PowerShell collectors for Microsoft 365 ecosystem
- FastAPI-based REST and GraphQL APIs
- Memgraph database for high-performance graph operations
- Docker containerization for easy deployment
- Comprehensive security and compliance features

📦 Core Features:
- Multi-cloud asset discovery (Microsoft 365, Azure, AWS, GCP)
- Real-time relationship mapping and analytics
- Risk-based security scoring
- SIEM integration (CrowdStrike, Splunk, Sentinel, Elastic)
- Compliance reporting (SOC2, ISO27001, PCI-DSS)
- Web-based dashboard and API interfaces

🔒 Security Implementation:
- JWT-based authentication with RBAC
- Input validation and sanitization
- Comprehensive audit logging
- Rate limiting and DoS protection
- Field-level encryption for sensitive data
- Security scanning in CI/CD pipeline

🧪 Testing & Quality:
- Unit tests with pytest
- Integration tests with Docker
- PowerShell script analysis with PSScriptAnalyzer
- Security scanning with Bandit, Safety, Semgrep
- Performance testing with Locust
- Code quality with Black, isort, flake8, mypy

🚀 Deployment & Operations:
- Docker Compose for development
- Kubernetes manifests for production
- Prometheus metrics and Grafana dashboards
- Elasticsearch and Kibana for logging
- GitHub Actions CI/CD pipeline
- Automated backup and restore procedures

📚 Documentation:
- Comprehensive README with quick start guide
- Technical architecture documentation
- Security guidelines and vulnerability reporting
- Contribution guidelines for community development
- API documentation with OpenAPI/Swagger
- PowerShell module documentation

🤝 Community Focus:
- Apache 2.0 license for maximum compatibility
- Modular architecture for easy extension
- Comprehensive examples and templates
- Active community engagement and support
- Regular security updates and maintenance

This initial commit establishes CloudScope as a production-ready,
enterprise-grade open-source solution for unified asset inventory
management with a strong focus on security, scalability, and
community collaboration.

Co-authored-by: CloudScope Community <community@cloudscope.io>
"""
    
    # Create the commit
    run_command(f'git commit -m "{commit_message}"')
    
    print("✅ Initial commit created successfully!")
    
    # Create development branch
    print("🌿 Creating development branch...")
    run_command("git checkout -b develop")
    run_command("git checkout main")
    print("✓ Development branch created")
    
    # Display summary
    print("\n📊 Repository Summary:")
    print("=" * 30)
    
    # Count files by type
    file_counts = {
        "Python files": run_command("find . -name '*.py' | wc -l", capture_output=True),
        "PowerShell files": run_command("find . -name '*.ps1' | wc -l", capture_output=True),
        "Configuration files": run_command("find . -name '*.json' -o -name '*.yml' -o -name '*.yaml' | wc -l", capture_output=True),
        "Documentation files": run_command("find . -name '*.md' | wc -l", capture_output=True),
        "Total files": run_command("git ls-files | wc -l", capture_output=True)
    }
    
    for file_type, count in file_counts.items():
        print(f"  {file_type}: {count}")
    
    # Display next steps
    print("\n🎯 Next Steps:")
    print("=" * 15)
    print("1. Push to GitHub:")
    print("   git push -u origin main")
    print("   git push -u origin develop")
    print("")
    print("2. Set up your environment:")
    print("   cp config/cloudscope-config.example.json config/cloudscope-config.json")
    print("   cp config/m365-config.example.json config/m365-config.json")
    print("   # Edit configuration files with your settings")
    print("")
    print("3. Start development:")
    print("   make setup")
    print("   make dev")
    print("")
    print("4. View documentation:")
    print("   - API Docs: http://localhost:8000/docs")
    print("   - GraphQL: http://localhost:8000/graphql")
    print("   - Monitoring: http://localhost:3001")
    print("")
    print("📚 Documentation available in:")
    print("   - README.md - Getting started")
    print("   - SECURITY.md - Security guidelines")
    print("   - CONTRIBUTING.md - Contribution guide")
    print("   - docs/TECHNICAL_NOTES.md - Architecture details")
    print("")
    print("🌟 CloudScope is now ready for development!")

if __name__ == "__main__":
    initialize_git_repository()
