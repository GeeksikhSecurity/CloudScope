#!/bin/bash

# CloudScope External Integrations
# Integrate CloudScope with various third-party tools and services

set -euo pipefail

# Configuration
CONFIG_FILE="${CONFIG_FILE:-./config/cloudscope-config.json}"
INTEGRATION_CONFIG="${INTEGRATION_CONFIG:-./config/integrations.json}"
TEMP_DIR="${TEMP_DIR:-/tmp/cloudscope-integrations}"

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
log_integration() { echo -e "${PURPLE}[INTEGRATION]${NC} $1"; }

# Initialize temp directory
mkdir -p "$TEMP_DIR"

# Slack Integration
send_slack_notification() {
    local webhook_url="$1"
    local message="$2"
    local channel="${3:-#cloudscope-alerts}"
    
    log_integration "Sending Slack notification..."
    
    local payload=$(cat <<EOF
{
    "channel": "$channel",
    "username": "CloudScope Bot",
    "icon_emoji": ":cloud:",
    "text": "$message",
    "attachments": [
        {
            "color": "good",
            "fields": [
                {
                    "title": "Source",
                    "value": "CloudScope Asset Inventory",
                    "short": true
                },
                {
                    "title": "Timestamp",
                    "value": "$(date -u +"%Y-%m-%d %H:%M:%S UTC")",
                    "short": true
                }
            ]
        }
    ]
}
EOF
)
    
    curl -X POST -H 'Content-type: application/json' \
        --data "$payload" \
        "$webhook_url" 2>/dev/null || log_error "Failed to send Slack notification"
}

# Microsoft Teams Integration
send_teams_notification() {
    local webhook_url="$1"
    local title="$2"
    local message="$3"
    
    log_integration "Sending Teams notification..."
    
    local payload=$(cat <<EOF
{
    "@type": "MessageCard",
    "@context": "https://schema.org/extensions",
    "themeColor": "0072C6",
    "summary": "$title",
    "sections": [{
        "activityTitle": "CloudScope Alert",
        "activitySubtitle": "$title",
        "activityImage": "https://example.com/cloudscope-icon.png",
        "facts": [{
            "name": "Status",
            "value": "$message"
        }, {
            "name": "Generated",
            "value": "$(date -u +"%Y-%m-%d %H:%M:%S UTC")"
        }],
        "markdown": true
    }]
}
EOF
)
    
    curl -X POST -H 'Content-type: application/json' \
        --data "$payload" \
        "$webhook_url" 2>/dev/null || log_error "Failed to send Teams notification"
}

# Jira Integration
create_jira_issue() {
    local jira_url="$1"
    local api_token="$2"
    local project_key="$3"
    local summary="$4"
    local description="$5"
    
    log_integration "Creating Jira issue..."
    
    local payload=$(cat <<EOF
{
    "fields": {
        "project": {
            "key": "$project_key"
        },
        "summary": "$summary",
        "description": "$description",
        "issuetype": {
            "name": "Task"
        },
        "labels": ["cloudscope", "asset-inventory"],
        "priority": {
            "name": "Medium"
        }
    }
}
EOF
)
    
    local response=$(curl -X POST \
        -H "Authorization: Bearer $api_token" \
        -H "Content-Type: application/json" \
        --data "$payload" \
        "$jira_url/rest/api/2/issue" 2>/dev/null)
    
    if [[ $? -eq 0 ]]; then
        local issue_key=$(echo "$response" | jq -r '.key // empty')
        if [[ -n "$issue_key" ]]; then
            log_success "Created Jira issue: $issue_key"
            echo "$issue_key"
        else
            log_error "Failed to create Jira issue"
        fi
    fi
}

# ServiceNow Integration
create_servicenow_incident() {
    local instance_url="$1"
    local username="$2"
    local password="$3"
    local short_description="$4"
    local description="$5"
    
    log_integration "Creating ServiceNow incident..."
    
    local payload=$(cat <<EOF
{
    "short_description": "$short_description",
    "description": "$description",
    "category": "Infrastructure",
    "subcategory": "Asset Management",
    "impact": "3",
    "urgency": "3",
    "assignment_group": "CloudOps",
    "caller_id": "cloudscope_integration"
}
EOF
)
    
    local response=$(curl -X POST \
        -u "$username:$password" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        --data "$payload" \
        "$instance_url/api/now/table/incident" 2>/dev/null)
    
    if [[ $? -eq 0 ]]; then
        local incident_number=$(echo "$response" | jq -r '.result.number // empty')
        if [[ -n "$incident_number" ]]; then
            log_success "Created ServiceNow incident: $incident_number"
            echo "$incident_number"
        else
            log_error "Failed to create ServiceNow incident"
        fi
    fi
}

# PagerDuty Integration
trigger_pagerduty_alert() {
    local integration_key="$1"
    local summary="$2"
    local details="$3"
    local severity="${4:-warning}"
    
    log_integration "Triggering PagerDuty alert..."
    
    local payload=$(cat <<EOF
{
    "routing_key": "$integration_key",
    "event_action": "trigger",
    "payload": {
        "summary": "$summary",
        "severity": "$severity",
        "source": "CloudScope",
        "custom_details": {
            "details": "$details",
            "environment": "production",
            "service": "asset-inventory"
        }
    }
}
EOF
)
    
    curl -X POST \
        -H "Content-Type: application/json" \
        --data "$payload" \
        "https://events.pagerduty.com/v2/enqueue" 2>/dev/null || \
        log_error "Failed to trigger PagerDuty alert"
}

# Splunk Integration
send_to_splunk() {
    local hec_url="$1"
    local hec_token="$2"
    local event_data="$3"
    local source_type="${4:-cloudscope}"
    
    log_integration "Sending data to Splunk..."
    
    local payload=$(cat <<EOF
{
    "event": $event_data,
    "sourcetype": "$source_type",
    "source": "CloudScope",
    "host": "$(hostname)"
}
EOF
)
    
    curl -X POST \
        -H "Authorization: Splunk $hec_token" \
        -H "Content-Type: application/json" \
        --data "$payload" \
        "$hec_url/services/collector/event" 2>/dev/null || \
        log_error "Failed to send data to Splunk"
}

# DataDog Integration
send_datadog_metric() {
    local api_key="$1"
    local metric_name="$2"
    local metric_value="$3"
    local tags="$4"
    
    log_integration "Sending metric to DataDog..."
    
    local timestamp=$(date +%s)
    local payload=$(cat <<EOF
{
    "series": [{
        "metric": "cloudscope.$metric_name",
        "points": [[$timestamp, $metric_value]],
        "type": "gauge",
        "tags": $tags
    }]
}
EOF
)
    
    curl -X POST \
        -H "DD-API-KEY: $api_key" \
        -H "Content-Type: application/json" \
        --data "$payload" \
        "https://api.datadoghq.com/api/v1/series" 2>/dev/null || \
        log_error "Failed to send metric to DataDog"
}

# CI/CD Integration (GitHub Actions)
trigger_github_workflow() {
    local repo_owner="$1"
    local repo_name="$2"
    local workflow_id="$3"
    local github_token="$4"
    local ref="${5:-main}"
    
    log_integration "Triggering GitHub workflow..."
    
    local payload=$(cat <<EOF
{
    "ref": "$ref",
    "inputs": {
        "triggered_by": "CloudScope",
        "timestamp": "$(date -u +"%Y-%m-%d %H:%M:%S UTC")"
    }
}
EOF
)
    
    curl -X POST \
        -H "Authorization: token $github_token" \
        -H "Accept: application/vnd.github.v3+json" \
        --data "$payload" \
        "https://api.github.com/repos/$repo_owner/$repo_name/actions/workflows/$workflow_id/dispatches" \
        2>/dev/null || log_error "Failed to trigger GitHub workflow"
}

# Webhook Integration (Generic)
call_webhook() {
    local webhook_url="$1"
    local payload="$2"
    local auth_header="${3:-}"
    
    log_integration "Calling webhook: $webhook_url"
    
    local curl_args=(-X POST -H "Content-Type: application/json" --data "$payload")
    
    if [[ -n "$auth_header" ]]; then
        curl_args+=(-H "$auth_header")
    fi
    
    curl "${curl_args[@]}" "$webhook_url" 2>/dev/null || \
        log_error "Failed to call webhook"
}

# Export functions for different formats
export_for_integration() {
    local export_type="$1"
    local data_file="$2"
    local output_file="$3"
    
    case "$export_type" in
        "prometheus")
            log_info "Exporting metrics in Prometheus format..."
            # Convert to Prometheus exposition format
            ;;
        "elasticsearch")
            log_info "Exporting data for Elasticsearch..."
            # Convert to bulk index format
            ;;
        "grafana")
            log_info "Exporting dashboard for Grafana..."
            # Generate Grafana dashboard JSON
            ;;
        *)
            log_error "Unknown export type: $export_type"
            return 1
            ;;
    esac
}

# Main function
main() {
    local action="${1:-help}"
    
    case "$action" in
        "slack")
            send_slack_notification "$2" "$3" "${4:-}"
            ;;
        "teams")
            send_teams_notification "$2" "$3" "$4"
            ;;
        "jira")
            create_jira_issue "$2" "$3" "$4" "$5" "$6"
            ;;
        "servicenow")
            create_servicenow_incident "$2" "$3" "$4" "$5" "$6"
            ;;
        "pagerduty")
            trigger_pagerduty_alert "$2" "$3" "$4" "${5:-warning}"
            ;;
        "splunk")
            send_to_splunk "$2" "$3" "$4" "${5:-cloudscope}"
            ;;
        "datadog")
            send_datadog_metric "$2" "$3" "$4" "$5"
            ;;
        "github")
            trigger_github_workflow "$2" "$3" "$4" "$5" "${6:-main}"
            ;;
        "webhook")
            call_webhook "$2" "$3" "${4:-}"
            ;;
        "export")
            export_for_integration "$2" "$3" "$4"
            ;;
        "help"|*)
            echo "CloudScope External Integrations"
            echo ""
            echo "Usage: $0 <action> [parameters]"
            echo ""
            echo "Actions:"
            echo "  slack <webhook_url> <message> [channel]"
            echo "  teams <webhook_url> <title> <message>"
            echo "  jira <url> <token> <project> <summary> <description>"
            echo "  servicenow <url> <user> <pass> <summary> <description>"
            echo "  pagerduty <key> <summary> <details> [severity]"
            echo "  splunk <hec_url> <token> <event_data> [source_type]"
            echo "  datadog <api_key> <metric> <value> <tags>"
            echo "  github <owner> <repo> <workflow> <token> [ref]"
            echo "  webhook <url> <payload> [auth_header]"
            echo "  export <type> <data_file> <output_file>"
            echo ""
            ;;
    esac
}

# Run main function
main "$@"