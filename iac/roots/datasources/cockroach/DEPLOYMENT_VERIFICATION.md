# CockroachDB Insecure Deployment Verification

## Changes Made for Insecure Deployment

### 1. User Data Scripts Updated

#### Node User Data (`templates/user_data.sh`)
- ✅ Removed certificate directory creation
- ✅ Changed systemd service from `securecockroachdb.service` to `insecurecockroachdb.service`
- ✅ Updated CockroachDB start command to use `--insecure` flag
- ✅ Removed certificate-related dependencies
- ✅ Added automatic service startup after join list configuration

#### Management User Data (`templates/mgmt_user_data.sh`)
- ✅ Removed certificate generation scripts
- ✅ Removed SSH/sshpass dependencies (not needed for insecure)
- ✅ Updated all CockroachDB commands to use `--insecure` flag
- ✅ Added comprehensive management scripts for insecure deployment
- ✅ Added automatic cluster initialization
- ✅ Created sample database setup with more test data

### 2. Terraform Configuration

#### Security Groups
- ✅ Proper security group rules for inter-node communication (port 26257)
- ✅ Admin UI access rules (port 8080)
- ✅ Management instance access to all nodes
- ✅ Load balancer health check access

#### Load Balancer
- ✅ Network Load Balancer configured for SQL port (26257)
- ✅ Admin UI load balancer configured (port 8080)
- ✅ Health checks configured to use HTTP endpoint `/health?ready=1`

#### Outputs
- ✅ Updated outputs to reflect insecure deployment
- ✅ Added connection information for both load balancer and individual nodes
- ✅ Added security warnings in output descriptions
- ✅ Added quick start commands

### 3. README Documentation
- ✅ Comprehensive README with insecure deployment instructions
- ✅ Clear security warnings throughout
- ✅ Step-by-step deployment guide
- ✅ Network configuration details
- ✅ Load balancer setup instructions
- ✅ Post-deployment verification steps

## Deployment Flow Verification

### 1. Infrastructure Deployment Order
1. **KMS Keys** → **IAM Roles** → **Network** (Foundation)
2. **CockroachDB Nodes** (3 instances with user data)
3. **Load Balancer** with target groups and health checks
4. **Management Instance** (deployed after nodes are ready)

### 2. Node Startup Process
1. **System Setup**: Package updates, SSM agent, time sync
2. **CockroachDB Installation**: Download and install v25.2.2
3. **Storage Setup**: Format and mount data volume
4. **Service Configuration**: Create insecure systemd service
5. **Join List Building**: Query AWS API for all node IPs
6. **Service Startup**: Start CockroachDB with insecure flag

### 3. Management Instance Process
1. **System Setup**: Package updates, SSM agent, time sync
2. **CockroachDB Installation**: Download client tools
3. **Script Creation**: Initialize, setup, check, and query scripts
4. **Auto-Initialization**: Automatically initialize cluster after 90s delay

### 4. Cluster Initialization
1. **Wait for Nodes**: Management instance waits for nodes to be ready
2. **Initialize Cluster**: Run `cockroach init --insecure`
3. **Database Setup**: Create sample database and test data
4. **Verification**: Provide scripts to check cluster status

## Security Considerations (INSECURE DEPLOYMENT)

### ⚠️ Security Warnings
- **No Authentication**: Any user can connect as root without password
- **No Encryption**: All data transmitted in plain text
- **No Authorization**: All users have full access to all data
- **Open Access**: Cluster is open to any client that can reach node IPs

### Network Security
- **VPC Isolation**: Nodes are in private subnets
- **Security Groups**: Restrict access to VPC CIDR blocks
- **No Public IPs**: Instances not directly accessible from internet
- **SSM Access**: Use Session Manager for secure shell access

## Connection Methods

### Via Load Balancer (Recommended)
```bash
cockroach sql --insecure --host=<load-balancer-dns>:26257
```

### Via Individual Nodes
```bash
cockroach sql --insecure --host=<node-ip>:26257
```

### Admin UI Access
- Load Balancer: `http://<load-balancer-dns>:8080`
- Individual Nodes: `http://<node-ip>:8080`

## Post-Deployment Verification Steps

### 1. Connect to Management Instance
```bash
aws ssm start-session --target <mgmt-instance-id> --region <region>
```

### 2. Verify Database Connectivity
```bash
cockroach sql --insecure --host=<load-balancer>:26257 -e "SHOW DATABASES;"
```

## Troubleshooting

### Common Issues
1. **Nodes not joining**: Check security group rules and time sync
2. **Load balancer health checks failing**: Verify port 8080 accessibility
3. **Connection timeouts**: Check VPC routing and security groups
4. **Time sync issues**: Verify Amazon Time Sync Service configuration


## Expected Deployment Result

After successful deployment, you should have:
- ✅ 3 CockroachDB nodes running in insecure mode
- ✅ Network Load Balancer distributing traffic
- ✅ Management instance with initialization scripts
- ✅ Sample database with test data
- ✅ Admin UI accessible without authentication
- ✅ All instances accessible via SSM Session Manager

This deployment is now fully configured for **INSECURE MODE** and should work as expected for testing and development purposes.
