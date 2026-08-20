# KMS Keys Foundation Layer

## Purpose
Creates AWS KMS encryption keys for all services in the Iceberg data lakehouse, providing centralized encryption management across primary and secondary regions with automatic key rotation and service-specific policies.

## What It Creates
- **10 Service-Specific KMS Keys**: Encryption keys for Secrets Manager, Systems Manager, S3, Glue, Athena, CloudWatch, EBS, DynamoDB, MSK, and DMS
- **Multi-Region Support**: Keys deployed in both primary and secondary regions (except DynamoDB - primary only)
- **Key Aliases**: Standardized aliases for easy key reference across the platform
- **Service Policies**: Tailored IAM policies for each AWS service integration

## Why It's Needed
- **Data Encryption**: Ensures all data is encrypted at rest across the entire platform
- **Compliance**: Meets security requirements for financial data processing
- **Key Management**: Centralized encryption key management with automatic rotation
- **Service Integration**: Enables secure communication between AWS services

## Configuration Options

### Basic Configuration (terraform.tfvars)
```hcl
APP                  = "${APP_NAME}"
ENV                  = "${ENV_NAME}"
AWS_PRIMARY_REGION   = "us-east-1"
AWS_SECONDARY_REGION = "us-west-2"
```

### Key Services and Usage

| Service | Primary Use | Key Policy Features |
|---------|-------------|-------------------|
| **Secrets Manager** | Database credentials, API keys | Root account access only |
| **Systems Manager** | Configuration parameters | Root account access only |
| **S3** | Data lake storage buckets | S3 service permissions with source conditions |
| **Glue** | Data catalog encryption | Glue service permissions for metadata |
| **Athena** | Query result encryption | Root account access only |
| **CloudWatch** | Log encryption | CloudWatch Logs service permissions |
| **EBS** | EC2 volume encryption | Root account access only |
| **DynamoDB** | Table encryption | Glue decrypt permissions for catalog access |
| **MSK** | Kafka cluster encryption | Root account access only |
| **DMS** | Replication encryption | DMS service permissions for data migration |

## Key Features
- **Automatic Key Rotation**: Enabled for all keys (365-day cycle)
- **Service-Specific Policies**: Tailored permissions for each AWS service
- **Consistent Naming**: Standardized `${APP}-${ENV}-service-secret-key` pattern
- **Resource Tagging**: Application, Environment, and Usage tags for all keys
- **Multi-Region Deployment**: Consistent encryption across regions

## Dependencies
- AWS Provider ~> 6.0 configured for both primary and secondary regions
- IAM permissions to create and manage KMS keys and aliases
