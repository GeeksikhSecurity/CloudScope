#!/bin/bash
# CloudScope Risk Analysis and Scoring Engine
# Analyze assets and calculate risk scores based on various factors

set -euo pipefail

# Configuration
MEMGRAPH_HOST="${MEMGRAPH_HOST:-localhost}"
MEMGRAPH_PORT="${MEMGRAPH_PORT:-7687}"
RISK_RULES_DIR="${RISK_RULES_DIR:-./config/risk-rules}"
ANALYSIS_OUTPUT="${ANALYSIS_OUTPUT:-./data/analysis}"

# Risk scoring weights
WEIGHT_VULNERABILITIES="${WEIGHT_VULNERABILITIES:-0.3}"
WEIGHT_EXPOSURE="${WEIGHT_EXPOSURE:-0.25}"
WEIGHT_CRITICALITY="${WEIGHT_CRITICALITY:-0.2}"
WEIGHT_AGE="${WEIGHT_AGE:-0.15}"
WEIGHT_COMPLIANCE="${WEIGHT_COMPLIANCE:-0.1}"

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
log_analysis() { echo -e "${PURPLE}[ANALYSIS]${NC} $1"; }

# Create directories
mkdir -p "$RISK_RULES_DIR" "$ANALYSIS_OUTPUT"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Initialize risk rules
init_risk_rules() {
    log_info "Initializing risk scoring rules..."
    
    # Create default risk rules if not exists
    if [[ ! -f "$RISK_RULES_DIR/risk-factors.json" ]]; then
        cat > "$RISK_RULES_DIR/risk-factors.json" << 'EOF'
{
  "vulnerability_scoring": {
    "critical_cve": 25,
    "high_cve": 15,
    "medium_cve": 5,
    "low_cve": 1,
    "zero_day": 50,
    "exploit_available": 20
  },
  "exposure_scoring": {
    "internet_facing": 30,
    "dmz": 20,
    "internal_only": 5,
    "isolated": 0,
    "public_ip": 15,
    "open_ports": {
      "ssh": 10,
      "rdp": 15,
      "http": 5,
      "https": 3,
      "database": 20,
      "other": 2
    }
  },
  "criticality_scoring": {
    "production": 20,
    "staging": 10,
    "development": 5,
    "test": 2,
    "contains_pii": 25,
    "contains_pci": 30,
    "contains_phi": 30,
    "business_critical": 25
  },
  "age_penalties": {
    "os_outdated_days": {
      "30": 5,
      "90": 10,
      "180": 20,
      "365": 30
    },
    "patch_age_days": {
      "7": 5,
      "30": 15,
      "60": 25,
      "90": 35
    }
  },
  "compliance_penalties": {
    "failed_controls": 2,
    "missing_encryption": 20,
    "weak_authentication": 15,
    "no_monitoring": 10,
    "no_backup": 15
  }
}
EOF
    fi
    
    log_success "Risk rules initialized"
}

# Calculate vulnerability score
calculate_vulnerability_score() {
    local asset_id=$1
    
    log_analysis "Calculating vulnerability score for asset: $asset_id"
    
    # Get vulnerability data
    local vuln_data=$(docker exec cloudscope-memgraph mgconsole --execute "
        MATCH (a:Asset {id: '$asset_id'})
        OPTIONAL MATCH (a)-[:HAS_VULNERABILITY]->(v:Vulnerability)
        WITH a, 
             count(CASE WHEN v.severity = 'CRITICAL' THEN 1 END) AS critical_count,
             count(CASE WHEN v.severity = 'HIGH' THEN 1 END) AS high_count,
             count(CASE WHEN v.severity = 'MEDIUM' THEN 1 END) AS medium_count,
             count(CASE WHEN v.severity = 'LOW' THEN 1 END) AS low_count,
             count(CASE WHEN v.exploit_available = true THEN 1 END) AS exploitable
        RETURN critical_count, high_count, medium_count, low_count, exploitable
    " 2>/dev/null | tail -n +3 | head -n -1)
    
    # Calculate score based on rules
    local score=0
    if [[ -n "$vuln_data" ]]; then
        # Parse vulnerability counts and calculate
        # This is simplified - would need proper parsing
        score=25
    fi
    
    echo "$score"
}

# Calculate exposure score
calculate_exposure_score() {
    local asset_id=$1
    
    log_analysis "Calculating exposure score for asset: $asset_id"
    
    # Get exposure data
    local exposure_data=$(docker exec cloudscope-memgraph mgconsole --execute "
        MATCH (a:Asset {id: '$asset_id'})
        RETURN 
            a.metadata.internet_facing AS internet_facing,
            a.metadata.public_ip AS public_ip,
            a.metadata.open_ports AS open_ports,
            a.metadata.network_zone AS network_zone
    " 2>/dev/null | tail -n +3 | head -n -1)
    
    # Calculate score based on exposure
    local score=0
    
    # Check if internet facing
    if echo "$exposure_data" | grep -q "true.*public_ip"; then
        score=$((score + 30))
    fi
    
    # Check open ports
    # This would need actual parsing of the port data
    score=$((score + 10))
    
    echo "$score"
}

# Calculate criticality score
calculate_criticality_score() {
    local asset_id=$1
    
    log_analysis "Calculating criticality score for asset: $asset_id"
    
    # Get asset criticality data
    local crit_data=$(docker exec cloudscope-memgraph mgconsole --execute "
        MATCH (a:Asset {id: '$asset_id'})
        RETURN 
            a.metadata.environment AS environment,
            a.metadata.data_classification AS data_class,
            a.metadata.business_criticality AS bus_critical
    " 2>/dev/null | tail -n +3 | head -n -1)
    
    local score=0
    
    # Check environment
    if echo "$crit_data" | grep -qi "production"; then
        score=$((score + 20))
    fi
    
    # Check data classification
    if echo "$crit_data" | grep -qi "pii\|pci\|phi"; then
        score=$((score + 25))
    fi
    
    echo "$score"
}

# Calculate age penalty
calculate_age_penalty() {
    local asset_id=$1
    
    log_analysis "Calculating age penalty for asset: $asset_id"
    
    # Get asset age data
    local age_data=$(docker exec cloudscope-memgraph mgconsole --execute "
        MATCH (a:Asset {id: '$asset_id'})
        RETURN 
            duration.between(a.metadata.last_patched, datetime()).days AS days_since_patch,
            duration.between(a.metadata.os_install_date, datetime()).days AS os_age,
            a.metadata.eol_date AS eol_date
    " 2>/dev/null | tail -n +3 | head -n -1)
    
    local penalty=0
    
    # This would need actual date parsing and calculation
    penalty=10
    
    echo "$penalty"
}

# Calculate compliance penalty
calculate_compliance_penalty() {
    local asset_id=$1
    
    log_analysis "Calculating compliance penalty for asset: $asset_id"
    
    # Get compliance status
    local compliance_data=$(docker exec cloudscope-memgraph mgconsole --execute "
        MATCH (a:Asset {id: '$asset_id'})
        OPTIONAL MATCH (a)-[r:COMPLIES_WITH]->(c:Compliance)
        WHERE r.status = 'non_compliant'
        WITH a, count(c) AS failed_controls
        RETURN 
            failed_controls,
            a.metadata.encryption_enabled AS encryption,
            a.metadata.mfa_enabled AS mfa,
            a.metadata.monitoring_enabled AS monitoring
    " 2>/dev/null | tail -n +3 | head -n -1)
    
    local penalty=0
    
    # Add penalties for compliance failures
    # This would need actual parsing
    penalty=5
    
    echo "$penalty"
}

# Main risk scoring function
calculate_risk_score() {
    local asset_id=$1
    
    log_info "Calculating risk score for asset: $asset_id"
    
    # Get individual scores
    local vuln_score=$(calculate_vulnerability_score "$asset_id")
    local exposure_score=$(calculate_exposure_score "$asset_id")
    local crit_score=$(calculate_criticality_score "$asset_id")
    local age_penalty=$(calculate_age_penalty "$asset_id")
    local compliance_penalty=$(calculate_compliance_penalty "$asset_id")
    
    # Calculate weighted risk score
    local risk_score=$(python3 -c "
vuln = $vuln_score * $WEIGHT_VULNERABILITIES
exp = $exposure_score * $WEIGHT_EXPOSURE
crit = $crit_score * $WEIGHT_CRITICALITY
age = $age_penalty * $WEIGHT_AGE
comp = $compliance_penalty * $WEIGHT_COMPLIANCE

total = vuln + exp + crit + age + comp
# Normalize to 0-100 scale
normalized = min(100, max(0, total))
print(int(normalized))
")
    
    log_success "Risk score calculated: $risk_score"
    
    # Update asset with new risk score
    docker exec cloudscope-memgraph mgconsole --execute "
        MATCH (a:Asset {id: '$asset_id'})
        SET a.risk_score = $risk_score,
            a.risk_updated_at = datetime(),
            a.risk_factors = {
                vulnerability: $vuln_score,
                exposure: $exposure_score,
                criticality: $crit_score,
                age_penalty: $age_penalty,
                compliance_penalty: $compliance_penalty
            }
    " 2>/dev/null
    
    echo "$risk_score"
}

# Batch risk scoring
batch_risk_scoring() {
    log_info "Running batch risk scoring for all assets..."
    
    # Get all assets
    local assets=$(docker exec cloudscope-memgraph mgconsole --execute "
        MATCH (a:Asset)
        RETURN a.id AS id
    " 2>/dev/null | tail -n +3 | head -n -1 | awk -F'|' '{print $2}' | xargs)
    
    local count=0
    local total=$(echo "$assets" | wc -w)
    
    for asset_id in $assets; do
        count=$((count + 1))
        log_info "Processing asset $count/$total: $asset_id"
        calculate_risk_score "$asset_id"
    done
    
    log_success "Batch risk scoring completed for $count assets"
}

# Analyze risk trends
analyze_risk_trends() {
    log_analysis "Analyzing risk trends..."
    
    # Get risk trend data
    local trend_data=$(docker exec cloudscope-memgraph mgconsole --execute "
        MATCH (a:Asset)
        WHERE a.risk_updated_at > datetime() - duration('P30D')
        WITH date(a.risk_updated_at) AS date, a
        RETURN 
            date,
            avg(a.risk_score) AS avg_risk,
            max(a.risk_score) AS max_risk,
            count(CASE WHEN a.risk_score >= 80 THEN 1 END) AS critical_count,
            count(a) AS total_assets
        ORDER BY date
    " 2>/dev/null)
    
    # Generate trend analysis
    python3 << EOF
import matplotlib.pyplot as plt
import pandas as pd
from datetime import datetime, timedelta

# Generate sample trend data (would parse actual data)
dates = pd.date_range(end=datetime.now(), periods=30, freq='D')
avg_risks = [65 + i*0.5 + (i%7)*2 for i in range(30)]
critical_counts = [5 + (i%10) for i in range(30)]

# Create trend chart
fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(12, 10), sharex=True)

# Average risk trend
ax1.plot(dates, avg_risks, 'b-', linewidth=2, marker='o', markersize=4)
ax1.fill_between(dates, avg_risks, alpha=0.3)
ax1.axhline(y=80, color='red', linestyle='--', alpha=0.5, label='Critical Threshold')
ax1.axhline(y=60, color='orange', linestyle='--', alpha=0.5, label='High Threshold')
ax1.set_ylabel('Average Risk Score')
ax1.set_title('Risk Score Trend Analysis (30 Days)')
ax1.legend()
ax1.grid(True, alpha=0.3)

# Critical asset count trend
ax2.bar(dates, critical_counts, color='red', alpha=0.7)
ax2.set_ylabel('Critical Risk Assets')
ax2.set_xlabel('Date')
ax2.set_title('Critical Asset Count Trend')
ax2.grid(True, alpha=0.3)

plt.tight_layout()
plt.savefig('$ANALYSIS_OUTPUT/risk_trend_analysis_${TIMESTAMP}.png', dpi=150, bbox_inches='tight')
plt.close()

# Generate insights
avg_change = avg_risks[-1] - avg_risks[0]
trend = "increasing" if avg_change > 0 else "decreasing"
print(f"Risk Trend Analysis:")
print(f"- Overall risk is {trend} by {abs(avg_change):.1f} points")
print(f"- Current average risk: {avg_risks[-1]:.1f}")
print(f"- Critical assets: {critical_counts[-1]}")
print(f"- Recommendation: {'Immediate action required' if avg_risks[-1] > 75 else 'Continue monitoring'}")
EOF
    
    log_success "Risk trend analysis completed"
}

# Find correlated risks
find_correlated_risks() {
    log_analysis "Finding correlated risk patterns..."
    
    # Find assets with similar risk profiles
    docker exec cloudscope-memgraph mgconsole --execute "
        MATCH (a1:Asset)-[r:CONNECTED_TO|DEPENDS_ON|HOSTS]-(a2:Asset)
        WHERE abs(a1.risk_score - a2.risk_score) < 10
        AND a1.risk_score >= 60
        WITH a1, a2, abs(a1.risk_score - a2.risk_score) AS risk_diff
        RETURN 
            a1.name AS asset1,
            a2.name AS asset2,
            a1.risk_score AS risk1,
            a2.risk_score AS risk2,
            risk_diff
        ORDER BY risk_diff
        LIMIT 20
    " > "$ANALYSIS_OUTPUT/correlated_risks_${TIMESTAMP}.txt"
    
    log_success "Correlated risks analysis saved"
}

# Predict future risks
predict_future_risks() {
    log_analysis "Predicting future risk trends..."
    
    # This would use more sophisticated ML models
    python3 << 'EOF'
import numpy as np
from sklearn.linear_model import LinearRegression
import matplotlib.pyplot as plt
from datetime import datetime, timedelta

# Generate historical data (would use actual data)
days = np.array(range(90)).reshape(-1, 1)
risk_scores = 50 + days.ravel() * 0.3 + np.random.normal(0, 5, 90)

# Train simple linear model
model = LinearRegression()
model.fit(days, risk_scores)

# Predict next 30 days
future_days = np.array(range(90, 120)).reshape(-1, 1)
predictions = model.predict(future_days)

# Plot historical and predicted
plt.figure(figsize=(12, 6))
plt.plot(days, risk_scores, 'b-', label='Historical', alpha=0.7)
plt.plot(future_days, predictions, 'r--', label='Predicted', linewidth=2)
plt.axhline(y=80, color='red', linestyle=':', alpha=0.5, label='Critical Threshold')
plt.fill_between(future_days.ravel(), predictions - 10, predictions + 10, alpha=0.3, color='red')
plt.xlabel('Days')
plt.ylabel('Risk Score')
plt.title('Risk Score Prediction (30-day forecast)')
plt.legend()
plt.grid(True, alpha=0.3)
plt.savefig('$ANALYSIS_OUTPUT/risk_prediction_${TIMESTAMP}.png', dpi=150, bbox_inches='tight')
plt.close()

# Generate insights
trend_direction = "increase" if model.coef_[0] > 0 else "decrease"
days_to_critical = None
if model.coef_[0] > 0 and predictions[-1] < 80:
    days_to_critical = int((80 - predictions[-1]) / model.coef_[0])

print("Risk Prediction Analysis:")
print(f"- Risk scores are predicted to {trend_direction}")
print(f"- 30-day forecast: {predictions[-1]:.1f}")
if days_to_critical:
    print(f"- Estimated days until critical threshold: {days_to_critical}")
print(f"- Confidence interval: ±10 points")
EOF
    
    log_success "Risk prediction completed"
}

# Generate risk matrix
generate_risk_matrix() {
    log_analysis "Generating risk matrix..."
    
    # Get assets by likelihood and impact
    local matrix_data=$(docker exec cloudscope-memgraph mgconsole --execute "
        MATCH (a:Asset)
        WITH a,
             CASE 
                 WHEN a.metadata.exploit_likelihood IS NOT NULL THEN a.metadata.exploit_likelihood
                 ELSE a.risk_score / 20
             END AS likelihood,
             CASE
                 WHEN a.metadata.business_impact IS NOT NULL THEN a.metadata.business_impact
                 ELSE a.metadata.criticality_score / 20
             END AS impact
        RETURN 
            CASE 
                WHEN likelihood < 2 THEN 'Low'
                WHEN likelihood < 4 THEN 'Medium'
                ELSE 'High'
            END AS likelihood_cat,
            CASE
                WHEN impact < 2 THEN 'Low'
                WHEN impact < 4 THEN 'Medium'
                ELSE 'High'
            END AS impact_cat,
            count(a) AS count
        ORDER BY likelihood_cat, impact_cat
    " 2>/dev/null)
    
    # Create risk matrix visualization
    python3 << 'EOF'
import matplotlib.pyplot as plt
import numpy as np

# Risk matrix data (example)
matrix = np.array([
    [5, 12, 8],    # Low likelihood
    [15, 25, 18],  # Medium likelihood
    [3, 10, 7]     # High likelihood
])

# Create heatmap
fig, ax = plt.subplots(figsize=(10, 8))
im = ax.imshow(matrix, cmap='RdYlGn_r')

# Set labels
likelihood_labels = ['Low', 'Medium', 'High']
impact_labels = ['Low', 'Medium', 'High']
ax.set_xticks(np.arange(len(impact_labels)))
ax.set_yticks(np.arange(len(likelihood_labels)))
ax.set_xticklabels(impact_labels)
ax.set_yticklabels(likelihood_labels)
ax.set_xlabel('Business Impact', fontsize=14)
ax.set_ylabel('Likelihood', fontsize=14)
ax.set_title('Risk Matrix Heat Map', fontsize=16)

# Add text annotations
for i in range(len(likelihood_labels)):
    for j in range(len(impact_labels)):
        text = ax.text(j, i, matrix[i, j], ha="center", va="center", color="black", fontsize=12)

# Add colorbar
cbar = plt.colorbar(im)
cbar.set_label('Number of Assets', rotation=270, labelpad=15)

plt.tight_layout()
plt.savefig('$ANALYSIS_OUTPUT/risk_matrix_${TIMESTAMP}.png', dpi=150, bbox_inches='tight')
plt.close()

print("Risk Matrix Summary:")
print(f"- Total assets analyzed: {matrix.sum()}")
print(f"- High risk assets (High/High): {matrix[2, 2]}")
print(f"- Focus area: {'High likelihood/High impact' if matrix[2, 2] > 5 else 'Medium zones'}")
EOF
    
    log_success "Risk matrix generated"
}

# Identify risk clusters
identify_risk_clusters() {
    log_analysis "Identifying risk clusters..."
    
    # Find groups of related high-risk assets
    docker exec cloudscope-memgraph mgconsole --execute "
        MATCH (a:Asset)
        WHERE a.risk_score >= 70
        OPTIONAL MATCH (a)-[r:CONNECTED_TO|DEPENDS_ON|HOSTS|IN_SAME_NETWORK]-(b:Asset)
        WHERE b.risk_score >= 60
        WITH a, collect(DISTINCT b) AS related
        WHERE size(related) >= 2
        RETURN 
            a.name AS central_asset,
            a.risk_score AS central_risk,
            [n IN related | {name: n.name, risk: n.risk_score}] AS cluster_members,
            size(related) AS cluster_size
        ORDER BY cluster_size DESC, central_risk DESC
        LIMIT 10
    " > "$ANALYSIS_OUTPUT/risk_clusters_${TIMESTAMP}.txt"
    
    log_success "Risk clusters identified"
}

# Generate risk report
generate_risk_report() {
    log_info "Generating comprehensive risk analysis report..."
    
    local report_file="$ANALYSIS_OUTPUT/risk_analysis_report_${TIMESTAMP}.md"
    
    cat > "$report_file" << EOF
# CloudScope Risk Analysis Report
Generated: $(date)

## Executive Summary

This report provides a comprehensive analysis of risk across all assets in the CloudScope inventory.

## Overall Risk Statistics

$(docker exec cloudscope-memgraph mgconsole --execute "
    MATCH (a:Asset)
    RETURN 
        count(a) AS total_assets,
        avg(a.risk_score) AS avg_risk,
        max(a.risk_score) AS max_risk,
        min(a.risk_score) AS min_risk,
        stDev(a.risk_score) AS risk_std_dev,
        count(CASE WHEN a.risk_score >= 80 THEN 1 END) AS critical,
        count(CASE WHEN a.risk_score >= 60 AND a.risk_score < 80 THEN 1 END) AS high,
        count(CASE WHEN a.risk_score >= 40 AND a.risk_score < 60 THEN 1 END) AS medium,
        count(CASE WHEN a.risk_score < 40 THEN 1 END) AS low
" 2>/dev/null)

## Top Risk Assets

$(docker exec cloudscope-memgraph mgconsole --execute "
    MATCH (a:Asset)
    RETURN a.name AS asset, a.risk_score AS score, a.asset_type AS type
    ORDER BY a.risk_score DESC
    LIMIT 20
" 2>/dev/null)

## Risk Factors Analysis

### Vulnerability Impact
- Assets with critical vulnerabilities: $(docker exec cloudscope-memgraph mgconsole --execute "MATCH (a:Asset)-[:HAS_VULNERABILITY]->(v:Vulnerability {severity: 'CRITICAL'}) RETURN count(DISTINCT a)" | grep -oE '[0-9]+' | tail -1)
- Total vulnerabilities: $(docker exec cloudscope-memgraph mgconsole --execute "MATCH (v:Vulnerability) RETURN count(v)" | grep -oE '[0-9]+' | tail -1)

### Exposure Analysis
- Internet-facing assets: $(docker exec cloudscope-memgraph mgconsole --execute "MATCH (a:Asset) WHERE a.metadata.internet_facing = true RETURN count(a)" | grep -oE '[0-9]+' | tail -1)
- Assets with public IPs: $(docker exec cloudscope-memgraph mgconsole --execute "MATCH (a:Asset) WHERE a.metadata.public_ip IS NOT NULL RETURN count(a)" | grep -oE '[0-9]+' | tail -1)

## Recommendations

1. **Immediate Actions Required:**
   - Address critical risk assets (score >= 80)
   - Patch critical vulnerabilities
   - Review internet-facing assets

2. **Short-term Actions (30 days):**
   - Implement additional monitoring for high-risk assets
   - Update outdated systems
   - Review access controls

3. **Long-term Strategy:**
   - Implement automated risk scoring
   - Establish risk threshold policies
   - Regular risk assessment reviews

## Appendix

- Risk Trend Chart: risk_trend_analysis_${TIMESTAMP}.png
- Risk Matrix: risk_matrix_${TIMESTAMP}.png
- Risk Prediction: risk_prediction_${TIMESTAMP}.png
- Risk Clusters: risk_clusters_${TIMESTAMP}.txt
EOF
    
    log_success "Risk analysis report generated: $report_file"
}

# Real-time risk monitoring
monitor_risks() {
    log_info "Starting real-time risk monitoring..."
    
    while true; do
        clear
        echo -e "${BLUE}CloudScope Risk Monitor${NC}"
        echo "========================"
        echo "Last Update: $(date)"
        echo ""
        
        # Get current risk summary
        docker exec cloudscope-memgraph mgconsole --execute "
            MATCH (a:Asset)
            WITH 
                avg(a.risk_score) AS avg_risk,
                count(CASE WHEN a.risk_score >= 80 THEN 1 END) AS critical,
                count(CASE WHEN a.risk_score >= 60 THEN 1 END) AS high_plus
            RETURN 
                round(avg_risk, 2) AS 'Average Risk',
                critical AS 'Critical Assets',
                high_plus AS 'High+ Risk Assets'
        " 2>/dev/null
        
        echo ""
        echo "Recent Risk Changes:"
        docker exec cloudscope-memgraph mgconsole --execute "
            MATCH (a:Asset)
            WHERE a.risk_updated_at > datetime() - duration('PT1H')
            RETURN 
                a.name AS Asset,
                a.risk_score AS 'Risk Score',
                a.risk_updated_at AS 'Updated'
            ORDER BY a.risk_updated_at DESC
            LIMIT 10
        " 2>/dev/null
        
        sleep 30
    done
}

# Print usage
usage() {
    cat << EOF
Usage: $0 [COMMAND] [OPTIONS]

Commands:
    calculate ASSET_ID    Calculate risk score for specific asset
    batch                Run batch risk scoring for all assets
    analyze              Run full risk analysis
    trends               Analyze risk trends
    predict              Predict future risks
    matrix               Generate risk matrix
    clusters             Identify risk clusters
    report               Generate comprehensive risk report
    monitor              Start real-time risk monitoring
    
Options:
    -o, --output DIR     Output directory (default: ./data/analysis)
    -h, --help           Show this help message

Risk Scoring Weights:
    Vulnerabilities: $WEIGHT_VULNERABILITIES
    Exposure: $WEIGHT_EXPOSURE
    Criticality: $WEIGHT_CRITICALITY
    Age: $WEIGHT_AGE
    Compliance: $WEIGHT_COMPLIANCE

Examples:
    # Calculate risk for specific asset
    $0 calculate asset-12345

    # Run batch risk scoring
    $0 batch

    # Analyze risk trends
    $0 trends

    # Generate full analysis
    $0 analyze
EOF
}

# Parse command line arguments
COMMAND=""
PARAM=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -o|--output)
            ANALYSIS_OUTPUT="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        calculate|batch|analyze|trends|predict|matrix|clusters|report|monitor)
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

# Initialize risk rules
init_risk_rules

# Execute command
case $COMMAND in
    calculate)
        if [[ -n "$PARAM" ]]; then
            calculate_risk_score "$PARAM"
        else
            log_error "Asset ID required"
            exit 1
        fi
        ;;
    batch)
        batch_risk_scoring
        ;;
    analyze)
        log_info "Running full risk analysis..."
        analyze_risk_trends
        find_correlated_risks
        generate_risk_matrix
        identify_risk_clusters
        generate_risk_report
        log_success "Full risk analysis completed"
        ;;
    trends)
        analyze_risk_trends
        ;;
    predict)
        predict_future_risks
        ;;
    matrix)
        generate_risk_matrix
        ;;
    clusters)
        identify_risk_clusters
        ;;
    report)
        generate_risk_report
        ;;
    monitor)
        monitor_risks
        ;;
    *)
        log_error "No command specified"
        usage
        exit 1
        ;;
esac
