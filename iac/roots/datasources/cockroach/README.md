# CockroachDB Insecure Deployment on AWS EC2

This directory contains Terraform configurations for deploying CockroachDB in an **insecure mode** on AWS EC2 instances. This deployment is intended for **testing and development purposes only**.

> See the [root README](../../../../README.md#important-notice) for the
> project-level insecure-mode notice; this module intentionally ships without
> TLS, authentication, or authorization for sample simplicity.

## ⚠️ Security Warning

**This is an insecure deployment configuration with the following risks:**
- Your cluster is open to any client that can access any node's IP addresses
- Any user, including root, can log in without providing a password
- Any user connecting as root can read or write any data in your cluster
- There is no network encryption or authentication, and thus no confidentiality

**Do not use this configuration in production environments.**

## Prerequisites

- SSH access to each EC2 instance (required for distributing and starting CockroachDB binaries)
- AWS CLI configured with appropriate permissions
- Terraform >= 1.8.0
- Network configuration allowing TCP communication on:
  - Port **26257** for intra-cluster and client-cluster communication
  - Port **8080** to expose the DB Console

## Architecture Requirements

### Node Distribution
- **Do not run multiple node processes on the same VM or machine** - this defeats CockroachDB's replication and creates a single point of failure
- Start each node on a separate VM or machine
- Use at least **3 nodes** to ensure survivability

### Storage Configuration
For nodes with multiple disks or SSDs, choose one approach:
1. **RAID Volume**: Configure disks as a single RAID volume, then pass to `--store` flag
2. **Multiple Stores**: Provide separate `--store` flag for each disk

⚠️ **Warning**: If you start a node with multiple `--store` flags, you cannot scale back to a single store. You must decommission the node and start fresh.

### Locality Configuration
Use the `--locality` flag to describe each node's location:
```bash
--locality=region=west,zone=us-west-1
```
- Order key-value pairs from most to least inclusive
- Keys and order must be consistent across all nodes

## Deployment Strategies

### Single Availability Zone
- **Tolerate 1 node failure**: Use at least 3 nodes with default 3-way replication
- **Tolerate 2 node failures**: Use at least 5 nodes and increase replication factor to 5

### Multiple Availability Zones
- **Tolerate 1 AZ failure**: Use at least 3 AZs per region with `--locality` flag
- Use the same number of nodes in each AZ to avoid resource overloading

### Multiple Regions
- **Tolerate 1 region failure**: Use at least 3 regions

## Deployment Steps

### Step 1: Create EC2 Instances

1. Launch an instance for each planned cluster node
2. Create a separate instance for workload testing if needed
3. **Instance Requirements**:
   - Use **m5 instances** (m5.xlarge to m5.8xlarge) with SSD-backed EBS volumes
   - For bare-metal simulation: use **m5d** with SSD Instance Store volumes
   - **m5a**, **m6i**, and **m6a** instances are also acceptable
   - **Avoid "burstable" t2 instances** (they limit single-core load)
4. Ensure all instances are in the **same security group**
5. Note the VPC ID for security group configuration

### Step 2: Configure Network Security

Add the following **Custom TCP inbound rules** to your security group:

#### Inter-node and Client Communication
| Field | Value |
|-------|-------|
| Port Range | 26257 |
| Source | Security group ID (e.g., sg-07ab277a) |

#### Application Data Access
| Field | Value |
|-------|-------|
| Port Range | 26257 |
| Source | Your application's IP ranges |

#### DB Console Access
Choose your access level:

**Partially Open** (Recommended for testing):
| Field | Value |
|-------|-------|
| Port Range | 8080 |
| Source | Specific IP addresses |

**Completely Open** (Less secure):
| Field | Value |
|-------|-------|
| Port Range | 8080 |
| Source | 0.0.0.0/0 |

**Completely Closed** (SSH tunnel required):
| Field | Value |
|-------|-------|
| Port Range | 8080 |
| Source | None (block all) |

#### Load Balancer Health Check
| Field | Value |
|-------|-------|
| Port Range | 8080 |
| Source | VPC IP range in CIDR (e.g., 10.12.0.0/16) |

### Step 3: Synchronize Clocks

CockroachDB requires clock synchronization to preserve data consistency. Nodes automatically shut down if clocks drift more than 80% of the maximum offset (500ms default).

#### Configure Amazon Time Sync Service:
1. Ensure `/etc/chrony.conf` contains:
   ```
   server 169.254.169.123 prefer iburst minpoll 4 maxpoll 4
   ```
2. Comment out other server or pool lines
3. Verify configuration:
   ```bash
   chronyc sources -v
   ```
   Look for a line with `* 169.254.169.123` (the * indicates preferred time server)

### Step 4: Set Up Load Balancing

Load balancing provides performance and reliability benefits by distributing traffic and decoupling client health from individual nodes.

#### Configure AWS Network Load Balancer:
1. **Create Network Load Balancer**:
   - Select your VPC and **all availability zones** of your instances
   - Set load balancer port to **26257**

2. **Create Target Group**:
   - Use TCP port **26257**
   - Configure health checks:
     - Protocol: **HTTP**
     - Port: **8080**
     - Path: `/health?ready=1`

3. **Register Instances**:
   - Add your CockroachDB instances to the target group
   - Specify port **26257**

4. **Note the Load Balancer IP**:
   - Find the internal (private) IP address in the Network Interfaces section of the EC2 console
   - Use this IP for application connections

### Step 5: Start CockroachDB Nodes

You can start the nodes manually or automate the process using systemd. The following steps use systemd for automated management.

#### For Each Node in Your Cluster:

⚠️ **Note**: After completing these steps, nodes will not yet be live. They will complete the startup process and join together to form a cluster once initialized in Step 6.

1. **SSH to the target machine** and ensure you are logged in as the **root user**

2. **Install CockroachDB for Linux**:
   ```bash
   # Download and install CockroachDB binary
   wget -qO- https://binaries.cockroachdb.com/cockroach-v25.2.2.linux-amd64.tgz | tar xvz
   sudo cp -i cockroach-v25.2.2.linux-amd64/cockroach /usr/local/bin/
   ```

3. **Create the CockroachDB directory**:
   ```bash
   mkdir /var/lib/cockroach
   ```

4. **Create a Unix user named cockroach**:
   ```bash
   useradd cockroach
   ```

5. **Change ownership of the cockroach directory**:
   ```bash
   chown cockroach /var/lib/cockroach
   ```

6. **Create the systemd service file**:
   
   **Option A**: Download the sample configuration template:
   ```bash
   curl -o /etc/systemd/system/insecurecockroachdb.service https://raw.githubusercontent.com/cockroachdb/docs/main/src/current/_includes/v25.2/prod-deployment/insecurecockroachdb.service
   ```
   
   **Option B**: Create the file manually:
   ```bash
   cat > /etc/systemd/system/insecurecockroachdb.service << 'EOF'
   [Unit]
   Description=Cockroach Database cluster node
   Requires=network.target
   
   [Service]
   Type=notify
   WorkingDirectory=/var/lib/cockroach
   ExecStart=/usr/local/bin/cockroach start --insecure --advertise-addr=<node1 address> --join=<node1 address>,<node2 address>,<node3 address> --cache=.25 --max-sql-memory=.25
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
   ```

7. **Configure the service file** by updating the following flags:

   | Flag | Description |
   |------|-------------|
   | `--advertise-addr` | IP address/hostname and port for other nodes to use. Port defaults to 26257 if omitted. Must route to an IP address the node is listening on. |
   | `--join` | Addresses of 3-5 initial cluster nodes. These should match the addresses that target nodes are advertising. |

   **Example configuration**:
   ```bash
   ExecStart=/usr/local/bin/cockroach start --insecure --advertise-addr=10.0.1.10:26257 --join=10.0.1.10:26257,10.0.1.11:26257,10.0.1.12:26257 --cache=.25 --max-sql-memory=.25
   ```

   **Optional**: Add `--locality` flag for multi-datacenter deployments:
   ```bash
   --locality=region=us-west,zone=us-west-1a
   ```

8. **Start the CockroachDB service**:
   ```bash
   systemctl start insecurecockroachdb
   ```

9. **Enable automatic startup after reboot**:
   ```bash
   systemctl enable insecurecockroachdb
   ```

10. **Repeat these steps for each additional node** in your cluster

#### Service Management Commands:
- **Stop a node**: `systemctl stop insecurecockroachdb`
- **Check status**: `systemctl status insecurecockroachdb`
- **View logs**: `journalctl -u insecurecockroachdb -f`

### Step 6: Initialize the Cluster

After all nodes are configured and started, complete the cluster initialization:

1. **Install CockroachDB on your local machine** (if not already installed):
   ```bash
   wget -qO- https://binaries.cockroachdb.com/cockroach-v25.2.2.linux-amd64.tgz | tar xvz
   sudo cp -i cockroach-v25.2.2.linux-amd64/cockroach /usr/local/bin/
   ```

2. **Initialize the cluster**:
   ```bash
   cockroach init --insecure --host=<address of any node on --join list>
   ```
   
   **Example**:
   ```bash
   cockroach init --insecure --host=10.0.1.10:26257
   ```

3. **Verify successful initialization**:
   Each node will print helpful details including:
   - CockroachDB version
   - URL for the DB Console
   - SQL URL for client connections

## Terraform Deployment

After completing the manual AWS setup and CockroachDB installation steps above, deploy the Terraform configuration:

```bash
# Initialize Terraform
terraform init

# Plan the deployment
terraform plan

# Apply the configuration
terraform apply
```

## Post-Deployment Verification

1. **Check cluster status**:
   ```bash
   cockroach node status --insecure --host=<load-balancer-ip>:26257
   ```

2. **Access DB Console**:
   - Navigate to `http://<node-ip>:8080` in your browser
   - No authentication required (insecure mode)

3. **Test connectivity**:
   ```bash
   cockroach sql --insecure --host=<load-balancer-ip>:26257
   ```

## Important Notes

- This configuration is for **testing and development only**
- Consider implementing a secure cluster for any production use case
- All instances should use Amazon Time Sync Service for clock synchronization
- Monitor cluster health through the DB Console at port 8080
- Use the load balancer IP for all application connections

## Troubleshooting

- **Clock sync issues**: Verify Amazon Time Sync Service configuration
- **Connection problems**: Check security group rules and load balancer configuration
- **Node failures**: Ensure proper replication factor and node distribution
- **Performance issues**: Verify instance types and avoid t2 instances

For additional details, refer to the [CockroachDB Production Checklist](https://www.cockroachlabs.com/docs/stable/recommended-production-settings.html) and [Topology Patterns](https://www.cockroachlabs.com/docs/stable/topology-patterns.html).
