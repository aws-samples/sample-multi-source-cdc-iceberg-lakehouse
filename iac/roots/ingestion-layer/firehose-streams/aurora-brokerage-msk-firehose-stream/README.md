# Aurora Brokerage MSK Firehose Stream

## Purpose
Creates a Kinesis Data Firehose delivery stream that ingests Aurora PostgreSQL brokerage transaction data from MSK topics into Apache Iceberg tables, with Lambda transformation for DMS CDC envelope flattening.

## What It Creates
- **Firehose Delivery Stream**: `aurora-brokerage-msk-stream` for real-time data ingestion
- **Lambda Transformer**: Flattens DMS CDC envelope format to flat brokerage records
- **Glue Table Integration**: `aurora_brokerage_transactions_table` in Aurora database
- **CloudWatch Logging**: Monitoring and error tracking for the ingestion pipeline
- **IAM Roles**: Secure access to MSK, S3, Glue, and Lake Formation

## Why It's Needed
- **CDC Data Processing**: Transforms DMS change data capture format for analytics
- **Real-time Ingestion**: Streams brokerage transactions from Aurora to data lake
- **Schema Management**: Handles brokerage-specific fields (order_id as unique key)
- **Error Handling**: Captures and stores failed transformations for debugging

## Configuration Options

### Basic Configuration (terraform.tfvars)
```hcl
APP    = "${APP_NAME}"
ENV    = "${ENV_NAME}"
REGION = "us-east-1"

# Stream Configuration
FIREHOSE_STREAM_NAME = "aurora-brokerage-msk-stream"
AURORA_BROKERAGE_TABLE_NAME = "aurora_brokerage_transactions_table"

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
- **DMS Envelope Transformation**: Lambda function extracts `data` field from CDC records
- **Brokerage Schema**: Optimized for order-based transactions with `order_id` unique key
- **Iceberg Format**: Efficient columnar storage with schema evolution support
- **Error Recovery**: Failed records stored in S3 error prefix for reprocessing
- **Lake Formation Integration**: Automatic permissions for data access and governance

## Data Flow
1. **Aurora PostgreSQL** → DMS captures brokerage transaction changes
2. **DMS** → Publishes CDC envelopes to MSK topic
3. **MSK Topic** → Firehose stream consumes messages
4. **Lambda Transformer** → Flattens DMS envelope to brokerage record
5. **Iceberg Table** → Stores transformed data in S3 with Glue catalog

## Dependencies
- Foundation layer (KMS keys, S3 buckets, IAM roles)
- Aurora PostgreSQL cluster with DMS replication
- MSK cluster with `msk-ingest-aurora-brokerage-transactions` topic
- Glue database and table definitions
- Lambda transformer function

## Monitoring
- **CloudWatch Logs**: `/aws/firehose/${APP_NAME}-${ENV_NAME}-aurora-brokerage-msk-stream`
- **Firehose Metrics**: Delivery success/failure rates and processing latency
- **Lambda Metrics**: Transformation success rates and error counts
