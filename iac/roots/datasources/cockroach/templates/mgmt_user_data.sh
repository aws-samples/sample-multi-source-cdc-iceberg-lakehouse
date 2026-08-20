#!/bin/bash
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

# CockroachDB Management Instance Setup Script - INSECURE MODE

# Update system packages
dnf update -y
dnf install -y wget jq chrony postgresql15

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

# Set hostname
# hostnamectl set-hostname ${cluster_name}-mgmt

# Download and install CockroachDB
echo "Downloading CockroachDB..."
cd /tmp
wget -qO- https://binaries.cockroachdb.com/cockroach-v25.2.2.linux-amd64.tgz | tar xvz
cp -i cockroach-v25.2.2.linux-amd64/cockroach /usr/local/bin/
chmod +x /usr/local/bin/cockroach

# Everything below this line is commented out
: '
# Create cluster initialization script
cat > /home/ec2-user/initialize_cluster.sh << 'EOF'
#!/bin/bash
# CockroachDB Cluster Initialization Script - INSECURE MODE

NODE_IP="${cockroach_nodes[0]}"
LB_ENDPOINT="${lb_endpoint}"

echo "Waiting for CockroachDB nodes to be ready..."
sleep 60  # Give nodes time to start up

echo "Initializing CockroachDB cluster using node at $NODE_IP..."
cockroach init --insecure --host=$NODE_IP:26257

echo "Cluster initialization complete!"
echo "You can now connect to the cluster using:"
echo "cockroach sql --insecure --host=$LB_ENDPOINT:26257"
echo ""
echo "Or connect to individual nodes:"
%{ for i, ip in cockroach_nodes ~}
echo "Node ${i + 1}: cockroach sql --insecure --host=${ip}:26257"
%{ endfor ~}
EOF

chmod +x /home/ec2-user/initialize_cluster.sh
chown ec2-user:ec2-user /home/ec2-user/initialize_cluster.sh

# Create database setup script
cat > /home/ec2-user/setup_database.sh << 'EOF'
#!/bin/bash
# CockroachDB Database Setup Script - INSECURE MODE

LB_ENDPOINT="${lb_endpoint}"

echo "Setting up sample database..."
cockroach sql --insecure --host=$LB_ENDPOINT:26257 << SQL_COMMANDS
CREATE DATABASE IF NOT EXISTS defaultdb;
CREATE USER IF NOT EXISTS app_user;
GRANT ALL ON DATABASE defaultdb TO app_user;

USE defaultdb;
CREATE TABLE IF NOT EXISTS transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id STRING NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    transaction_type STRING NOT NULL,
    timestamp TIMESTAMPTZ DEFAULT now(),
    description STRING
);

INSERT INTO transactions (account_id, amount, transaction_type, description) VALUES
('ACC001', 1000.00, 'DEPOSIT', 'Initial deposit'),
('ACC001', -50.00, 'WITHDRAWAL', 'ATM withdrawal'),
('ACC002', 2500.00, 'DEPOSIT', 'Salary deposit'),
('ACC002', -125.75, 'PAYMENT', 'Online purchase'),
('ACC003', 750.00, 'DEPOSIT', 'Transfer from savings'),
('ACC003', -25.00, 'FEE', 'Monthly maintenance fee'),
('ACC004', 5000.00, 'DEPOSIT', 'Business revenue'),
('ACC004', -1200.00, 'PAYMENT', 'Vendor payment');

-- Create some additional sample data
INSERT INTO transactions (account_id, amount, transaction_type, description)
SELECT 
    'ACC' || LPAD((random() * 100)::int::text, 3, '0'),
    (random() * 2000 - 1000)::decimal(10,2),
    CASE WHEN random() < 0.3 THEN 'DEPOSIT' 
         WHEN random() < 0.6 THEN 'WITHDRAWAL'
         WHEN random() < 0.8 THEN 'PAYMENT'
         ELSE 'TRANSFER' END,
    'Sample transaction ' || generate_random_uuid()::text
FROM generate_series(1, 50);
SQL_COMMANDS

echo "Database setup complete!"
echo "Sample data has been inserted into the defaultdb database."
EOF

chmod +x /home/ec2-user/setup_database.sh
chown ec2-user:ec2-user /home/ec2-user/setup_database.sh

# Create cluster status check script
cat > /home/ec2-user/check_cluster.sh << 'EOF'
#!/bin/bash
# CockroachDB Cluster Status Check Script - INSECURE MODE

LB_ENDPOINT="${lb_endpoint}"

echo "=== CockroachDB Cluster Status ==="
echo "Checking cluster status via load balancer: $LB_ENDPOINT:26257"
echo ""

echo "Node Status:"
cockroach node status --insecure --host=$LB_ENDPOINT:26257

echo ""
echo "Database List:"
cockroach sql --insecure --host=$LB_ENDPOINT:26257 -e "SHOW DATABASES;"

echo ""
echo "Cluster Info:"
cockroach sql --insecure --host=$LB_ENDPOINT:26257 -e "SELECT * FROM crdb_internal.cluster_settings WHERE variable = 'cluster.organization' OR variable = 'version';"

echo ""
echo "Individual Node Connections:"
%{ for i, ip in cockroach_nodes ~}
echo "Testing connection to Node ${i + 1} (${ip}):"
cockroach sql --insecure --host=${ip}:26257 -e "SELECT 'Node ${i + 1} - Connected' AS status;" 2>/dev/null || echo "Node ${i + 1} - Connection failed"
%{ endfor ~}
EOF

chmod +x /home/ec2-user/check_cluster.sh
chown ec2-user:ec2-user /home/ec2-user/check_cluster.sh

# Create sample query script
cat > /home/ec2-user/sample_queries.sh << 'EOF'
#!/bin/bash
# CockroachDB Sample Queries Script - INSECURE MODE

LB_ENDPOINT="${lb_endpoint}"

echo "=== Running Sample Queries ==="
echo "Connecting to: $LB_ENDPOINT:26257"
echo ""

echo "1. Account Balances:"
cockroach sql --insecure --host=$LB_ENDPOINT:26257 -e "
USE defaultdb;
SELECT 
    account_id,
    SUM(amount) as balance,
    COUNT(*) as transaction_count
FROM transactions 
GROUP BY account_id 
ORDER BY balance DESC;
"

echo ""
echo "2. Recent Transactions:"
cockroach sql --insecure --host=$LB_ENDPOINT:26257 -e "
USE defaultdb;
SELECT 
    account_id,
    amount,
    transaction_type,
    description,
    timestamp
FROM transactions 
ORDER BY timestamp DESC 
LIMIT 10;
"

echo ""
echo "3. Transaction Summary by Type:"
cockroach sql --insecure --host=$LB_ENDPOINT:26257 -e "
USE defaultdb;
SELECT 
    transaction_type,
    COUNT(*) as count,
    SUM(amount) as total_amount,
    AVG(amount) as avg_amount
FROM transactions 
GROUP BY transaction_type 
ORDER BY count DESC;
"
EOF

chmod +x /home/ec2-user/sample_queries.sh
chown ec2-user:ec2-user /home/ec2-user/sample_queries.sh

# Create README file with usage instructions
cat > /home/ec2-user/README.md << 'EOF'
# CockroachDB Management Instance - INSECURE MODE

⚠️ **WARNING: This is an INSECURE deployment for testing purposes only!**

This instance provides tools for managing the CockroachDB cluster in insecure mode.

## Setup Process

Follow these steps in order:

1. **Initialize the cluster** (run this first):
   ```bash
   ./initialize_cluster.sh
   ```

2. **Set up the sample database**:
   ```bash
   ./setup_database.sh
   ```

3. **Check cluster status**:
   ```bash
   ./check_cluster.sh
   ```

4. **Run sample queries**:
   ```bash
   ./sample_queries.sh
   ```

## Cluster Information

- **Cluster Name**: ${cluster_name}
- **Node Count**: ${node_count}
- **Load Balancer**: ${lb_endpoint}
- **Node IPs**: ${join(", ", cockroach_nodes)}

## Connecting to the Database

### Via Load Balancer (Recommended):
```bash
cockroach sql --insecure --host=${lb_endpoint}:26257
```

### Via Individual Nodes:
%{ for i, ip in cockroach_nodes ~}
```bash
# Node ${i + 1}
cockroach sql --insecure --host=${ip}:26257
```
%{ endfor ~}

## Admin UI Access

Access the CockroachDB Admin UI through any node or the load balancer:
- Load Balancer: http://${lb_endpoint}:8080
%{ for i, ip in cockroach_nodes ~}
- Node ${i + 1}: http://${ip}:8080
%{ endfor ~}

## Common Commands

### Check cluster status:
```bash
cockroach node status --insecure --host=${lb_endpoint}:26257
```

### List databases:
```bash
cockroach sql --insecure --host=${lb_endpoint}:26257 -e "SHOW DATABASES;"
```

### Connect to sample database:
```bash
cockroach sql --insecure --host=${lb_endpoint}:26257 --database=defaultdb
```

## Security Notes

- **No authentication required** - any user can connect as root
- **No encryption** - all data transmitted in plain text
- **No authorization** - all users have full access to all data
- **Use only for testing and development**

## Troubleshooting

- Check node logs: `sudo journalctl -u insecurecockroachdb -f`
- Verify time sync: `chronyc sources -v`
- Check network connectivity between nodes
- Ensure all nodes are running: `./check_cluster.sh`

EOF

chown ec2-user:ec2-user /home/ec2-user/README.md

# Wait for nodes to be ready, then automatically initialize the cluster
echo "Waiting for CockroachDB nodes to be ready before initialization..."
sleep 90  # Give nodes time to start up

# Run cluster initialization automatically
echo "Auto-initializing CockroachDB cluster..."
su - ec2-user -c "/home/ec2-user/initialize_cluster.sh" >> /var/log/cockroach-mgmt-setup.log 2>&1

# Log completion
echo "CockroachDB management instance setup completed at $(date)" >> /var/log/cockroach-mgmt-setup.log
echo "Management instance for ${cluster_name} is ready!" >> /var/log/cockroach-mgmt-setup.log
echo "Cluster initialization attempted automatically." >> /var/log/cockroach-mgmt-setup.log
'

# Create a simple check_cluster.sh script that just shows CockroachDB is installed
cat > /home/ec2-user/check_cluster.sh << 'EOF'
#!/bin/bash
echo "CockroachDB is installed but not configured."
echo "CockroachDB version:"
cockroach version
EOF

chmod +x /home/ec2-user/check_cluster.sh
chown ec2-user:ec2-user /home/ec2-user/check_cluster.sh

# Log completion
echo "CockroachDB management instance installation completed at $(date), but configuration was skipped" >> /var/log/cockroach-mgmt-setup.log
