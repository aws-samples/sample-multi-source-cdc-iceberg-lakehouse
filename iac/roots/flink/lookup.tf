# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# -----------------------------------------------------------------------------
# KMS — for SSM SecureString parameters
# -----------------------------------------------------------------------------
data "aws_kms_key" "ssm_kms_key" {
  key_id = "alias/${var.APP}-${var.ENV}-systems-manager-secret-key"
}

# -----------------------------------------------------------------------------
# VPC / Networking
# -----------------------------------------------------------------------------
data "aws_ssm_parameter" "vpc_id" {
  name = "/${var.APP}/${var.ENV}/vpc-id"
}

data "aws_ssm_parameter" "private_subnet_ids" {
  name = "/${var.APP}/${var.ENV}/vpc-private-subnet-ids"
}

# -----------------------------------------------------------------------------
# MSK Ingest bootstrap (IAM auth)
# -----------------------------------------------------------------------------
data "aws_ssm_parameter" "msk_bootstrap_servers_iam" {
  name = "/${var.APP}/${var.ENV}/msk-ingest-cluster-bootstrap-servers-sasl-iam"
}

# MSK Source cluster (used only by the msk_source Flink app)
data "aws_ssm_parameter" "msk_source_bootstrap_servers_iam" {
  name = "/${var.APP}/${var.ENV}/msk-source-cluster-bootstrap-servers-sasl-iam"
}

# -----------------------------------------------------------------------------
# S3 Buckets — assets bucket (JAR location) + Iceberg datalake (warehouse)
# -----------------------------------------------------------------------------
data "aws_ssm_parameter" "assets_bucket_name" {
  name = "/${var.APP}/${var.ENV}/assets-bucket-name"
}

data "aws_ssm_parameter" "iceberg_datalake_bucket_name" {
  name = "/${var.APP}/${var.ENV}/iceberg-datalake-bucket-name"
}

# S3 Tables — managed Iceberg (REST catalog endpoint, SigV4 auth)
data "aws_ssm_parameter" "s3_table_bucket_arn" {
  name = "/${var.APP}/${var.ENV}/s3-table-bucket-arn"
}

# -----------------------------------------------------------------------------
# Glue Catalog databases (Path 2 — `c_` prefix)
# -----------------------------------------------------------------------------
data "aws_ssm_parameter" "db_c_oracle" {
  name = "/${var.APP}/${var.ENV}/db-c-oracle"
}

data "aws_ssm_parameter" "db_c_aurora" {
  name = "/${var.APP}/${var.ENV}/db-c-aurora"
}

data "aws_ssm_parameter" "db_c_crdb" {
  name = "/${var.APP}/${var.ENV}/db-c-crdb"
}

data "aws_ssm_parameter" "db_c_msk_src" {
  name = "/${var.APP}/${var.ENV}/db-c-msk-src"
}

# -----------------------------------------------------------------------------
# MSK Topics — financial + brokerage per source
# -----------------------------------------------------------------------------
data "aws_ssm_parameter" "topic_oracle_fin" {
  name = "/${var.APP}/${var.ENV}/topic-dbz-oracle-fin"
}

data "aws_ssm_parameter" "topic_oracle_brk" {
  name = "/${var.APP}/${var.ENV}/topic-dbz-oracle-brk"
}

data "aws_ssm_parameter" "topic_aurora_fin" {
  name = "/${var.APP}/${var.ENV}/topic-dbz-aurora-fin"
}

data "aws_ssm_parameter" "topic_aurora_brk" {
  name = "/${var.APP}/${var.ENV}/topic-dbz-aurora-brk"
}

data "aws_ssm_parameter" "topic_crdb_fin" {
  name = "/${var.APP}/${var.ENV}/topic-crdb-fin"
}

data "aws_ssm_parameter" "topic_crdb_brk" {
  name = "/${var.APP}/${var.ENV}/topic-crdb-brk"
}

data "aws_ssm_parameter" "topic_msk_src_fin" {
  name = "/${var.APP}/${var.ENV}/topic-msk-src-fin"
}

data "aws_ssm_parameter" "topic_msk_src_brk" {
  name = "/${var.APP}/${var.ENV}/topic-msk-src-brk"
}

# -----------------------------------------------------------------------------
# Locals — consolidate SSM values
# -----------------------------------------------------------------------------
locals {
  account_id  = data.aws_caller_identity.current.account_id
  region      = data.aws_region.current.region
  name_prefix = "${var.APP}-${var.ENV}"

  vpc_id             = data.aws_ssm_parameter.vpc_id.value
  private_subnet_ids = split(",", data.aws_ssm_parameter.private_subnet_ids.value)

  msk_bootstrap_servers        = data.aws_ssm_parameter.msk_bootstrap_servers_iam.value
  msk_source_bootstrap_servers = data.aws_ssm_parameter.msk_source_bootstrap_servers_iam.value

  assets_bucket_name           = data.aws_ssm_parameter.assets_bucket_name.value
  iceberg_datalake_bucket_name = data.aws_ssm_parameter.iceberg_datalake_bucket_name.value
  iceberg_warehouse            = "s3://${data.aws_ssm_parameter.iceberg_datalake_bucket_name.value}/"
  s3_table_bucket_arn          = data.aws_ssm_parameter.s3_table_bucket_arn.value

  # Per-app configuration: topics, target Glue DB, Flink main class, bootstrap servers
  # Note: S3 Tables namespace names match Glue DB names for Path 2 (same `c_*` prefix).
  apps = {
    oracle = {
      db                = data.aws_ssm_parameter.db_c_oracle.value
      s3_tables_db      = data.aws_ssm_parameter.db_c_oracle.value
      topic_financial   = data.aws_ssm_parameter.topic_oracle_fin.value
      topic_brokerage   = data.aws_ssm_parameter.topic_oracle_brk.value
      main_class        = "com.aws.iceberg.flink.job.OracleCdcJob"
      bootstrap_servers = data.aws_ssm_parameter.msk_bootstrap_servers_iam.value
    }
    aurora = {
      db                = data.aws_ssm_parameter.db_c_aurora.value
      s3_tables_db      = data.aws_ssm_parameter.db_c_aurora.value
      topic_financial   = data.aws_ssm_parameter.topic_aurora_fin.value
      topic_brokerage   = data.aws_ssm_parameter.topic_aurora_brk.value
      main_class        = "com.aws.iceberg.flink.job.AuroraCdcJob"
      bootstrap_servers = data.aws_ssm_parameter.msk_bootstrap_servers_iam.value
    }
    cockroach = {
      db                = data.aws_ssm_parameter.db_c_crdb.value
      s3_tables_db      = data.aws_ssm_parameter.db_c_crdb.value
      topic_financial   = data.aws_ssm_parameter.topic_crdb_fin.value
      topic_brokerage   = data.aws_ssm_parameter.topic_crdb_brk.value
      main_class        = "com.aws.iceberg.flink.job.CockroachCdcJob"
      bootstrap_servers = data.aws_ssm_parameter.msk_bootstrap_servers_iam.value
    }
    msk_source = {
      db                = data.aws_ssm_parameter.db_c_msk_src.value
      s3_tables_db      = data.aws_ssm_parameter.db_c_msk_src.value
      topic_financial   = data.aws_ssm_parameter.topic_msk_src_fin.value
      topic_brokerage   = data.aws_ssm_parameter.topic_msk_src_brk.value
      main_class        = "com.aws.iceberg.flink.job.MskAppendJob"
      bootstrap_servers = data.aws_ssm_parameter.msk_source_bootstrap_servers_iam.value
    }
  }
}
