# Foundation IAM Roles

## Purpose
Creates comprehensive IAM roles and policies for the Iceberg data lakehouse platform, enabling secure access across AWS Glue, Lake Formation, CockroachDB, and DMS services.

## What It Creates
- **AWS Glue Role**: Service role with S3, Iceberg, MSK, and Lake Formation permissions
- **Lake Formation Role**: Service role for data lake management and S3 Tables API access
- **CockroachDB Role**: EC2 instance role with SSM access for database nodes
- **DMS Roles**: Required service roles for VPC management, CloudWatch logs, and endpoint access
- **SSM Parameters**: Role ARNs stored for cross-module reference

## Why It's Needed
- **Service Integration**: Enables secure communication between AWS services
- **Data Lake Access**: Provides Lake Formation with necessary permissions for Iceberg tables
- **Streaming Data**: Allows Glue to access MSK clusters for real-time processing
- **Cross-Service Security**: Implements least-privilege access patterns across the platform

## Configuration Options

### Basic Configuration (terraform.tfvars)
```hcl
APP                           = "${APP_NAME}"
ENV                           = "${ENV_NAME}"
AWS_PRIMARY_REGION            = "us-east-1"
AWS_SECONDARY_REGION          = "us-west-2"
SSM_KMS_KEY_ALIAS             = "${APP_NAME}-${ENV_NAME}-systems-manager-secret-key"
EBS_KMS_KEY_ALIAS             = "${APP_NAME}-${ENV_NAME}-ebs-secret-key"
SECRETS_MANAGER_KMS_KEY_ALIAS = "${APP_NAME}-${ENV_NAME}-secrets-manager-secret-key"
MSK_SOURCE_CLUSTER_NAME       = "${APP_NAME}-${ENV_NAME}-msk-ingest-cluster"
```

### Role Permissions Summary

#### AWS Glue Role
- S3 bucket access for data, scripts, and logs
- S3 Tables API for Iceberg operations
- MSK cluster access for streaming data
- KMS encryption/decryption
- Secrets Manager and SSM Parameter access
- Lake Formation and DataZone integration

#### Lake Formation Role
- S3 Tables API operations
- Glue Data Catalog management
- Cross-account data lake settings (version 4)

#### CockroachDB Role
- SSM Session Manager access
- Parameter Store access for configuration
- EC2 instance metadata access

#### DMS Roles
- VPC management for replication instances
- CloudWatch logs for monitoring
- MSK endpoint access for streaming targets

## Key Features
- Least-privilege access patterns with resource-specific permissions
- Cross-account Lake Formation settings for data sharing
- Comprehensive tagging strategy for resource management
- SSM parameter storage for role ARN references
- KMS integration for encryption at rest and in transit

## Dependencies
- Foundation layer (KMS keys must exist for encryption references)
- Network layer (VPC and subnets for service access)
- MSK cluster name for streaming permissions
