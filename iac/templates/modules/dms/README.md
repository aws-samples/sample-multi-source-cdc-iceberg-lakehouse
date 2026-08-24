# DMS Replication Module

This Terraform module creates AWS Database Migration Service (DMS) resources for replicating data from various source databases to Amazon MSK (Managed Streaming for Apache Kafka) with comprehensive security, monitoring, and authentication features.

## Features

- **Multi-Source Support**: Supports Oracle and Aurora PostgreSQL source databases
- **MSK Integration**: Direct replication to Amazon MSK with SASL/SCRAM authentication
- **Change Data Capture**: Optimized for real-time CDC with configurable migration types
- **Security**: KMS encryption for data at rest and in transit with VPC isolation
- **Flexible Configuration**: Configurable instance classes, storage, and replication settings
- **Automatic Role Management**: Creates required DMS service roles with proper permissions
- **Monitoring Integration**: CloudWatch logs and metrics for comprehensive monitoring

## Architecture

```
┌─────────────────────┐    ┌─────────────────────┐    ┌─────────────────────┐
│   Source Database   │    │  DMS Replication    │    │   Amazon MSK        │
│                     │    │     Instance        │    │                     │
│ • Oracle DB         │───►│                     │───►│ • SASL/SCRAM Auth   │
│ • Aurora PostgreSQL │    │ • CDC Processing    │    │ • Topic Routing     │
│ • SSL/LogMiner      │    │ • KMS Encryption    │    │ • JSON Messages     │
│ • Heartbeat Mon.    │    │ • Multi-AZ Support  │    │                     │
└─────────────────────┘    └─────────────────────┘    └─────────────────────┘
```

## Usage

### Oracle to MSK Replication

```hcl
module "oracle_dms" {
  source = "../../templates/modules/dms"

  APP = "myapp"
  ENV = "prod"

  dms_kms_key_alias              = "dms-encryption-key"
  dms_replication_instance_class = "dms.r5.large"
  dms_allocated_storage          = 200

  source_engine = "oracle"

  source_endpoint_config = {
    server_name                 = "oracle.example.com"
    port                        = 1521
    database_name               = "XEPDB1"
    username                    = "SYSTEM"
    password                    = var.oracle_password
    ssl_mode                    = "none"
    extra_connection_attributes = "useLogminerReader=N;useBfile=Y;addSupplementalLogging=Y"
  }

  msk_message_format = "json"

  table_mappings = jsonencode({
    rules = [
      {
        rule-type = "selection"
        rule-id   = "1"
        rule-name = "include-trading-tables"
        object-locator = {
          schema-name = "TRADING"
          table-name  = "%"
        }
        rule-action = "include"
      }
    ]
  })

  migration_type              = "cdc"
  start_replication_task      = false
  replication_instance_suffix = "oracle"
}
```

### Aurora PostgreSQL to MSK Replication

```hcl
module "aurora_dms" {
  source = "../../templates/modules/dms"

  APP = "myapp"
  ENV = "prod"

  dms_kms_key_alias              = "dms-encryption-key"
  dms_replication_instance_class = "dms.r5.large"

  source_engine = "aurora-postgresql"

  source_endpoint_config = {
    server_name                 = "aurora-cluster.cluster-xyz.us-east-1.rds.amazonaws.com"
    port                        = 5432
    database_name               = "equitydb"
    username                    = "postgres"
    password                    = var.aurora_password
    ssl_mode                    = "require"
    extra_connection_attributes = "heartbeatEnable=true;heartbeatFrequency=30;heartbeatSchema=public"
  }

  table_mappings = jsonencode({
    rules = [
      {
        rule-type = "selection"
        rule-id   = "1"
        rule-name = "include-transactions"
        object-locator = {
          schema-name = "public"
          table-name  = "equity_trades"
        }
        rule-action = "include"
      }
    ]
  })

  migration_type              = "cdc"
  replication_instance_suffix = "aurora"
}
```

## Inputs

| Name                           | Description                                    | Type     | Default          | Required |
| ------------------------------ | ---------------------------------------------- | -------- | ---------------- | :------: |
| APP                            | Application name                               | `string` | n/a              |   yes    |
| ENV                            | Environment name                               | `string` | n/a              |   yes    |
| dms_kms_key_alias              | KMS key alias for DMS encryption               | `string` | n/a              |   yes    |
| source_engine                  | Source database engine                         | `string` | n/a              |   yes    |
| source_endpoint_config         | Source endpoint configuration object           | `object` | n/a              |   yes    |
| table_mappings                 | DMS table mappings JSON                        | `string` | n/a              |   yes    |
| replication_instance_suffix    | Suffix for replication instance naming         | `string` | n/a              |   yes    |
| dms_replication_instance_class | DMS replication instance class                 | `string` | `"dms.t3.micro"` |    no    |
| dms_allocated_storage          | Allocated storage in GB                        | `number` | `50`             |    no    |
| dms_engine_version             | DMS engine version                             | `string` | `"3.5.3"`        |    no    |
| dms_multi_az                   | Enable Multi-AZ deployment                     | `bool`   | `false`          |    no    |
| dms_publicly_accessible        | Make instance publicly accessible              | `bool`   | `false`          |    no    |
| dms_auto_minor_version_upgrade | Enable automatic minor version upgrades       | `bool`   | `true`           |    no    |
| dms_apply_immediately          | Apply changes immediately                      | `bool`   | `false`          |    no    |
| msk_message_format             | Message format for MSK target                 | `string` | `"json"`         |    no    |
| migration_type                 | Migration type                                 | `string` | `"cdc"`          |    no    |
| start_replication_task         | Start replication task after creation         | `bool`   | `false`          |    no    |
| replication_task_settings      | DMS replication task settings JSON             | `string` | `null`           |    no    |

## Outputs

| Name                     | Description                         |
| ------------------------ | ----------------------------------- |
| replication_instance_arn | ARN of the DMS replication instance |
| replication_instance_id  | ID of the DMS replication instance  |
| source_endpoint_arn      | ARN of the source endpoint          |
| source_endpoint_id       | ID of the source endpoint           |
| msk_target_endpoint_arn  | ARN of the MSK target endpoint      |
| msk_target_endpoint_id   | ID of the MSK target endpoint       |
| replication_task_arn     | ARN of the DMS replication task     |
| replication_task_id      | ID of the DMS replication task      |

## Source Endpoint Configuration

### Oracle Configuration

```hcl
source_endpoint_config = {
  server_name                 = "oracle.example.com"
  port                        = 1521
  database_name               = "XEPDB1"  # PDB name
  username                    = "SYSTEM"
  password                    = var.oracle_password
  ssl_mode                    = "none"
  extra_connection_attributes = "useLogminerReader=N;useBfile=Y;addSupplementalLogging=Y"
}
```

**Oracle-specific attributes:**
- `useLogminerReader=N`: Disable LogMiner and use Binary Reader instead
- `useBfile=Y`: Enable binary file access
- `addSupplementalLogging=Y`: Add supplemental logging automatically

### Aurora PostgreSQL Configuration

```hcl
source_endpoint_config = {
  server_name                 = "aurora-cluster.cluster-xyz.us-east-1.rds.amazonaws.com"
  port                        = 5432
  database_name               = "equitydb"
  username                    = "postgres"
  password                    = var.aurora_password
  ssl_mode                    = "require"
  extra_connection_attributes = "heartbeatEnable=true;heartbeatFrequency=30;heartbeatSchema=public"
}
```

**Aurora-specific attributes:**
- `heartbeatEnable=true`: Enable CDC heartbeat monitoring
- `heartbeatFrequency=30`: Heartbeat every 30 seconds
- `heartbeatSchema=public`: Schema for heartbeat table

## MSK Target Configuration

The module automatically configures MSK target endpoint with:

- **Authentication**: SASL/SCRAM using credentials from Secrets Manager
- **Message Format**: Configurable JSON or JSON-unformatted
- **Topic Routing**: Based on table mappings and object-mapping rules
- **Security**: KMS encryption and VPC isolation

### MSK Credentials

Credentials are automatically retrieved from:
- **Secret Name**: `AmazonMSK_{APP}-{ENV}-msk-ingest-cluster-credentials`
- **Bootstrap Servers**: From SSM parameter `/{APP}/{ENV}/msk-ingest-cluster-bootstrap-servers-sasl-scram`

## Table Mappings

### Selection Rules

Include specific tables:

```json
{
  "rules": [
    {
      "rule-type": "selection",
      "rule-id": "1",
      "rule-name": "include-specific-table",
      "object-locator": {
        "schema-name": "public",
        "table-name": "transactions"
      },
      "rule-action": "include"
    }
  ]
}
```

### Object Mapping Rules

Route tables to specific Kafka topics:

```json
{
  "rules": [
    {
      "rule-type": "object-mapping",
      "rule-id": "2",
      "rule-name": "map-to-topic",
      "object-locator": {
        "schema-name": "public",
        "table-name": "transactions"
      },
      "rule-action": "map-record-to-record",
      "kafka-target-topic": "financial.transactions"
    }
  ]
}
```

## Migration Types

| Type              | Description                                    | Use Case                    |
| ----------------- | ---------------------------------------------- | --------------------------- |
| `full-load`       | One-time full table copy                       | Initial data migration      |
| `cdc`             | Change data capture only                       | Real-time streaming         |
| `full-load-and-cdc` | Full load followed by CDC                    | Complete migration solution |

## Implementation Details

### Automatic Role Creation

The module creates required DMS service roles:

- `dms-vpc-role`: VPC access for DMS
- `dms-cloudwatch-logs-role`: CloudWatch logs access
- `dms-access-for-endpoint`: Endpoint access permissions

### Subnet Group Configuration

Automatically creates DMS subnet group using private subnets from VPC configuration.

### Security Configuration

- **KMS Encryption**: Uses customer-managed KMS key for encryption at rest
- **VPC Isolation**: Deploys in private subnets with security group restrictions
- **SSL/TLS**: Configurable SSL modes for source connections

### Monitoring Integration

- **CloudWatch Logs**: Automatic log group creation for task monitoring
- **Metrics**: Built-in CloudWatch metrics for replication monitoring
- **Heartbeat**: Configurable heartbeat monitoring for CDC health

## Troubleshooting

### Common Issues

1. **Connection Failures**
   - Verify security group rules allow DMS access
   - Check SSL configuration and certificates
   - Validate credentials in Secrets Manager

2. **CDC Issues**
   - Ensure supplemental logging is enabled (Oracle)
   - Verify heartbeat configuration (Aurora)
   - Check LogMiner configuration (Oracle)

3. **MSK Authentication**
   - Verify SASL/SCRAM credentials in Secrets Manager
   - Check MSK cluster authentication configuration
   - Validate bootstrap server endpoints

### Debugging Steps

1. **Check DMS Task Status**
   ```bash
   aws dms describe-replication-tasks --filters Name=replication-task-id,Values=<task-id>
   ```

2. **View CloudWatch Logs**
   ```bash
   aws logs describe-log-streams --log-group-name dms-tasks-<instance-id>
   ```

3. **Test Source Connection**
   ```bash
   aws dms test-connection --replication-instance-arn <instance-arn> --endpoint-arn <endpoint-arn>
   ```

## Dependencies

This module requires:

- **Terraform**: >= 1.8.0
- **AWS Provider**: >= 5.0
- **Foundation Layer**: VPC, subnets, KMS keys, security groups
- **Source Database**: Oracle or Aurora PostgreSQL with CDC enabled
- **MSK Cluster**: With SASL/SCRAM authentication configured
- **IAM Permissions**:
  - DMS service management
  - KMS encrypt/decrypt
  - VPC and subnet access
  - Secrets Manager read access
  - SSM Parameter Store read access

## Related Modules

- `../../roots/datasources/oracle`: Oracle database source
- `../../roots/datasources/aurora`: Aurora PostgreSQL source  
- `../../roots/ingestion-layer/msk-ingest`: MSK cluster target
- `../../foundation/kms-keys`: Provides required KMS keys
- `../../foundation/network`: Provides VPC and subnets
