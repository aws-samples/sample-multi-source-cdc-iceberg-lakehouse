# Athena Query Engine

## Purpose
Creates an Amazon Athena workgroup for SQL analytics on the Iceberg data lakehouse, providing serverless query capabilities with encrypted results and CloudWatch monitoring.

## What It Creates
- **Athena Workgroup**: Dedicated workgroup with enforced configuration and CloudWatch metrics
- **KMS Encryption**: Encrypted query results using customer-managed KMS keys
- **S3 Output Configuration**: Secure storage location for query results
- **CloudWatch Integration**: Query performance and usage metrics

## Why It's Needed
- **SQL Analytics**: Standard SQL interface for querying Iceberg tables
- **Serverless Querying**: No infrastructure management required
- **Cost Control**: Workgroup-level query limits and monitoring
- **Security**: Encrypted query results and access controls
- **Performance Monitoring**: CloudWatch metrics for query optimization

## Configuration Options

### Basic Configuration (terraform.tfvars)
```hcl
APP                  = "${APP_NAME}"
ENV                  = "${ENV_NAME}"
AWS_PRIMARY_REGION   = "us-east-1"
WORKGROUP_NAME       = "${APP_NAME}-${ENV_NAME}-workgroup"
ATHENA_OUTPUT_BUCKET = "s3://${APP_NAME}-${ENV_NAME}-athena-output-primary"
ATHENA_KMS_KEY_ALIAS = "${APP_NAME}-${ENV_NAME}-athena-secret-key"
```

### Environment-Specific Examples

#### Production Environment
```hcl
WORKGROUP_NAME       = "${APP_NAME}-prod-analytics-workgroup"
ATHENA_OUTPUT_BUCKET = "s3://${APP_NAME}-prod-athena-results-primary"
```

#### Development Environment
```hcl
WORKGROUP_NAME       = "${APP_NAME}-dev-workgroup"
ATHENA_OUTPUT_BUCKET = "s3://${APP_NAME}-dev-athena-output-primary"
```

## Key Features
- Enforced workgroup configuration for consistent query execution
- KMS encryption for all query results stored in S3
- CloudWatch metrics publishing for performance monitoring
- Integration with AWS Glue Data Catalog for Iceberg tables
- Cost control through workgroup-level settings

## Query Examples
```sql
-- Query financial transactions
SELECT transaction_id, transaction_amount, customer_id
FROM iceberg_database.financial_transactions
WHERE transaction_date >= DATE('2024-01-01')
ORDER BY timestamp DESC
LIMIT 100;

-- Fraud analysis by merchant
SELECT merchant_category, COUNT(*) as total_transactions,
       SUM(CASE WHEN is_fraud THEN 1 ELSE 0 END) as fraud_count
FROM iceberg_database.financial_transactions
WHERE transaction_date >= DATE('2024-01-01')
GROUP BY merchant_category;
```

## Integration Points
- **Glue Catalog**: Queries tables registered in AWS Glue Data Catalog
- **Iceberg Tables**: Native support for time travel and schema evolution
- **S3 Storage**: Direct reads from S3 in Apache Iceberg format


## Dependencies
- Foundation layer (KMS keys, S3 buckets)
- AWS Glue Data Catalog with registered Iceberg tables
- IAM permissions for Athena service access
