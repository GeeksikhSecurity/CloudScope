#!/bin/bash
# CloudScope Testing Script
# Run various test scenarios for CloudScope

set -euo pipefail

# Configuration
TEST_DATA_DIR="${TEST_DATA_DIR:-./tests/data}"
TEST_CONFIG="${TEST_CONFIG:-./tests/config/test-config.json}"
COVERAGE_DIR="${COVERAGE_DIR:-./htmlcov}"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_test() { echo -e "${PURPLE}[TEST]${NC} $1"; }

# Check virtual environment
check_venv() {
    if [[ -z "${VIRTUAL_ENV:-}" ]]; then
        log_error "Virtual environment not activated"
        log_info "Please run: source venv/bin/activate"
        exit 1
    fi
}

# Create test configuration
create_test_config() {
    log_info "Creating test configuration..."
    
    mkdir -p "$(dirname "$TEST_CONFIG")"
    
    cat > "$TEST_CONFIG" << 'EOF'
{
    "environment": "test",
    "database": {
        "memgraph": {
            "host": "localhost",
            "port": 7688,
            "database": "cloudscope_test"
        },
        "postgres": {
            "host": "localhost",
            "port": 5433,
            "database": "cloudscope_test",
            "user": "cloudscope_test",
            "password": "test_password"
        }
    },
    "collectors": {
        "mock_aws": {
            "enabled": true,
            "use_mock_data": true
        },
        "mock_azure": {
            "enabled": true,
            "use_mock_data": true
        }
    },
    "logging": {
        "level": "DEBUG",
        "file": "./tests/logs/test.log"
    }
}
EOF
    
    log_success "Test configuration created"
}

# Setup test database
setup_test_db() {
    log_info "Setting up test database..."
    
    # Start test Memgraph instance
    docker run -d \
        --name cloudscope-test-memgraph \
        -p 7688:7687 \
        memgraph/memgraph-platform:latest \
        2>/dev/null || log_warning "Test Memgraph already running"
    
    # Wait for database to be ready
    sleep 5
    
    # Initialize test schema
    docker exec cloudscope-test-memgraph mgconsole --execute "CREATE INDEX ON :Asset(id);" || true
    
    log_success "Test database ready"
}

# Teardown test database
teardown_test_db() {
    log_info "Tearing down test database..."
    
    docker stop cloudscope-test-memgraph 2>/dev/null || true
    docker rm cloudscope-test-memgraph 2>/dev/null || true
    
    log_success "Test database removed"
}

# Run unit tests
run_unit_tests() {
    log_test "Running unit tests..."
    
    python -m pytest tests/unit/ -v \
        --cov=cloudscope \
        --cov-report=html \
        --cov-report=term \
        --cov-report=xml \
        -x
    
    log_success "Unit tests completed"
}

# Run integration tests
run_integration_tests() {
    log_test "Running integration tests..."
    
    # Setup test database
    setup_test_db
    
    python -m pytest tests/integration/ -v \
        --cov=cloudscope \
        --cov-append \
        --cov-report=html \
        --cov-report=term \
        -x
    
    # Teardown test database
    teardown_test_db
    
    log_success "Integration tests completed"
}

# Run end-to-end tests
run_e2e_tests() {
    log_test "Running end-to-end tests..."
    
    # Start all services
    docker-compose -f docker-compose.test.yml up -d
    
    # Wait for services
    log_info "Waiting for services to start..."
    sleep 10
    
    # Run E2E tests
    python -m pytest tests/e2e/ -v \
        --cov=cloudscope \
        --cov-append \
        --cov-report=html \
        --cov-report=term
    
    # Stop services
    docker-compose -f docker-compose.test.yml down
    
    log_success "E2E tests completed"
}

# Run performance tests
run_performance_tests() {
    log_test "Running performance tests..."
    
    python -m pytest tests/performance/ -v \
        --benchmark-only \
        --benchmark-autosave \
        --benchmark-save-data
    
    log_success "Performance tests completed"
}

# Run security tests
run_security_tests() {
    log_test "Running security tests..."
    
    # Run bandit for security issues
    log_info "Running bandit security scan..."
    bandit -r cloudscope/ -f json -o tests/reports/bandit.json || true
    
    # Run safety check for dependencies
    log_info "Running safety check on dependencies..."
    safety check --json --output tests/reports/safety.json || true
    
    # Run security-specific tests
    python -m pytest tests/security/ -v
    
    log_success "Security tests completed"
}

# Run compliance tests
run_compliance_tests() {
    log_test "Running compliance tests..."
    
    python -m pytest tests/compliance/ -v \
        -k "compliance" \
        --junit-xml=tests/reports/compliance.xml
    
    log_success "Compliance tests completed"
}

# Run collector tests
run_collector_tests() {
    local collector=${1:-all}
    
    log_test "Running collector tests: $collector"
    
    if [[ "$collector" == "all" ]]; then
        python -m pytest tests/collectors/ -v
    else
        python -m pytest tests/collectors/test_${collector}_collector.py -v
    fi
    
    log_success "Collector tests completed"
}

# Run mutation tests
run_mutation_tests() {
    log_test "Running mutation tests..."
    
    # Install mutmut if not installed
    pip install mutmut
    
    # Run mutation testing
    mutmut run \
        --paths-to-mutate cloudscope/ \
        --tests-dir tests/ \
        --runner "python -m pytest tests/unit/"
    
    # Generate report
    mutmut html
    
    log_success "Mutation tests completed. Report: html/index.html"
}

# Generate test data
generate_test_data() {
    log_info "Generating test data..."
    
    mkdir -p "$TEST_DATA_DIR"
    
    # Generate mock asset data
    python -c "
import json
import random
from datetime import datetime, timedelta

# Generate mock assets
assets = []
asset_types = ['EC2_Instance', 'S3_Bucket', 'RDS_Instance', 'Azure_VM', 'GCP_Instance']
sources = ['aws_collector', 'azure_collector', 'gcp_collector']

for i in range(100):
    asset = {
        'id': f'test-asset-{i:04d}',
        'name': f'TestAsset{i:04d}',
        'asset_type': random.choice(asset_types),
        'source': random.choice(sources),
        'risk_score': random.randint(0, 100),
        'metadata': {
            'region': random.choice(['us-east-1', 'us-west-2', 'eu-west-1']),
            'environment': random.choice(['dev', 'staging', 'production']),
            'team': random.choice(['platform', 'security', 'data'])
        },
        'created_at': (datetime.now() - timedelta(days=random.randint(0, 365))).isoformat(),
        'updated_at': datetime.now().isoformat()
    }
    assets.append(asset)

# Save test data
with open('$TEST_DATA_DIR/mock_assets.json', 'w') as f:
    json.dump(assets, f, indent=2)

print(f'Generated {len(assets)} mock assets')
"
    
    # Generate mock findings
    python -c "
import json
import random
from datetime import datetime

findings = []
severities = ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL']
statuses = ['OPEN', 'IN_PROGRESS', 'RESOLVED', 'FALSE_POSITIVE']

for i in range(50):
    finding = {
        'id': f'finding-{i:04d}',
        'title': f'Test Finding {i}',
        'description': 'This is a test finding for CloudScope testing',
        'severity': random.choice(severities),
        'status': random.choice(statuses),
        'asset_id': f'test-asset-{random.randint(0, 99):04d}',
        'created_at': datetime.now().isoformat()
    }
    findings.append(finding)

with open('$TEST_DATA_DIR/mock_findings.json', 'w') as f:
    json.dump(findings, f, indent=2)

print(f'Generated {len(findings)} mock findings')
"
    
    log_success "Test data generated in $TEST_DATA_DIR"
}

# Run test coverage report
generate_coverage_report() {
    log_info "Generating coverage report..."
    
    # Generate HTML report
    coverage html
    
    # Generate console report
    coverage report
    
    # Generate XML report for CI/CD
    coverage xml
    
    log_success "Coverage report generated: $COVERAGE_DIR/index.html"
    
    # Open in browser (macOS)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        open "$COVERAGE_DIR/index.html"
    fi
}

# Run all tests
run_all_tests() {
    log_test "Running all tests..."
    
    # Clear previous coverage
    coverage erase
    
    # Run all test suites
    run_unit_tests
    run_integration_tests
    run_security_tests
    run_compliance_tests
    run_collector_tests
    
    # Generate final coverage report
    generate_coverage_report
    
    log_success "All tests completed"
}

# Print test summary
print_test_summary() {
    log_info "Test Summary"
    log_info "============"
    
    # Count test results
    if [[ -f ".coverage" ]]; then
        coverage report --skip-covered | tail -n 3
    fi
    
    # Show test counts
    echo ""
    echo "Test Counts:"
    find tests/ -name "test_*.py" -exec grep -c "def test_" {} + | \
        awk -F: '{sum+=$2} END {print "  Total test functions: " sum}'
    
    # Show report locations
    echo ""
    echo "Reports:"
    echo "  Coverage HTML: $COVERAGE_DIR/index.html"
    echo "  Coverage XML: coverage.xml"
    [[ -f "tests/reports/bandit.json" ]] && echo "  Security: tests/reports/bandit.json"
    [[ -f "tests/reports/safety.json" ]] && echo "  Dependencies: tests/reports/safety.json"
}

# Clean test artifacts
clean_tests() {
    log_info "Cleaning test artifacts..."
    
    # Remove coverage data
    rm -rf .coverage* htmlcov/ coverage.xml
    
    # Remove test reports
    rm -rf tests/reports/
    
    # Remove pytest cache
    find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
    find . -type d -name ".pytest_cache" -exec rm -rf {} + 2>/dev/null || true
    
    # Remove test logs
    rm -rf tests/logs/
    
    log_success "Test artifacts cleaned"
}

# Print usage
usage() {
    cat << EOF
Usage: $0 [COMMAND] [OPTIONS]

Commands:
    all                 Run all tests
    unit                Run unit tests
    integration         Run integration tests
    e2e                 Run end-to-end tests
    performance         Run performance tests
    security            Run security tests
    compliance          Run compliance tests
    collector [NAME]    Run collector tests (or specific collector)
    mutation            Run mutation tests
    
    generate-data       Generate test data
    coverage            Generate coverage report
    clean               Clean test artifacts
    
Options:
    -h, --help         Show this help message

Examples:
    # Run all tests
    $0 all
    
    # Run only unit tests
    $0 unit
    
    # Run specific collector tests
    $0 collector aws
    
    # Generate test data
    $0 generate-data
    
    # Clean test artifacts
    $0 clean
EOF
}

# Main execution
check_venv

case ${1:-} in
    all) run_all_tests ;;
    unit) run_unit_tests ;;
    integration) run_integration_tests ;;
    e2e) run_e2e_tests ;;
    performance) run_performance_tests ;;
    security) run_security_tests ;;
    compliance) run_compliance_tests ;;
    collector) run_collector_tests "${2:-all}" ;;
    mutation) run_mutation_tests ;;
    generate-data) generate_test_data ;;
    coverage) generate_coverage_report ;;
    clean) clean_tests ;;
    -h|--help) usage ;;
    *)
        if [[ -n "${1:-}" ]]; then
            log_error "Unknown command: $1"
        fi
        usage
        exit 1
        ;;
esac

# Print summary if tests were run
if [[ "${1:-}" =~ ^(all|unit|integration|e2e|performance|security|compliance|collector)$ ]]; then
    print_test_summary
fi
