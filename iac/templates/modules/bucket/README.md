# S3 Bucket Module

This Terraform module creates secure S3 buckets with optional cross-region replication, KMS encryption, and comprehensive IAM policies for the Iceberg Data Lakehouse project.

## Features

- **Dual-Region Support**: Primary and optional secondary bucket creation with cross-region replication
- **KMS Encryption**: Customer-managed key encryption for both regions
- **Cross-Region Replication**: Configurable bidirectional replication with IAM roles and policies
- **Security Hardening**: Private ACLs, bucket ownership controls, and force destroy protection
- **Flexible Configuration**: Configurable bucket naming and replication settings

## Architecture

```
┌─────────────────────┐    ┌─────────────────────┐    ┌─────────────────────┐
│   Primary Bucket    │    │   Replication       │    │  Secondary Bucket   │
│                     │    │                     │    │                     │
│ • KMS Encrypted     │◄──►│ • IAM Roles         │◄──►│ • KMS Encrypted     │
│ • Private ACL       │    │ • Bidirectional     │    │ • Private ACL       │
│ • Versioning        │    │ • KMS Permissions   │    │ • Versioning        │
│ • Force Destroy     │    │                     │    │ • Force Destroy     │
└─────────────────────┘    └─────────────────────┘    └─────────────────────┘
```

## Usage

### Basic Usage (Single Region)

```hcl
module "data_bucket" {
  source = "../../../templates/modules/bucket"

  providers = {
    aws.primary   = aws.us_east_1
    aws.secondary = aws.us_west_2
  }

  RESOURCE_PREFIX              = "${APP_NAME}-dev-data"
  BUCKET_NAME_PRIMARY_REGION   = "primary"
  BUCKET_NAME_SECONDARY_REGION = "secondary"
  PRIMARY_CMK_ARN              = data.aws_kms_key.primary.arn
  SECONDARY_CMK_ARN            = data.aws_kms_key.secondary.arn
  ENABLE_REPLICATION           = false
  APP                          = "${APP_NAME}"
  ENV                          = "dev"
  USAGE                        = "data-storage"
}
```

### Advanced Usage with Cross-Region Replication

```hcl
module "iceberg_bucket" {
  source = "../../../templates/modules/bucket"

  providers = {
    aws.primary   = aws.us_east_1
    aws.secondary = aws.us_west_2
  }

  RESOURCE_PREFIX              = "${APP_NAME}-prod-iceberg-datalake"
  BUCKET_NAME_PRIMARY_REGION   = "primary"
  BUCKET_NAME_SECONDARY_REGION = "secondary"
  PRIMARY_CMK_ARN              = data.aws_kms_key.s3_primary.arn
  SECONDARY_CMK_ARN            = data.aws_kms_key.s3_secondary.arn
  ENABLE_REPLICATION           = true
  APP                          = "${APP_NAME}"
  ENV                          = "prod"
  USAGE                        = "iceberg-tables"
}
```

## Inputs

| Name                         | Description                                    | Type     | Default | Required |
| ---------------------------- | ---------------------------------------------- | -------- | ------- | :------: |
| RESOURCE_PREFIX              | Prefix for bucket naming                       | `string` | n/a     |   yes    |
| BUCKET_NAME_PRIMARY_REGION   | Primary region bucket name suffix              | `string` | n/a     |   yes    |
| BUCKET_NAME_SECONDARY_REGION | Secondary region bucket name suffix            | `string` | n/a     |   yes    |
| PRIMARY_CMK_ARN              | KMS key ARN for primary region encryption     | `string` | n/a     |   yes    |
| SECONDARY_CMK_ARN            | KMS key ARN for secondary region encryption   | `string` | n/a     |   yes    |
| APP                          | Application name for tagging                   | `string` | n/a     |   yes    |
| ENV                          | Environment name for tagging                   | `string` | n/a     |   yes    |
| USAGE                        | Usage description for tagging                  | `string` | n/a     |   yes    |
| ENABLE_REPLICATION           | Enable cross-region replication                | `bool`   | `false` |    no    |

## Outputs

| Name                                 | Description                                   |
| ------------------------------------ | --------------------------------------------- |
| primary_bucket_arn                   | ARN of the primary bucket                     |
| primary_bucket_id                    | ID of the primary bucket                      |
| primary_bucket_name                  | Name of the primary bucket                    |
| primary_bucket_regional_domain_name  | Regional domain name of the primary bucket    |
| secondary_bucket_arn                 | ARN of the secondary bucket (if replication enabled) |
| secondary_bucket_id                  | ID of the secondary bucket (if replication enabled) |
| secondary_bucket_regional_domain_name | Regional domain name of the secondary bucket |

## Implementation Details

### Bucket Naming Convention

Buckets are named using the following pattern:
```
Primary:   ${RESOURCE_PREFIX}-${BUCKET_NAME_PRIMARY_REGION}
Secondary: ${RESOURCE_PREFIX}-${BUCKET_NAME_SECONDARY_REGION}
```

Example:
```
Primary:   ${APP_NAME}-prod-iceberg-datalake-primary
Secondary: ${APP_NAME}-prod-iceberg-datalake-secondary
```

### Cross-Region Replication

When `ENABLE_REPLICATION = true`, the module creates:

- **IAM Roles**: Separate roles for primary-to-secondary and secondary-to-primary replication
- **IAM Policies**: Comprehensive policies for S3 and KMS permissions
- **Bidirectional Replication**: Both buckets replicate to each other
- **KMS Integration**: Replication works with customer-managed KMS keys

### Security Configuration

- **Encryption**: All buckets encrypted with customer-managed KMS keys
- **ACLs**: Private ACLs with BucketOwnerPreferred ownership
- **Versioning**: Enabled automatically when replication is configured
- **Force Destroy**: Enabled for development environments

### IAM Permissions

The module creates comprehensive IAM policies for replication including:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:ListBucket",
        "s3:GetReplicationConfiguration",
        "s3:GetObjectVersionForReplication",
        "s3:ReplicateObject",
        "s3:ReplicateDelete"
      ],
      "Effect": "Allow",
      "Resource": ["bucket-arn", "bucket-arn/*"]
    },
    {
      "Action": [
        "kms:Decrypt",
        "kms:GenerateDataKey"
      ],
      "Effect": "Allow",
      "Resource": "kms-key-arn"
    }
  ]
}
```

## Common Use Cases

### Data Lake Storage

```hcl
module "datalake_bucket" {
  source = "../../../templates/modules/bucket"
  
  providers = {
    aws.primary   = aws.us_east_1
    aws.secondary = aws.us_west_2
  }
  
  RESOURCE_PREFIX              = "analytics-prod-datalake"
  BUCKET_NAME_PRIMARY_REGION   = "primary"
  BUCKET_NAME_SECONDARY_REGION = "secondary"
  PRIMARY_CMK_ARN              = data.aws_kms_key.primary.arn
  SECONDARY_CMK_ARN            = data.aws_kms_key.secondary.arn
  ENABLE_REPLICATION           = true
  APP                          = "analytics"
  ENV                          = "prod"
  USAGE                        = "iceberg-datalake"
}
```

### Log Storage

```hcl
module "log_bucket" {
  source = "../../../templates/modules/bucket"
  
  providers = {
    aws.primary   = aws.us_east_1
    aws.secondary = aws.us_west_2
  }
  
  RESOURCE_PREFIX              = "${APP_NAME}-dev-logs"
  BUCKET_NAME_PRIMARY_REGION   = "primary"
  BUCKET_NAME_SECONDARY_REGION = "secondary"
  PRIMARY_CMK_ARN              = data.aws_kms_key.primary.arn
  SECONDARY_CMK_ARN            = data.aws_kms_key.secondary.arn
  ENABLE_REPLICATION           = false
  APP                          = "${APP_NAME}"
  ENV                          = "dev"
  USAGE                        = "application-logs"
}
```

## Security Considerations

1. **Encryption**
   - All buckets encrypted with customer-managed KMS keys
   - Separate keys for primary and secondary regions
   - KMS permissions integrated with replication policies

2. **Access Control**
   - Private ACLs prevent public access
   - BucketOwnerPreferred ownership for cross-account scenarios
   - IAM policies follow least privilege principle

3. **Replication Security**
   - Separate IAM roles for each replication direction
   - KMS permissions scoped to specific buckets and regions
   - Secure cross-region data transfer

4. **Data Protection**
   - Force destroy enabled for development environments
   - Versioning enabled when replication is configured
   - Lifecycle policies can be added for cost optimization

## Troubleshooting

### Common Issues

1. **Replication Failures**
   - Verify KMS key permissions in both regions
   - Check IAM role trust relationships
   - Ensure bucket versioning is enabled

2. **Access Denied Errors**
   - Verify KMS key policies allow S3 service access
   - Check bucket policies and ACLs
   - Ensure IAM roles have correct permissions

3. **Bucket Creation Failures**
   - Verify bucket names are globally unique
   - Check region availability for S3 features
   - Ensure provider configurations are correct

### Debugging Commands

```bash
# Check bucket replication status
aws s3api get-bucket-replication --bucket bucket-name

# Verify KMS key permissions
aws kms describe-key --key-id key-arn

# Check IAM role policies
aws iam get-role-policy --role-name role-name --policy-name policy-name

# List bucket contents
aws s3 ls s3://bucket-name --recursive
```

## Dependencies

This module requires:

- **Terraform**: >= 1.0
- **AWS Provider**: >= 5.0 with dual-region configuration
- **KMS Keys**: Customer-managed keys in both regions
- **IAM Permissions**:
  - S3 bucket creation and management
  - IAM role and policy creation
  - KMS key usage permissions

## Related Modules

- `../../foundation/kms-keys`: Provides required KMS keys for encryption
- `../../../roots/foundation/buckets`: Uses this module for lakehouse storage
- Other data processing modules that consume these buckets
