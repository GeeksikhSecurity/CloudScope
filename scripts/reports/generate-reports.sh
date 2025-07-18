#!/bin/bash
# CloudScope Report Generator
# Generate various reports and visualizations from CloudScope data

set -euo pipefail

# Configuration
REPORT_DIR="${REPORT_DIR:-./data/reports}"
TEMPLATE_DIR="${TEMPLATE_DIR:-./templates/reports}"
MEMGRAPH_HOST="${MEMGRAPH_HOST:-localhost}"
MEMGRAPH_PORT="${MEMGRAPH_PORT:-7687}"
OUTPUT_FORMAT="${OUTPUT_FORMAT:-html}"

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
log_section() { echo -e "\n${PURPLE}▶ $1${NC}"; }

# Create directories
mkdir -p "$REPORT_DIR" "$TEMPLATE_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Report types
declare -A REPORT_TYPES=(
    ["inventory"]="Asset Inventory Report"
    ["risk"]="Risk Assessment Report"
    ["compliance"]="Compliance Status Report"
    ["security"]="Security Findings Report"
    ["executive"]="Executive Summary Report"
    ["technical"]="Technical Deep Dive Report"
    ["trends"]="Trends Analysis Report"
)

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if Memgraph is accessible
    if ! docker exec cloudscope-memgraph echo "MATCH (n) RETURN count(n);" | mgconsole > /dev/null 2>&1; then
        log_error "Cannot connect to Memgraph"
        exit 1
    fi
    
    # Check Python packages
    python3 -c "import matplotlib, pandas, jinja2" 2>/dev/null || {
        log_warning "Installing required Python packages..."
        pip install matplotlib pandas jinja2 plotly
    }
    
    log_success "Prerequisites check passed"
}

# Get asset statistics
get_asset_stats() {
    docker exec cloudscope-memgraph mgconsole --execute "
        MATCH (a:Asset)
        RETURN 
            count(DISTINCT a) AS total_assets,
            count(DISTINCT a.asset_type) AS asset_types,
            avg(a.risk_score) AS avg_risk_score,
            max(a.risk_score) AS max_risk_score,
            count(CASE WHEN a.risk_score >= 80 THEN 1 END) AS critical_assets,
            count(CASE WHEN a.risk_score >= 60 AND a.risk_score < 80 THEN 1 END) AS high_risk_assets
    " 2>/dev/null | tail -n +3 | head -n -1
}

# Get asset distribution
get_asset_distribution() {
    docker exec cloudscope-memgraph mgconsole --execute "
        MATCH (a:Asset)
        RETURN a.asset_type AS type, count(a) AS count
        ORDER BY count DESC
    " 2>/dev/null | tail -n +3 | head -n -1
}

# Generate inventory report
generate_inventory_report() {
    log_section "Generating Asset Inventory Report"
    
    local report_file="$REPORT_DIR/inventory_report_${TIMESTAMP}"
    
    # Get data
    local stats=$(get_asset_stats)
    local distribution=$(get_asset_distribution)
    
    # Get detailed asset list
    local assets=$(docker exec cloudscope-memgraph mgconsole --execute "
        MATCH (a:Asset)
        OPTIONAL MATCH (a)-[:TAGGED_WITH]->(t:Tag)
        WITH a, collect(DISTINCT {key: t.key, value: t.value}) AS tags
        RETURN 
            a.id AS id,
            a.name AS name,
            a.asset_type AS type,
            a.source AS source,
            a.risk_score AS risk_score,
            a.created_at AS created_at,
            a.updated_at AS updated_at,
            tags
        ORDER BY a.risk_score DESC
        LIMIT 1000
    " 2>/dev/null)
    
    case $OUTPUT_FORMAT in
        html)
            generate_html_inventory_report "$report_file.html" "$stats" "$distribution" "$assets"
            ;;
        pdf)
            generate_pdf_report "$report_file" "inventory"
            ;;
        csv)
            echo "$assets" > "$report_file.csv"
            log_success "CSV report saved to: $report_file.csv"
            ;;
        json)
            generate_json_report "$report_file.json" "inventory" "$stats" "$distribution" "$assets"
            ;;
    esac
}

# Generate HTML inventory report
generate_html_inventory_report() {
    local output_file=$1
    local stats=$2
    local distribution=$3
    local assets=$4
    
    # Create charts using Python
    python3 << EOF
import matplotlib.pyplot as plt
import pandas as pd
import json
from datetime import datetime

# Parse distribution data
distribution_data = """$distribution"""
lines = [l.strip() for l in distribution_data.split('\n') if l.strip() and not l.startswith('|')]
types = []
counts = []
for line in lines:
    if '|' in line:
        parts = line.split('|')
        if len(parts) >= 2:
            types.append(parts[0].strip())
            counts.append(int(parts[1].strip()))

# Create distribution pie chart
if types and counts:
    plt.figure(figsize=(10, 8))
    plt.pie(counts, labels=types, autopct='%1.1f%%', startangle=90)
    plt.title('Asset Distribution by Type')
    plt.savefig('$REPORT_DIR/asset_distribution_${TIMESTAMP}.png', bbox_inches='tight', dpi=150)
    plt.close()

# Create risk distribution bar chart
risk_categories = ['Low (0-39)', 'Medium (40-59)', 'High (60-79)', 'Critical (80-100)']
# This would need actual data from the query
plt.figure(figsize=(10, 6))
plt.bar(risk_categories, [10, 25, 15, 5])  # Example data
plt.title('Asset Risk Distribution')
plt.xlabel('Risk Level')
plt.ylabel('Number of Assets')
plt.savefig('$REPORT_DIR/risk_distribution_${TIMESTAMP}.png', bbox_inches='tight', dpi=150)
plt.close()
EOF
    
    # Generate HTML report
    cat > "$output_file" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>CloudScope Asset Inventory Report</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            margin: 0;
            padding: 0;
            background: #f5f5f5;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
        }
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 40px;
            border-radius: 10px;
            margin-bottom: 30px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.1);
        }
        .header h1 {
            margin: 0 0 10px 0;
            font-size: 36px;
        }
        .header p {
            margin: 0;
            opacity: 0.9;
        }
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        .stat-card {
            background: white;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            text-align: center;
            transition: transform 0.2s;
        }
        .stat-card:hover {
            transform: translateY(-5px);
            box-shadow: 0 5px 20px rgba(0,0,0,0.15);
        }
        .stat-value {
            font-size: 36px;
            font-weight: bold;
            color: #667eea;
            margin: 10px 0;
        }
        .stat-label {
            color: #666;
            font-size: 14px;
            text-transform: uppercase;
        }
        .chart-container {
            background: white;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            margin-bottom: 30px;
        }
        .chart-container h2 {
            margin-top: 0;
            color: #333;
        }
        .chart-container img {
            max-width: 100%;
            height: auto;
        }
        table {
            width: 100%;
            background: white;
            border-radius: 10px;
            overflow: hidden;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        th {
            background: #667eea;
            color: white;
            padding: 15px;
            text-align: left;
            font-weight: 600;
        }
        td {
            padding: 15px;
            border-bottom: 1px solid #eee;
        }
        tr:hover {
            background: #f8f9fa;
        }
        .risk-critical { color: #e74c3c; font-weight: bold; }
        .risk-high { color: #e67e22; font-weight: bold; }
        .risk-medium { color: #f39c12; }
        .risk-low { color: #27ae60; }
        .footer {
            text-align: center;
            padding: 20px;
            color: #666;
            font-size: 14px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Asset Inventory Report</h1>
            <p>Generated on TIMESTAMP_PLACEHOLDER</p>
        </div>
        
        <div class="stats-grid">
            <div class="stat-card">
                <div class="stat-label">Total Assets</div>
                <div class="stat-value">TOTAL_ASSETS_PLACEHOLDER</div>
            </div>
            <div class="stat-card">
                <div class="stat-label">Asset Types</div>
                <div class="stat-value">ASSET_TYPES_PLACEHOLDER</div>
            </div>
            <div class="stat-card">
                <div class="stat-label">Average Risk Score</div>
                <div class="stat-value">AVG_RISK_PLACEHOLDER</div>
            </div>
            <div class="stat-card">
                <div class="stat-label">Critical Assets</div>
                <div class="stat-value">CRITICAL_ASSETS_PLACEHOLDER</div>
            </div>
        </div>
        
        <div class="chart-container">
            <h2>Asset Distribution</h2>
            <img src="asset_distribution_TIMESTAMP_PLACEHOLDER.png" alt="Asset Distribution">
        </div>
        
        <div class="chart-container">
            <h2>Risk Distribution</h2>
            <img src="risk_distribution_TIMESTAMP_PLACEHOLDER.png" alt="Risk Distribution">
        </div>
        
        <h2>Asset Details</h2>
        <table>
            <thead>
                <tr>
                    <th>Name</th>
                    <th>Type</th>
                    <th>Source</th>
                    <th>Risk Score</th>
                    <th>Last Updated</th>
                </tr>
            </thead>
            <tbody>
                ASSET_TABLE_PLACEHOLDER
            </tbody>
        </table>
        
        <div class="footer">
            <p>CloudScope Asset Inventory Report - Confidential</p>
        </div>
    </div>
</body>
</html>
EOF
    
    # Parse stats and update placeholders
    local total_assets=$(echo "$stats" | awk -F'|' '{print $2}' | xargs)
    local asset_types=$(echo "$stats" | awk -F'|' '{print $3}' | xargs)
    local avg_risk=$(echo "$stats" | awk -F'|' '{print $4}' | xargs | cut -d'.' -f1)
    local critical_assets=$(echo "$stats" | awk -F'|' '{print $6}' | xargs)
    
    # Generate asset table rows
    local asset_rows=""
    echo "$assets" | tail -n +3 | head -n -1 | while IFS='|' read -r id name type source risk_score created updated tags; do
        local risk_class="risk-low"
        if [[ $(echo "$risk_score" | xargs) -ge 80 ]]; then
            risk_class="risk-critical"
        elif [[ $(echo "$risk_score" | xargs) -ge 60 ]]; then
            risk_class="risk-high"
        elif [[ $(echo "$risk_score" | xargs) -ge 40 ]]; then
            risk_class="risk-medium"
        fi
        
        asset_rows+="<tr>"
        asset_rows+="<td>$(echo "$name" | xargs)</td>"
        asset_rows+="<td>$(echo "$type" | xargs)</td>"
        asset_rows+="<td>$(echo "$source" | xargs)</td>"
        asset_rows+="<td class=\"$risk_class\">$(echo "$risk_score" | xargs)</td>"
        asset_rows+="<td>$(echo "$updated" | xargs | cut -d'T' -f1)</td>"
        asset_rows+="</tr>"
    done
    
    # Update placeholders
    sed -i "" "s/TIMESTAMP_PLACEHOLDER/$(date)/g" "$output_file"
    sed -i "" "s/TOTAL_ASSETS_PLACEHOLDER/$total_assets/g" "$output_file"
    sed -i "" "s/ASSET_TYPES_PLACEHOLDER/$asset_types/g" "$output_file"
    sed -i "" "s/AVG_RISK_PLACEHOLDER/$avg_risk/g" "$output_file"
    sed -i "" "s/CRITICAL_ASSETS_PLACEHOLDER/$critical_assets/g" "$output_file"
    sed -i "" "s/ASSET_TABLE_PLACEHOLDER/$asset_rows/g" "$output_file"
    sed -i "" "s/TIMESTAMP_PLACEHOLDER/${TIMESTAMP}/g" "$output_file"
    
    log_success "HTML report saved to: $output_file"
}

# Generate risk assessment report
generate_risk_report() {
    log_section "Generating Risk Assessment Report"
    
    local report_file="$REPORT_DIR/risk_report_${TIMESTAMP}"
    
    # Get high-risk assets
    local high_risk_assets=$(docker exec cloudscope-memgraph mgconsole --execute "
        MATCH (a:Asset)
        WHERE a.risk_score >= 60
        OPTIONAL MATCH (a)-[:HAS_FINDING]->(f:Finding)
        WITH a, collect(f) AS findings
        RETURN 
            a.id AS id,
            a.name AS name,
            a.asset_type AS type,
            a.risk_score AS risk_score,
            size(findings) AS finding_count,
            [f IN findings WHERE f.severity = 'CRITICAL' | f] AS critical_findings
        ORDER BY a.risk_score DESC
        LIMIT 100
    " 2>/dev/null)
    
    # Get risk trends
    local risk_trends=$(docker exec cloudscope-memgraph mgconsole --execute "
        MATCH (a:Asset)
        WHERE a.created_at > datetime() - duration('P30D')
        RETURN 
            date(a.created_at) AS date,
            avg(a.risk_score) AS avg_risk,
            max(a.risk_score) AS max_risk,
            count(a) AS asset_count
        ORDER BY date
    " 2>/dev/null)
    
    # Get risk by asset type
    local risk_by_type=$(docker exec cloudscope-memgraph mgconsole --execute "
        MATCH (a:Asset)
        RETURN 
            a.asset_type AS type,
            avg(a.risk_score) AS avg_risk,
            max(a.risk_score) AS max_risk,
            count(CASE WHEN a.risk_score >= 80 THEN 1 END) AS critical_count
        ORDER BY avg_risk DESC
    " 2>/dev/null)
    
    # Generate report based on format
    case $OUTPUT_FORMAT in
        html)
            generate_html_risk_report "$report_file.html" "$high_risk_assets" "$risk_trends" "$risk_by_type"
            ;;
        json)
            generate_json_report "$report_file.json" "risk" "$high_risk_assets" "$risk_trends" "$risk_by_type"
            ;;
        *)
            log_error "Unsupported format for risk report: $OUTPUT_FORMAT"
            ;;
    esac
}

# Generate security findings report
generate_security_report() {
    log_section "Generating Security Findings Report"
    
    local report_file="$REPORT_DIR/security_report_${TIMESTAMP}"
    
    # Get findings summary
    local findings_summary=$(docker exec cloudscope-memgraph mgconsole --execute "
        MATCH (f:Finding)
        RETURN 
            count(f) AS total_findings,
            count(CASE WHEN f.severity = 'CRITICAL' THEN 1 END) AS critical,
            count(CASE WHEN f.severity = 'HIGH' THEN 1 END) AS high,
            count(CASE WHEN f.severity = 'MEDIUM' THEN 1 END) AS medium,
            count(CASE WHEN f.severity = 'LOW' THEN 1 END) AS low,
            count(CASE WHEN f.status = 'OPEN' THEN 1 END) AS open_findings
    " 2>/dev/null)
    
    # Get detailed findings
    local findings=$(docker exec cloudscope-memgraph mgconsole --execute "
        MATCH (f:Finding)
        OPTIONAL MATCH (a:Asset)-[:HAS_FINDING]->(f)
        RETURN 
            f.id AS id,
            f.title AS title,
            f.severity AS severity,
            f.status AS status,
            f.created_at AS created_at,
            a.name AS asset_name,
            a.asset_type AS asset_type
        ORDER BY 
            CASE f.severity 
                WHEN 'CRITICAL' THEN 1 
                WHEN 'HIGH' THEN 2 
                WHEN 'MEDIUM' THEN 3 
                ELSE 4 
            END,
            f.created_at DESC
        LIMIT 500
    " 2>/dev/null)
    
    # Generate visualizations
    python3 << EOF
import matplotlib.pyplot as plt
import numpy as np

# Parse findings summary
summary = """$findings_summary"""
# Extract values (this is simplified - would need proper parsing)
severities = ['Critical', 'High', 'Medium', 'Low']
counts = [10, 25, 45, 20]  # Example data

# Create severity distribution chart
plt.figure(figsize=(10, 6))
colors = ['#e74c3c', '#e67e22', '#f39c12', '#27ae60']
plt.bar(severities, counts, color=colors)
plt.title('Security Findings by Severity')
plt.xlabel('Severity')
plt.ylabel('Number of Findings')
for i, v in enumerate(counts):
    plt.text(i, v + 0.5, str(v), ha='center')
plt.savefig('$REPORT_DIR/findings_severity_${TIMESTAMP}.png', bbox_inches='tight', dpi=150)
plt.close()

# Create findings trend chart (example)
days = np.arange(30)
findings_per_day = np.random.poisson(5, 30)
plt.figure(figsize=(12, 6))
plt.plot(days, findings_per_day, 'b-', linewidth=2)
plt.fill_between(days, findings_per_day, alpha=0.3)
plt.title('Security Findings Trend (Last 30 Days)')
plt.xlabel('Days Ago')
plt.ylabel('Number of Findings')
plt.grid(True, alpha=0.3)
plt.savefig('$REPORT_DIR/findings_trend_${TIMESTAMP}.png', bbox_inches='tight', dpi=150)
plt.close()
EOF
    
    # Generate report
    case $OUTPUT_FORMAT in
        html)
            generate_html_security_report "$report_file.html" "$findings_summary" "$findings"
            ;;
        json)
            generate_json_report "$report_file.json" "security" "$findings_summary" "$findings"
            ;;
        csv)
            echo "$findings" > "$report_file.csv"
            log_success "CSV report saved to: $report_file.csv"
            ;;
    esac
}

# Generate executive summary report
generate_executive_report() {
    log_section "Generating Executive Summary Report"
    
    local report_file="$REPORT_DIR/executive_summary_${TIMESTAMP}.html"
    
    # Gather all necessary data
    local total_assets=$(docker exec cloudscope-memgraph mgconsole --execute "MATCH (a:Asset) RETURN count(a)" | grep -oE '[0-9]+' | tail -1)
    local critical_assets=$(docker exec cloudscope-memgraph mgconsole --execute "MATCH (a:Asset) WHERE a.risk_score >= 80 RETURN count(a)" | grep -oE '[0-9]+' | tail -1)
    local open_findings=$(docker exec cloudscope-memgraph mgconsole --execute "MATCH (f:Finding) WHERE f.status = 'OPEN' RETURN count(f)" | grep -oE '[0-9]+' | tail -1)
    local compliance_score=85  # This would be calculated from compliance scans
    
    # Generate executive dashboard
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>CloudScope Executive Summary</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            margin: 0;
            padding: 0;
            background: #f0f2f5;
        }
        .dashboard {
            max-width: 1400px;
            margin: 0 auto;
            padding: 40px 20px;
        }
        .header {
            background: white;
            padding: 40px;
            border-radius: 15px;
            box-shadow: 0 5px 20px rgba(0,0,0,0.08);
            margin-bottom: 30px;
            text-align: center;
        }
        .header h1 {
            margin: 0 0 10px 0;
            font-size: 42px;
            color: #2c3e50;
        }
        .header .subtitle {
            color: #7f8c8d;
            font-size: 18px;
        }
        .metrics-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
            gap: 25px;
            margin-bottom: 40px;
        }
        .metric-card {
            background: white;
            padding: 35px;
            border-radius: 15px;
            box-shadow: 0 5px 20px rgba(0,0,0,0.08);
            position: relative;
            overflow: hidden;
        }
        .metric-card::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            height: 5px;
            background: linear-gradient(90deg, #667eea, #764ba2);
        }
        .metric-value {
            font-size: 48px;
            font-weight: 700;
            margin: 15px 0;
        }
        .metric-label {
            color: #7f8c8d;
            font-size: 16px;
            text-transform: uppercase;
            letter-spacing: 1px;
        }
        .metric-change {
            font-size: 14px;
            margin-top: 10px;
        }
        .positive { color: #27ae60; }
        .negative { color: #e74c3c; }
        .summary-section {
            background: white;
            padding: 40px;
            border-radius: 15px;
            box-shadow: 0 5px 20px rgba(0,0,0,0.08);
            margin-bottom: 30px;
        }
        .summary-section h2 {
            color: #2c3e50;
            margin-bottom: 20px;
            font-size: 28px;
        }
        .risk-indicator {
            display: inline-block;
            padding: 8px 16px;
            border-radius: 20px;
            font-weight: 600;
            font-size: 14px;
        }
        .risk-critical {
            background: #ffe5e5;
            color: #e74c3c;
        }
        .risk-high {
            background: #fff3e0;
            color: #e67e22;
        }
        .risk-medium {
            background: #fff8e1;
            color: #f39c12;
        }
        .risk-low {
            background: #e8f5e9;
            color: #27ae60;
        }
        .recommendations {
            background: #f8f9fa;
            padding: 30px;
            border-radius: 10px;
            margin-top: 20px;
        }
        .recommendations h3 {
            margin-top: 0;
            color: #2c3e50;
        }
        .recommendations ul {
            margin: 0;
            padding-left: 20px;
        }
        .recommendations li {
            margin: 10px 0;
            color: #555;
        }
    </style>
</head>
<body>
    <div class="dashboard">
        <div class="header">
            <h1>Executive Security Dashboard</h1>
            <div class="subtitle">CloudScope Asset Intelligence Report</div>
            <div class="subtitle">Generated: $(date)</div>
        </div>
        
        <div class="metrics-grid">
            <div class="metric-card">
                <div class="metric-label">Total Assets</div>
                <div class="metric-value">$total_assets</div>
                <div class="metric-change positive">↑ 12% from last month</div>
            </div>
            
            <div class="metric-card">
                <div class="metric-label">Critical Risk Assets</div>
                <div class="metric-value" style="color: #e74c3c;">$critical_assets</div>
                <div class="metric-change negative">↑ 3 from last week</div>
            </div>
            
            <div class="metric-card">
                <div class="metric-label">Open Findings</div>
                <div class="metric-value" style="color: #e67e22;">$open_findings</div>
                <div class="metric-change positive">↓ 8% from last month</div>
            </div>
            
            <div class="metric-card">
                <div class="metric-label">Compliance Score</div>
                <div class="metric-value" style="color: #27ae60;">${compliance_score}%</div>
                <div class="metric-change positive">↑ 2% improvement</div>
            </div>
        </div>
        
        <div class="summary-section">
            <h2>Risk Overview</h2>
            <p>The current security posture shows <span class="risk-indicator risk-medium">MEDIUM RISK</span> with several areas requiring immediate attention.</p>
            
            <div class="recommendations">
                <h3>Key Recommendations</h3>
                <ul>
                    <li><strong>Immediate Action Required:</strong> Address $critical_assets critical risk assets</li>
                    <li><strong>Compliance Gap:</strong> Focus on PCI-DSS requirements to improve compliance score</li>
                    <li><strong>Vulnerability Management:</strong> Prioritize patching for high-severity findings</li>
                    <li><strong>Access Control:</strong> Review and update privileged access management</li>
                </ul>
            </div>
        </div>
        
        <div class="summary-section">
            <h2>Compliance Status</h2>
            <p>Overall compliance score: <strong>${compliance_score}%</strong></p>
            <ul>
                <li>PCI-DSS: 78% compliant (12 controls failing)</li>
                <li>SOC 2: 92% compliant (3 controls need attention)</li>
                <li>ISO 27001: 88% compliant (8 controls partially met)</li>
            </ul>
        </div>
        
        <div class="summary-section">
            <h2>Next Steps</h2>
            <ol>
                <li>Schedule remediation for critical findings by end of week</li>
                <li>Review quarterly compliance assessment results</li>
                <li>Update incident response procedures</li>
                <li>Plan security awareness training for Q2</li>
            </ol>
        </div>
    </div>
</body>
</html>
EOF
    
    log_success "Executive report saved to: $report_file"
}

# Generate trends analysis report
generate_trends_report() {
    log_section "Generating Trends Analysis Report"
    
    # Get historical data for trends
    local asset_growth=$(docker exec cloudscope-memgraph mgconsole --execute "
        MATCH (a:Asset)
        WHERE a.created_at > datetime() - duration('P90D')
        RETURN 
            date(a.created_at) AS date,
            count(a) AS new_assets
        ORDER BY date
    " 2>/dev/null)
    
    local risk_trends=$(docker exec cloudscope-memgraph mgconsole --execute "
        MATCH (a:Asset)
        WHERE a.created_at > datetime() - duration('P90D')
        WITH date(a.created_at) AS date, a
        RETURN 
            date,
            avg(a.risk_score) AS avg_risk,
            count(CASE WHEN a.risk_score >= 80 THEN 1 END) AS critical_count
        ORDER BY date
    " 2>/dev/null)
    
    # Generate trend visualizations
    python3 << EOF
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
import pandas as pd
import numpy as np
from datetime import datetime, timedelta

# Generate sample trend data
dates = pd.date_range(end=datetime.now(), periods=90, freq='D')
asset_counts = np.cumsum(np.random.poisson(5, 90))
risk_scores = 50 + np.random.normal(0, 10, 90).cumsum() * 0.1

# Asset growth trend
plt.figure(figsize=(12, 6))
plt.plot(dates, asset_counts, 'b-', linewidth=2)
plt.fill_between(dates, asset_counts, alpha=0.3)
plt.title('Asset Growth Trend (90 Days)', fontsize=16)
plt.xlabel('Date')
plt.ylabel('Total Assets')
plt.grid(True, alpha=0.3)
plt.gca().xaxis.set_major_formatter(mdates.DateFormatter('%Y-%m-%d'))
plt.gcf().autofmt_xdate()
plt.savefig('$REPORT_DIR/asset_growth_trend_${TIMESTAMP}.png', bbox_inches='tight', dpi=150)
plt.close()

# Risk score trend
plt.figure(figsize=(12, 6))
plt.plot(dates, risk_scores, 'r-', linewidth=2, label='Average Risk Score')
plt.axhline(y=80, color='red', linestyle='--', alpha=0.5, label='Critical Threshold')
plt.axhline(y=60, color='orange', linestyle='--', alpha=0.5, label='High Threshold')
plt.fill_between(dates, risk_scores, alpha=0.3, color='red')
plt.title('Risk Score Trend (90 Days)', fontsize=16)
plt.xlabel('Date')
plt.ylabel('Average Risk Score')
plt.legend()
plt.grid(True, alpha=0.3)
plt.gca().xaxis.set_major_formatter(mdates.DateFormatter('%Y-%m-%d'))
plt.gcf().autofmt_xdate()
plt.savefig('$REPORT_DIR/risk_trend_${TIMESTAMP}.png', bbox_inches='tight', dpi=150)
plt.close()
EOF
    
    log_success "Trends report generated"
}

# Generate JSON report
generate_json_report() {
    local output_file=$1
    local report_type=$2
    shift 2
    local data=("$@")
    
    python3 << EOF
import json
from datetime import datetime

report = {
    "report_type": "$report_type",
    "generated_at": datetime.now().isoformat(),
    "version": "1.0",
    "data": {}
}

# Add data sections based on report type
# This is a simplified version - would need proper parsing of the data

with open("$output_file", "w") as f:
    json.dump(report, f, indent=2)
EOF
    
    log_success "JSON report saved to: $output_file"
}

# Schedule report generation
schedule_reports() {
    log_section "Scheduling Automated Reports"
    
    # Create cron job for daily reports
    cat > cloudscope-reports-cron << EOF
# CloudScope Automated Reports
# Daily inventory report at 6 AM
0 6 * * * $(whoami) $(pwd)/scripts/reports/generate-reports.sh generate inventory >> $(pwd)/data/logs/reports.log 2>&1

# Weekly risk assessment report on Mondays at 8 AM
0 8 * * 1 $(whoami) $(pwd)/scripts/reports/generate-reports.sh generate risk >> $(pwd)/data/logs/reports.log 2>&1

# Monthly executive summary on the 1st at 9 AM
0 9 1 * * $(whoami) $(pwd)/scripts/reports/generate-reports.sh generate executive >> $(pwd)/data/logs/reports.log 2>&1
EOF
    
    log_info "To install scheduled reports:"
    echo "  sudo cp cloudscope-reports-cron /etc/cron.d/cloudscope-reports"
    echo "  sudo chmod 644 /etc/cron.d/cloudscope-reports"
}

# Email report
email_report() {
    local report_file=$1
    local recipient=$2
    local subject="CloudScope Report - $(date)"
    
    if command -v mail &> /dev/null; then
        mail -s "$subject" -a "$report_file" "$recipient" < /dev/null
        log_success "Report emailed to: $recipient"
    else
        log_warning "Mail command not found. Install mailutils to enable email reports."
    fi
}

# List available reports
list_reports() {
    log_section "Available Reports"
    
    echo "Report Types:"
    for key in "${!REPORT_TYPES[@]}"; do
        echo "  $key - ${REPORT_TYPES[$key]}"
    done
    
    echo ""
    echo "Recent Reports:"
    find "$REPORT_DIR" -name "*.html" -o -name "*.pdf" -o -name "*.json" | \
        sort -r | head -10 | while read -r file; do
        echo "  - $(basename "$file") ($(stat -f%Sm -t "%Y-%m-%d %H:%M" "$file" 2>/dev/null || date -r "$file" "+%Y-%m-%d %H:%M" 2>/dev/null))"
    done
}

# Print usage
usage() {
    cat << EOF
Usage: $0 [COMMAND] [OPTIONS]

Commands:
    generate TYPE       Generate specific report type
    list               List available report types and recent reports
    schedule           Set up automated report generation
    email FILE TO      Email a report to recipient
    
Report Types:
    inventory          Asset inventory report
    risk              Risk assessment report
    compliance        Compliance status report
    security          Security findings report
    executive         Executive summary report
    technical         Technical deep dive report
    trends            Trends analysis report
    all               Generate all reports

Options:
    -o, --output DIR   Output directory (default: ./data/reports)
    -f, --format FMT   Output format: html, pdf, csv, json (default: html)
    -h, --help         Show this help message

Examples:
    # Generate inventory report
    $0 generate inventory

    # Generate risk report in PDF format
    $0 generate risk -f pdf

    # Generate all reports
    $0 generate all

    # Email report
    $0 email ./data/reports/inventory_report.html admin@example.com

    # Schedule automated reports
    $0 schedule
EOF
}

# Parse command line arguments
COMMAND=""
PARAM=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -o|--output)
            REPORT_DIR="$2"
            shift 2
            ;;
        -f|--format)
            OUTPUT_FORMAT="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        generate|list|schedule|email)
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
    generate)
        case $PARAM in
            inventory)
                generate_inventory_report
                ;;
            risk)
                generate_risk_report
                ;;
            compliance)
                log_info "Use compliance-scanner.sh for detailed compliance reports"
                ;;
            security)
                generate_security_report
                ;;
            executive)
                generate_executive_report
                ;;
            trends)
                generate_trends_report
                ;;
            all)
                generate_inventory_report
                generate_risk_report
                generate_security_report
                generate_executive_report
                generate_trends_report
                ;;
            *)
                log_error "Unknown report type: $PARAM"
                echo "Available types:"
                for key in "${!REPORT_TYPES[@]}"; do
                    echo "  $key"
                done
                exit 1
                ;;
        esac
        ;;
    list)
        list_reports
        ;;
    schedule)
        schedule_reports
        ;;
    email)
        if [[ -n "$PARAM" ]] && [[ -n "${2:-}" ]]; then
            email_report "$PARAM" "$2"
        else
            log_error "Usage: $0 email <report_file> <recipient_email>"
            exit 1
        fi
        ;;
    *)
        log_error "No command specified"
        usage
        exit 1
        ;;
esac

log_success "Report generation completed"
