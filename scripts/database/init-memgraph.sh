#!/bin/bash
# CloudScope Database Initialization Script
# This script initializes the Memgraph database with required schema

set -euo pipefail

# Configuration
MEMGRAPH_HOST="${MEMGRAPH_HOST:-localhost}"
MEMGRAPH_PORT="${MEMGRAPH_PORT:-7687}"
MEMGRAPH_USER="${MEMGRAPH_USER:-}"
MEMGRAPH_PASS="${MEMGRAPH_PASS:-}"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Memgraph is running
check_memgraph() {
    log_info "Checking Memgraph connection..."
    
    # Try to connect to Memgraph
    if docker exec cloudscope-memgraph echo "MATCH (n) RETURN count(n);" | mgconsole --host=$MEMGRAPH_HOST --port=$MEMGRAPH_PORT &> /dev/null; then
        log_success "Connected to Memgraph"
        return 0
    else
        log_error "Cannot connect to Memgraph at $MEMGRAPH_HOST:$MEMGRAPH_PORT"
        return 1
    fi
}

# Initialize schema
init_schema() {
    log_info "Initializing CloudScope schema..."
    
    # Create the Cypher queries
    cat << 'EOF' > /tmp/cloudscope-schema.cypher
// CloudScope Memgraph Schema Initialization

// Create indexes for better performance
CREATE INDEX ON :Asset(id);
CREATE INDEX ON :Asset(name);
CREATE INDEX ON :Asset(asset_type);
CREATE INDEX ON :Asset(source);
CREATE INDEX ON :Asset(risk_score);
CREATE INDEX ON :Tag(key);
CREATE INDEX ON :Tag(value);
CREATE INDEX ON :Compliance(framework);
CREATE INDEX ON :Compliance(requirement);
CREATE INDEX ON :Finding(severity);
CREATE INDEX ON :Finding(status);

// Create constraints
CREATE CONSTRAINT ON (a:Asset) ASSERT a.id IS UNIQUE;
CREATE CONSTRAINT ON (t:Tag) ASSERT t.key IS UNIQUE;
CREATE CONSTRAINT ON (c:Compliance) ASSERT c.id IS UNIQUE;
CREATE CONSTRAINT ON (f:Finding) ASSERT f.id IS UNIQUE;

// Create stored procedures for common operations

// Procedure to create or update an asset
CREATE PROCEDURE create_or_update_asset(
    id STRING,
    name STRING,
    asset_type STRING,
    source STRING,
    metadata MAP,
    risk_score INT,
    created_at STRING,
    updated_at STRING
) RETURNS (asset NODE)
LANGUAGE CYPHER AS $$
    MERGE (a:Asset {id: id})
    SET a.name = name,
        a.asset_type = asset_type,
        a.source = source,
        a.metadata = metadata,
        a.risk_score = risk_score,
        a.updated_at = updated_at
    ON CREATE SET a.created_at = created_at
    RETURN a AS asset;
$$;

// Procedure to create asset relationships
CREATE PROCEDURE create_asset_relationship(
    source_id STRING,
    target_id STRING,
    relationship_type STRING,
    properties MAP
) RETURNS (created BOOLEAN)
LANGUAGE CYPHER AS $$
    MATCH (source:Asset {id: source_id})
    MATCH (target:Asset {id: target_id})
    CALL apoc.create.relationship(source, relationship_type, properties, target) YIELD rel
    RETURN true AS created;
$$;

// Procedure to add tags to an asset
CREATE PROCEDURE add_asset_tags(
    asset_id STRING,
    tags MAP
) RETURNS (asset NODE)
LANGUAGE CYPHER AS $$
    MATCH (a:Asset {id: asset_id})
    UNWIND keys(tags) AS key
    MERGE (t:Tag {key: key, value: tags[key]})
    MERGE (a)-[:TAGGED_WITH]->(t)
    RETURN a AS asset;
$$;

// Procedure to find assets by risk score
CREATE PROCEDURE find_assets_by_risk(
    min_score INT,
    max_score INT
) RETURNS (assets LIST)
LANGUAGE CYPHER AS $$
    MATCH (a:Asset)
    WHERE a.risk_score >= min_score AND a.risk_score <= max_score
    RETURN collect(a) AS assets;
$$;

// Procedure to get asset dependencies
CREATE PROCEDURE get_asset_dependencies(
    asset_id STRING,
    depth INT
) RETURNS (dependencies LIST)
LANGUAGE CYPHER AS $$
    MATCH (a:Asset {id: asset_id})
    MATCH path = (a)-[*1..depth]->(dependency:Asset)
    RETURN collect(DISTINCT dependency) AS dependencies;
$$;

// Procedure to calculate blast radius
CREATE PROCEDURE calculate_blast_radius(
    asset_id STRING
) RETURNS (affected_assets LIST, count INT)
LANGUAGE CYPHER AS $$
    MATCH (a:Asset {id: asset_id})
    MATCH (a)-[*1..3]-(affected:Asset)
    WHERE affected.id <> asset_id
    WITH collect(DISTINCT affected) AS affected_assets
    RETURN affected_assets, size(affected_assets) AS count;
$$;

// Create initial system nodes
MERGE (sys:System {name: 'CloudScope', version: '1.0.0', initialized_at: datetime()});

EOF

    # Execute the schema initialization
    docker exec -i cloudscope-memgraph mgconsole --host=$MEMGRAPH_HOST --port=$MEMGRAPH_PORT < /tmp/cloudscope-schema.cypher
    
    if [ $? -eq 0 ]; then
        log_success "Schema initialized successfully"
        rm /tmp/cloudscope-schema.cypher
    else
        log_error "Failed to initialize schema"
        return 1
    fi
}

# Create sample data (optional)
create_sample_data() {
    log_info "Creating sample data..."
    
    cat << 'EOF' > /tmp/cloudscope-sample-data.cypher
// Sample CloudScope Data

// Create sample assets
CALL create_or_update_asset(
    'aws-ec2-i-1234567890',
    'WebServer-01',
    'EC2_Instance',
    'aws_collector',
    {region: 'us-east-1', instance_type: 't3.medium', vpc_id: 'vpc-123'},
    75,
    '2025-01-01T00:00:00Z',
    '2025-01-17T00:00:00Z'
) YIELD asset;

CALL create_or_update_asset(
    'aws-rds-db-prod-01',
    'ProductionDB',
    'RDS_Instance',
    'aws_collector',
    {engine: 'postgres', version: '14.6', multi_az: true},
    85,
    '2025-01-01T00:00:00Z',
    '2025-01-17T00:00:00Z'
) YIELD asset;

CALL create_or_update_asset(
    'azure-vm-app-01',
    'AppServer-01',
    'Azure_VM',
    'azure_collector',
    {resource_group: 'rg-production', size: 'Standard_D4s_v3'},
    60,
    '2025-01-01T00:00:00Z',
    '2025-01-17T00:00:00Z'
) YIELD asset;

// Create relationships
CALL create_asset_relationship(
    'aws-ec2-i-1234567890',
    'aws-rds-db-prod-01',
    'CONNECTS_TO',
    {port: 5432, protocol: 'PostgreSQL'}
) YIELD created;

// Add tags
CALL add_asset_tags(
    'aws-ec2-i-1234567890',
    {environment: 'production', team: 'platform', compliance: 'pci-dss'}
) YIELD asset;

CALL add_asset_tags(
    'aws-rds-db-prod-01',
    {environment: 'production', team: 'database', compliance: 'pci-dss'}
) YIELD asset;

// Create compliance nodes
CREATE (c1:Compliance {
    id: 'pci-dss-3.2.1',
    framework: 'PCI-DSS',
    version: '3.2.1',
    requirement: 'Encrypt transmission of cardholder data',
    description: 'Use strong cryptography and security protocols'
});

CREATE (c2:Compliance {
    id: 'soc2-cc6.1',
    framework: 'SOC2',
    version: 'Type II',
    requirement: 'Logical and Physical Access Controls',
    description: 'The entity implements logical access security measures'
});

// Link assets to compliance requirements
MATCH (a:Asset {id: 'aws-rds-db-prod-01'})
MATCH (c:Compliance {id: 'pci-dss-3.2.1'})
CREATE (a)-[:COMPLIES_WITH {status: 'compliant', last_checked: datetime()}]->(c);

// Create sample findings
CREATE (f1:Finding {
    id: 'finding-001',
    title: 'Unencrypted Data in Transit',
    description: 'Application server communicating with database without TLS',
    severity: 'HIGH',
    status: 'OPEN',
    created_at: datetime(),
    asset_id: 'aws-ec2-i-1234567890'
});

MATCH (a:Asset {id: 'aws-ec2-i-1234567890'})
MATCH (f:Finding {id: 'finding-001'})
CREATE (a)-[:HAS_FINDING]->(f);

EOF

    # Execute sample data creation
    docker exec -i cloudscope-memgraph mgconsole --host=$MEMGRAPH_HOST --port=$MEMGRAPH_PORT < /tmp/cloudscope-sample-data.cypher
    
    if [ $? -eq 0 ]; then
        log_success "Sample data created successfully"
        rm /tmp/cloudscope-sample-data.cypher
    else
        log_error "Failed to create sample data"
        return 1
    fi
}

# Verify schema
verify_schema() {
    log_info "Verifying schema..."
    
    # Check if procedures exist
    docker exec cloudscope-memgraph echo "CALL mg.procedures() YIELD name WHERE name STARTS WITH 'create_or_update_asset' RETURN count(name) AS count;" | mgconsole --host=$MEMGRAPH_HOST --port=$MEMGRAPH_PORT
    
    # Count nodes
    docker exec cloudscope-memgraph echo "MATCH (n) RETURN labels(n) AS label, count(n) AS count;" | mgconsole --host=$MEMGRAPH_HOST --port=$MEMGRAPH_PORT
}

# Main function
main() {
    log_info "CloudScope Database Initialization"
    log_info "=================================="
    
    # Check if Memgraph is accessible
    if ! check_memgraph; then
        log_error "Please ensure Memgraph is running:"
        echo "  docker-compose up -d memgraph"
        exit 1
    fi
    
    # Initialize schema
    init_schema
    
    # Ask about sample data
    read -p "Create sample data? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        create_sample_data
    fi
    
    # Verify schema
    verify_schema
    
    log_success "Database initialization complete!"
}

# Run main function
main "$@"
