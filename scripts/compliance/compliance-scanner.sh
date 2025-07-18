#!/bin/bash
# CloudScope Compliance Scanner
# Scan assets for compliance with various frameworks (PCI-DSS, SOC2, ISO27001, etc.)

set -euo pipefail

# Configuration
CONFIG_FILE="${CONFIG_FILE:-./config/cloudscope-config.json}"
COMPLIANCE_RULES="${COMPLIANCE_RULES:-./config/compliance-rules}"
OUTPUT_DIR="${OUTPUT_DIR:-./data/compliance-reports}"
MEMGRAPH_HOST="${MEMGRAPH_HOST:-localhost}"
MEMGRAPH_PORT="${MEMGRAPH_PORT:-7687}"

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
log_finding() { echo -e "${PURPLE}[FINDING]${NC} $1"; }

# Create output directory
mkdir -p "$OUTPUT_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Compliance frameworks
declare -A FRAMEWORKS=(
    ["pci-dss"]="PCI-DSS v3.2.1"
    ["soc2"]="SOC 2 Type II"
    ["iso27001"]="ISO 27001:2013"
    ["hipaa"]="HIPAA Security Rule"
    ["gdpr"]="GDPR"
    ["cis"]="CIS Controls v8"
    ["nist"]="NIST Cybersecurity Framework"
)

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if Memgraph is accessible
    if ! docker exec cloudscope-memgraph echo "MATCH (n) RETURN count(n);" | mgconsole > /dev/null 2>&1; then
        log_error "Cannot connect to Memgraph"
        exit 1
    fi
    
    # Check Python
    if ! command -v python3 &> /dev/null; then
        log_error "Python 3 is required"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Load compliance rules
load_compliance_rules() {
    local framework=$1
    local rules_file="$COMPLIANCE_RULES/${framework}.json"
    
    if [[ ! -f "$rules_file" ]]; then
        log_warning "Creating default rules for $framework"
        create_default_rules "$framework"
    fi
    
    cat "$rules_file"
}

# Create default compliance rules
create_default_rules() {
    local framework=$1
    mkdir -p "$COMPLIANCE_RULES"
    
    case $framework in
        "pci-dss")
            cat > "$COMPLIANCE_RULES/${framework}.json" << 'EOF'
{
  "framework": "PCI-DSS v3.2.1",
  "version": "3.2.1",
  "rules": [
    {
      "id": "pci-1.1",
      "requirement": "Install and maintain a firewall configuration",
      "description": "Establish and implement firewall and router configuration standards",
      "query": "MATCH (a:Asset) WHERE a.asset_type IN ['Firewall', 'Router', 'NetworkDevice'] AND NOT EXISTS(a.metadata.firewall_rules) RETURN a",
      "severity": "HIGH"
    },
    {
      "id": "pci-2.1",
      "requirement": "Do not use vendor-supplied defaults",
      "description": "Always change vendor-supplied defaults and remove or disable unnecessary default accounts",
      "query": "MATCH (a:Asset) WHERE a.metadata.default_password = true OR a.metadata.default_config = true RETURN a",
      "severity": "CRITICAL"
    },
    {
      "id": "pci-3.4",
      "requirement": "Render PAN unreadable anywhere it is stored",
      "description": "Encrypt storage of cardholder data",
      "query": "MATCH (a:Asset) WHERE a.asset_type IN ['Database', 'Storage'] AND (NOT EXISTS(a.metadata.encryption_at_rest) OR a.metadata.encryption_at_rest = false) RETURN a",
      "severity": "CRITICAL"
    },
    {
      "id": "pci-8.1",
      "requirement": "Identify all users with a unique ID",
      "description": "Assign all users a unique ID before allowing them to access system components",
      "query": "MATCH (u:Asset {asset_type: 'User'}) WHERE NOT EXISTS(u.metadata.unique_id) OR u.metadata.shared_account = true RETURN u",
      "severity": "HIGH"
    }
  ]
}
EOF
            ;;
            
        "soc2")
            cat > "$COMPLIANCE_RULES/${framework}.json" << 'EOF'
{
  "framework": "SOC 2 Type II",
  "version": "2017",
  "rules": [
    {
      "id": "cc6.1",
      "requirement": "Logical and Physical Access Controls",
      "description": "The entity implements logical access security measures",
      "query": "MATCH (a:Asset) WHERE NOT EXISTS(a.metadata.access_control) OR a.metadata.access_control = 'none' RETURN a",
      "severity": "HIGH"
    },
    {
      "id": "cc6.3",
      "requirement": "Role-Based Access Control",
      "description": "The entity authorizes access based on roles and responsibilities",
      "query": "MATCH (a:Asset)-[:HAS_ACCESS]->(u:Asset {asset_type: 'User'}) WHERE NOT EXISTS(a.metadata.rbac_enabled) RETURN a, u",
      "severity": "MEDIUM"
    },
    {
      "id": "cc7.2",
      "requirement": "System Monitoring",
      "description": "The entity monitors system components for anomalies",
      "query": "MATCH (a:Asset) WHERE a.asset_type IN ['Server', 'Application'] AND NOT EXISTS(a.metadata.monitoring_enabled) RETURN a",
      "severity": "HIGH"
    },
    {
      "id": "a1.2",
      "requirement": "Risk Assessment Process",
      "description": "The entity identifies and assesses risks on a periodic basis",
      "query": "MATCH (a:Asset) WHERE NOT EXISTS(a.risk_score) OR a.metadata.last_risk_assessment < datetime() - duration('P90D') RETURN a",
      "severity": "MEDIUM"
    }
  ]
}
EOF
            ;;
            
        "iso27001")
            cat > "$COMPLIANCE_RULES/${framework}.json" << 'EOF'
{
  "framework": "ISO 27001:2013",
  "version": "2013",
  "rules": [
    {
      "id": "A.9.1.1",
      "requirement": "Access control policy",
      "description": "An access control policy should be established, documented and reviewed",
      "query": "MATCH (a:Asset) WHERE NOT EXISTS(a.metadata.access_policy) RETURN a",
      "severity": "MEDIUM"
    },
    {
      "id": "A.12.1.1",
      "requirement": "Documented operating procedures",
      "description": "Operating procedures should be documented and made available",
      "query": "MATCH (a:Asset) WHERE a.asset_type = 'Application' AND NOT EXISTS(a.metadata.documentation_url) RETURN a",
      "severity": "LOW"
    },
    {
      "id": "A.12.2.1",
      "requirement": "Controls against malware",
      "description": "Detection, prevention and recovery controls against malware",
      "query": "MATCH (a:Asset) WHERE a.asset_type IN ['Server', 'Workstation'] AND NOT EXISTS(a.metadata.antivirus_installed) RETURN a",
      "severity": "HIGH"
    },
    {
      "id": "A.18.1.3",
      "requirement": "Protection of records",
      "description": "Records should be protected from loss, destruction, falsification",
      "query": "MATCH (a:Asset) WHERE a.asset_type = 'Database' AND NOT EXISTS(a.metadata.backup_enabled) RETURN a",
      "severity": "HIGH"
    }
  ]
}
EOF
            ;;
    esac
}

# Run compliance scan for a framework
run_framework_scan() {
    local framework=$1
    log_info "Running compliance scan for ${FRAMEWORKS[$framework]}"
    
    # Load rules
    local rules=$(load_compliance_rules "$framework")
    
    # Create findings array
    local findings=()
    local compliant_count=0
    local non_compliant_count=0
    
    # Process each rule
    echo "$rules" | jq -r '.rules[] | @json' | while read -r rule_json; do
        local rule=$(echo "$rule_json" | jq -r '.')
        local rule_id=$(echo "$rule" | jq -r '.id')
        local requirement=$(echo "$rule" | jq -r '.requirement')
        local query=$(echo "$rule" | jq -r '.query')
        local severity=$(echo "$rule" | jq -r '.severity')
        
        log_info "Checking rule $rule_id: $requirement"
        
        # Execute query
        local results=$(docker exec cloudscope-memgraph mgconsole --execute "$query" 2>/dev/null || echo "")
        local violation_count=$(echo "$results" | grep -v "^$" | wc -l)
        
        if [[ $violation_count -gt 0 ]]; then
            log_finding "Non-compliant: $rule_id - $violation_count violations found"
            non_compliant_count=$((non_compliant_count + 1))
            
            # Create finding
            cat >> "$OUTPUT_DIR/${framework}_findings_${TIMESTAMP}.json" << EOF
{
  "rule_id": "$rule_id",
  "requirement": "$requirement",
  "severity": "$severity",
  "status": "NON_COMPLIANT",
  "violation_count": $violation_count,
  "timestamp": "$(date -Iseconds)"
},
EOF
        else
            log_success "Compliant: $rule_id"
            compliant_count=$((compliant_count + 1))
        fi
    done
    
    # Generate summary
    generate_framework_summary "$framework" "$compliant_count" "$non_compliant_count"
}

# Generate framework summary
generate_framework_summary() {
    local framework=$1
    local compliant=$2
    local non_compliant=$3
    local total=$((compliant + non_compliant))
    local compliance_percentage=0
    
    if [[ $total -gt 0 ]]; then
        compliance_percentage=$(awk "BEGIN {printf \"%.1f\", ($compliant / $total) * 100}")
    fi
    
    cat > "$OUTPUT_DIR/${framework}_summary_${TIMESTAMP}.json" << EOF
{
  "framework": "${FRAMEWORKS[$framework]}",
  "scan_date": "$(date -Iseconds)",
  "summary": {
    "total_rules": $total,
    "compliant": $compliant,
    "non_compliant": $non_compliant,
    "compliance_percentage": $compliance_percentage
  }
}
EOF
    
    log_info "Framework: ${FRAMEWORKS[$framework]}"
    log_info "Compliance: ${compliance_percentage}% ($compliant/$total rules)"
}

# Run asset-level compliance check
check_asset_compliance() {
    local asset_id=$1
    log_info "Checking compliance for asset: $asset_id"
    
    # Get asset details
    local asset_info=$(docker exec cloudscope-memgraph mgconsole --execute "
        MATCH (a:Asset {id: '$asset_id'})
        RETURN a.name AS name, a.asset_type AS type, a.metadata AS metadata
    ")
    
    # Check against all frameworks
    local compliance_status={}
    
    for framework in "${!FRAMEWORKS[@]}"; do
        local rules=$(load_compliance_rules "$framework")
        local violations=0
        
        # Check each rule
        echo "$rules" | jq -r '.rules[] | @json' | while read -r rule_json; do
            local rule=$(echo "$rule_json" | jq -r '.')
            local query=$(echo "$rule" | jq -r '.query')
            
            # Modify query to check specific asset
            local asset_query="${query/MATCH (a:Asset)/MATCH (a:Asset {id: '$asset_id'})}"
            
            local result=$(docker exec cloudscope-memgraph mgconsole --execute "$asset_query" 2>/dev/null || echo "")
            if [[ -n "$result" ]]; then
                violations=$((violations + 1))
            fi
        done
        
        echo "  $framework: $violations violations"
    done
}

# Generate executive report
generate_executive_report() {
    log_info "Generating executive compliance report..."
    
    local report_file="$OUTPUT_DIR/executive_report_${TIMESTAMP}.html"
    
    cat > "$report_file" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>CloudScope Compliance Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        h1 { color: #333; }
        h2 { color: #666; margin-top: 30px; }
        .summary { background: #f5f5f5; padding: 20px; border-radius: 5px; margin: 20px 0; }
        .compliant { color: green; font-weight: bold; }
        .non-compliant { color: red; font-weight: bold; }
        .warning { color: orange; font-weight: bold; }
        table { border-collapse: collapse; width: 100%; margin: 20px 0; }
        th, td { border: 1px solid #ddd; padding: 12px; text-align: left; }
        th { background-color: #4CAF50; color: white; }
        .chart { margin: 20px 0; }
        .severity-critical { background-color: #ff4444; color: white; }
        .severity-high { background-color: #ff8844; color: white; }
        .severity-medium { background-color: #ffaa44; }
        .severity-low { background-color: #ffdd44; }
    </style>
</head>
<body>
    <h1>CloudScope Compliance Report</h1>
    <p>Generated: TIMESTAMP_PLACEHOLDER</p>
    
    <div class="summary">
        <h2>Executive Summary</h2>
        <p>This report provides a comprehensive overview of compliance status across multiple frameworks.</p>
    </div>
    
    <h2>Compliance by Framework</h2>
    <table>
        <tr>
            <th>Framework</th>
            <th>Compliance %</th>
            <th>Compliant Rules</th>
            <th>Non-Compliant Rules</th>
            <th>Status</th>
        </tr>
EOF
    
    # Add framework results
    for framework in "${!FRAMEWORKS[@]}"; do
        if [[ -f "$OUTPUT_DIR/${framework}_summary_${TIMESTAMP}.json" ]]; then
            local summary=$(cat "$OUTPUT_DIR/${framework}_summary_${TIMESTAMP}.json")
            local percentage=$(echo "$summary" | jq -r '.summary.compliance_percentage')
            local compliant=$(echo "$summary" | jq -r '.summary.compliant')
            local non_compliant=$(echo "$summary" | jq -r '.summary.non_compliant')
            
            local status_class="compliant"
            local status_text="Compliant"
            if (( $(echo "$percentage < 70" | bc -l) )); then
                status_class="non-compliant"
                status_text="Non-Compliant"
            elif (( $(echo "$percentage < 90" | bc -l) )); then
                status_class="warning"
                status_text="Needs Attention"
            fi
            
            cat >> "$report_file" << EOF
        <tr>
            <td>${FRAMEWORKS[$framework]}</td>
            <td>${percentage}%</td>
            <td>$compliant</td>
            <td>$non_compliant</td>
            <td class="$status_class">$status_text</td>
        </tr>
EOF
        fi
    done
    
    cat >> "$report_file" << 'EOF'
    </table>
    
    <h2>Critical Findings</h2>
    <table>
        <tr>
            <th>Framework</th>
            <th>Rule ID</th>
            <th>Requirement</th>
            <th>Severity</th>
            <th>Violations</th>
        </tr>
EOF
    
    # Add critical findings
    find "$OUTPUT_DIR" -name "*_findings_${TIMESTAMP}.json" -exec cat {} \; | \
        jq -s 'map(select(.severity == "CRITICAL" or .severity == "HIGH"))' | \
        jq -r '.[] | "<tr><td>\(.framework // "Unknown")</td><td>\(.rule_id)</td><td>\(.requirement)</td><td class=\"severity-\(.severity | ascii_downcase)\">\(.severity)</td><td>\(.violation_count)</td></tr>"' \
        >> "$report_file"
    
    cat >> "$report_file" << EOF
    </table>
    
    <h2>Recommendations</h2>
    <ul>
        <li>Address all CRITICAL findings immediately</li>
        <li>Create remediation plan for HIGH severity findings within 30 days</li>
        <li>Schedule regular compliance scans (monthly recommended)</li>
        <li>Implement continuous compliance monitoring</li>
    </ul>
    
    <p><em>Report generated by CloudScope Compliance Scanner</em></p>
</body>
</html>
EOF
    
    # Update timestamp
    sed -i "" "s/TIMESTAMP_PLACEHOLDER/$(date)/g" "$report_file"
    
    log_success "Executive report generated: $report_file"
}

# Create compliance findings in database
create_findings_in_db() {
    log_info "Creating findings in database..."
    
    find "$OUTPUT_DIR" -name "*_findings_${TIMESTAMP}.json" -exec cat {} \; | while read -r finding; do
        if [[ -n "$finding" && "$finding" != "," ]]; then
            local rule_id=$(echo "$finding" | jq -r '.rule_id')
            local requirement=$(echo "$finding" | jq -r '.requirement')
            local severity=$(echo "$finding" | jq -r '.severity')
            local violation_count=$(echo "$finding" | jq -r '.violation_count')
            
            docker exec cloudscope-memgraph mgconsole --execute "
                CREATE (f:Finding {
                    id: '${rule_id}_${TIMESTAMP}',
                    title: '$requirement',
                    description: 'Compliance violation detected',
                    severity: '$severity',
                    status: 'OPEN',
                    source: 'compliance_scanner',
                    created_at: datetime(),
                    metadata: {
                        rule_id: '$rule_id',
                        violation_count: $violation_count
                    }
                })
            " 2>/dev/null || true
        fi
    done
    
    log_success "Findings created in database"
}

# Schedule compliance scans
schedule_scans() {
    log_info "Creating scheduled compliance scan..."
    
    # Create cron job
    local cron_file="/etc/cron.d/cloudscope-compliance"
    
    cat > cloudscope-compliance-cron << EOF
# CloudScope Compliance Scanner - Run daily at 2 AM
0 2 * * * $(whoami) $(pwd)/scripts/compliance/compliance-scanner.sh scan all >> $(pwd)/data/logs/compliance-scanner.log 2>&1
EOF
    
    log_info "To install scheduled scan:"
    echo "  sudo cp cloudscope-compliance-cron /etc/cron.d/cloudscope-compliance"
    echo "  sudo chmod 644 /etc/cron.d/cloudscope-compliance"
}

# Print usage
usage() {
    cat << EOF
Usage: $0 [COMMAND] [OPTIONS]

Commands:
    scan FRAMEWORK      Run compliance scan for specific framework
    scan all           Run compliance scan for all frameworks
    check ASSET_ID     Check compliance for specific asset
    report             Generate executive report from latest scan
    schedule           Create scheduled compliance scans
    list               List available compliance frameworks

Options:
    -o, --output DIR   Output directory (default: ./data/compliance-reports)
    -h, --help         Show this help message

Frameworks:
    pci-dss           PCI-DSS v3.2.1
    soc2              SOC 2 Type II
    iso27001          ISO 27001:2013
    hipaa             HIPAA Security Rule
    gdpr              GDPR
    cis               CIS Controls v8
    nist              NIST Cybersecurity Framework

Examples:
    # Scan for PCI-DSS compliance
    $0 scan pci-dss

    # Scan all frameworks
    $0 scan all

    # Check specific asset
    $0 check asset-12345

    # Generate report
    $0 report
EOF
}

# Parse command line arguments
COMMAND=""
PARAM=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        scan|check|report|schedule|list)
            COMMAND="$1"
            PARAM="${2:-}"
            shift
            [[ -n "$PARAM" ]] && shift
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Main execution
check_prerequisites

case $COMMAND in
    scan)
        if [[ "$PARAM" == "all" ]]; then
            for framework in "${!FRAMEWORKS[@]}"; do
                run_framework_scan "$framework"
            done
            create_findings_in_db
            generate_executive_report
        elif [[ -n "$PARAM" ]] && [[ -n "${FRAMEWORKS[$PARAM]}" ]]; then
            run_framework_scan "$PARAM"
            create_findings_in_db
        else
            log_error "Invalid framework: $PARAM"
            echo "Available frameworks:"
            for f in "${!FRAMEWORKS[@]}"; do
                echo "  $f - ${FRAMEWORKS[$f]}"
            done
            exit 1
        fi
        ;;
    check)
        if [[ -n "$PARAM" ]]; then
            check_asset_compliance "$PARAM"
        else
            log_error "Asset ID required"
            exit 1
        fi
        ;;
    report)
        generate_executive_report
        ;;
    schedule)
        schedule_scans
        ;;
    list)
        echo "Available compliance frameworks:"
        for f in "${!FRAMEWORKS[@]}"; do
            echo "  $f - ${FRAMEWORKS[$f]}"
        done
        ;;
    *)
        log_error "No command specified"
        usage
        exit 1
        ;;
esac

log_success "Compliance scan completed"
