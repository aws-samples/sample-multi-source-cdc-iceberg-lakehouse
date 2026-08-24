# Ingestion Layer

## Overview

The Ingestion Layer is responsible for capturing and moving data from various data sources to the Iceberg Data Lakehouse. It provides two parallel ingestion paths:

- **Path 1** (DMS + Firehose + Lambda): 8 Firehose roots (16 delivery streams), 2 DMS modules, MSK Ingest cluster
- **Path 2** (MSK Connect Debezium source + Apache Flink): 2 Debezium source connectors (Oracle/Aurora), 4 Managed Apache Flink applications (one per source), MSK Ingest cluster (shared)

Both paths write to S3 Iceberg and S3 Tables in parallel.

## Architecture

```
┌───────────────────────┐    ┌──────────────────────────────────┐     ┌──────────────────────┐
│      Data Sources     │    │        Ingestion Layer           │     │    Storage Layer     │
│                       │    │                                  │     │                      │
│ • Oracle on EC2       │───▶│ Path 1:                          │───▶ │ • S3 Iceberg         │
│ • Aurora PostgreSQL   │    │  • DMS (Oracle/Aurora)           │     │ • S3 Tables          │
│ • CockroachDB on EC2  │    │  • 16 Firehose delivery streams  │     │ • AWS Glue Catalog   │
│ • MSK Direct          │    │  • Lambda Transform              │     │ • 8 Glue Databases   │
│                       │    │ Path 2:                          │     │                      │
│                       │    │  • Debezium sources (Oracle/     │     │                      │
│                       │    │    Aurora) on MSK Connect        │     │                      │
│                       │    │  • 4 Managed Apache Flink apps    │     │                      │
│                       │    │ Shared: MSK Ingest (dual auth)   │     │                      │
└───────────────────────┘    └──────────────────────────────────┘     └──────────────────────┘
```

## Data Flow Patterns

### Real-time CDC Streaming (6 streams with Lambda transformation)

```
Oracle/Aurora ──CDC──▶ DMS ──▶ MSK ──▶ Firehose ──▶ Lambda ──▶ S3 Iceberg + S3 Tables
CockroachDB ──Changefeed──▶ MSK ──▶ Firehose ──▶ Lambda ──▶ S3 Iceberg + S3 Tables
```

### Direct Streaming (2 streams without transformation)

```
EC2 Data Generator ──▶ MSK Source ──▶ Firehose (no Lambda) ──▶ S3 Iceberg + S3 Tables
```

### Path 2: MSK Connect Debezium source + Apache Flink

```
Oracle/Aurora ──▶ MSK Connect (Debezium source) ──▶ MSK Ingest (IAM) ──▶ Managed Apache Flink ──▶ S3 Iceberg + S3 Tables
CockroachDB ──▶ Changefeed (IAM) ──▶ MSK Ingest ──▶ Managed Apache Flink ──▶ S3 Iceberg + S3 Tables
MSK Source ──▶ MSK Ingest ──▶ Managed Apache Flink ──▶ S3 Iceberg + S3 Tables
```

Note: only Oracle and Aurora use a Debezium source connector on MSK Connect. CockroachDB
writes to MSK Ingest directly via its native changefeed (IAM auth), and MSK-direct data
is produced straight to the MSK Source cluster. All four are then consumed by a dedicated
Managed Apache Flink application that writes the Iceberg `c_*` tables.

## Components

The ingestion layer consists of several modules designed for comprehensive data ingestion across all data sources:

### 1. Firehose Streams (8 streams)

**Location**: `iac/roots/ingestion-layer/firehose-streams/`

The core of the ingestion architecture with 8 specialized streams covering all data source and transaction type combinations:

#### CDC Sources (6 streams with Lambda transformation)

- **Oracle Financial MSK Firehose Stream**: Oracle financial transactions via DMS CDC
- **Oracle Brokerage MSK Firehose Stream**: Oracle brokerage transactions via DMS CDC
- **Aurora Financial MSK Firehose Stream**: Aurora financial transactions via DMS CDC
- **Aurora Brokerage MSK Firehose Stream**: Aurora brokerage transactions via DMS CDC
- **CockroachDB Financial MSK Firehose Stream**: CockroachDB financial via changefeed
- **CockroachDB Brokerage MSK Firehose Stream**: CockroachDB brokerage via changefeed

#### Direct Sources (2 streams without transformation)

- **MSK Financial Firehose Stream**: Direct MSK streaming for financial data
- **MSK Brokerage Firehose Stream**: Direct MSK streaming for brokerage data

**Key Features**:

- **Lambda Transformation**: Python 3.11 functions flatten DMS CDC envelopes for CDC sources
- **Field Transformation**: UPPERCASE to lowercase conversion for Glue compatibility
- **Format Handling**: Supports both MSK and Kinesis record formats
- **Error Handling**: Comprehensive error handling with Firehose response formats
- **Iceberg Integration**: Direct delivery to S3 in Apache Iceberg format
- **Glue Catalog**: Automatic table creation and metadata management

### 2. DMS Replication Modules

#### DMS Oracle Module

**Location**: `iac/roots/ingestion-layer/dms-oracle/`

Oracle-specific database replication with CDC capabilities:

- **Oracle Source Integration**: LogMiner-based CDC from Oracle databases
- **MSK Target**: Real-time streaming to MSK ingestion cluster
- **Table Selection**: Automatic discovery of Oracle user schema tables
- **Performance Optimized**: Enhanced memory and CDC batch settings

#### DMS Aurora Module

**Location**: `iac/roots/ingestion-layer/dms-aurora/`

Aurora PostgreSQL replication with logical replication:

- **Aurora Source Integration**: PostgreSQL logical replication support
- **MSK Target**: Streaming to MSK with SASL/SCRAM authentication
- **Multi-AZ Support**: Aurora cluster compatibility
- **PostgreSQL Optimized**: Aurora-specific configuration settings

**DMS Configuration Recommendation**

Each DMS task has settings that you can configure according to your needs. Some of the settings to consider for CDC load are below:

- ParallelApplyThreads: This sets the number of concurrent threads that DMS uses to load to the target. If you see target latency is higher or target is not able to keep with the source in terms of throughput then increasing this value can help
- ParallelApplyBufferSize: This specifies the maximum number of records to store in each buffer queue for concurrent threads to push
- ParallelApplyQueuesPerThread: This Specifies the number of queues that each thread accesses to take data records out of queues and generate a batch load

There are other configuration that can be set for task and for tuning CDC load to match your requirements.
Please refer to [AWS documentation](https://docs.aws.amazon.com/dms/latest/userguide/CHAP_Tasks.CustomizingTasks.TaskSettings.html)
for details

### 3. MSK Ingestion Cluster

**Location**: `iac/roots/ingestion-layer/msk-ingest/`

Dedicated MSK cluster for data ingestion with comprehensive management:

- **Provisioned MSK Cluster**: kafka.m5.large instances with 3-broker configuration
- **Dual Authentication**: IAM and SASL/SCRAM support for different integration patterns
- **Automated Topic Management**: EC2 configuration instance creates and manages topics
- **Security**: KMS encryption, VPC deployment, security group controls
- **Monitoring**: CloudWatch integration for performance and health metrics

### 4. Debezium Source Connectors (Path 2)

**Location**: `iac/roots/ingestion-layer/debezium-oracle/`, `iac/roots/ingestion-layer/debezium-aurora/`

MSK Connect Debezium source connectors for CDC capture:

- **Debezium Oracle**: LogMiner-based CDC via MSK Connect, writes to MSK Ingest (IAM auth)
- **Debezium Aurora**: PostgreSQL pgoutput-based CDC via MSK Connect, writes to MSK Ingest (IAM auth)

### 5. Managed Apache Flink Applications (Path 2)

**Location**: `iac/roots/flink/`

Amazon Managed Service for Apache Flink applications consume from MSK Ingest and write to
S3 Iceberg + S3 Tables (they replaced the earlier MSK Connect Iceberg Sink connectors):

- **4 applications**, one per source: `OracleCdcJob`, `AuroraCdcJob`, `CockroachCdcJob`, `MskAppendJob`
- Each reads its source's financial + brokerage topics from MSK Ingest (IAM auth) and writes
  the `fin` + `brk` tables in its `c_*` Glue database, plus the parallel S3 Tables namespace
- CDC jobs (Oracle/Aurora/Cockroach) apply upserts via equality deletes (`__op`/`op` → RowKind);
  `MskAppendJob` is append-only (all INSERT)
- Deployed via `make deploy-flink-all` (builds/uploads the Flink JAR, then applies `iac/roots/flink`)

## Deployment Architecture

### Deployment Order

The ingestion layer components should be deployed in the following order:

1. **Prerequisites**: Foundation layer (network, KMS, IAM, S3 buckets, Glue databases, S3 Tables)
2. **Data Sources**: Oracle, Aurora, CockroachDB, MSK data sources
3. **MSK Ingestion Cluster**: Deploy first as all ingestion components depend on it
4. **Path 1**: DMS Oracle/Aurora, then all 8 Firehose stream roots
5. **Path 2**: Connector plugins, Debezium Oracle/Aurora sources, then the 4 Managed Apache Flink apps (`make deploy-flink-all`)
6. **Post-deployment**: `setup-source-tables` → `start-dms-tasks` → `setup-cockroachdb-changefeeds` → `generate-data`

### Deployment Commands

#### Complete Ingestion Layer

```bash
# Deploy Path 1 (DMS Oracle/Aurora + all 8 firehose streams)
make deploy-path1

# Deploy Path 2 (Debezium sources + Managed Apache Flink apps)
make deploy-path2

# Start DMS replication tasks
make start-dms-tasks

# Stop DMS replication tasks (if needed)
make stop-dms-tasks
```

#### Individual Firehose Streams (only if NOT using deploy-path1)

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

# CockroachDB CDC streams
make deploy-cfmfs  # CockroachDB Financial MSK Firehose Stream
make deploy-cbmfs  # CockroachDB Brokerage MSK Firehose Stream
```

#### Core Infrastructure Components

```bash
# Deploy MSK ingestion cluster
make deploy-msk-ingest

# Deploy DMS replication modules
make deploy-dms-oracle
make deploy-dms-aurora
```

### Data Lake Output Structure

After deployment, the ingestion layer creates:

#### Glue Catalog Databases (8 databases)

- **Path 1 (Firehose)**: `{app}_{env}_f_oracle`, `{app}_{env}_f_aurora`, `{app}_{env}_f_crdb`, `{app}_{env}_f_msk_src`
- **Path 2 (Flink)**: `{app}_{env}_c_oracle`, `{app}_{env}_c_aurora`, `{app}_{env}_c_crdb`, `{app}_{env}_c_msk_src`

#### Iceberg Tables (16 total - 2 per database: `fin`, `brk`)

- **Path 1**: `{db}.fin`, `{db}.brk` for each of the 4 Firehose databases
- **Path 2**: `{db}.fin`, `{db}.brk` for each of the 4 Flink databases

#### S3 Iceberg Storage (16 tables)

Each table folder contains:

- `data/` - Parquet files with transaction data
- `metadata/` - Iceberg metadata and schema information
- `errors/` - Firehose processing errors for troubleshooting (Path 1 only)

## Lambda Transformation Architecture

### CDC Sources Transformation

For Oracle, Aurora, and CockroachDB sources, Lambda functions process DMS CDC envelopes:

**Input Format (DMS Envelope)**:

```json
{
  "data": {
    "transaction_id": "TXN123",
    "CUSTOMER_ID": "CUST456",
    "TRANSACTION_AMOUNT": 100.5
  },
  "metadata": {
    "timestamp": "2024-01-01T12:00:00Z",
    "operation": "INSERT",
    "table-name": "transactions"
  }
}
```

**Output Format (Flat Record)**:

```json
{
  "transaction_id": "TXN123",
  "customer_id": "CUST456",
  "transaction_amount": 100.5,
  "dms_timestamp": "2024-01-01T12:00:00Z",
  "dms_operation": "INSERT"
}
```

**Transformation Logic**:

- Extract transaction data from DMS envelope structure
- Convert UPPERCASE field names to lowercase for Glue compatibility
- Flatten nested structures into single-level records
- Add DMS metadata fields with `dms_` prefix
- Handle schema evolution automatically

### Direct Sources (No Transformation)

MSK direct streams bypass Lambda transformation as data is already in flat format from Lambda data generators.

## Monitoring and Observability

### CloudWatch Metrics

#### Firehose Metrics

- `DeliveryToS3.Records`: Records delivered to S3 Iceberg tables
- `DeliveryToS3.Success`: Successful delivery rate per stream
- `DeliveryToS3.DataFreshness`: Age of oldest record in buffer
- `IncomingRecords`: Records received from MSK topics

#### DMS Metrics

- `CDCLatencySource`: Source endpoint latency for CDC
- `CDCLatencyTarget`: Target endpoint latency for MSK delivery
- `FullLoadThroughputBandwidthTarget`: Data transfer rate
- `FreeableMemory`: Available memory on replication instance

#### MSK Metrics

- `MessagesInPerSec`: Message ingestion rate per topic
- `BytesInPerSec`: Data ingestion rate in bytes
- `UnderReplicatedPartitions`: Replication health
- `OfflinePartitionsCount`: Partition availability

#### Lambda Transformation Metrics

- `Duration`: Transformation processing time
- `Errors`: Transformation failures requiring investigation
- `Invocations`: Total transformation requests
- `Throttles`: Rate limiting events

### Logging Locations

- **Firehose**: `/aws/kinesisfirehose/{stream-name}`
- **Lambda Transformers**: `/aws/lambda/{function-name}`
- **DMS**: `/aws/dms/task/{task-name}`
- **MSK**: EC2 instance logs and Kafka broker logs

## Security

### Encryption

- **Data at Rest**: Customer-managed KMS keys for all storage
- **Data in Transit**: TLS/SSL for all data transfers
- **Secrets**: Database credentials in AWS Secrets Manager
- **MSK**: KMS encryption with SASL/SCRAM authentication

### Network Security

- **VPC Deployment**: All components in private subnets
- **Security Groups**: Restrictive rules for necessary traffic only
- **VPC Endpoints**: S3 access without internet gateway
- **NAT Gateway**: Controlled outbound internet access

### Authentication

- **IAM Roles**: Least-privilege roles for all components
- **SASL/SCRAM**: MSK authentication with Secrets Manager credentials
- **Service-to-Service**: IAM-based authentication between AWS services

## Integration Points

### Data Sources Integration

- **Oracle Database**: Connection via DMS with LogMiner CDC
- **Aurora PostgreSQL**: Logical replication through DMS
- **CockroachDB**: Changefeed streaming (requires manual enablement)
- **MSK Direct**: Lambda data generators publishing to topics

### Storage Layer Integration

- **S3 Iceberg Tables**: Direct delivery in Apache Iceberg format
- **Glue Data Catalog**: Automatic table creation and schema management
- **Cross-Region Replication**: Primary data with disaster recovery

### Query Engine Integration

- **Amazon Athena**: SQL queries on all Iceberg tables
- **Snowflake**: External table integration via Iceberg catalog (see `snowflake-integration/`)

## Related Documentation

### Module-Specific Documentation

- [Firehose Streams Documentation](firehose-streams/README.md)
- [DMS Oracle Module](dms-oracle/README.md)
- [DMS Aurora Module](dms-aurora/README.md)
- [MSK Ingestion Module](msk-ingest/README.md)
- [Debezium Oracle Source](debezium-oracle/)
- [Debezium Aurora Source](debezium-aurora/)
- [Managed Apache Flink Applications (Path 2)](../flink/README.md)

### Architecture Documentation

- [Data Ingestion Flows](../../../diagrams/data-ingestion-flows.md)
- [Foundation Layer](../foundation/README.md)
- [Data Sources Layer](../datasources/README.md)
- [Main Project Documentation](../../../README.md)
