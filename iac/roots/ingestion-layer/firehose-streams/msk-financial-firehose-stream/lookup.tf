# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_s3_bucket" "iceberg_datalake_bucket" {
  bucket = "${var.APP}-${var.ENV}-iceberg-datalake-primary"
}

# KMS key for S3 encryption
data "aws_kms_key" "s3_primary_key" {
  key_id = "alias/${var.APP}-${var.ENV}-s3-secret-key"
}

# MSK cluster information
data "aws_msk_cluster" "msk_cluster" {
  cluster_name = "${var.APP}-${var.ENV}-msk-source-cluster"
}

data "aws_ssm_parameter" "msk_source_financial_transactions_topic_name" {
  name = "/${var.APP}/${var.ENV}/${var.MSK_FINANCIAL_TOPIC_NAME_PARAMETER}"
}

data "aws_ssm_parameter" "msk_database_name" {
  name = "/${var.APP}/${var.ENV}/${var.MSK_DATABASE_NAME_PARAMETER}"
}

data "aws_ssm_parameter" "s3_table_bucket_arn" {
  name = "/${var.APP}/${var.ENV}/s3-table-bucket-arn"
}

data "aws_ssm_parameter" "s3_table_bucket_name" {
  name = "/${var.APP}/${var.ENV}/s3-table-bucket-name"
}

locals {
  S3_KMS_ARN            = data.aws_kms_key.s3_primary_key.arn
  MSK_CLUSTER_ARN       = data.aws_msk_cluster.msk_cluster.arn
  MSK_CLUSTER_NAME      = data.aws_msk_cluster.msk_cluster.cluster_name
  MSK_DATABASE_NAME     = data.aws_ssm_parameter.msk_database_name.value
  TOPIC_NAME            = data.aws_ssm_parameter.msk_source_financial_transactions_topic_name.value
  S3_TABLES_BUCKET_ARN  = data.aws_ssm_parameter.s3_table_bucket_arn.value
  S3_TABLES_CATALOG_ARN = "arn:aws:glue:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:catalog/s3tablescatalog/${data.aws_ssm_parameter.s3_table_bucket_name.value}"
}
