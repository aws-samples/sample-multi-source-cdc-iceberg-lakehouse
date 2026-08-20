# Debezium Oracle (MSK Connect)

Deploys a Debezium Oracle CDC source connector on Amazon MSK Connect. This connector captures change events from Oracle Database via LogMiner and publishes them to MSK Ingest topics using IAM authentication.

## Architecture

```
Oracle DB → MSK Connect (Debezium Oracle) → MSK Ingest (IAM auth) → Apache Flink
```

## Resources Created

- MSK Connect connector (Debezium Oracle source)
- CloudWatch log group for connector logs
- References the shared MSK Connect plugin uploaded during `deploy-path2`

## Prerequisites

- Foundation layer deployed (VPC, KMS, IAM roles)
- Oracle data source deployed and running
- MSK Ingest cluster deployed
- MSK Connect Debezium Oracle plugin uploaded to S3

## Deployment

```bash
make deploy-debezium-oracle
```

## Inputs

See `variables.tf` for the full list of configurable parameters.

## Outputs

See `outputs.tf` for exported values (connector ARN, log group).
