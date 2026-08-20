# CockroachDB Financial MSK Firehose Stream

## Purpose
Creates a Kinesis Data Firehose delivery stream that ingests CockroachDB financial transaction data from MSK topics into Apache Iceberg tables, with Lambda transformation for changefeed envelope flattening.

## What It Creates
- **Firehose Delivery Stream**: `cockroach-financial-msk-stream` for real-time data ingestion
- **Lambda Transformer**: Flattens CockroachDB changefeed envelope format to flat financial records
- **Glue Table Integration**: `fin` table in CockroachDB Firehose database
- **CloudWatch Logging**: Monitoring and error tracking for the ingestion pipeline

## Why It's Needed
- **CDC Data Processing**: Transforms CockroachDB changefeed format for analytics
- **Real-time Ingestion**: Streams financial transactions from CockroachDB to data lake
- **Schema Management**: Handles financial-specific fields (transaction_id as unique key)
- **Error Handling**: Captures and stores failed transformations for debugging

## Configuration Options

### Basic Configuration (terraform.tfvars)
```hcl
APP    = "${APP_NAME}"
ENV    = "${ENV_NAME}"
REGION = "us-east-1"

# Stream Configuration
FIREHOSE_STREAM_NAME = "cockroach-financial-msk-stream"
COCKROACH_FINANCIAL_TABLE_NAME = "fin"

# Performance Tuning
BUFFERING_SIZE     = 5     # MB
BUFFERING_INTERVAL = 30    # seconds
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
BUFFERING_INTERVAL = 15    # Quick delivery for development
LOG_RETENTION_DAYS = 3     # Shorter retention for cost savings
```

## CockroachDB Changefeed Setup

### Prerequisites
- CockroachDB NLB endpoint (from SSM: `/${APP_NAME}/${ENV_NAME}/cockroachdb-endpoint`)
- MSK bootstrap brokers IAM endpoint (from SSM: `/${APP_NAME}/${ENV_NAME}/msk-ingest-cluster-bootstrap-servers-sasl-iam`)
- Financial MSK IAM role ARN: `arn:aws:iam::<account_id>:role/${APP_NAME}-${ENV_NAME}-cockroach-financial-msk-role`

### Enable Rangefeed (one-time cluster setting)
```sql
cockroach sql --insecure --host=<cockroachdb_nlb_endpoint>

SET CLUSTER SETTING kv.rangefeed.enabled = true;
```

### Create External Connection
The external connection includes `topic_name` to map the CockroachDB table name (`financial_transactions`) to the expected MSK topic name (`crdb_fin`).

Each CockroachDB stream (financial/brokerage) uses a separate external connection with its own IAM role.

```sql
CREATE EXTERNAL CONNECTION msk_financial AS 'kafka://<bootstrap_brokers_endpoint>/?tls_enabled=true&sasl_enabled=true&sasl_mechanism=AWS_MSK_IAM&sasl_aws_region=us-east-1&sasl_aws_iam_role_arn=arn:aws:iam::<account_id>:role/${APP_NAME}-${ENV_NAME}-cockroach-financial-msk-role&sasl_aws_iam_session_name=crdb_fin&topic_name=crdb_fin';
```

### Create Changefeed
```sql
CREATE CHANGEFEED FOR TABLE defaultdb.financial_transactions INTO 'external://msk_financial' WITH envelope=enriched, key_in_value;
```

### Manage Changefeeds
```sql
SHOW CHANGEFEED JOBS;

CANCEL JOB <job_id>;
```

### Troubleshooting
- **NLB timeouts**: The NLB may intermittently timeout. Retry the command if you get a connection timeout.

## Key Features
- **Changefeed Envelope Transformation**: Lambda function extracts `data` field from changefeed records
- **Financial Schema**: Optimized for transaction-based records with `transaction_id` unique key
- **Iceberg Format**: Efficient columnar storage with schema evolution support
- **Error Recovery**: Failed records stored in S3 error prefix for reprocessing
- **Lake Formation Integration**: Automatic permissions for data access and governance

## Data Flow
1. **CockroachDB** → Changefeed captures financial transaction changes
2. **Changefeed** → Publishes CDC envelopes to MSK topic
3. **MSK Topic** → Firehose stream consumes messages
4. **Lambda Transformer** → Flattens changefeed envelope to financial record
5. **Iceberg Table** → Stores transformed data in S3 with Glue catalog

## Dependencies
- Foundation layer (KMS keys, S3 buckets, IAM roles)
- CockroachDB cluster with changefeed enabled
- MSK cluster with `crdb_fin` topic
- Glue database and table definitions
- Lambda transformer function

## Monitoring
- **CloudWatch Logs**: `/aws/firehose/${APP_NAME}-${ENV_NAME}-cockroach-financial-msk-stream`
- **Firehose Metrics**: Delivery success/failure rates and processing latency
- **Lambda Metrics**: Transformation success rates and error counts
