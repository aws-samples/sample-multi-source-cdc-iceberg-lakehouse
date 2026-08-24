# Aurora PostgreSQL Data Source

## Purpose
Creates an Aurora PostgreSQL cluster as a transactional data source for the Iceberg data lakehouse, simulating a real-world financial system with synthetic transaction data.

## What It Creates
- **Aurora PostgreSQL 16.4 Cluster**: Multi-AZ cluster with 2 instances and monitoring
- **Database**: `equitydb` with master user credentials in Secrets Manager
- **Security Group**: Allows PostgreSQL access from private subnets
- **Optional Bastion Host**: EC2 instance for secure database access via SSM

## Why It's Needed
- **Source System Simulation**: Provides realistic transactional database for testing
- **DMS Replication Source**: Continuous data changes for CDC replication
- **Performance Testing**: Handles concurrent read/write operations
- **Schema Evolution**: Tests downstream systems with database changes

## Configuration Options

### Basic Configuration (terraform.tfvars)
```hcl
APP    = "${APP_NAME}"
ENV    = "${ENV_NAME}"
REGION = "us-east-1"

# Bastion Host Configuration
ENABLE_BASTION_HOST   = true     # Deploy bastion host for database access
BASTION_INSTANCE_TYPE = "t3.micro"  # Instance type for bastion host
```

### Configuration Examples

#### Production Environment
```hcl
ENABLE_BASTION_HOST   = false    # No bastion host in production
BASTION_INSTANCE_TYPE = "t3.small"  # Larger instance if needed
```

#### Development Environment
```hcl
ENABLE_BASTION_HOST   = true     # Enable for development access
BASTION_INSTANCE_TYPE = "t3.micro"  # Cost-effective for dev
```

### Bastion Host Access
When `ENABLE_BASTION_HOST = true`:

**Prerequisites**: Install AWS CLI Session Manager plugin:
- **Installation Guide**: https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html
- **Required for**: `make connect-to-aurora` command

**Connection Methods**:
```bash
# Using Makefile command (recommended)
make connect-to-aurora
```

**Features**:
- PostgreSQL client tools pre-installed
- No SSH keys required - uses IAM permissions
- Secure access through AWS Systems Manager

## Key Features
- Encrypted storage and automatic password generation
- Enhanced monitoring with 5-second intervals
- IAM database authentication enabled
- Optional bastion host with SSM Session Manager access
- Automatic minor version upgrades

## Dependencies
- Foundation layer (VPC, private subnets, KMS keys)
- Security groups allowing PostgreSQL port 5432
