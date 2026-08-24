# Foundation Infrastructure Layer

## Overview

The foundation layer provides the core infrastructure components for the Iceberg Data Lakehouse project. These modules create the fundamental AWS resources required by all other components of the system, including networking, security, storage, and query engines.

## Architecture Components

The foundation layer consists of 7 core modules that must be deployed first to establish the infrastructure foundation:

### 1. KMS Keys Module
**Purpose**: Encryption keys for all AWS services across primary and secondary regions

**Key Resources:**
- KMS keys for Secrets Manager, Systems Manager, S3, Glue, Athena, EventBridge, CloudWatch, DataZone, EBS, DynamoDB, and MSK
- Key aliases for easy reference across modules
- Key policies with appropriate service permissions
- Automatic key rotation enabled for all keys

### 2. Network Module  
**Purpose**: VPC infrastructure with secure networking for all components

**Key Resources:**
- VPC with DNS support and CIDR configuration
- Public and private subnets across multiple availability zones
- Internet Gateway for public subnet access
- NAT Gateway for private subnet internet connectivity
- Route tables and subnet associations
- VPC Endpoints for AWS services (S3, Glue, etc.)
- Security Groups for network traffic control
- SSM parameters for cross-module network reference

### 3. IAM Roles Module
**Purpose**: Service roles and policies for AWS services integration

**Key Resources:**
- AWS Glue service role with comprehensive permissions (S3, Iceberg, Lake Formation, MSK)
- Lake Formation service role for data lake management
- Lake Formation data lake settings and admin configuration
- Cross-service trust relationships and policies

### 4. S3 Buckets Module
**Purpose**: All S3 storage buckets for the data lakehouse with encryption and replication

**Key Resources:**
- **Iceberg Datalake Bucket**: Primary Apache Iceberg table storage with cross-region replication
- **Athena Output Bucket**: Query results storage with KMS encryption
- **Assets Bucket**: Project assets and configuration files
- SSM parameters for bucket name cross-reference

### 5. Glue Databases Module
**Purpose**: AWS Glue catalog databases for organizing metadata from all data sources

**Key Resources:**
- **4 Glue Databases**: Oracle, Aurora, CockroachDB, and MSK transaction databases
- Database naming: `{app}_{env}_{source}_transactions_database`
- SSM parameters for database name storage
- Unified metadata catalog for all data sources

### 6. S3 Tables Module
**Purpose**: Managed Apache Iceberg tables with automatic compaction via S3 Tables

**Key Resources:**
- S3 Tables table bucket with maintenance configuration
- 8 namespaces (4 Firehose `f_*`, 4 Connect `c_*`) with `fin`/`brk` tables each
- Lake Formation registration with federation for Athena access
- Glue federated catalog (`s3tablescatalog`) for query access
- All tables pre-created with `metadata` blocks and typed schemas

### 7. Athena Query Engine Module
**Purpose**: Serverless SQL analytics workgroup for Iceberg data querying

**Key Resources:**
- Dedicated Athena workgroup with enforced configuration
- KMS encryption for query results
- S3 output location configuration
- CloudWatch metrics integration
- Cost control and monitoring capabilities

## Deployment Order

The foundation modules must be deployed in the following order due to dependencies:

```bash
# Deploy all foundation components
make deploy-foundation
```

**Individual module deployment order:**
1. **KMS Keys** → 2. **Network** → 3. **IAM Roles** → 4. **S3 Buckets** → 5. **Glue Databases** → 6. **S3 Tables** → 7. **Athena**

## Key Features

### Security
- End-to-end encryption with customer-managed KMS keys
- IAM roles following principle of least privilege
- VPC isolation with private subnets for sensitive resources
- Security groups and NACLs for network-level protection

### High Availability
- Multi-AZ deployment across availability zones
- Cross-region replication for critical data buckets
- Redundant networking with multiple subnets

### Cost Optimization
- Appropriate resource sizing for expected workloads
- Cost allocation tags on all resources
- Serverless components where applicable (Athena)

### Monitoring & Observability
- CloudWatch integration across all services
- VPC Flow Logs for network monitoring
- CloudTrail for API call tracking
- Performance metrics for query engines

## Integration Points

### Cross-Module Dependencies
- **Network**: Provides VPC, subnets, and security groups for all other layers
- **KMS Keys**: Encryption keys used by S3, Glue, Athena, and other services
- **IAM Roles**: Service permissions for Glue and Lake Formation
- **S3 Buckets**: Storage foundation for data lake, logs, and query results
- **Glue Databases**: Metadata catalog for all data sources and query engines

### SSM Parameter Store
All modules store critical configuration in SSM parameters for cross-module reference:
- VPC and subnet IDs
- KMS key ARNs and aliases
- S3 bucket names
- Glue database names
- IAM role ARNs

## Dependencies

### External Dependencies
- AWS Account with appropriate service quotas
- Multi-region AWS provider configuration
- Terraform >= 1.8.0

### Internal Dependencies
- Must be deployed before data sources layer
- Required by ingestion layer components
- Foundation for query engine layer

## Outputs

Each module provides outputs for integration with other layers:
- Network IDs and security group references
- KMS key ARNs for encryption
- IAM role ARNs for service integration
- S3 bucket names and configurations
- Glue database names and catalog information

For detailed module-specific documentation, see individual README files in each subdirectory.
