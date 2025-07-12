# Contributing to CloudScope

Welcome to the CloudScope community! We're excited that you're interested in contributing to this open-source unified asset inventory platform. This guide will help you get started with contributing code, documentation, or other improvements.

## 🌟 Ways to Contribute

- 🐛 **Bug Reports**: Help us identify and fix issues
- 💡 **Feature Requests**: Suggest new functionality
- 📝 **Documentation**: Improve guides, examples, and references
- 🔧 **Code Contributions**: Fix bugs, add features, optimize performance
- 🧪 **Testing**: Write tests, test new features, report compatibility issues
- 🎨 **UI/UX**: Improve the user interface and experience
- 📦 **Integrations**: Add new collectors, SIEM connectors, or data sources

## 🚀 Getting Started

### Prerequisites

- **Git**: Version control system
- **Docker & Docker Compose**: For development environment
- **PowerShell 7+**: For PowerShell collector development
- **Python 3.9+**: For core engine development
- **Node.js 18+**: For web UI development

### Development Environment Setup

1. **Fork and Clone**
```bash
# Fork the repository on GitHub first
git clone https://github.com/YOUR_USERNAME/CloudScope.git
cd CloudScope
git remote add upstream https://github.com/GeeksikhSecurity/CloudScope.git
```

2. **Environment Setup**
```bash
# Copy example configuration
cp config/cloudscope-config.example.json config/cloudscope-config.json

# Start development environment
docker-compose -f docker-compose.dev.yml up -d

# Install development dependencies
pip install -r requirements-dev.txt
npm install
```

3. **Verify Setup**
```bash
# Run tests to ensure everything is working
./scripts/run-tests.sh

# Start development server
./scripts/dev-server.sh
```

## 📋 Development Guidelines

### Code Standards

#### **Python Code Standards**
```python
# Use type hints
def process_assets(assets: List[Asset]) -> Dict[str, Any]:
    """Process a list of assets and return summary statistics.
    
    Args:
        assets: List of Asset objects to process
        
    Returns:
        Dictionary containing processing statistics
        
    Raises:
        ValueError: If assets list is empty
        ProcessingError: If asset processing fails
    """
    pass

# Follow PEP 8 style guide
# Use descriptive variable names
# Include comprehensive docstrings
# Handle exceptions appropriately
```

#### **PowerShell Code Standards**
```powershell
<#
.SYNOPSIS
Comprehensive description of function purpose

.DESCRIPTION
Detailed description of what the function does, including any important behavior

.PARAMETER ParameterName
Description of what this parameter does

.EXAMPLE
Example of how to use this function

.NOTES
Any additional notes or requirements
#>
function Get-AssetData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$AssetId,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("JSON", "CSV", "XML")]
        [string]$OutputFormat = "JSON"
    )
    
    # Use proper error handling
    try {
        # Implementation here
    }
    catch {
        Write-Error "Failed to retrieve asset data: $($_.Exception.Message)"
        throw
    }
}
```

#### **JavaScript/TypeScript Standards**
```typescript
// Use TypeScript for type safety
interface Asset {
  id: string;
  name: string;
  assetType: AssetType;
  metadata: Record<string, unknown>;
}

// Use descriptive function names
async function fetchAssetRelationships(assetId: string): Promise<Asset[]> {
  try {
    const response = await fetch(`/api/v1/assets/${assetId}/relationships`);
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }
    return await response.json();
  } catch (error) {
    console.error('Failed to fetch asset relationships:', error);
    throw error;
  }
}
```

### Security Guidelines

#### **Input Validation**
```python
# Always validate inputs
import re
from typing import Optional

def validate_asset_id(asset_id: str) -> bool:
    """Validate asset ID format (UUID)."""
    pattern = r'^[a-f0-9\-]{36}$'
    return bool(re.match(pattern, asset_id))

def sanitize_string_input(input_str: str, max_length: int = 255) -> str:
    """Sanitize string input to prevent injection attacks."""
    if not isinstance(input_str, str):
        raise ValueError("Input must be a string")
    
    # Remove potentially dangerous characters
    sanitized = re.sub(r'[<>"\';\\]', '', input_str)
    
    # Limit length
    return sanitized[:max_length]
```

#### **Secure API Development**
```python
from fastapi import HTTPException, Depends
from fastapi.security import HTTPBearer

security = HTTPBearer()

async def verify_token(token: str = Depends(security)) -> dict:
    """Verify JWT token and return user info."""
    try:
        # Token verification logic
        payload = jwt.decode(token.credentials, SECRET_KEY, algorithms=["HS256"])
        return payload
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Invalid token")

@app.get("/api/v1/assets")
async def get_assets(user: dict = Depends(verify_token)):
    """Get assets with authentication required."""
    # Implementation here
    pass
```

#### **Secret Management**
```python
import os
from typing import Optional

def get_secret(secret_name: str) -> Optional[str]:
    """Retrieve secret from environment variables or key vault."""
    # First try environment variable
    secret = os.getenv(secret_name)
    
    if not secret:
        # Try key vault (implementation specific)
        secret = retrieve_from_key_vault(secret_name)
    
    if not secret:
        raise ValueError(f"Secret '{secret_name}' not found")
    
    return secret

# Never log secrets
def log_request(request_data: dict) -> None:
    """Log request data with secrets redacted."""
    safe_data = {k: v if k not in SENSITIVE_FIELDS else "***REDACTED***" 
                 for k, v in request_data.items()}
    logger.info(f"Request: {safe_data}")
```

### Testing Standards

#### **Unit Tests**
```python
import pytest
from unittest.mock import Mock, patch
from cloudscope.processors.asset_processor import AssetProcessor

class TestAssetProcessor:
    """Test cases for AssetProcessor class."""
    
    @pytest.fixture
    def mock_db(self):
        """Mock database connection."""
        return Mock()
    
    @pytest.fixture
    def processor(self, mock_db):
        """Create AssetProcessor instance with mocked dependencies."""
        return AssetProcessor(mock_db)
    
    def test_process_valid_assets(self, processor):
        """Test processing valid asset data."""
        # Arrange
        assets_data = {
            "users": [{"id": "user1", "name": "Test User"}]
        }
        
        # Act
        result = processor.process_collection_batch(assets_data)
        
        # Assert
        assert result is True
        processor.db.create_asset_nodes.assert_called_once()
    
    def test_process_invalid_assets_raises_error(self, processor):
        """Test processing invalid asset data raises appropriate error."""
        # Arrange
        invalid_data = {"invalid": "data"}
        
        # Act & Assert
        with pytest.raises(ValueError, match="Invalid asset data format"):
            processor.process_collection_batch(invalid_data)
```

#### **Integration Tests**
```python
import pytest
import requests
from testcontainers import compose

class TestAPIIntegration:
    """Integration tests for CloudScope API."""
    
    @pytest.fixture(scope="class")
    def docker_services(self):
        """Start CloudScope services for testing."""
        with compose.DockerCompose(".", compose_file_name="docker-compose.test.yml") as services:
            services.wait_for("http://localhost:8000/health")
            yield services
    
    def test_create_and_retrieve_asset(self, docker_services):
        """Test complete asset creation and retrieval workflow."""
        base_url = "http://localhost:8000"
        
        # Create asset
        asset_data = {
            "name": "Test Asset",
            "asset_type": "device",
            "metadata": {"test": True}
        }
        
        response = requests.post(f"{base_url}/api/v1/assets", json=asset_data)
        assert response.status_code == 201
        
        asset_id = response.json()["id"]
        
        # Retrieve asset
        response = requests.get(f"{base_url}/api/v1/assets/{asset_id}")
        assert response.status_code == 200
        assert response.json()["name"] == "Test Asset"
```

#### **PowerShell Tests**
```powershell
# Using Pester for PowerShell testing
Describe "Get-M365Assets" {
    BeforeAll {
        # Setup test environment
        Mock Connect-MgGraph { return $true }
        Mock Get-MgUser { return @(@{Id="user1"; DisplayName="Test User"}) }
    }
    
    Context "When collecting user assets" {
        It "Should return user data in correct format" {
            # Act
            $result = Get-M365Assets -AssetType "Users"
            
            # Assert
            $result.users | Should -HaveCount 1
            $result.users[0].id | Should -Be "user1"
            $result.users[0].display_name | Should -Be "Test User"
        }
        
        It "Should handle authentication failures gracefully" {
            # Arrange
            Mock Connect-MgGraph { throw "Authentication failed" }
            
            # Act & Assert
            { Get-M365Assets } | Should -Throw "Authentication failed"
        }
    }
}
```

## 📝 Documentation Standards

### Code Documentation
- **Function/Method Documentation**: Include purpose, parameters, return values, and examples
- **Class Documentation**: Describe purpose, key methods, and usage patterns
- **Module Documentation**: Explain module purpose and main components

### User Documentation
- **Step-by-step Guides**: Clear instructions with examples
- **Configuration References**: Complete parameter descriptions
- **Troubleshooting**: Common issues and solutions
- **API Documentation**: Complete endpoint documentation with examples

### Example Documentation
```markdown
## Configuring Microsoft 365 Collector

The Microsoft 365 collector gathers asset data from your Microsoft 365 tenant.

### Prerequisites
- Microsoft 365 tenant with admin access
- App registration with appropriate permissions
- Certificate or client secret for authentication

### Configuration

1. **Create App Registration**
   ```bash
   # Using Azure CLI
   az ad app create --display-name "CloudScope-Collector" \
                    --required-resource-accesses manifest.json
   ```

2. **Configure Permissions**
   The following permissions are required:
   - `User.Read.All` - Read user profiles
   - `Group.Read.All` - Read group information
   - `Application.Read.All` - Read application data

3. **Update Configuration**
   ```json
   {
     "microsoft_365": {
       "tenant_id": "your-tenant-id",
       "client_id": "your-client-id",
       "certificate_thumbprint": "your-cert-thumbprint"
     }
   }
   ```

### Usage
```powershell
./collectors/powershell/microsoft-365/Get-M365Assets.ps1 -ConfigPath "config.json"
```
```

## 🔀 Pull Request Process

### Before Submitting

1. **Create Feature Branch**
```bash
git checkout -b feature/your-feature-name
```

2. **Make Changes**
- Follow coding standards
- Add tests for new functionality
- Update documentation
- Ensure all tests pass

3. **Commit Changes**
```bash
# Use conventional commit format
git commit -m "feat: add Microsoft Defender collector integration

- Add PowerShell collector for Defender endpoints
- Include device security score calculation
- Add integration tests for API endpoints
- Update documentation with configuration examples

Closes #123"
```

### Pull Request Template

When creating a pull request, use this template:

```markdown
## Description
Brief description of changes made

## Type of Change
- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update

## Testing
- [ ] Unit tests added/updated
- [ ] Integration tests added/updated
- [ ] Manual testing completed
- [ ] All tests pass

## Security Considerations
- [ ] Input validation implemented
- [ ] Authentication/authorization checked
- [ ] Secrets properly managed
- [ ] Security review completed

## Documentation
- [ ] Code documentation updated
- [ ] User documentation updated
- [ ] API documentation updated
- [ ] Configuration examples added

## Checklist
- [ ] Code follows project style guidelines
- [ ] Self-review of code completed
- [ ] Tests added for new functionality
- [ ] Documentation updated
- [ ] No breaking changes (or clearly documented)
```

### Review Process

1. **Automated Checks**: All CI/CD checks must pass
2. **Code Review**: At least one maintainer review required
3. **Security Review**: Required for security-related changes
4. **Documentation Review**: Ensure documentation is complete and accurate

## 🐛 Bug Reports

When reporting bugs, please include:

### Bug Report Template
```markdown
**Describe the Bug**
A clear and concise description of what the bug is.

**To Reproduce**
Steps to reproduce the behavior:
1. Go to '...'
2. Click on '....'
3. Scroll down to '....'
4. See error

**Expected Behavior**
A clear and concise description of what you expected to happen.

**Screenshots**
If applicable, add screenshots to help explain your problem.

**Environment:**
- OS: [e.g., Windows 10, Ubuntu 20.04]
- CloudScope Version: [e.g., 1.0.0]
- PowerShell Version: [e.g., 7.2.1]
- Python Version: [e.g., 3.9.7]
- Docker Version: [e.g., 20.10.12]

**Configuration:**
```json
{
  "relevant": "configuration options"
}
```

**Logs:**
```
Relevant log entries
```

**Additional Context**
Add any other context about the problem here.
```

## 💡 Feature Requests

### Feature Request Template
```markdown
**Is your feature request related to a problem? Please describe.**
A clear and concise description of what the problem is.

**Describe the solution you'd like**
A clear and concise description of what you want to happen.

**Describe alternatives you've considered**
A clear and concise description of any alternative solutions or features you've considered.

**Use Case**
Describe the specific use case this feature would enable.

**Implementation Ideas**
If you have ideas on how this could be implemented, please share them.

**Additional Context**
Add any other context or screenshots about the feature request here.
```

## 🏷️ Labeling System

We use labels to categorize issues and pull requests:

- **Type Labels**: `bug`, `feature`, `documentation`, `security`
- **Priority Labels**: `critical`, `high`, `medium`, `low`
- **Component Labels**: `collector`, `api`, `ui`, `database`
- **Status Labels**: `needs-review`, `in-progress`, `blocked`

## 🎯 Contributor Recognition

We recognize contributors in multiple ways:

- **Contributors File**: Listed in CONTRIBUTORS.md
- **Release Notes**: Mentioned in release announcements
- **Social Media**: Featured on project social media
- **Swag**: CloudScope branded merchandise for significant contributions

## 📞 Getting Help

- **Documentation**: Check our comprehensive docs first
- **Discussions**: Use GitHub Discussions for questions
- **Discord**: Join our community Discord server
- **Issues**: Create an issue for bug reports or feature requests

## 📜 Code of Conduct

Please read and follow our [Code of Conduct](CODE_OF_CONDUCT.md). We're committed to providing a welcoming and inclusive environment for all contributors.

---

**Thank you for contributing to CloudScope! Your efforts help make asset inventory management better for everyone in the security and operations community.**
