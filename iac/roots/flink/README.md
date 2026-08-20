# Managed Flink — Path 2 Ingestion

<!--
Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
SPDX-License-Identifier: MIT-0
-->

This Terraform root module deploys **four Amazon Managed Service for Apache Flink** applications that consume CDC / streaming data from the MSK Ingest cluster and write to Apache Iceberg tables in the Glue Data Catalog.

## What it deploys

| App key      | Main class                                      | Source → Topics                                | Target Glue DB              |
| ------------ | ----------------------------------------------- | ---------------------------------------------- | --------------------------- |
| `oracle`     | `com.aws.iceberg.flink.job.DebeziumCdcJob`      | `topic-dbz-oracle-fin` / `topic-dbz-oracle-brk` | `{APP}_{ENV}_c_oracle`      |
| `aurora`     | `com.aws.iceberg.flink.job.DebeziumCdcJob`      | `topic-dbz-aurora-fin` / `topic-dbz-aurora-brk` | `{APP}_{ENV}_c_aurora`      |
| `cockroach`  | `com.aws.iceberg.flink.job.CockroachCdcJob`     | `topic-crdb-fin` / `topic-crdb-brk`             | `{APP}_{ENV}_c_crdb`        |
| `msk_source` | `com.aws.iceberg.flink.job.MskAppendJob`        | `topic-msk-src-fin` / `topic-msk-src-brk`       | `{APP}_{ENV}_c_msk_src`     |

Each app writes to two tables in its database: `fin` (financial) and `brk` (brokerage).

## Resources

- `aws_iam_role.flink_role` — service execution role (Glue, S3, MSK IAM, KMS, Logs, VPC ENI)
- `aws_security_group.flink` — egress-only SG attached to each Flink app
- `aws_cloudwatch_log_group.flink` + 4 × `aws_cloudwatch_log_stream.flink`
- 4 × `aws_kinesisanalyticsv2_application.flink` (iterated via `for_each` over `local.apps`)
- `aws_ssm_parameter.flink_role_arn` → `/${APP}/${ENV}/flink-role-arn`

## Prerequisites (SSM parameters consumed)

- `vpc-id`, `vpc-private-subnet-ids`
- `msk-ingest-cluster-bootstrap-servers-sasl-iam`
- `assets-bucket-name` (must contain the app JAR at `FLINK_APP_JAR_KEY`)
- `iceberg-datalake-bucket-name`
- `db-c-oracle`, `db-c-aurora`, `db-c-crdb`, `db-c-msk-src`
- `topic-dbz-oracle-fin|brk`, `topic-dbz-aurora-fin|brk`, `topic-crdb-fin|brk`, `topic-msk-src-fin|brk`

## JAR upload

The Flink application JAR is **not** uploaded by this module. Build and upload it separately (via Makefile) to:

```
s3://<assets-bucket>/<FLINK_APP_JAR_KEY>
```

Default key: `flink/flink-iceberg-sink-1.0-SNAPSHOT.jar`.

## Key variables

| Name                          | Default                                          |
| ----------------------------- | ------------------------------------------------ |
| `FLINK_RUNTIME`               | `FLINK-2_2`                                      |
| `FLINK_PARALLELISM`           | `4`                                              |
| `FLINK_PARALLELISM_PER_KPU`   | `1`                                              |
| `FLINK_AUTO_SCALING`          | `true`                                           |
| `FLINK_LOG_LEVEL`             | `INFO`                                           |
| `FLINK_CHECKPOINT_INTERVAL_MS`| `60000`                                          |
| `FLINK_APP_JAR_KEY`           | `flink/flink-iceberg-sink-1.0-SNAPSHOT.jar`      |

## Deploy

```bash
terraform init
terraform apply
```
