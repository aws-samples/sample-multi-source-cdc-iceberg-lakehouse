# Network Infrastructure

## Purpose
Creates the core VPC networking infrastructure for the Iceberg data lakehouse, providing secure multi-AZ connectivity for all data sources, ingestion, and query components.

## What It Creates
- **Multi-AZ VPC**: 10.38.0.0/16 CIDR with DNS support across 3-4 availability zones
- **Private Subnets**: 4 subnets (10.38.192.0/21 - 10.38.216.0/21) for secure resource deployment
- **Public Subnets**: 4 subnets (10.38.224.0/21 - 10.38.248.0/21) for internet-facing resources
- **NAT Gateway**: Single NAT with EIP for outbound internet access from private subnets
- **Internet Gateway**: Direct internet access for public subnets
- **S3 VPC Endpoint**: Gateway endpoint for cost-effective S3 access from private subnets
- **VPC Security Group**: Default security group with VPC CIDR and self-referencing rules
- **SSM Parameters**: Encrypted storage of all network identifiers for cross-module access

## Why It's Needed
- **Foundation Layer**: Required by all other modules for secure resource deployment
- **Multi-AZ Resilience**: Ensures high availability across multiple availability zones
- **Cost Optimization**: S3 VPC endpoint eliminates data transfer costs for S3 access
- **Security Isolation**: Private subnets protect databases and processing resources
- **Shared Infrastructure**: SSM parameters enable other modules to reference network resources

## Configuration Options

### Basic Configuration (terraform.tfvars)
```hcl
APP                  = "${APP_NAME}"
ENV                  = "${ENV_NAME}"
AWS_PRIMARY_REGION   = "us-east-1"
AWS_SECONDARY_REGION = "us-west-2"
S3_KMS_KEY_ALIAS     = "${APP_NAME}-${ENV_NAME}-s3-secret-key"
SSM_KMS_KEY_ALIAS    = "${APP_NAME}-${ENV_NAME}-systems-manager-secret-key"
```

### Network Architecture
```
VPC (10.38.0.0/16)
├── Private Subnets (NAT Gateway → Internet)
│   ├── 10.38.192.0/21 (AZ-1) - Databases, MSK, Processing
│   ├── 10.38.200.0/21 (AZ-2) - Databases, MSK, Processing  
│   ├── 10.38.208.0/21 (AZ-3) - Databases, MSK, Processing
│   └── 10.38.216.0/21 (AZ-4) - Databases, MSK, Processing
├── Public Subnets (Internet Gateway)
│   ├── 10.38.224.0/21 (AZ-1) - NAT Gateway, Bastion Hosts
│   ├── 10.38.232.0/21 (AZ-2) - Load Balancers
│   ├── 10.38.240.0/21 (AZ-3) - Load Balancers
│   └── 10.38.248.0/21 (AZ-4) - Load Balancers
└── VPC Endpoints
    └── S3 Gateway Endpoint (Private Route Table)
```

## Key Features
- Automatic AZ validation (minimum 3 AZs required)
- Customer-managed KMS encryption for all SSM parameters
- AWS Provider v6.0 compatible security group rules
- S3 VPC Gateway endpoint for cost-effective data access
- Comprehensive resource tagging and naming conventions

## Dependencies
- Foundation layer: KMS keys module (provides SSM encryption key)
- AWS Provider >= 6.0 with proper IAM permissions

## SSM Parameters Created
All parameters encrypted with customer-managed KMS key:
- `/${APP}/${ENV}/vpc-id`: VPC identifier
- `/${APP}/${ENV}/vpc-cidr-block`: VPC CIDR block
- `/${APP}/${ENV}/vpc-sg`: Default VPC security group ID
- `/${APP}/${ENV}/vpc-private-subnet-ids`: Comma-separated private subnet IDs
- `/${APP}/${ENV}/vpc-public-subnet-ids`: Comma-separated public subnet IDs
- `/${APP}/${ENV}/vpc-availability-zone-names`: Comma-separated AZ names
