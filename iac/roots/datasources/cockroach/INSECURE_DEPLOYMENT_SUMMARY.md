# CockroachDB Insecure Deployment - Summary

## ✅ Conversion Complete

Your CockroachDB deployment has been successfully converted from secure to **insecure mode** for testing purposes.

## 🔧 What Was Changed

### 1. User Data Scripts
- **Node Script** (`templates/user_data.sh`): Updated to use `--insecure` flag and removed certificate dependencies
- **Management Script** (`templates/mgmt_user_data.sh`): Removed certificate generation, added insecure connection scripts

### 2. Configuration Files
- **README.md**: Comprehensive insecure deployment guide with security warnings
- **outputs.tf**: Updated outputs with insecure connection information and warnings
- **DEPLOYMENT_VERIFICATION.md**: Detailed verification checklist

### 3. Key Features Added
- **Automatic cluster initialization** from management instance
- **Sample database setup** with test transaction data
- **Multiple management scripts** for cluster operations
- **Comprehensive documentation** with security warnings

## 🚀 Deployment Process

### 1. Deploy Infrastructure
```bash
# From the cockroach directory
terraform init
terraform plan
terraform apply
```

### 2. What Happens Automatically
1. **3 CockroachDB nodes** start in insecure mode
2. **Network Load Balancer** distributes traffic
3. **Management instance** auto-initializes the cluster
4. **Sample database** gets created with test data

### 3. Access Methods

#### Connect to Management Instance
```bash
aws ssm start-session --target <mgmt-instance-id> --region <region>
```

#### Connect to Database
```bash
# Via load balancer (recommended)
cockroach sql --insecure --host=<load-balancer-dns>:26257

# Via individual nodes
cockroach sql --insecure --host=<node-ip>:26257
```

#### Access Admin UI
- Load Balancer: `http://<load-balancer-dns>:8080`
- Individual Nodes: `http://<node-ip>:8080`

## ⚠️ Security Warnings

This is an **INSECURE deployment** with the following characteristics:

### What's NOT Secure
- ❌ **No authentication** - anyone can connect as root
- ❌ **No encryption** - all data transmitted in plain text
- ❌ **No authorization** - all users have full database access
- ❌ **Open cluster** - accessible to any client reaching node IPs

### What IS Secure
- ✅ **VPC isolation** - nodes in private subnets
- ✅ **Security groups** - restrict access to VPC CIDR
- ✅ **No public IPs** - not directly internet accessible
- ✅ **SSM access** - secure shell access via Session Manager

## 🧪 Testing Scenarios

### Basic Connectivity Test
```bash
cockroach sql --insecure --host=<lb-dns>:26257 -e "SELECT 1;"
```

### Cluster Health Check
```bash
cockroach node status --insecure --host=<lb-dns>:26257
```

## 📊 Expected Results

After deployment, you should see:

### Terraform Outputs
- CockroachDB endpoints (SQL and UI)
- Instance IDs and IP addresses
- SSM connection commands
- Usage instructions with security warnings

### Management Instance
- Auto-initialized cluster
- Sample database with ~58 transaction records
- Ready-to-use management scripts
- Comprehensive README documentation

### Cluster Status
- 3 nodes in healthy state
- Load balancer distributing traffic
- Admin UI accessible without authentication
- Sample queries returning test data

## 🔍 Verification Checklist

- [ ] All 3 nodes show as healthy in cluster status
- [ ] Load balancer health checks passing
- [ ] Can connect via both load balancer and individual nodes
- [ ] Admin UI accessible and shows cluster overview
- [ ] Sample database contains transaction data
- [ ] All instances accessible via SSM Session Manager

## 🛠️ Troubleshooting

### If nodes aren't joining:
- Check security group rules
- Verify time synchronization
- Check systemd service status: `sudo systemctl status insecurecockroachdb`

### If load balancer health checks fail:
- Verify port 8080 is accessible
- Check CockroachDB service is running
- Verify health endpoint: `curl http://<node-ip>:8080/health?ready=1`

## 📝 Next Steps

1. **Deploy the infrastructure** using Terraform
2. **Wait 5-10 minutes** for full initialization
3. **Connect to management instance** via SSM
4. **Run verification scripts** to confirm everything works
5. **Start testing** your applications against the cluster


