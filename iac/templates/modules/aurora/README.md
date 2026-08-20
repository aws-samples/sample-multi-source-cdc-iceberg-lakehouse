# Aurora PostgreSQL Module

This Terraform module creates an Amazon Aurora PostgreSQL cluster with comprehensive security, monitoring, and optional bastion host access.

## Features

- **Aurora PostgreSQL 16.4**: Provisioned cluster with multi-AZ deployment
- **Enhanced Security**: Encrypted storage, IAM authentication, and VPC isolation
- **Comprehensive Monitoring**: Enhanced monitoring with CloudWatch integration
- **Automatic Management**: Password generation, minor version upgrades, and parameter groups
- **Optional Bastion Host**: Secure database access via SSM Session Manager
- **Flexible Configuration**: Customizable instance types, storage, and networking

## Architecture

```
┌─────────────────────┐    ┌─────────────────────┐    ┌─────────────────────┐
│   Aurora Cluster    │    │  Secrets Manager    │    │   Bastion Host      │
│                     │    │                     │    │   (Optional)        │
│ • Writer Instance   │◄───┤ • Auto-generated    │    │ • SSM Access        │
│ • Reader Instance   │    │   passwords         │    │ • PostgreSQL Client │
│ • Parameter Group   │    │ • KMS Encrypted     │    │ • Private Subnet    │
│ • Enhanced Monitor  │    │                     │    │                     │
└─────────────────────┘    └─────────────────────┘    └─────────────────────┘
```

## Usage

```hcl
module "aurora" {
  source = "../../../templates/modules/aurora"
  
  # Required variables
  APP                = "myapp"
  ENV                = "dev"
  cluster_identifier = "aurora"
  cluster_engine     = "aurora-postgresql"
  database_name      = "mydb"
  master_username    = "master"
  port               = "5432"
  instance_class     = "db.t3.medium"
  
  # Network configuration
  subnet_ids         = ["subnet-12345", "subnet-67890"]
  security_group_ids = ["sg-abcdef123"]
  
  # Optional: Bastion host for secure access
  enable_bastion_host     = true
  bastion_instance_type   = "t3.micro"
  vpc_id                  = "vpc-12345"
  vpc_cidr_block          = "10.0.0.0/16"
  secrets_manager_kms_key = "arn:aws:kms:region:account:key/key-id" # pragma: allowlist secret
}
```

## Inputs

| Name                    | Description                                      | Type           | Default        | Required |
| ----------------------- | ------------------------------------------------ | -------------- | -------------- | :------: |
| APP                     | Application name                                 | `string`       | n/a            |   yes    |
| ENV                     | Environment name                                 | `string`       | n/a            |   yes    |
| cluster_identifier      | Identifier of the cluster                        | `string`       | `""`           |   yes    |
| cluster_engine          | Name of the engine                               | `string`       | `""`           |   yes    |
| database_name           | Name of the database                             | `string`       | `""`           |   yes    |
| master_username         | Username of the master account                   | `string`       | `""`           |   yes    |
| subnet_ids              | List of subnet IDs for RDS                       | `list(string)` | `[]`           |   yes    |
| security_group_ids      | List of security group IDs for RDS               | `list(string)` | `[]`           |   yes    |
| instance_class          | Instance type of RDS instance                    | `string`       | `""`           |   yes    |
| engine_version          | Aurora PostgreSQL engine version                 | `string`       | `"16.4"`       |    no    |
| engine_mode             | Engine mode of the RDS instance                  | `string`       | `"provisioned"`|    no    |
| port                    | Port on which to connect to the DB cluster       | `string`       | `"5533"`       |    no    |
| enable_bastion_host     | Whether to deploy a bastion host                 | `bool`         | `false`        |    no    |
| bastion_instance_type   | Instance type for the bastion host               | `string`       | `"t3.micro"`   |    no    |
| vpc_id                  | VPC ID for bastion host security group           | `string`       | `""`           |    no    |
| vpc_cidr_block          | VPC CIDR block for bastion host rules            | `string`       | `""`           |    no    |
| secrets_manager_kms_key | KMS key for secrets manager                      | `string`       | `""`           |    no    |

## Outputs

| Name                        | Description                                    |
| --------------------------- | ---------------------------------------------- |
| cluster_arn                 | ARN of the RDS cluster                         |
| cluster_identifier          | Cluster identifier of the RDS cluster         |
| cluster_resource            | Cluster resource ID of the RDS cluster        |
| cluster_instances           | List of instances that are part of the cluster|
| instance_id                 | ID of the RDS instances                        |
| writer_endpoint             | The writer endpoint                            |
| reader_endpoint             | The reader endpoint                            |
| bastion_instance_id         | Instance ID of the Aurora bastion host         |
| bastion_private_ip          | Private IP of the Aurora bastion host          |
| bastion_security_group_id   | Security group ID of the Aurora bastion host  |
| bastion_connection_command  | SSM command to connect to the bastion host    |

## Implementation Details

### Aurora Cluster Configuration

The module creates a fully configured Aurora PostgreSQL cluster:

```hcl
resource "aws_rds_cluster" "aurora" {
  engine                              = var.cluster_engine
  engine_version                      = var.engine_version
  cluster_identifier                  = "${var.APP}-${var.ENV}-${var.cluster_identifier}"
  database_name                       = var.database_name
  master_username                     = var.master_username
  master_password                     = random_password.db_password.result  # pragma: allowlist secret
  iam_database_authentication_enabled = true
  storage_encrypted                   = true
  apply_immediately                   = true
  skip_final_snapshot                 = true
}
```

### Automatic Password Management

- 16-character passwords with mixed case, numbers, and special characters
- Stored securely in AWS Secrets Manager with KMS encryption
- Passwords are marked as sensitive in Terraform state

### Enhanced Monitoring

The module enables comprehensive monitoring:

- **Enhanced Monitoring**: 5-minute intervals with detailed metrics
- **CloudWatch Integration**: Automatic log group creation
- **Performance Insights**: Available for troubleshooting
- **IAM Role**: Dedicated monitoring role with proper permissions

### Optional Bastion Host

When `enable_bastion_host = true`, the module creates:

- **EC2 Instance**: In private subnet with PostgreSQL client tools
- **Security Group**: Allows SSH access and PostgreSQL connectivity
- **IAM Policies**: SSM Session Manager and Secrets Manager access
- **User Data Script**: Installs PostgreSQL client and AWS CLI
- **SSM Parameters**: Stores bastion host information

### Connection Examples

#### Direct Connection (from within VPC)

```bash
# Using writer endpoint
psql -h <writer_endpoint> -p 5432 -U master -d mydb

# Using reader endpoint for read-only queries
psql -h <reader_endpoint> -p 5432 -U master -d mydb
```

#### Bastion Host Connection

```bash
# Connect to bastion host via SSM
aws ssm start-session --target <bastion_instance_id>

# From bastion host, connect to Aurora
psql -h <writer_endpoint> -p 5432 -U master -d mydb
```

#### IAM Database Authentication

```bash
# Generate auth token
export PGPASSWORD=$(aws rds generate-db-auth-token \
  --hostname <writer_endpoint> \
  --port 5432 \
  --username <iam_user>)

# Connect using IAM authentication
psql -h <writer_endpoint> -p 5432 -U <iam_user> -d mydb
```

## Security Considerations

1. **Encryption**
   - Data encrypted at rest using default KMS key
   - Data encrypted in transit using SSL/TLS
   - Secrets Manager integration for credential management

2. **Network Security**
   - Deploy in private subnets only
   - Use security groups to restrict access
   - VPC isolation prevents external access

3. **Access Control**
   - IAM database authentication enabled
   - Bastion host uses SSM Session Manager (no SSH keys)
   - Least privilege IAM policies

4. **Monitoring**
   - Enhanced monitoring for performance insights
   - CloudWatch logs for audit trails
   - Parameter group logging enabled

## Troubleshooting

### Common Issues

1. **Connection Timeouts**
   - Verify security group rules allow PostgreSQL port
   - Check subnet routing and NAT gateway configuration
   - Ensure Aurora is in private subnets

2. **Authentication Failures**
   - Verify credentials in Secrets Manager
   - Check IAM database authentication setup
   - Ensure proper IAM policies for database access

3. **Bastion Host Access**
   - Verify SSM agent is running on bastion host
   - Check IAM role permissions for SSM
   - Ensure VPC endpoints for SSM are configured

### Debugging Steps

1. **Check Cluster Status**
   ```bash
   aws rds describe-db-clusters --db-cluster-identifier <cluster_id>
   ```

2. **Verify Security Groups**
   ```bash
   aws ec2 describe-security-groups --group-ids <security_group_id>
   ```

3. **Test Bastion Host Connectivity**
   ```bash
   aws ssm start-session --target <bastion_instance_id>
   ```

## Dependencies

This module requires:

- **Terraform**: >= 1.0
- **AWS Provider**: >= 5.0
- **Network Layer**: VPC and private subnets must exist
- **Security Groups**: Must allow PostgreSQL port (5432)
- **KMS Keys**: For Secrets Manager encryption (if using bastion host)
- **IAM Permissions**:
  - RDS cluster management
  - Secrets Manager read/write
  - EC2 instance management (if using bastion host)
  - SSM Session Manager access

## Related Modules

- `../ec2`: Used for bastion host creation
- `../../foundation/network`: Provides VPC and subnets
- `../../foundation/kms-keys`: Provides KMS keys for encryption
