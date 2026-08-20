# MSK Firehose Ingestion Module

This Terraform module creates a Kinesis Data Firehose delivery stream that ingests data from MSK topics into Apache Iceberg tables, supporting both direct streaming and Lambda transformation for DMS CDC data.

## Features

- **MSK to Iceberg Pipeline**: Direct streaming from Kafka topics to Iceberg tables
- **Optional Lambda Transformation**: DMS envelope flattening for CDC sources
- **Comprehensive IAM Security**: Least privilege access with MSK, S3, Glue, and KMS permissions
- **CloudWatch Integration**: Logging and monitoring for pipeline observability
- **Lake Formation Ready**: Automatic permissions for Glue catalog and table access
- **Configurable Buffering**: Optimized for both real-time and batch processing patterns

## Architecture

```
┌─────────────────────┐    ┌─────────────────────┐    ┌─────────────────────┐
│   MSK Topic         │    │  Firehose Stream    │    │   Iceberg Table     │
│                     │    │                     │    │                     │
│ • Kafka Messages    │───►│ • Optional Lambda   │───►│ • S3 Storage        │
│ • Real-time Data    │    │ • Buffering         │    │ • Glue Catalog      │
│ • CDC or Direct     │    │ • Error Handling    │    │ • Query Ready       │
└─────────────────────┘    └─────────────────────┘    └─────────────────────┘
```

## Usage

```hcl
module "msk_firehose_ingestion" {
  source = "../../../templates/modules/msk-firehose-ingestion"

  # Required Configuration
  APP                  = "${APP_NAME}"
  ENV                  = "dev"
  FIREHOSE_STREAM_NAME = "oracle-financial-stream"
  REGION               = "us-east-1"
  
  # MSK Configuration
  MSK_CLUSTER_ARN      = data.aws_msk_cluster.main.arn
  MSK_CLUSTER_NAME     = data.aws_msk_cluster.main.cluster_name
  TOPIC_NAME           = "oracle-financial-transactions"
  
  # Storage Configuration
  S3_BUCKET_ARN        = data.aws_s3_bucket.datalake.arn
  S3_KMS_ARN           = data.aws_kms_key.s3.arn
  
  # Glue Catalog Configuration
  GLUE_DATABASE_NAME   = "oracle_transactions"
  GLUE_TABLE_NAME      = "financial_transactions"
  TABLE_TYPE           = "financial"  # or "brokerage"
  
  # Optional: Lambda Transformation (for DMS CDC data)
  ENABLE_LAMBDA_TRANSFORMATION = true
  LAMBDA_TRANSFORMER_ARN       = module.transformer.lambda_function_arn
  
  # Optional: Buffering Configuration
  BUFFERING_SIZE       = 5    # MB
  BUFFERING_INTERVAL   = 30   # seconds
  LOG_RETENTION_DAYS   = 7    # days
}
```

## Requirements

| Name      | Version |
| --------- | ------- |
| terraform | >= 1.0  |
| aws       | ~> 6.0  |

## Providers

| Name | Version |
| ---- | ------- |
| aws  | ~> 6.0  |

## Inputs

| Name                         | Description                                           | Type     | Default | Required |
| ---------------------------- | ----------------------------------------------------- | -------- | ------- | :------: |
| APP                          | Application name used for resource naming and tagging | `string` | n/a     |   yes    |
| ENV                          | Environment name used for resource naming and tagging | `string` | n/a     |   yes    |
| FIREHOSE_STREAM_NAME         | Name for the Firehose delivery stream                 | `string` | n/a     |   yes    |
| REGION                       | AWS region where resources will be deployed           | `string` | n/a     |   yes    |
| MSK_CLUSTER_ARN              | ARN of the MSK cluster to read from                   | `string` | n/a     |   yes    |
| MSK_CLUSTER_NAME             | Name of the MSK cluster                               | `string` | n/a     |   yes    |
| TOPIC_NAME                   | MSK topic name for ingestion                          | `string` | n/a     |   yes    |
| S3_BUCKET_ARN                | ARN of the S3 bucket for storing Iceberg data         | `string` | n/a     |   yes    |
| S3_KMS_ARN                   | ARN of the KMS key used for S3 encryption             | `string` | n/a     |   yes    |
| GLUE_DATABASE_NAME           | Name of the Glue database for the Iceberg table       | `string` | n/a     |   yes    |
| GLUE_TABLE_NAME              | Name of the Glue table for the Iceberg data           | `string` | n/a     |   yes    |
| TABLE_TYPE                   | Type of table (financial or brokerage)                | `string` | n/a     |   yes    |
| ENABLE_LAMBDA_TRANSFORMATION | Enable Lambda transformation for DMS data             | `bool`   | `false` |    no    |
| LAMBDA_TRANSFORMER_ARN       | ARN of Lambda transformer function                     | `string` | `""`    |    no    |
| BUFFERING_SIZE               | Buffer size in MB for Firehose                        | `number` | `5`     |    no    |
| BUFFERING_INTERVAL           | Buffer interval in seconds for Firehose               | `number` | `30`    |    no    |
| LOG_RETENTION_DAYS           | Number of days to retain CloudWatch logs              | `number` | `7`     |    no    |

## Outputs

| Name                          | Description                                       |
| ----------------------------- | ------------------------------------------------- |
| firehose_delivery_stream_name | Name of the Kinesis Data Firehose delivery stream |
| firehose_delivery_stream_arn  | ARN of the Kinesis Data Firehose delivery stream  |
| firehose_role_arn             | ARN of the IAM role used by Firehose              |
| firehose_role_name            | Name of the IAM role used by Firehose             |
| cloudwatch_log_group_name     | Name of the CloudWatch log group for Firehose     |
| cloudwatch_log_group_arn      | ARN of the CloudWatch log group for Firehose      |
| cloudwatch_log_stream_name    | Name of the CloudWatch log stream for Firehose    |
| cloudwatch_log_stream_arn     | ARN of the CloudWatch log stream for Firehose     |

## Resources Created

- `aws_cloudwatch_log_group` - CloudWatch log group for Firehose logs
- `aws_cloudwatch_log_stream` - CloudWatch log stream for Firehose
- `aws_iam_policy` - IAM policy for Firehose with necessary permissions
- `aws_iam_role` - IAM role for Firehose service
- `aws_iam_role_policy_attachment` - Attachment of policy to role
- `aws_kinesis_firehose_delivery_stream` - Kinesis Data Firehose delivery stream
- `aws_lakeformation_permissions` - Lake Formation permissions for database and tables

## IAM Permissions

The module creates an IAM role with the following permissions:

### MSK Permissions

- `kafka:CreateVpcConnection` - Create VPC connection to MSK cluster
- `kafka:GetBootstrapBrokers` - Get MSK bootstrap brokers
- `kafka:DescribeCluster` / `kafka:DescribeClusterV2` - Describe MSK cluster
- `kafka-cluster:Connect` - Connect to MSK cluster
- `kafka-cluster:DescribeTopic` / `kafka-cluster:DescribeTopicDynamicConfiguration` - Describe Kafka topics
- `kafka-cluster:ReadData` - Read data from Kafka topics

### Glue Permissions

- `glue:GetTable` / `glue:GetDatabase` / `glue:UpdateTable` - Manage Glue catalog
- `glue:GetSchemaVersion` - Access schema versions

### S3 and KMS Permissions

- `s3:AbortMultipartUpload` / `s3:GetBucketLocation` / `s3:GetObject` / `s3:ListBucket` / `s3:ListBucketMultipartUploads` / `s3:PutObject` / `s3:DeleteObject` - S3 operations
- `kms:Decrypt` / `kms:Encrypt` / `kms:GenerateDataKey` - KMS operations

### CloudWatch Permissions

- `logs:PutLogEvents` - Write to CloudWatch logs

## Lake Formation Integration

The module automatically configures Lake Formation permissions for:

### Database Permissions

- `DESCRIBE` - View database metadata
- `CREATE_TABLE` - Create new tables
- `ALTER` - Modify database structure
- `DROP` - Delete database

### Table Permissions (Wildcard)

- `SELECT` - Read table data
- `INSERT` - Add new data
- `DELETE` - Remove data
- `DESCRIBE` - View table metadata
- `ALTER` - Modify table structure
- `DROP` - Delete tables

## Configuration Details

### Lambda Transformation

When `ENABLE_LAMBDA_TRANSFORMATION = true`:

- **Purpose**: Flattens DMS CDC envelope format to flat transaction records
- **Processing**: Extracts `data` field from DMS envelope structure
- **Error Handling**: Failed transformations logged and stored in error prefix
- **Performance**: Configurable buffer size and interval for batch processing

### Iceberg Table Configuration

- **Unique Keys**: Automatically configured based on `TABLE_TYPE`
  - `financial`: Uses `transaction_id` as unique key
  - `brokerage`: Uses `order_id` as unique key
- **Storage Format**: Apache Iceberg with S3 backend
- **Partitioning**: Handled by Iceberg table format
- **Schema Evolution**: Supported through Glue catalog integration

### Error Handling

- **Error Prefix**: `{table_name}/errors/` in S3 bucket
- **Failed Records**: Stored with original format for debugging
- **CloudWatch Logs**: Detailed error information and processing metrics
- **Retry Logic**: Built-in Firehose retry mechanisms

## Implementation Examples

### DMS CDC Source (with Lambda transformation)
```hcl
module "oracle_financial_stream" {
  source = "../../../templates/modules/msk-firehose-ingestion"
  
  # ... basic configuration ...
  
  # Enable transformation for DMS envelope data
  ENABLE_LAMBDA_TRANSFORMATION = true
  LAMBDA_TRANSFORMER_ARN       = module.dms_transformer.lambda_function_arn
  TABLE_TYPE                   = "financial"
}
```

### Direct MSK Source (no transformation)
```hcl
module "msk_financial_stream" {
  source = "../../../templates/modules/msk-firehose-ingestion"
  
  # ... basic configuration ...
  
  # Direct streaming without transformation
  ENABLE_LAMBDA_TRANSFORMATION = false
  TABLE_TYPE                   = "financial"
}
```

## Troubleshooting

### Common Issues

1. **Stream Creation Failures**
   - Verify MSK cluster is active and accessible
   - Check IAM permissions for Firehose service role
   - Ensure Glue table exists before stream creation

2. **Data Not Appearing in S3**
   - Check CloudWatch logs for processing errors
   - Verify MSK topic has data and correct permissions
   - Monitor Firehose metrics for delivery failures

3. **Lambda Transformation Errors**
   - Review Lambda function logs for transformation failures
   - Verify input data format matches expected DMS envelope
   - Check Lambda function timeout and memory settings

### Debugging Steps

1. **Check Firehose Status**
   ```bash
   aws firehose describe-delivery-stream --delivery-stream-name ${STREAM_NAME}
   ```

2. **Monitor CloudWatch Logs**
   ```bash
   aws logs describe-log-groups --log-group-name-prefix "/aws/firehose/"
   ```

3. **Verify MSK Connectivity**
   ```bash
   aws kafka describe-cluster --cluster-arn ${MSK_CLUSTER_ARN}
   ```

## Dependencies

This module requires:

- **Foundation Layer**: KMS keys, S3 buckets, IAM roles
- **MSK Cluster**: Provisioned cluster with configured topics
- **Glue Catalog**: Database and table definitions
- **Lambda Function**: Transformer function (if transformation enabled)
- **Lake Formation**: Admin permissions configured

## Related Modules

- `../firehose-lambda-transformer`: Provides DMS data transformation
- `../msk-provisioned`: Creates MSK cluster for data sources
- `../../roots/ingestion-layer/firehose-streams/*`: Implementation examples
