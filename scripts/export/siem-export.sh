#!/bin/bash
# CloudScope SIEM Export Script
# Export CloudScope data to various SIEM platforms

set -euo pipefail

# Configuration
EXPORT_DIR="${EXPORT_DIR:-./data/exports}"
CONFIG_FILE="${CONFIG_FILE:-./config/cloudscope-config.json}"
MEMGRAPH_HOST="${MEMGRAPH_HOST:-localhost}"
MEMGRAPH_PORT="${MEMGRAPH_PORT:-7687}"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Create export directory
mkdir -p "$EXPORT_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Export to CrowdStrike format
export_crowdstrike() {
    log_info "Exporting data for CrowdStrike..."
    
    OUTPUT_FILE="$EXPORT_DIR/crowdstrike_assets_${TIMESTAMP}.json"
    
    # Query Memgraph and format for CrowdStrike
    cat << 'EOF' | docker exec -i cloudscope-memgraph mgconsole --output-format=json > "$OUTPUT_FILE.tmp"
MATCH (a:Asset)
OPTIONAL MATCH (a)-[:TAGGED_WITH]->(t:Tag)
OPTIONAL MATCH (a)-[:HAS_FINDING]->(f:Finding)
WITH a, collect(DISTINCT {key: t.key, value: t.value}) AS tags, collect(DISTINCT f) AS findings
RETURN {
    aid: a.id,
    hostname: a.name,
    platform_name: a.asset_type,
    os_version: coalesce(a.metadata.os_version, 'Unknown'),
    agent_version: 'CloudScope-1.0.0',
    last_seen: a.updated_at,
    tags: tags,
    device_policies: {
        prevention_policy: 'Standard',
        sensor_update_policy: 'Default'
    },
    device_status: CASE 
        WHEN a.risk_score >= 80 THEN 'Critical'
        WHEN a.risk_score >= 60 THEN 'High'
        WHEN a.risk_score >= 40 THEN 'Medium'
        ELSE 'Normal'
    END,
    findings: [f IN findings | {
        detection_id: f.id,
        detection_name: f.title,
        severity: f.severity,
        tactic: coalesce(f.tactic, 'Unknown'),
        technique: coalesce(f.technique, 'Unknown'),
        created_timestamp: f.created_at
    }]
} AS asset
EOF
    
    # Format the output for CrowdStrike API
    python3 -c "
import json
import sys

with open('$OUTPUT_FILE.tmp', 'r') as f:
    data = json.load(f)

# Transform to CrowdStrike format
crowdstrike_data = {
    'meta': {
        'query_time': '$TIMESTAMP',
        'powered_by': 'CloudScope',
        'version': '1.0.0'
    },
    'resources': [item['asset'] for item in data if 'asset' in item]
}

with open('$OUTPUT_FILE', 'w') as f:
    json.dump(crowdstrike_data, f, indent=2)
"
    
    rm -f "$OUTPUT_FILE.tmp"
    log_success "CrowdStrike export saved to: $OUTPUT_FILE"
}

# Export to Splunk format
export_splunk() {
    log_info "Exporting data for Splunk..."
    
    OUTPUT_FILE="$EXPORT_DIR/splunk_assets_${TIMESTAMP}.json"
    
    # Query Memgraph and format for Splunk
    cat << 'EOF' | docker exec -i cloudscope-memgraph mgconsole --output-format=json > "$OUTPUT_FILE.tmp"
MATCH (a:Asset)
OPTIONAL MATCH (a)-[:TAGGED_WITH]->(t:Tag)
OPTIONAL MATCH (a)-[:HAS_FINDING]->(f:Finding)
OPTIONAL MATCH (a)-[:COMPLIES_WITH]->(c:Compliance)
WITH a, 
     collect(DISTINCT {key: t.key, value: t.value}) AS tags,
     collect(DISTINCT f) AS findings,
     collect(DISTINCT c) AS compliance
RETURN {
    time: datetime(),
    source: 'cloudscope',
    sourcetype: 'cloudscope:asset',
    host: a.name,
    event: {
        asset_id: a.id,
        asset_name: a.name,
        asset_type: a.asset_type,
        source_system: a.source,
        risk_score: a.risk_score,
        created_at: a.created_at,
        updated_at: a.updated_at,
        metadata: a.metadata,
        tags: tags,
        compliance_status: [c IN compliance | {
            framework: c.framework,
            requirement: c.requirement,
            status: 'compliant'
        }],
        security_findings: [f IN findings | {
            finding_id: f.id,
            title: f.title,
            severity: f.severity,
            status: f.status
        }]
    }
} AS splunk_event
EOF
    
    # Convert to Splunk HEC format
    python3 -c "
import json
import sys
import time

with open('$OUTPUT_FILE.tmp', 'r') as f:
    data = json.load(f)

# Write as newline-delimited JSON for Splunk HEC
with open('$OUTPUT_FILE', 'w') as f:
    for item in data:
        if 'splunk_event' in item:
            event = item['splunk_event']
            # Add timestamp in epoch format
            event['time'] = int(time.time())
            f.write(json.dumps(event) + '\n')
"
    
    rm -f "$OUTPUT_FILE.tmp"
    log_success "Splunk export saved to: $OUTPUT_FILE"
}

# Export to Microsoft Sentinel format
export_sentinel() {
    log_info "Exporting data for Microsoft Sentinel..."
    
    OUTPUT_FILE="$EXPORT_DIR/sentinel_assets_${TIMESTAMP}.json"
    
    # Query Memgraph and format for Sentinel
    cat << 'EOF' | docker exec -i cloudscope-memgraph mgconsole --output-format=json > "$OUTPUT_FILE.tmp"
MATCH (a:Asset)
OPTIONAL MATCH (a)-[:TAGGED_WITH]->(t:Tag)
OPTIONAL MATCH (a)-[:HAS_FINDING]->(f:Finding)
WITH a, collect(DISTINCT t) AS tags, collect(DISTINCT f) AS findings
RETURN {
    TimeGenerated: datetime(),
    SourceSystem: 'CloudScope',
    Computer: a.name,
    AssetId_s: a.id,
    AssetName_s: a.name,
    AssetType_s: a.asset_type,
    AssetSource_s: a.source,
    RiskScore_d: toFloat(a.risk_score),
    CreatedAt_t: a.created_at,
    UpdatedAt_t: a.updated_at,
    Tags_s: [t IN tags | t.key + '=' + t.value],
    Metadata_s: a.metadata,
    FindingCount_d: size(findings),
    HighSeverityFindings_d: size([f IN findings WHERE f.severity = 'HIGH']),
    CriticalSeverityFindings_d: size([f IN findings WHERE f.severity = 'CRITICAL']),
    Type: 'CloudScope_Asset_CL'
} AS sentinel_event
EOF
    
    # Format for Azure Monitor Data Collector API
    python3 -c "
import json
import sys

with open('$OUTPUT_FILE.tmp', 'r') as f:
    data = json.load(f)

# Extract events
events = [item['sentinel_event'] for item in data if 'sentinel_event' in item]

# Format for Azure Monitor
sentinel_data = {
    'WorkspaceId': 'YOUR_WORKSPACE_ID',
    'SharedKey': 'YOUR_SHARED_KEY',
    'LogType': 'CloudScope_Asset',
    'TimeStampField': 'TimeGenerated',
    'Records': events
}

with open('$OUTPUT_FILE', 'w') as f:
    json.dump(sentinel_data, f, indent=2)
"
    
    rm -f "$OUTPUT_FILE.tmp"
    log_success "Sentinel export saved to: $OUTPUT_FILE"
}

# Export to Elastic/ELK format
export_elastic() {
    log_info "Exporting data for Elastic..."
    
    OUTPUT_FILE="$EXPORT_DIR/elastic_assets_${TIMESTAMP}.ndjson"
    
    # Query Memgraph and format for Elastic
    cat << 'EOF' | docker exec -i cloudscope-memgraph mgconsole --output-format=json > "$OUTPUT_FILE.tmp"
MATCH (a:Asset)
OPTIONAL MATCH (a)-[:TAGGED_WITH]->(t:Tag)
OPTIONAL MATCH (a)-[:HAS_FINDING]->(f:Finding)
OPTIONAL MATCH (a)-[r:CONNECTS_TO|DEPENDS_ON|HOSTS|MANAGES]->(related:Asset)
WITH a, 
     collect(DISTINCT {key: t.key, value: t.value}) AS tags,
     collect(DISTINCT f) AS findings,
     collect(DISTINCT {type: type(r), asset: related.id}) AS relationships
RETURN {
    index_action: {_index: 'cloudscope-assets', _id: a.id},
    document: {
        '@timestamp': datetime(),
        'asset.id': a.id,
        'asset.name': a.name,
        'asset.type': a.asset_type,
        'asset.source': a.source,
        'asset.risk_score': a.risk_score,
        'asset.created_at': a.created_at,
        'asset.updated_at': a.updated_at,
        'asset.metadata': a.metadata,
        'tags': tags,
        'findings.count': size(findings),
        'findings.details': [f IN findings | {
            id: f.id,
            title: f.title,
            severity: f.severity,
            status: f.status
        }],
        'relationships': relationships,
        'ecs.version': '8.0.0'
    }
} AS elastic_doc
EOF
    
    # Convert to Elasticsearch bulk format
    python3 -c "
import json
import sys

with open('$OUTPUT_FILE.tmp', 'r') as f:
    data = json.load(f)

# Write as NDJSON for Elasticsearch bulk API
with open('$OUTPUT_FILE', 'w') as f:
    for item in data:
        if 'elastic_doc' in item:
            doc = item['elastic_doc']
            # Write index action
            f.write(json.dumps({'index': doc['index_action']}) + '\n')
            # Write document
            f.write(json.dumps(doc['document']) + '\n')
"
    
    rm -f "$OUTPUT_FILE.tmp"
    log_success "Elastic export saved to: $OUTPUT_FILE"
}

# Export to generic CSV format
export_csv() {
    log_info "Exporting data to CSV format..."
    
    OUTPUT_FILE="$EXPORT_DIR/assets_${TIMESTAMP}.csv"
    
    # Query Memgraph and export as CSV
    cat << 'EOF' | docker exec -i cloudscope-memgraph mgconsole --output-format=csv > "$OUTPUT_FILE"
MATCH (a:Asset)
OPTIONAL MATCH (a)-[:TAGGED_WITH]->(t:Tag)
OPTIONAL MATCH (a)-[:HAS_FINDING]->(f:Finding)
WITH a, 
     collect(DISTINCT t.key + '=' + t.value) AS tags,
     count(DISTINCT f) AS finding_count,
     max(f.severity) AS max_severity
RETURN 
    a.id AS asset_id,
    a.name AS asset_name,
    a.asset_type AS asset_type,
    a.source AS source,
    a.risk_score AS risk_score,
    a.created_at AS created_at,
    a.updated_at AS updated_at,
    CASE 
        WHEN size(tags) > 0 THEN reduce(s = '', tag IN tags | s + CASE WHEN s = '' THEN '' ELSE ';' END + tag)
        ELSE ''
    END AS tags,
    finding_count,
    coalesce(max_severity, 'NONE') AS highest_severity
ORDER BY a.risk_score DESC
EOF
    
    log_success "CSV export saved to: $OUTPUT_FILE"
}

# Send to SIEM via API
send_to_siem() {
    local siem_type=$1
    local data_file=$2
    
    case $siem_type in
        crowdstrike)
            log_info "Sending data to CrowdStrike API..."
            # Example API call (requires actual API credentials)
            # curl -X POST https://api.crowdstrike.com/devices/entities/devices/v1 \
            #      -H "Authorization: Bearer $CROWDSTRIKE_TOKEN" \
            #      -H "Content-Type: application/json" \
            #      -d @"$data_file"
            log_warning "CrowdStrike API integration not configured. Manual upload required."
            ;;
            
        splunk)
            log_info "Sending data to Splunk HEC..."
            # Example HEC call (requires actual HEC token and endpoint)
            # curl -k https://splunk-server:8088/services/collector/event \
            #      -H "Authorization: Splunk $SPLUNK_HEC_TOKEN" \
            #      -d @"$data_file"
            log_warning "Splunk HEC not configured. Manual upload required."
            ;;
            
        sentinel)
            log_info "Sending data to Microsoft Sentinel..."
            # Example Log Analytics call (requires workspace ID and key)
            # python3 ./scripts/export/sentinel_uploader.py --file "$data_file"
            log_warning "Sentinel Log Analytics not configured. Manual upload required."
            ;;
            
        elastic)
            log_info "Sending data to Elasticsearch..."
            # Example bulk upload (requires Elasticsearch endpoint)
            # curl -X POST "localhost:9200/_bulk" \
            #      -H "Content-Type: application/x-ndjson" \
            #      --data-binary @"$data_file"
            log_warning "Elasticsearch endpoint not configured. Manual upload required."
            ;;
    esac
}

# Generate export summary
generate_export_summary() {
    log_info "Generating export summary..."
    
    SUMMARY_FILE="$EXPORT_DIR/export_summary_${TIMESTAMP}.txt"
    
    cat > "$SUMMARY_FILE" << EOF
CloudScope Export Summary
========================
Timestamp: $(date)
Export Directory: $EXPORT_DIR

Files Generated:
EOF
    
    # List all files created during this export
    find "$EXPORT_DIR" -name "*_${TIMESTAMP}*" -type f | while read -r file; do
        size=$(ls -lh "$file" | awk '{print $5}')
        echo "- $(basename "$file"): $size" >> "$SUMMARY_FILE"
    done
    
    # Add asset statistics
    asset_stats=$(docker exec cloudscope-memgraph mgconsole << 'EOF'
MATCH (a:Asset)
OPTIONAL MATCH (a)-[:HAS_FINDING]->(f:Finding)
WITH count(DISTINCT a) AS total_assets,
     avg(a.risk_score) AS avg_risk_score,
     count(DISTINCT f) AS total_findings
RETURN total_assets, round(avg_risk_score, 2) AS avg_risk_score, total_findings;
EOF
)
    
    echo -e "\nAsset Statistics:\n$asset_stats" >> "$SUMMARY_FILE"
    
    log_success "Summary written to: $SUMMARY_FILE"
    cat "$SUMMARY_FILE"
}

# Print usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS] [SIEM_TYPE]

Export CloudScope data to various SIEM platforms

SIEM Types:
    all             Export to all supported formats
    crowdstrike     Export for CrowdStrike Falcon
    splunk          Export for Splunk
    sentinel        Export for Microsoft Sentinel
    elastic         Export for Elastic/ELK
    csv             Export to generic CSV format

Options:
    -o, --output DIR    Output directory (default: ./data/exports)
    -c, --config FILE   Configuration file (default: ./config/cloudscope-config.json)
    -u, --upload        Upload to SIEM after export (requires API configuration)
    -h, --help          Show this help message

Examples:
    # Export to all formats
    $0 all

    # Export only for CrowdStrike
    $0 crowdstrike

    # Export and upload to Splunk
    $0 -u splunk

    # Export to custom directory
    $0 -o /tmp/exports all
EOF
}

# Parse command line arguments
UPLOAD=false
SIEM_TYPE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -o|--output)
            EXPORT_DIR="$2"
            shift 2
            ;;
        -c|--config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        -u|--upload)
            UPLOAD=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            SIEM_TYPE="$1"
            shift
            ;;
    esac
done

# Main execution
main() {
    log_info "CloudScope SIEM Export"
    log_info "====================="
    
    # Check if SIEM type is specified
    if [[ -z "$SIEM_TYPE" ]]; then
        log_error "Please specify a SIEM type"
        usage
        exit 1
    fi
    
    # Export based on SIEM type
    case $SIEM_TYPE in
        all)
            export_crowdstrike
            export_splunk
            export_sentinel
            export_elastic
            export_csv
            ;;
        crowdstrike)
            export_crowdstrike
            [[ "$UPLOAD" == "true" ]] && send_to_siem crowdstrike "$EXPORT_DIR/crowdstrike_assets_${TIMESTAMP}.json"
            ;;
        splunk)
            export_splunk
            [[ "$UPLOAD" == "true" ]] && send_to_siem splunk "$EXPORT_DIR/splunk_assets_${TIMESTAMP}.json"
            ;;
        sentinel)
            export_sentinel
            [[ "$UPLOAD" == "true" ]] && send_to_siem sentinel "$EXPORT_DIR/sentinel_assets_${TIMESTAMP}.json"
            ;;
        elastic)
            export_elastic
            [[ "$UPLOAD" == "true" ]] && send_to_siem elastic "$EXPORT_DIR/elastic_assets_${TIMESTAMP}.ndjson"
            ;;
        csv)
            export_csv
            ;;
        *)
            log_error "Unknown SIEM type: $SIEM_TYPE"
            usage
            exit 1
            ;;
    esac
    
    # Generate summary
    generate_export_summary
    
    log_success "Export complete!"
}

# Run main function
main
