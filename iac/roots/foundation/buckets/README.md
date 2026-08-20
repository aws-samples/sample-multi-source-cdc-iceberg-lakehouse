# S3 Buckets Foundation

## Purpose
Creates all S3 buckets required for the Iceberg data lakehouse, providing encrypted storage for data, logs, and analytics results with optional cross-region replication.

## What It Creates
- **Iceberg Datalake Bucket**: Primary storage for Apache Iceberg tables with cross-region replication
- **Athena Output Bucket**: Query results storage with KMS encryption
- **Assets Bucket**: Project assets and configuration files storage
- **SSM Parameters**: Bucket names stored for cross-module reference

## Why It's Needed
- **Data Storage**: Centralized storage for all lakehouse data in Iceberg format
- **Query Results**: Secure storage for Athena query outputs
- **Disaster Recovery**: Cross-region replication for critical data buckets

## Configuration Options

### Basic Configuration (terraform.tfvars)
```hcl
APP                        = "${APP_NAME}"
ENV                        = "${ENV_NAME}"
AWS_PRIMARY_REGION         = "us-east-1"
AWS_SECONDARY_REGION       = "us-west-2"
S3_PRIMARY_KMS_KEY_ALIAS   = "${APP_NAME}-${ENV_NAME}-s3-secret-key"
S3_SECONDARY_KMS_KEY_ALIAS = "${APP_NAME}-${ENV_NAME}-s3-secret-key"
```

### Environment-Specific Examples

#### Production Environment
```hcl
APP                        = "${APP_NAME}"
ENV                        = "prod"
AWS_PRIMARY_REGION         = "us-east-1"
AWS_SECONDARY_REGION       = "us-west-2"
```

#### Development Environment
```hcl
APP                        = "${APP_NAME}"
ENV                        = "dev"
AWS_PRIMARY_REGION         = "us-east-1"
AWS_SECONDARY_REGION       = "us-east-1"  # Same region for dev
```

## Bucket Details

### Iceberg Datalake Bucket
- **Purpose**: Primary Apache Iceberg table storage
- **Replication**: Enabled for disaster recovery
- **Encryption**: Customer-managed KMS keys
- **Usage**: Financial and brokerage transaction tables

### Athena Output Bucket
- **Purpose**: Query results from Athena workgroup
- **Replication**: Disabled (query results are reproducible)
- **Encryption**: KMS encrypted
- **Usage**: SQL analytics output storage

## Key Features
- KMS encryption for all buckets using customer-managed keys
- Cross-region replication for critical data buckets
- Private ACLs with bucket owner preferred ownership
- SSM parameter storage for cross-module bucket name reference
- Force destroy enabled for development environments
- Comprehensive IAM policies for replication

## Dependencies
- Foundation layer (KMS keys for S3 encryption)
- Multi-region AWS provider configuration
- IAM permissions for S3 bucket management and replication
