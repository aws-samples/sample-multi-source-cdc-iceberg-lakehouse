# Oracle Data Source

## Purpose
Creates an Oracle Database 21c Express Edition on EC2 as a transactional data source for the Iceberg data lakehouse, providing synthetic financial transaction data for testing and demonstration.

## What It Creates
- **Oracle 21c XE on EC2**: r5.2xlarge instance with 100GB encrypted EBS volume
- **Database Configuration**: XE SID with XEPDB1 pluggable database
- **Security Group**: Allows Oracle (1521) and SSH (22) access from VPC
- **Secrets Management**: Auto-generated passwords stored in Secrets Manager
- **SSM Parameters**: Connection strings and database configuration
- **IAM Role**: EC2 role with Secrets Manager and SSM access

## Why It's Needed
- **Source System Simulation**: Realistic transactional database for CDC testing
- **DMS Integration**: Primary source for Database Migration Service replication
- **Data Generation**: Target for synthetic trading data generation
- **Schema Testing**: Validates downstream systems with Oracle-specific data types

## Configuration Options

### Basic Configuration (terraform.tfvars)
```hcl
APP    = "${APP_NAME}"
ENV    = "${ENV_NAME}"
REGION = "us-east-1"

# Oracle Configuration
ORACLE_INSTANCE_TYPE = "r5.2xlarge"
ORACLE_VOLUME_SIZE   = 100
ORACLE_VERSION       = "21c"
ORACLE_PORT          = 1521
ORACLE_SID           = "XE"
ORACLE_PDB           = "XEPDB1"
ORACLE_USER          = "ORACLE_USER"
```

### Environment-Specific Examples

#### Production Environment
```hcl
ORACLE_INSTANCE_TYPE = "r5.4xlarge"
ORACLE_VOLUME_SIZE   = 500
```

#### Development Environment
```hcl
ORACLE_INSTANCE_TYPE = "r5.large"
ORACLE_VOLUME_SIZE   = 50
```

## Key Features
- Encrypted EBS storage with customer-managed KMS keys
- Auto-generated secure passwords for admin and application users
- SSM Session Manager access (no SSH keys required)
- Comprehensive connection parameter storage in SSM
- Integration with data generator service via Secrets Manager
- Oracle XE with pluggable database architecture

## Database Structure
- **Container Database**: XE (Oracle Express Edition)
- **Pluggable Database**: XEPDB1 (application data)
- **Admin User**: SYS/SYSTEM (default Oracle XE password)
- **Application User**: ORACLE_USER (auto-generated password)
- **CDC Users**: C##DBZUSER (Debezium LogMiner), C##DMSUSER (DMS Binary Reader)

## Connection Information
All connection details are stored securely:
- **SSM Parameters**: Host, port, SID, PDB, connection strings
- **Secrets Manager**: Admin password, user password, data generator connection
- **Outputs**: Instance ID, private IP, secret ARNs

**Prerequisites**: Install AWS CLI Session Manager plugin:
- **Installation Guide**: https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html
- **Required for**: `make connect-to-oracle` command

**Connection Methods**:
```bash
# Using Makefile command (recommended)
make connect-to-oracle
```

## Dependencies
- Foundation layer (VPC, KMS keys, SSM parameters)
- EC2 module for instance creation
- Security groups allowing Oracle port access
