# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

data "aws_iam_role" "cockroachdb_role" {
  name = "${var.APP}-${var.ENV}-cockroachdb-role"
}

data "aws_msk_cluster" "ingest_cluster" {
  cluster_name = local.MSK_CLUSTER_NAME
}

data "aws_s3_bucket" "iceberg_datalake_bucket" {
  bucket = "${var.APP}-${var.ENV}-iceberg-datalake-primary"
}

data "aws_kms_key" "s3_primary_key" {
  key_id = "alias/${var.APP}-${var.ENV}-s3-secret-key"
}

data "aws_ssm_parameter" "msk_ingest_cockroach_financial_transactions_topic_name" {
  name = "/${var.APP}/${var.ENV}/${var.COCKROACH_FINANCIAL_TOPIC_NAME_PARAMETER}"
}

data "aws_ssm_parameter" "cockroach_database_name" {
  name = "/${var.APP}/${var.ENV}/${var.COCKROACH_DATABASE_NAME_PARAMETER}"
}

data "aws_ssm_parameter" "s3_table_bucket_arn" {
  name = "/${var.APP}/${var.ENV}/s3-table-bucket-arn"
}

data "aws_ssm_parameter" "s3_table_bucket_name" {
  name = "/${var.APP}/${var.ENV}/s3-table-bucket-name"
}

locals {
  S3_KMS_ARN              = data.aws_kms_key.s3_primary_key.arn
  MSK_CLUSTER_ARN         = data.aws_msk_cluster.ingest_cluster.arn
  MSK_CLUSTER_NAME        = "${var.APP}-${var.ENV}-msk-ingest-cluster"
  COCKROACH_DATABASE_NAME = data.aws_ssm_parameter.cockroach_database_name.value
  COCKROACHDB_ROLE_ARN    = data.aws_iam_role.cockroachdb_role.arn
  TOPIC_NAME              = data.aws_ssm_parameter.msk_ingest_cockroach_financial_transactions_topic_name.value
  S3_TABLES_BUCKET_ARN    = data.aws_ssm_parameter.s3_table_bucket_arn.value
  S3_TABLES_CATALOG_ARN   = "arn:aws:glue:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:catalog/s3tablescatalog/${data.aws_ssm_parameter.s3_table_bucket_name.value}"
}

