#!/bin/bash
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

# CockroachDB installation and configuration script - INSECURE MODE

# Update system packages
dnf update -y
dnf install -y wget jq chrony awscli

# Ensure SSM agent is installed and running (should be pre-installed on AL2023)
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

# Configure Amazon Time Sync Service
echo "Configuring Amazon Time Sync Service..."
cat > /etc/chrony.conf << EOF
# Use Amazon Time Sync Service
server 169.254.169.123 prefer iburst minpoll 4 maxpoll 4

# This directive specify the location of the file containing ID/key pairs for
# NTP authentication.
keyfile /etc/chrony.keys

# This directive specify the file into which chronyd will store the rate
# information.
driftfile /var/lib/chrony/drift

# Uncomment the following line to turn logging on.
#log tracking measurements statistics

# Log files location.
logdir /var/log/chrony

# Stop bad estimates upsetting machine clock.
maxupdateskew 100.0

# This directive enables kernel synchronisation (every 11 minutes) of the
# real-time clock. Note that it can't be used along with the 'rtcfile' directive.
rtcsync

# Step the system clock instead of slewing it if the adjustment is larger than
# one second.
makestep 1.0 3
EOF

# Restart chrony service
systemctl restart chronyd
systemctl enable chronyd

# Verify Amazon Time Sync Service is being used
echo "Verifying Amazon Time Sync Service..."
chronyc sources -v
chronyc tracking

# Set hostname
# INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
# PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
# hostnamectl set-hostname ${cluster_name}-$INSTANCE_ID

# Install CockroachDB
echo "Installing CockroachDB..."
wget -qO- https://binaries.cockroachdb.com/cockroach-v25.2.2.linux-amd64.tgz | tar xvz
cp -i cockroach-v25.2.2.linux-amd64/cockroach /usr/local/bin/
mkdir -p /usr/local/lib/cockroach
cp -i cockroach-v25.2.2.linux-amd64/lib/libgeos.so /usr/local/lib/cockroach/
cp -i cockroach-v25.2.2.linux-amd64/lib/libgeos_c.so /usr/local/lib/cockroach/

# Function to get IMDSv2 token
get_imds_token() {
    curl -X PUT "http://169.254.169.254/latest/api/token" \
        -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" \
        -s --connect-timeout 5 --max-time 10
}

# Function to get current instance's private IP using IMDSv2
get_private_ip() {
    local token=$(get_imds_token)
    curl -H "X-aws-ec2-metadata-token: $token" \
        -s --connect-timeout 5 --max-time 10 \
        http://169.254.169.254/latest/meta-data/local-ipv4
}

# Function to get current instance's region using IMDSv2
get_region() {
    local token=$(get_imds_token)
    curl -H "X-aws-ec2-metadata-token: $token" \
        -s --connect-timeout 5 --max-time 10 \
        http://169.254.169.254/latest/meta-data/placement/region
}

# Function to wait for all CockroachDB instances to be running
wait_for_all_instances() {
    local region=$1
    local expected_count=${node_count}
    local max_attempts=15 
    local attempt=1
    
    echo "Waiting for all $expected_count CockroachDB instances to be running..."
    
    while [ $attempt -le $max_attempts ]; do
        local running_count=$(aws ec2 describe-instances \
            --region "$region" \
            --filters "Name=tag:Component,Values=cockroachdb" "Name=instance-state-name,Values=running" \
            --query 'length(Reservations[].Instances[])' \
            --output text 2>/dev/null || echo "0")
        
        echo "Attempt $attempt/$max_attempts: Found $running_count/$expected_count running instances"
        
        if [ "$running_count" -eq "$expected_count" ]; then
            echo "All $expected_count instances are running!"
            return 0
        fi
        
        sleep 30
        ((attempt++))
    done
    
    echo "ERROR: Timeout waiting for all instances to be running"
    return 1
}

# Function to get all CockroachDB instances' private IPs
get_cockroach_instances() {
    local region=$1
    aws ec2 describe-instances \
        --region "$region" \
        --filters "Name=tag:Component,Values=cockroachdb" "Name=instance-state-name,Values=running" \
        --query 'Reservations[].Instances[].PrivateIpAddress' \
        --output text | tr '\t' '\n' | sort
}

# Setup CockroachDB systemd service
setup_cockroach_service() {
    echo "Setting up CockroachDB systemd service..."
    
    # Get current instance info
    local PRIVATE_IP=$(get_private_ip)
    local REGION=$(get_region)
    
    echo "Current instance private IP: $PRIVATE_IP"
    echo "Current AWS region: $REGION"
    
    # Wait for all instances to be running
    if ! wait_for_all_instances "$REGION"; then
        echo "ERROR: Failed to wait for all instances. Proceeding anyway..."
    fi
    
    # Get all cockroach instances
    local COCKROACH_IPS=$(get_cockroach_instances "$REGION")
    echo "Found CockroachDB instances:"
    echo "$COCKROACH_IPS"
    
    # Create join string (comma-separated list of IPs)
    local JOIN_STRING=""
    for ip in $COCKROACH_IPS; do
        if [ -n "$JOIN_STRING" ]; then
            JOIN_STRING="$JOIN_STRING,"
        fi
        JOIN_STRING="$JOIN_STRING$ip"
    done
    
    echo "Join string: $JOIN_STRING"
    
    # Create the cockroach directory
    echo "Creating /var/lib/cockroach directory..."
    mkdir -p /var/lib/cockroach
    
    # Create cockroach user
    echo "Creating cockroach user..."
    if ! id "cockroach" &>/dev/null; then
        useradd cockroach
        echo "User 'cockroach' created"
    else
        echo "User 'cockroach' already exists"
    fi
    
    # Set ownership
    echo "Setting ownership of /var/lib/cockroach to cockroach user..."
    chown cockroach /var/lib/cockroach
    
    # Create the systemd service file
    echo "Creating systemd service file..."
    cat > /etc/systemd/system/insecurecockroachdb.service << EOF
[Unit]
Description=Cockroach Database cluster node
Requires=network.target
[Service]
Type=notify
WorkingDirectory=/var/lib/cockroach
ExecStart=/usr/local/bin/cockroach start --insecure --advertise-addr=$PRIVATE_IP --join=$JOIN_STRING --cache=.25 --max-sql-memory=.25
TimeoutStopSec=300
Restart=always
RestartSec=10
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=cockroach
User=cockroach
[Install]
WantedBy=default.target
EOF
    
    echo "Service file created at /etc/systemd/system/insecurecockroachdb.service"
    
    # Reload systemd
    echo "Reloading systemd daemon..."
    systemctl daemon-reload
    
    # Enable the service
    echo "Enabling insecurecockroachdb service..."
    systemctl enable insecurecockroachdb.service
    
    # Start the service
    echo "Starting insecurecockroachdb service..."
    systemctl start insecurecockroachdb.service
    
    # Wait a bit for the service to start
    sleep 15
    
    # Check service status
    echo "Checking service status..."
    systemctl status insecurecockroachdb.service --no-pager
    
    # Initialize the cluster (only on the first node based on IP sorting)
    local FIRST_IP=$(echo "$COCKROACH_IPS" | head -n1)
    if [ "$PRIVATE_IP" = "$FIRST_IP" ]; then
        echo "This is the first node ($PRIVATE_IP). Initializing the cluster..."
        
        # Wait a bit more for all nodes to be ready
        sleep 30
        
        # Initialize the cluster
        echo "Running: cockroach init --insecure --host=$PRIVATE_IP"
        if /usr/local/bin/cockroach init --insecure --host=$PRIVATE_IP; then
            echo "Cluster initialized successfully!"
        else
            echo "Cluster initialization failed or cluster already initialized"
        fi
    else
        echo "This is not the first node ($PRIVATE_IP != $FIRST_IP). Skipping cluster initialization."
    fi
    
    echo "CockroachDB setup complete!"
    echo "Service configuration:"
    echo "  Advertise address: $PRIVATE_IP"
    echo "  Join addresses: $JOIN_STRING"
    echo "  First node (initializer): $FIRST_IP"
    echo ""
    echo "To check status: systemctl status insecurecockroachdb"
    echo "To view logs: journalctl -u insecurecockroachdb -f"
}

# Run the setup in the background to avoid blocking the user data script
echo "Starting CockroachDB setup in background..."
setup_cockroach_service > /var/log/cockroach-setup.log 2>&1 &

echo "CockroachDB setup initiated. Check /var/log/cockroach-setup.log for progress."


