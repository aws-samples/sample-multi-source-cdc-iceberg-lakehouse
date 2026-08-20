# MSK Financial Firehose Stream

## Purpose
Creates a Kinesis Data Firehose delivery stream that ingests native MSK financial transaction data directly into Apache Iceberg tables without transformation, providing high-throughput streaming for pre-formatted data.

## What It Creates
- **Firehose Delivery Stream**: `msk-financial-stream` for direct MSK topic ingestion
- **Glue Table Integration**: `msk_financial_transactions_table` in MSK database
- **CloudWatch Logging**: Monitoring and error tracking for the ingestion pipeline
- **IAM Roles**: Secure access to MSK, S3, Glue, and Lake Formation

## Why It's Needed
- **Direct Streaming**: Ingests pre-formatted financial data without transformation overhead
- **High Throughput**: Optimized for native MSK topic consumption
- **Schema Management**: Handles financial-specific fields (transaction_id as unique key)
- **Real-time Analytics**: Enables immediate querying of streaming financial data

## Configuration Options

### Basic Configuration (terraform.tfvars)
```hcl
APP    = "${APP_NAME}"
ENV    = "${ENV_NAME}"
REGION = "us-east-1"

# Stream Configuration
FIREHOSE_STREAM_NAME = "msk-financial-stream"
MSK_FINANCIAL_TABLE_NAME = "msk_financial_transactions_table"

# Performance Tuning
BUFFERING_SIZE     = 5     # MB
BUFFERING_INTERVAL = 300   # seconds (5 minutes)
LOG_RETENTION_DAYS = 7     # days
```

### Configuration Examples

#### High-Volume Environment
```hcl
BUFFERING_SIZE     = 10    # Larger buffer for high throughput
BUFFERING_INTERVAL = 60    # Faster delivery for real-time needs
```

#### Development Environment
```hcl
BUFFERING_SIZE     = 1     # Smaller buffer for testing
BUFFERING_INTERVAL = 30    # Quick delivery for development
LOG_RETENTION_DAYS = 3     # Shorter retention for cost savings
```

## Key Features
- **No Lambda Transformation**: Direct streaming without processing overhead
- **Financial Schema**: Optimized for transaction-based records with `transaction_id` unique key
- **Iceberg Format**: Efficient columnar storage with schema evolution support
- **Error Recovery**: Failed records stored in S3 error prefix for reprocessing
- **Lake Formation Integration**: Automatic permissions for data access and governance

## Data Flow
1. **MSK Topic** → Contains pre-formatted financial transaction data
2. **Firehose Stream** → Directly consumes messages from MSK topic
3. **Iceberg Table** → Stores data in S3 with Glue catalog (no transformation)

## Dependencies
- Foundation layer (KMS keys, S3 buckets, IAM roles)
- MSK cluster with `msk-source-financial-transactions` topic
- Glue database and table definitions
- Pre-formatted financial data in MSK topic

## Monitoring
- **CloudWatch Logs**: `/aws/firehose/${APP_NAME}-${ENV_NAME}-msk-financial-stream`
- **Firehose Metrics**: Delivery success/failure rates and processing latency
- **MSK Metrics**: Topic consumption rates and lag monitoring
