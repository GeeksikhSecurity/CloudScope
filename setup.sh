#!/bin/bash

# CloudScope Installation and Setup Script
# This script initializes the CloudScope repository and sets up the development environment

set -e  # Exit on any error

echo "🚀 Setting up CloudScope - Open Source Unified Asset Inventory"
echo "================================================================"

# Check if we're in the right directory
if [ ! -f "README.md" ]; then
    echo "❌ Error: Please run this script from the CloudScope root directory"
    exit 1
fi

# Initialize git repository
echo "📁 Initializing Git repository..."
if [ ! -d ".git" ]; then
    git init
    echo "✓ Git repository initialized"
else
    echo "✓ Git repository already exists"
fi

# Create initial configuration files
echo "⚙️  Setting up configuration files..."
if [ ! -f "config/cloudscope-config.json" ]; then
    cp config/cloudscope-config.example.json config/cloudscope-config.json
    echo "✓ Created config/cloudscope-config.json from template"
    echo "📝 Please edit config/cloudscope-config.json with your settings"
fi

if [ ! -f "config/m365-config.json" ]; then
    cp config/m365-config.example.json config/m365-config.json
    echo "✓ Created config/m365-config.json from template"
    echo "📝 Please edit config/m365-config.json with your Microsoft 365 settings"
fi

# Create necessary directories
echo "📂 Creating necessary directories..."
mkdir -p logs exports output temp
mkdir -p collectors/python/aws collectors/python/gcp
mkdir -p core/models core/processors core/security core/middleware
mkdir -p tests/unit tests/integration tests/performance
mkdir -p web-ui/frontend web-ui/backend
mkdir -p deployment/kubernetes deployment/terraform
mkdir -p grafana/dashboards grafana/datasources
echo "✓ Directory structure created"

# Set up git hooks and initial commit
echo "🔧 Setting up git configuration..."

# Configure git hooks
if [ ! -f ".git/hooks/pre-commit" ]; then
    cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
# CloudScope pre-commit hook

echo "Running pre-commit checks..."

# Run Python linting
if command -v flake8 &> /dev/null; then
    echo "Running flake8..."
    flake8 . --count --select=E9,F63,F7,F82 --show-source --statistics
fi

# Run PowerShell script analysis
if command -v pwsh &> /dev/null; then
    echo "Running PowerShell Script Analyzer..."
    pwsh -Command "
        if (Get-Module -ListAvailable -Name PSScriptAnalyzer) {
            Invoke-ScriptAnalyzer -Path ./collectors/powershell/ -Recurse -Severity Warning
        }
    "
fi

echo "Pre-commit checks completed"
EOF
    chmod +x .git/hooks/pre-commit
    echo "✓ Git pre-commit hook installed"
fi

# Create initial git commit
echo "📝 Creating initial commit..."
git add .
git commit -m "feat: initial CloudScope repository setup

- Add comprehensive PowerShell Microsoft 365 collector
- Add FastAPI-based REST and GraphQL API
- Add Docker and docker-compose configuration
- Add comprehensive documentation and security guidelines
- Add CI/CD pipeline with GitHub Actions
- Add technical architecture documentation
- Set up modular collector framework
- Implement secure authentication and authorization
- Add comprehensive logging and monitoring setup

This establishes the foundation for CloudScope as an open-source
unified asset inventory platform for security and operations teams."

echo "✅ CloudScope setup completed successfully!"
echo ""
echo "🎯 Next Steps:"
echo "1. Edit configuration files in config/ directory"
echo "2. Set up your Microsoft 365 app registration"
echo "3. Configure your environment variables"
echo "4. Run: docker-compose up -d"
echo "5. Visit http://localhost:8000/docs for API documentation"
echo ""
echo "📚 Documentation:"
echo "- README.md - Getting started guide"
echo "- SECURITY.md - Security guidelines and reporting"
echo "- CONTRIBUTING.md - Contribution guidelines"
echo "- docs/TECHNICAL_NOTES.md - Technical architecture"
echo ""
echo "🤝 Community:"
echo "- GitHub: https://github.com/GeeksikhSecurity/CloudScope"
echo "- Issues: Report bugs and request features"
echo "- Discussions: Ask questions and share ideas"
echo ""
echo "Happy asset inventorying! 🌟"
