# MSK Ingestion Cluster

## Purpose
Creates Amazon MSK (Managed Streaming for Apache Kafka) provisioned cluster as the central streaming hub for the Iceberg data lakehouse, enabling real-time data ingestion from multiple database sources with dual authentication support.

## What It Creates
- **MSK Provisioned Cluster**: 3-broker cluster with SASL/SCRAM and IAM authentication
- **Topic Management**: 6 predefined topics for financial and brokerage transactions from 3 data sources
- **EC2 Configuration Instance**: Automated topic creation and Kafka client tools
- **Security Groups**: MSK and EC2 access controls with DMS integration
- **Cluster Policy**: Firehose VPC connection permissions for downstream processing

## Why It's Needed
- **Multi-Source Data Hub**: Centralizes streaming data from Oracle, Aurora, and CockroachDB
- **DMS Integration**: SASL/SCRAM authentication required for AWS DMS replication
- **Real-time Processing**: Enables downstream Firehose and Lambda processing
- **Topic Segregation**: Separate topics for financial vs brokerage transaction types

## Configuration Options

### Basic Configuration (terraform.tfvars)
```hcl
APP    = "${APP_NAME}"
ENV    = "${ENV_NAME}"
REGION = "us-east-1"

# MSK Configuration
ENABLE_MSK_SASL_AUTH = true
MSK_CLUSTER_NAME     = "msk-ingest-cluster"
KAFKA_VERSION        = "3.9.x"
KAFKA_INSTANCE_TYPE  = "kafka.m5.large"
KAFKA_STORAGE_SIZE   = 1000
```

### Configuration Examples

#### Production Environment
```hcl
KAFKA_INSTANCE_TYPE = "kafka.m5.xlarge"
KAFKA_STORAGE_SIZE  = 2000
ENABLE_MSK_SASL_AUTH = true
```

#### Development Environment
```hcl
KAFKA_INSTANCE_TYPE = "kafka.m5.large"
KAFKA_STORAGE_SIZE  = 500
ENABLE_MSK_SASL_AUTH = true
```

## Topic Strategy

The cluster creates 6 topics for dual transaction types across 3 data sources:

### Financial Transaction Topics
- **oracle_financial_transactions**: Oracle financial data via DMS
- **aurora_financial_transactions**: Aurora financial data via DMS  
- **cockroach_financial_transactions**: CockroachDB financial data

### Brokerage Transaction Topics
- **oracle_brokerage_transactions**: Oracle brokerage data via DMS
- **aurora_brokerage_transactions**: Aurora brokerage data via DMS
- **cockroach_brokerage_transactions**: CockroachDB brokerage data

### Topic Configuration
- **Replication Factor**: 3 (matches broker count for high availability)
- **Partitions**: 1 (scalable based on throughput requirements)
- **Retention**: Default Kafka retention policies

## Authentication Methods

### SASL/SCRAM Authentication
- **Required for**: AWS DMS integration
- **Port**: 9096
- **Credentials**: Auto-generated and stored in Secrets Manager
- **Secret Name**: `AmazonMSK_{cluster-name}-credentials`

### IAM Authentication  
- **Used by**: AWS services (Lambda, Glue, Firehose)
- **Port**: 9098
- **Credentials**: IAM roles and policies
- **Always enabled**: Alongside SASL/SCRAM

## EC2 Configuration Instance

### Purpose
- Automated topic creation during deployment
- Kafka client tools for administration
- Environment variable configuration for all users

### Installed Tools
- Java 11 and Kafka client tools (version 3.9.1)
- AWS CLI and jq for JSON processing
- Both SASL/SCRAM and IAM client configurations

### Topic Management
```bash
# Connect to EC2 instance
aws ssm start-session --target <instance-id>

# List topics
./kafka-topics.sh --list --bootstrap-server $BOOTSTRAP_SERVER --command-config client.properties

# Create additional topics
./kafka-topics.sh --create --bootstrap-server $BOOTSTRAP_SERVER --command-config client.properties \
  --replication-factor 3 --partitions 1 --topic new-topic-name
```

## Key Features
- Multi-AZ deployment across 3 private subnets for high availability
- KMS encryption at rest and in transit using customer-managed keys
- Dual authentication support for different integration patterns
- Automated topic creation with configurable replication and partitioning
- Firehose integration policy for downstream S3 data lake processing
- Comprehensive monitoring via CloudWatch metrics and logs

## Dependencies
- Foundation layer (VPC, KMS keys, security groups)
- Required SSM parameters:
  - `/{APP}/{ENV}/vpc-id`
  - `/{APP}/{ENV}/vpc-private-subnet-ids`
  - `/{APP}/{ENV}/vpc-sg`
- Required KMS keys:
  - MSK encryption key: `alias/{APP}-{ENV}-msk-secret-key`
  - Secrets Manager key: `alias/{APP}-{ENV}-secrets-manager-secret-key`

## Integration Points
- **DMS Replication**: Target for Oracle and Aurora CDC replication
- **Firehose Streams**: Source for S3 data lake ingestion
- **Lambda Processing**: Real-time data transformation
- **Glue Streaming**: ETL processing from Kafka topics

## Monitoring and Troubleshooting
- CloudWatch metrics for broker performance and topic throughput
- EC2 instance logs at `/var/log/user-data.log` for deployment issues
- Environment variables available system-wide via `/etc/profile.d/msk-env.sh`
- SASL/SCRAM credential validation through Secrets Manager
