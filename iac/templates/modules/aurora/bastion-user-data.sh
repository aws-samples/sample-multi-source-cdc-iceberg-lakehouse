#!/bin/bash -ex
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
echo "STARTING AURORA BASTION HOST SETUP"

APP_NAME="${app_name}"
ENV_NAME="${env_name}"
AURORA_PORT="${aurora_port}"
DATABASE_NAME="${database_name}"
MASTER_USERNAME="${username}"

TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" 2>/dev/null)
AWS_REGION=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/placement/region 2>/dev/null)

echo "Using AWS Region: $AWS_REGION"

# Update system and install PostgreSQL client
yum update -y
yum install -y postgresql17 awscli jq

# Set environment variables for easy access
cat >> /home/ec2-user/.bashrc << EOF

# Aurora Connection Environment Variables
export APP_NAME="$APP_NAME"
export ENV_NAME="$ENV_NAME"
export AURORA_PORT="$AURORA_PORT"
export DATABASE_NAME="$DATABASE_NAME"
export MASTER_USERNAME="$MASTER_USERNAME"
export AWS_REGION="$AWS_REGION"

# Helper function to get Aurora endpoint
get_aurora_endpoint() {
    aws ssm get-parameter \
        --name "/$APP_NAME/$ENV_NAME/aurora-cluster-endpoint" \
        --with-decryption \
        --query 'Parameter.Value' \
        --output text \
        --region "$AWS_REGION"
}

# Helper function to get Aurora password from Secrets Manager
get_aurora_password() {
    aws secretsmanager get-secret-value \
        --secret-id "$APP_NAME-$ENV_NAME-aurora-db-secret" \
        --query 'SecretString' \
        --output text \
        --region "$AWS_REGION" | jq -r '.password'
}

# Helper function to connect to Aurora
connect_to_aurora() {
    echo "Connecting to Aurora PostgreSQL..."
    echo "Getting Aurora endpoint..."
    AURORA_ENDPOINT=\$(get_aurora_endpoint)
    
    if [ -z "\$AURORA_ENDPOINT" ]; then
        echo "ERROR: Could not retrieve Aurora endpoint"
        return 1
    fi
    
    echo "Getting Aurora password..."
    AURORA_PASSWORD=\$(get_aurora_password)
    
    if [ -z "\$AURORA_PASSWORD" ]; then
        echo "ERROR: Could not retrieve Aurora password"
        return 1
    fi
    
    export PGPASSWORD="\$AURORA_PASSWORD"
    
    echo "Connection details:"
    echo "  Aurora endpoint: \$AURORA_ENDPOINT"
    echo "  Database: $DATABASE_NAME"
    echo "  Username: $MASTER_USERNAME"
    echo "  Port: $AURORA_PORT"
    echo "  Region: $AWS_REGION"
    echo ""
    
    echo "Connecting to Aurora..."
    psql -h "\$AURORA_ENDPOINT" -p "$AURORA_PORT" -U "$MASTER_USERNAME" -d "$DATABASE_NAME"
}

# Create connection script
alias aurora='connect_to_aurora'
echo ""
echo "=== Aurora Connection Setup Complete ==="
echo "Use 'aurora' command to connect to Aurora database"
echo "Or use './connect-to-aurora.sh' script"
EOF

# Create connection script for easy access
cat > /home/ec2-user/connect-to-aurora.sh << EOF
#!/bin/bash
source ~/.bashrc
connect_to_aurora
EOF

chmod +x /home/ec2-user/connect-to-aurora.sh
chown ec2-user:ec2-user /home/ec2-user/connect-to-aurora.sh

# Set ownership for .bashrc changes
chown ec2-user:ec2-user /home/ec2-user/.bashrc

echo ""
echo "=== Aurora Bastion Host Setup Completed! ==="
echo ""
echo "Connection Commands:"
echo "  1. Connect via alias: aurora"
echo "  2. Connect via script: ./connect-to-aurora.sh"
echo ""
echo "pglogical Extension Commands:"
echo "  1. Setup pglogical: pglogical-setup"
echo "  2. Check status: pglogical-status"
echo "  3. Manual setup: ./setup-pglogical.sh"
echo ""
echo "Manual Connection:"
echo "  psql -h \$(get_aurora_endpoint) -p $AURORA_PORT -U $MASTER_USERNAME -d $DATABASE_NAME"
echo ""
echo "SSM Connection Command:"
echo "  aws ssm start-session --target \$(aws ec2 describe-instances --filters \"Name=private-ip-address,Values=\$(aws ssm get-parameter --name \"/$APP_NAME/$ENV_NAME/aurora-bastion-host\" --with-decryption --query \"Parameter.Value\" --output text)\" --query \"Reservations[0].Instances[0].InstanceId\" --output text)"

# Create script to install pglogical extension
cat > /home/ec2-user/setup-pglogical.sh << EOF
#!/bin/bash
echo "=== Setting up pglogical extension on Aurora PostgreSQL ==="
source ~/.bashrc

# Function to wait for Aurora to be ready
wait_for_aurora() {
    echo "Waiting for Aurora to be ready..."
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        echo "Attempt $attempt/$max_attempts: Checking Aurora connectivity..."
        
        AURORA_ENDPOINT=\$(get_aurora_endpoint)
        if [ -z "\$AURORA_ENDPOINT" ]; then
            echo "Aurora endpoint not available yet, waiting 30 seconds..."
            sleep 30
            ((attempt++))
            continue
        fi
        
        AURORA_PASSWORD=\$(get_aurora_password)
        if [ -z "\$AURORA_PASSWORD" ]; then
            echo "Aurora password not available yet, waiting 30 seconds..."
            sleep 30
            ((attempt++))
            continue
        fi
        
        export PGPASSWORD="\$AURORA_PASSWORD"
        
        # Try to connect and run a simple query
        if psql -h "\$AURORA_ENDPOINT" -p "$AURORA_PORT" -U "$MASTER_USERNAME" -d "$DATABASE_NAME" -c "SELECT 1;" >/dev/null 2>&1; then
            echo "Aurora is ready!"
            return 0
        else
            echo "Aurora not ready yet, waiting 30 seconds..."
            sleep 30
            ((attempt++))
        fi
    done
    
    echo "ERROR: Aurora did not become ready within $$((max_attempts * 30)) seconds"
    return 1
}

# Function to create pglogical extension
create_pglogical_extension() {
    echo "Creating pglogical extension..."
    
    AURORA_ENDPOINT=\$(get_aurora_endpoint)
    AURORA_PASSWORD=\$(get_aurora_password)
    export PGPASSWORD="\$AURORA_PASSWORD"
    
    # Create the pglogical extension
    echo "Executing: CREATE EXTENSION IF NOT EXISTS pglogical;"
    psql -h "\$AURORA_ENDPOINT" -p "$AURORA_PORT" -U "$MASTER_USERNAME" -d "$DATABASE_NAME" \
        -c "CREATE EXTENSION IF NOT EXISTS pglogical;"
    
    if [ $$? -eq 0 ]; then
        echo "SUCCESS: pglogical extension created successfully"
    else
        echo "ERROR: Failed to create pglogical extension"
        return 1
    fi
}

# Function to verify pglogical extension
verify_pglogical_extension() {
    echo "Verifying pglogical extension installation..."
    
    AURORA_ENDPOINT=\$(get_aurora_endpoint)
    AURORA_PASSWORD=\$(get_aurora_password)
    export PGPASSWORD="\$AURORA_PASSWORD"
    
    # Verify the extension exists
    echo "Executing: SELECT * FROM pg_extension WHERE extname = 'pglogical';"
    RESULT=$$(psql -h "\$AURORA_ENDPOINT" -p "$AURORA_PORT" -U "$MASTER_USERNAME" -d "$DATABASE_NAME" \
        -t -c "SELECT extname, extversion FROM pg_extension WHERE extname = 'pglogical';")
    
    if [ ! -z "$RESULT" ]; then
        echo "SUCCESS: pglogical extension is installed"
        echo "Extension details: $RESULT"
        
        # Additional verification - check pglogical functions
        echo "Checking pglogical functions..."
        FUNCTIONS=$$(psql -h "\$AURORA_ENDPOINT" -p "$AURORA_PORT" -U "$MASTER_USERNAME" -d "$DATABASE_NAME" \
            -t -c "SELECT count(*) FROM pg_proc WHERE proname LIKE 'pglogical%';")
        echo "Found $FUNCTIONS pglogical functions"
        
        return 0
    else
        echo "ERROR: pglogical extension is not installed"
        return 1
    fi
}

# Main execution
main() {
    echo "Starting pglogical setup process..."
    
    # Wait for Aurora to be ready
    if ! wait_for_aurora; then
        echo "FAILED: Aurora not ready"
        exit 1
    fi
    
    # Create pglogical extension
    if ! create_pglogical_extension; then
        echo "FAILED: Could not create pglogical extension"
        exit 1
    fi
    
    # Verify pglogical extension
    if ! verify_pglogical_extension; then
        echo "FAILED: pglogical extension verification failed"
        exit 1
    fi
    
    echo ""
    echo "=== pglogical Extension Setup Complete! ==="
    echo "The pglogical extension is now available in your Aurora PostgreSQL database."
    echo ""
}

# Run main function
main "$$@"
EOF

chmod +x /home/ec2-user/setup-pglogical.sh
chown ec2-user:ec2-user /home/ec2-user/setup-pglogical.sh

# Create a helper script for manual pglogical operations
cat > /home/ec2-user/pglogical-helper.sh << EOF
#!/bin/bash
source ~/.bashrc

# Function to check pglogical status
check_pglogical_status() {
    echo "=== pglogical Extension Status ==="
    AURORA_ENDPOINT=\$(get_aurora_endpoint)
    AURORA_PASSWORD=\$(get_aurora_password)
    export PGPASSWORD="\$AURORA_PASSWORD"
    
    echo "Checking if pglogical extension is installed..."
    psql -h "\$AURORA_ENDPOINT" -p "$AURORA_PORT" -U "$MASTER_USERNAME" -d "$DATABASE_NAME" \
        -c "SELECT extname, extversion, extrelocatable FROM pg_extension WHERE extname = 'pglogical';"
    
    echo ""
    echo "Checking pglogical nodes..."
    psql -h "\$AURORA_ENDPOINT" -p "$AURORA_PORT" -U "$MASTER_USERNAME" -d "$DATABASE_NAME" \
        -c "SELECT * FROM pglogical.node;" 2>/dev/null || echo "No pglogical nodes configured yet"
}

# Function to create pglogical node
create_pglogical_node() {
    local node_name=$${1:-"aurora_node"}
    echo "Creating pglogical node: $node_name"
    
    AURORA_ENDPOINT=\$(get_aurora_endpoint)
    AURORA_PASSWORD=\$(get_aurora_password)
    export PGPASSWORD="\$AURORA_PASSWORD"
    
    psql -h "\$AURORA_ENDPOINT" -p "$AURORA_PORT" -U "$MASTER_USERNAME" -d "$DATABASE_NAME" \
        -c "SELECT pglogical.create_node(node_name := '$node_name', dsn := 'host=\$AURORA_ENDPOINT port=$AURORA_PORT dbname=$DATABASE_NAME user=$MASTER_USERNAME');"
}

# Show usage if no arguments
if [ $$# -eq 0 ]; then
    echo "pglogical Helper Script"
    echo "Usage: $$0 [command]"
    echo ""
    echo "Available commands:"
    echo "  status              - Check pglogical extension status"
    echo "  create-node [name]  - Create pglogical node (default: aurora_node)"
    echo ""
    exit 1
fi

case "$$1" in
    "status")
        check_pglogical_status
        ;;
    "create-node")
        create_pglogical_node "$$2"
        ;;
    *)
        echo "Unknown command: $$1"
        echo "Use '$$0' with no arguments to see usage"
        exit 1
        ;;
esac
EOF

chmod +x /home/ec2-user/pglogical-helper.sh
chown ec2-user:ec2-user /home/ec2-user/pglogical-helper.sh

# Add pglogical information to the bashrc
cat >> /home/ec2-user/.bashrc << EOF

# pglogical Extension Helper Functions
alias pglogical-status='./pglogical-helper.sh status'
alias pglogical-setup='./setup-pglogical.sh'

echo ""
echo "=== pglogical Extension Available ==="
echo "Commands:"
echo "  pglogical-setup     - Install and verify pglogical extension"
echo "  pglogical-status    - Check pglogical extension status"
echo "  ./pglogical-helper.sh create-node [name] - Create pglogical node"
EOF