# Debezium Aurora PostgreSQL (MSK Connect)

Deploys a Debezium PostgreSQL CDC source connector on Amazon MSK Connect. This connector captures change events from Aurora PostgreSQL via pgoutput logical decoding and publishes them to MSK Ingest topics using IAM authentication.

## Architecture

```
Aurora PostgreSQL → MSK Connect (Debezium PostgreSQL) → MSK Ingest (IAM auth) → Apache Flink
```

## Resources Created

- MSK Connect connector (Debezium PostgreSQL source)
- CloudWatch log group for connector logs
- References the shared MSK Connect plugin uploaded during `deploy-path2`

## Prerequisites

- Foundation layer deployed (VPC, KMS, IAM roles)
- Aurora PostgreSQL data source deployed and running
- MSK Ingest cluster deployed
- MSK Connect Debezium PostgreSQL plugin uploaded to S3

## Deployment

```bash
make deploy-debezium-aurora
```

## Inputs

See `variables.tf` for the full list of configurable parameters.

## Outputs

See `outputs.tf` for exported values (connector ARN, log group).
