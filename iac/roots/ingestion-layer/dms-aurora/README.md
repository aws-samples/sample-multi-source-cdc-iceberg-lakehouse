# DMS Aurora Data Replication

## Purpose
Creates AWS Database Migration Service (DMS) resources to replicate data from Aurora PostgreSQL to Amazon MSK using change data capture (CDC), enabling real-time streaming of financial and brokerage transaction data.

## What It Creates
- **DMS Replication Instance**: Multi-AZ capable instance for data replication
- **Source Endpoint**: Aurora PostgreSQL endpoint with SSL and heartbeat monitoring
- **Target Endpoint**: MSK endpoint with SASL/SCRAM authentication
- **Replication Task**: CDC task with dual-topic routing for transaction types
- **IAM Roles**: Required DMS service roles with KMS encryption permissions

## Why It's Needed
- **Real-time Data Streaming**: Captures Aurora changes and streams to MSK topics
- **Dual Transaction Processing**: Routes financial and brokerage transactions to separate topics
- **Change Data Capture**: Provides continuous replication without impacting source performance
- **Data Pipeline Foundation**: Enables downstream processing via Firehose and Lambda

## Configuration Options

### Basic Configuration (terraform.tfvars)
```hcl
APP    = "${APP_NAME}"
ENV    = "${ENV_NAME}"
REGION = "us-east-1"

# DMS Instance Configuration
DMS_REPLICATION_INSTANCE_CLASS = "dms.t3.micro"
DMS_ALLOCATED_STORAGE         = 50
DMS_ENGINE_VERSION           = "3.5.3"

# Replication Settings
START_AURORA_REPLICATION_TASK = false
AURORA_MSK_MIGRATION_TYPE    = "cdc"
```

### Configuration Examples

#### Production Environment
```hcl
DMS_REPLICATION_INSTANCE_CLASS = "dms.r5.large"
DMS_ALLOCATED_STORAGE         = 200
DMS_MULTI_AZ                 = true
START_AURORA_REPLICATION_TASK = true
```

#### Development Environment
```hcl
DMS_REPLICATION_INSTANCE_CLASS = "dms.t3.micro"
DMS_ALLOCATED_STORAGE         = 50
DMS_MULTI_AZ                 = false
START_AURORA_REPLICATION_TASK = false
```

## Table Mapping Strategy

The module implements dual-topic routing for transaction types:

### Financial Transactions
- **Source**: `public.financial_transactions` table
- **Target**: MSK topic from SSM parameter `aurora-financial-transactions-topic`
- **Use Case**: Banking, payments, transfers

### Brokerage Transactions  
- **Source**: `public.brokerage_transactions` table
- **Target**: MSK topic from SSM parameter `aurora-brokerage-transactions-topic`
- **Use Case**: Trading, securities, investments

### Table Mapping Rules
```json
{
  "rules": [
    {
      "rule-type": "selection",
      "rule-id": "1",
      "rule-name": "select-financial-table",
      "object-locator": {
        "schema-name": "public",
        "table-name": "financial_transactions"
      },
      "rule-action": "include"
    },
    {
      "rule-type": "object-mapping", 
      "rule-id": "3",
      "rule-name": "map-financial-to-topic",
      "object-locator": {
        "schema-name": "public",
        "table-name": "financial_transactions"
      },
      "rule-action": "map-record-to-record",
      "kafka-target-topic": "aurora.financial.transactions"
    }
  ]
}
```

## Key Features
- SSL-required connections to Aurora with certificate validation
- Heartbeat monitoring every 30 seconds for CDC health tracking
- KMS encryption for data at rest and in transit
- Multi-AZ deployment support for high availability
- Configurable message format (JSON/JSON-unformatted)
- Automatic DMS service role creation

## Dependencies
- Foundation layer (VPC, KMS keys, IAM roles)
- Aurora PostgreSQL cluster with CDC enabled
- MSK cluster with SASL/SCRAM authentication
- Required SSM parameters:
  - `/{APP}/{ENV}/aurora-cluster-endpoint`
  - `/{APP}/{ENV}/aurora-cluster-port` 
  - `/{APP}/{ENV}/aurora-database-name`
  - `/{APP}/{ENV}/aurora-financial-transactions-topic`
  - `/{APP}/{ENV}/aurora-brokerage-transactions-topic`
- Secrets Manager secret: `{APP}-{ENV}-aurora-db-secret`

## Monitoring and Troubleshooting
- CloudWatch logs integration for DMS task monitoring
- Heartbeat schema in Aurora for CDC health verification
- SSL connection validation and certificate management
- Task status monitoring through AWS console and CLI
