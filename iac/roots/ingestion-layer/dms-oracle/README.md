# DMS Oracle Data Replication

## Purpose
Creates AWS Database Migration Service (DMS) resources to replicate data from Oracle Database to Amazon MSK using LogMiner-based change data capture (CDC), enabling real-time streaming of financial and brokerage transaction data.

## What It Creates
- **DMS Replication Instance**: Multi-AZ capable instance for Oracle data replication
- **Source Endpoint**: Oracle endpoint with LogMiner CDC configuration
- **Target Endpoint**: MSK endpoint with SASL/SCRAM authentication
- **Replication Task**: CDC task with dual-topic routing for transaction types
- **IAM Roles**: Required DMS service roles with KMS encryption permissions

## Why It's Needed
- **Oracle CDC Integration**: Captures Oracle changes using LogMiner without impacting performance
- **Dual Transaction Processing**: Routes financial and brokerage transactions to separate MSK topics
- **Legacy System Integration**: Connects Oracle databases to modern streaming architecture
- **Real-time Data Pipeline**: Enables downstream processing via Firehose and Lambda

## Configuration Options

### Basic Configuration (terraform.tfvars)
```hcl
APP    = "${APP_NAME}"
ENV    = "${ENV_NAME}"
REGION = "us-east-1"

# DMS Instance Configuration
DMS_REPLICATION_INSTANCE_CLASS = "dms.r5.4xlarge"
DMS_ALLOCATED_STORAGE         = 200
DMS_ENGINE_VERSION           = "3.6.1"

# Replication Settings
START_ORACLE_REPLICATION_TASK = false
ORACLE_MSK_MIGRATION_TYPE    = "cdc"
```

### Configuration Examples

#### Production Environment
```hcl
DMS_REPLICATION_INSTANCE_CLASS = "dms.r5.xlarge"
DMS_ALLOCATED_STORAGE         = 500
DMS_MULTI_AZ                 = true
START_ORACLE_REPLICATION_TASK = true
```

#### Development Environment
```hcl
DMS_REPLICATION_INSTANCE_CLASS = "dms.t3.micro"
DMS_ALLOCATED_STORAGE         = 50
DMS_MULTI_AZ                 = false
START_ORACLE_REPLICATION_TASK = false
```

## Oracle LogMiner Configuration

### Connection Attributes
```
useLogminerReader=N;useBfile=Y;addSupplementalLogging=N
```

- **useLogminerReader=N**: Uses Binary Reader instead of LogMiner for better performance
- **useBfile=Y**: Enables binary file access for Binary Reader
- **addSupplementalLogging=N**: Supplemental logging is pre-configured on the Oracle instance

### Authentication
- **Username**: C##DMSUSER (Oracle common user with Binary Reader privileges)
- **Password**: Retrieved from Secrets Manager
- **SSL Mode**: None (internal VPC communication)

## Table Mapping Strategy

The module implements dual-topic routing for transaction types:

### Financial Transactions
- **Source**: `{ORACLE_USER}.FINANCIAL_TRANSACTIONS` table (schema name is `upper(local.oracle_user)` from SSM)
- **Target**: MSK topic from SSM parameter `topic-dms-oracle-fin`
- **Use Case**: Banking, payments, transfers

### Brokerage Transactions
- **Source**: `{ORACLE_USER}.BROKERAGE_TRANSACTIONS` table
- **Target**: MSK topic from SSM parameter `topic-dms-oracle-brk`
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
        "schema-name": "ORACLE_USER",
        "table-name": "FINANCIAL_TRANSACTIONS"
      },
      "rule-action": "include"
    },
    {
      "rule-type": "object-mapping",
      "rule-id": "3",
      "rule-name": "map-financial-to-topic",
      "object-locator": {
        "schema-name": "ORACLE_USER",
        "table-name": "FINANCIAL_TRANSACTIONS"
      },
      "rule-action": "map-record-to-record",
      "kafka-target-topic": "<dynamic from SSM: topic-dms-oracle-fin>"
    }
  ]
}
```

## Key Features
- LogMiner-based CDC for minimal Oracle performance impact
- Automatic supplemental logging configuration
- KMS encryption for data at rest and in transit
- Multi-AZ deployment support for high availability
- Configurable message format (JSON/JSON-unformatted)
- Oracle PDB (Pluggable Database) support
- Automatic DMS service role creation

## Dependencies
- Foundation layer (VPC, KMS keys, IAM roles)
- Oracle Database with LogMiner enabled and supplemental logging
- MSK cluster with SASL/SCRAM authentication
- Required SSM parameters:
  - `/{APP}/{ENV}/oracle-user`
  - `/{APP}/{ENV}/oracle-host`
  - `/{APP}/{ENV}/oracle-port`
  - `/{APP}/{ENV}/oracle-sid`
  - `/{APP}/{ENV}/oracle-pdb`
  - `/{APP}/{ENV}/oracle-financial-transactions-topic`
  - `/{APP}/{ENV}/oracle-brokerage-transactions-topic`
- Secrets Manager secret: `{APP}-{ENV}-oracle-cdc-password`

## Oracle Prerequisites
- Oracle Database 12c or higher with PDB architecture
- LogMiner enabled and configured
- C##DMSUSER common user with Binary Reader privileges (connects to CDB root)
- Supplemental logging enabled on source tables
- Archive log mode enabled for CDC

## Monitoring and Troubleshooting
- CloudWatch logs integration for DMS task monitoring
- LogMiner session monitoring through Oracle views
- Binary file access validation for LogMiner
- Task status monitoring through AWS console and CLI
