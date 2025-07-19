#!/bin/bash
# CloudScope Database Backup and Restore Script
# Backup and restore CloudScope databases (Memgraph, PostgreSQL, Elasticsearch)

set -euo pipefail

# Configuration
BACKUP_DIR="${BACKUP_DIR:-./backups}"
MEMGRAPH_CONTAINER="${MEMGRAPH_CONTAINER:-cloudscope-memgraph}"
POSTGRES_CONTAINER="${POSTGRES_CONTAINER:-cloudscope-postgres}"
ELASTIC_CONTAINER="${ELASTIC_CONTAINER:-cloudscope-elasticsearch}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

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

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Check if containers are running
check_containers() {
    local all_running=true
    
    if ! docker ps | grep -q "$MEMGRAPH_CONTAINER"; then
        log_warning "Memgraph container not running"
        all_running=false
    fi
    
    if ! docker ps | grep -q "$POSTGRES_CONTAINER"; then
        log_warning "PostgreSQL container not running"
        all_running=false
    fi
    
    if ! docker ps | grep -q "$ELASTIC_CONTAINER"; then
        log_warning "Elasticsearch container not running"
        all_running=false
    fi
    
    if [[ "$all_running" == "false" ]]; then
        log_error "Some containers are not running. Start them with: docker-compose up -d"
        return 1
    fi
    
    return 0
}

# Backup Memgraph
backup_memgraph() {
    log_info "Backing up Memgraph database..."
    
    local backup_file="$BACKUP_DIR/memgraph_${TIMESTAMP}.cypher"
    
    # Export database using DUMP DATABASE command
    docker exec "$MEMGRAPH_CONTAINER" bash -c "echo 'DUMP DATABASE;' | mgconsole" > "$backup_file"
    
    # Compress the backup
    gzip "$backup_file"
    
    log_success "Memgraph backup saved to: ${backup_file}.gz"
}

# Backup PostgreSQL
backup_postgres() {
    log_info "Backing up PostgreSQL database..."
    
    local backup_file="$BACKUP_DIR/postgres_${TIMESTAMP}.sql"
    
    # Get database credentials from environment or use defaults
    local db_name="${POSTGRES_DB:-cloudscope}"
    local db_user="${POSTGRES_USER:-cloudscope}"
    
    # Dump database
    docker exec "$POSTGRES_CONTAINER" pg_dump -U "$db_user" "$db_name" > "$backup_file"
    
    # Compress the backup
    gzip "$backup_file"
    
    log_success "PostgreSQL backup saved to: ${backup_file}.gz"
}

# Backup Elasticsearch
backup_elasticsearch() {
    log_info "Backing up Elasticsearch indices..."
    
    local backup_dir="$BACKUP_DIR/elasticsearch_${TIMESTAMP}"
    mkdir -p "$backup_dir"
    
    # Get list of indices
    local indices=$(docker exec "$ELASTIC_CONTAINER" curl -s -X GET "localhost:9200/_cat/indices?h=index" | grep -v "^\.")
    
    # Export each index
    for index in $indices; do
        log_info "Exporting index: $index"
        
        # Use elasticsearch-dump if available, otherwise use _reindex API
        docker exec "$ELASTIC_CONTAINER" curl -s -X GET "localhost:9200/$index/_search?size=10000" \
            -H "Content-Type: application/json" > "$backup_dir/${index}.json"
    done
    
    # Create a metadata file
    cat > "$backup_dir/metadata.json" << EOF
{
    "timestamp": "$(date -Iseconds)",
    "indices": [$(echo "$indices" | awk '{printf "\"%s\",", $0}' | sed 's/,$//')]
}
EOF
    
    # Compress the backup
    tar -czf "$backup_dir.tar.gz" -C "$BACKUP_DIR" "elasticsearch_${TIMESTAMP}"
    rm -rf "$backup_dir"
    
    log_success "Elasticsearch backup saved to: ${backup_dir}.tar.gz"
}

# Backup all databases
backup_all() {
    log_info "Starting full database backup..."
    
    check_containers || return 1
    
    # Create backup metadata
    cat > "$BACKUP_DIR/backup_metadata_${TIMESTAMP}.json" << EOF
{
    "timestamp": "$(date -Iseconds)",
    "version": "1.0.0",
    "components": {
        "memgraph": "memgraph_${TIMESTAMP}.cypher.gz",
        "postgres": "postgres_${TIMESTAMP}.sql.gz",
        "elasticsearch": "elasticsearch_${TIMESTAMP}.tar.gz"
    }
}
EOF
    
    # Perform backups
    backup_memgraph
    backup_postgres
    backup_elasticsearch
    
    # Create combined archive
    log_info "Creating combined backup archive..."
    tar -czf "$BACKUP_DIR/cloudscope_full_backup_${TIMESTAMP}.tar.gz" \
        -C "$BACKUP_DIR" \
        "backup_metadata_${TIMESTAMP}.json" \
        "memgraph_${TIMESTAMP}.cypher.gz" \
        "postgres_${TIMESTAMP}.sql.gz" \
        "elasticsearch_${TIMESTAMP}.tar.gz"
    
    log_success "Full backup completed: cloudscope_full_backup_${TIMESTAMP}.tar.gz"
}

# Restore Memgraph
restore_memgraph() {
    local backup_file=$1
    
    log_info "Restoring Memgraph from: $backup_file"
    
    # Check if backup file exists
    if [[ ! -f "$backup_file" ]]; then
        log_error "Backup file not found: $backup_file"
        return 1
    fi
    
    # Extract if compressed
    local cypher_file="$backup_file"
    if [[ "$backup_file" == *.gz ]]; then
        cypher_file="${backup_file%.gz}"
        gunzip -c "$backup_file" > "$cypher_file"
    fi
    
    # Clear existing database
    log_warning "Clearing existing Memgraph database..."
    docker exec "$MEMGRAPH_CONTAINER" bash -c "echo 'MATCH (n) DETACH DELETE n;' | mgconsole"
    
    # Restore database
    docker exec -i "$MEMGRAPH_CONTAINER" mgconsole < "$cypher_file"
    
    # Clean up temporary file
    if [[ "$backup_file" == *.gz ]]; then
        rm "$cypher_file"
    fi
    
    log_success "Memgraph restore completed"
}

# Restore PostgreSQL
restore_postgres() {
    local backup_file=$1
    
    log_info "Restoring PostgreSQL from: $backup_file"
    
    # Check if backup file exists
    if [[ ! -f "$backup_file" ]]; then
        log_error "Backup file not found: $backup_file"
        return 1
    fi
    
    # Get database credentials
    local db_name="${POSTGRES_DB:-cloudscope}"
    local db_user="${POSTGRES_USER:-cloudscope}"
    
    # Extract if compressed
    local sql_file="$backup_file"
    if [[ "$backup_file" == *.gz ]]; then
        sql_file="${backup_file%.gz}"
        gunzip -c "$backup_file" > "$sql_file"
    fi
    
    # Drop and recreate database
    log_warning "Recreating PostgreSQL database..."
    docker exec "$POSTGRES_CONTAINER" dropdb -U "$db_user" "$db_name" || true
    docker exec "$POSTGRES_CONTAINER" createdb -U "$db_user" "$db_name"
    
    # Restore database
    docker exec -i "$POSTGRES_CONTAINER" psql -U "$db_user" "$db_name" < "$sql_file"
    
    # Clean up temporary file
    if [[ "$backup_file" == *.gz ]]; then
        rm "$sql_file"
    fi
    
    log_success "PostgreSQL restore completed"
}

# Restore Elasticsearch
restore_elasticsearch() {
    local backup_file=$1
    
    log_info "Restoring Elasticsearch from: $backup_file"
    
    # Check if backup file exists
    if [[ ! -f "$backup_file" ]]; then
        log_error "Backup file not found: $backup_file"
        return 1
    fi
    
    # Extract backup
    local temp_dir=$(mktemp -d)
    tar -xzf "$backup_file" -C "$temp_dir"
    
    # Find the elasticsearch directory
    local es_dir=$(find "$temp_dir" -name "elasticsearch_*" -type d | head -1)
    
    if [[ -z "$es_dir" ]]; then
        log_error "Invalid Elasticsearch backup format"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Restore each index
    for json_file in "$es_dir"/*.json; do
        if [[ "$(basename "$json_file")" == "metadata.json" ]]; then
            continue
        fi
        
        local index_name=$(basename "$json_file" .json)
        log_info "Restoring index: $index_name"
        
        # Delete existing index
        docker exec "$ELASTIC_CONTAINER" curl -s -X DELETE "localhost:9200/$index_name" || true
        
        # Create index and import data
        # Note: This is a simplified restore. For production, use snapshot/restore API
        docker exec -i "$ELASTIC_CONTAINER" curl -s -X POST "localhost:9200/$index_name/_bulk" \
            -H "Content-Type: application/json" \
            --data-binary "@-" < "$json_file"
    done
    
    # Clean up
    rm -rf "$temp_dir"
    
    log_success "Elasticsearch restore completed"
}

# Restore all databases
restore_all() {
    local backup_archive=$1
    
    log_info "Starting full database restore from: $backup_archive"
    
    # Check if backup file exists
    if [[ ! -f "$backup_archive" ]]; then
        log_error "Backup archive not found: $backup_archive"
        return 1
    fi
    
    check_containers || return 1
    
    # Extract backup archive
    local temp_dir=$(mktemp -d)
    tar -xzf "$backup_archive" -C "$temp_dir"
    
    # Read metadata
    local metadata_file=$(find "$temp_dir" -name "backup_metadata_*.json" | head -1)
    
    if [[ -z "$metadata_file" ]]; then
        log_error "Backup metadata not found"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Extract component files
    local memgraph_backup=$(find "$temp_dir" -name "memgraph_*.cypher.gz" | head -1)
    local postgres_backup=$(find "$temp_dir" -name "postgres_*.sql.gz" | head -1)
    local elastic_backup=$(find "$temp_dir" -name "elasticsearch_*.tar.gz" | head -1)
    
    # Restore each component
    if [[ -n "$memgraph_backup" ]]; then
        restore_memgraph "$memgraph_backup"
    fi
    
    if [[ -n "$postgres_backup" ]]; then
        restore_postgres "$postgres_backup"
    fi
    
    if [[ -n "$elastic_backup" ]]; then
        restore_elasticsearch "$elastic_backup"
    fi
    
    # Clean up
    rm -rf "$temp_dir"
    
    log_success "Full restore completed"
}

# List available backups
list_backups() {
    log_info "Available backups in $BACKUP_DIR:"
    echo ""
    
    # List full backups
    echo "Full Backups:"
    find "$BACKUP_DIR" -name "cloudscope_full_backup_*.tar.gz" -type f | sort -r | while read -r file; do
        size=$(ls -lh "$file" | awk '{print $5}')
        date=$(basename "$file" | grep -oE '[0-9]{8}_[0-9]{6}')
        echo "  - $(basename "$file") ($size) - $date"
    done
    
    echo ""
    echo "Individual Component Backups:"
    
    # List Memgraph backups
    echo "  Memgraph:"
    find "$BACKUP_DIR" -name "memgraph_*.cypher.gz" -type f | sort -r | head -5 | while read -r file; do
        size=$(ls -lh "$file" | awk '{print $5}')
        echo "    - $(basename "$file") ($size)"
    done
    
    # List PostgreSQL backups
    echo "  PostgreSQL:"
    find "$BACKUP_DIR" -name "postgres_*.sql.gz" -type f | sort -r | head -5 | while read -r file; do
        size=$(ls -lh "$file" | awk '{print $5}')
        echo "    - $(basename "$file") ($size)"
    done
    
    # List Elasticsearch backups
    echo "  Elasticsearch:"
    find "$BACKUP_DIR" -name "elasticsearch_*.tar.gz" -type f | sort -r | head -5 | while read -r file; do
        size=$(ls -lh "$file" | awk '{print $5}')
        echo "    - $(basename "$file") ($size)"
    done
}

# Clean old backups
clean_old_backups() {
    local days=${1:-7}
    
    log_info "Cleaning backups older than $days days..."
    
    # Find and remove old backups
    find "$BACKUP_DIR" -name "*.gz" -type f -mtime +$days -delete
    find "$BACKUP_DIR" -name "*.tar.gz" -type f -mtime +$days -delete
    
    log_success "Old backups cleaned"
}

# Print usage
usage() {
    cat << EOF
Usage: $0 [COMMAND] [OPTIONS]

Commands:
    backup all              Backup all databases
    backup memgraph        Backup only Memgraph
    backup postgres        Backup only PostgreSQL
    backup elasticsearch   Backup only Elasticsearch
    
    restore all FILE       Restore all databases from full backup
    restore memgraph FILE  Restore only Memgraph
    restore postgres FILE  Restore only PostgreSQL
    restore elasticsearch FILE  Restore only Elasticsearch
    
    list                   List available backups
    clean [DAYS]          Remove backups older than DAYS (default: 7)

Options:
    -d, --dir DIR         Backup directory (default: ./backups)
    -h, --help           Show this help message

Examples:
    # Backup all databases
    $0 backup all
    
    # Restore from full backup
    $0 restore all ./backups/cloudscope_full_backup_20250117_235959.tar.gz
    
    # Backup only Memgraph
    $0 backup memgraph
    
    # List available backups
    $0 list
    
    # Clean backups older than 30 days
    $0 clean 30
EOF
}

# Parse command line arguments
COMMAND=""
SUBCOMMAND=""
FILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--dir)
            BACKUP_DIR="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        backup|restore)
            COMMAND="$1"
            SUBCOMMAND="$2"
            FILE="${3:-}"
            shift 2
            [[ -n "$FILE" ]] && shift
            ;;
        list|clean)
            COMMAND="$1"
            SUBCOMMAND="${2:-}"
            shift
            [[ -n "$SUBCOMMAND" ]] && shift
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Main execution
case $COMMAND in
    backup)
        case $SUBCOMMAND in
            all) backup_all ;;
            memgraph) backup_memgraph ;;
            postgres) backup_postgres ;;
            elasticsearch) backup_elasticsearch ;;
            *)
                log_error "Invalid backup target: $SUBCOMMAND"
                usage
                exit 1
                ;;
        esac
        ;;
    restore)
        if [[ -z "$FILE" ]]; then
            log_error "Restore requires a backup file"
            usage
            exit 1
        fi
        
        case $SUBCOMMAND in
            all) restore_all "$FILE" ;;
            memgraph) restore_memgraph "$FILE" ;;
            postgres) restore_postgres "$FILE" ;;
            elasticsearch) restore_elasticsearch "$FILE" ;;
            *)
                log_error "Invalid restore target: $SUBCOMMAND"
                usage
                exit 1
                ;;
        esac
        ;;
    list)
        list_backups
        ;;
    clean)
        clean_old_backups "$SUBCOMMAND"
        ;;
    *)
        log_error "Invalid command"
        usage
        exit 1
        ;;
esac
