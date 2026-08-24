# Firehose Streams Ingestion Layer

## Purpose
Creates 8 Kinesis Data Firehose delivery streams that ingest data from MSK topics into Apache Iceberg tables stored in S3, providing real-time data streaming capabilities for the data lakehouse. Each stream handles a specific data source and transaction type combination.

## What It Creates
- **8 Firehose Delivery Streams**: Complete coverage of all data source and transaction type combinations
- **Lambda Transformers**: DMS CDC envelope flattening for Oracle, Aurora, and CockroachDB sources
- **CloudWatch Logging**: Comprehensive monitoring and troubleshooting for each stream
- **IAM Roles & Policies**: Secure access to MSK, S3, Glue, and Lake Formation resources
- **Glue Table Integration**: Automatic schema management and catalog updates

## Why It's Needed
- **Real-time Ingestion**: Streams data from MSK topics to Iceberg tables with minimal latency
- **Data Transformation**: Flattens DMS CDC envelope format for database sources
- **Schema Evolution**: Handles schema changes automatically via Glue catalog integration
- **Dual Ingestion Patterns**: Supports both CDC transformation and direct streaming
- **Error Recovery**: Captures and stores failed transformations for debugging and reprocessing

## Stream Architecture

### 8 Firehose Streams Overview
| Stream Directory | Make Command | Source | Data Type | Lambda Transform | MSK Topic |
|------------------|--------------|--------|-----------|------------------|-----------|
| `oracle-financial-msk-firehose-stream` | `deploy-ofmfs` | Oracle DB | Financial | ✅ | `msk-ingest-oracle-financial-transactions` |
| `oracle-brokerage-msk-firehose-stream` | `deploy-obmfs` | Oracle DB | Brokerage | ✅ | `msk-ingest-oracle-brokerage-transactions` |
| `aurora-financial-msk-firehose-stream` | `deploy-afmfs` | Aurora PG | Financial | ✅ | `msk-ingest-aurora-financial-transactions` |
| `aurora-brokerage-msk-firehose-stream` | `deploy-abmfs` | Aurora PG | Brokerage | ✅ | `msk-ingest-aurora-brokerage-transactions` |
| `cockroach-financial-msk-firehose-stream` | `deploy-cfmfs` | CockroachDB | Financial | ❌ | `cockroach-financial-transactions` |
| `cockroach-brokerage-msk-firehose-stream` | `deploy-cbmfs` | CockroachDB | Brokerage | ❌ | `cockroach-brokerage-transactions` |
| `msk-financial-firehose-stream` | `deploy-mffs` | MSK Direct | Financial | ❌ | `financial-transactions` |
| `msk-brokerage-firehose-stream` | `deploy-mbfs` | MSK Direct | Brokerage | ❌ | `brokerage-transactions` |

### Data Flow Patterns

#### CDC Sources (Oracle, Aurora) - With Lambda Transformation
1. **Database** → DMS captures changes → MSK topic (DMS envelope format)
2. **MSK Topic** → Firehose stream consumes messages
3. **Lambda Transformer** → Flattens DMS envelope to transaction record
4. **Iceberg Table** → Stores transformed data in S3 with Glue catalog

#### Direct Sources (MSK, CockroachDB) - No Transformation
1. **Data Generator/CockroachDB** → Publishes directly to MSK topic (flat format)
2. **MSK Topic** → Firehose stream consumes messages
3. **Iceberg Table** → Stores data directly in S3 with Glue catalog

## Configuration Options

### Standard Configuration (terraform.tfvars)
```hcl
APP    = "${APP_NAME}"
ENV    = "${ENV_NAME}"
REGION = "us-east-1"

# Performance Tuning
BUFFERING_SIZE     = 5     # MB - batch size for S3 writes
BUFFERING_INTERVAL = 300   # seconds - max time before write
LOG_RETENTION_DAYS = 7     # days - CloudWatch log retention
```

### Environment-Specific Tuning

#### High-Volume Production
```hcl
BUFFERING_SIZE     = 10    # Larger batches for efficiency
BUFFERING_INTERVAL = 60    # Faster delivery for real-time needs
LOG_RETENTION_DAYS = 30    # Extended retention for compliance
```

#### Development/Testing
```hcl
BUFFERING_SIZE     = 1     # Smaller batches for quick testing
BUFFERING_INTERVAL = 30    # Quick delivery for development
LOG_RETENTION_DAYS = 3     # Shorter retention for cost savings
```

## Key Features
- **Dual Ingestion Patterns**: CDC sources with Lambda transformation vs direct streaming
- **Apache Iceberg Format**: Efficient columnar storage with schema evolution support
- **Automatic Schema Management**: Glue catalog integration with Lake Formation permissions
- **Error Handling**: Failed records stored in S3 error prefixes for reprocessing
- **Comprehensive Monitoring**: CloudWatch logs and metrics for each stream
- **Secure Access**: IAM roles with least-privilege access to all AWS services

## Dependencies
- **Foundation Layer**: KMS keys, S3 buckets, IAM roles, networking
- **Data Sources Layer**: MSK clusters, databases, data generators
- **Glue Catalog**: Databases and table definitions
- **Lambda Functions**: Transformer functions for CDC sources (Oracle, Aurora)

## Deployment

### Complete Deployment (Recommended)
```bash
# Deploy all 8 streams
make deploy-all-firehose-streams
```

### Individual Stream Deployment
```bash
# Oracle CDC streams
make deploy-ofmfs  # Oracle Financial MSK Firehose Stream
make deploy-obmfs  # Oracle Brokerage MSK Firehose Stream

# Aurora CDC streams  
make deploy-afmfs  # Aurora Financial MSK Firehose Stream
make deploy-abmfs  # Aurora Brokerage MSK Firehose Stream

# MSK direct streams
make deploy-mffs   # MSK Financial Firehose Stream
make deploy-mbfs   # MSK Brokerage Firehose Stream

# CockroachDB streams
make deploy-cfmfs  # CockroachDB Financial MSK Firehose Stream
make deploy-cbmfs  # CockroachDB Brokerage MSK Firehose Stream

# Deploy all streams at once
make deploy-all-firehose-streams
```

### Manual Deployment (Advanced)
```bash
# Example: Deploy Oracle Financial stream manually
cd oracle-financial-msk-firehose-stream
terraform init
terraform apply
```

## Output Tables
Each stream creates a corresponding Iceberg table in the appropriate Glue database:

- **Oracle Database**: `oracle_financial_transactions_table`, `oracle_brokerage_transactions_table`
- **Aurora Database**: `aurora_financial_transactions_table`, `aurora_brokerage_transactions_table`
- **CockroachDB Database**: `cockroach_financial_transactions_table`, `cockroach_brokerage_transactions_table`
- **MSK Database**: `msk_financial_transactions_table`, `msk_brokerage_transactions_table`

## Monitoring & Troubleshooting

### CloudWatch Logs
- **Oracle**: `/aws/firehose/${APP_NAME}-${ENV_NAME}-oracle-financial-msk-stream`
- **Aurora**: `/aws/firehose/${APP_NAME}-${ENV_NAME}-aurora-financial-msk-stream`
- **CockroachDB**: `/aws/firehose/${APP_NAME}-${ENV_NAME}-cockroach-financial-msk-stream`
- **MSK**: `/aws/firehose/${APP_NAME}-${ENV_NAME}-msk-financial-stream`

### Key Metrics
- **Delivery Success Rate**: Percentage of successful S3 writes
- **Processing Latency**: Time from MSK consumption to S3 delivery
- **Lambda Errors**: Transformation failures (CDC sources only)
- **Error Record Count**: Failed records stored in error prefixes

### Common Issues
- **Lambda Timeout**: Increase timeout for complex transformations
- **Schema Mismatch**: Check Glue catalog table definitions
- **MSK Connectivity**: Verify security group and VPC configuration
- **S3 Permissions**: Ensure Firehose role has write access to data lake bucket
