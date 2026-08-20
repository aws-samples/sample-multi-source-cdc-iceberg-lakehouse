# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

data "aws_ssm_parameter" "vpc_id" {
  name = "/${var.APP}/${var.ENV}/vpc-id"
}

data "aws_ssm_parameter" "vpc_private_subnet_ids" {
  name = "/${var.APP}/${var.ENV}/vpc-private-subnet-ids"
}

data "aws_ssm_parameter" "vpc_public_subnet_ids" {
  name = "/${var.APP}/${var.ENV}/vpc-public-subnet-ids"
}

data "aws_vpc" "vpc" {
  id = data.aws_ssm_parameter.vpc_id.value
}

data "aws_security_group" "msk_sg" {
  count = var.ENABLE_MSK_INTEGRATION ? 1 : 0
  name  = "${var.APP}-${var.ENV}-msk-sg"
}

data "aws_s3_bucket" "asset_bucket" {
  bucket = "${var.APP}-${var.ENV}-assets-primary"
}

data "aws_kms_key" "ssm_kms_key" {
  key_id = "alias/${var.APP}-${var.ENV}-systems-manager-secret-key"
}

data "aws_kms_key" "s3_primary_key" {
  key_id = "alias/${var.APP}-${var.ENV}-s3-secret-key"
}

data "aws_kms_key" "secrets_manager_kms_key" {
  key_id = "alias/${var.APP}-${var.ENV}-secrets-manager-secret-key"
}

# Oracle data source - only when Oracle integration is enabled
data "aws_secretsmanager_secret" "oracle_data_generator_connection" {
  count = var.ENABLE_ORACLE_INTEGRATION ? 1 : 0
  name  = "${var.APP}-${var.ENV}-oracle-db-secret"
}

# Aurora data source - only when Aurora integration is enabled
data "aws_secretsmanager_secret" "aurora_db_secret" {
  count = var.ENABLE_AURORA_INTEGRATION ? 1 : 0
  name  = "${var.APP}-${var.ENV}-aurora-db-secret"
}

data "aws_secretsmanager_secret" "msk_source_cluster_bootstrap_secret" {
  count = var.ENABLE_MSK_INTEGRATION ? 1 : 0
  name  = "${var.APP}-${var.ENV}-msk-source-bootstrap-servers-sasl-iam"
}

data "aws_ssm_parameter" "msk_source_financial_transactions_topic_name" {
  count = var.ENABLE_MSK_INTEGRATION ? 1 : 0
  name  = "/${var.APP}/${var.ENV}/${var.MSK_FINANCIAL_TRANSACTIONS_TOPIC_NAME_PARAMETER}"
}

data "aws_ssm_parameter" "msk_source_brokerage_transactions_topic_name" {
  count = var.ENABLE_MSK_INTEGRATION ? 1 : 0
  name  = "/${var.APP}/${var.ENV}/${var.MSK_BROKERAGE_TRANSACTIONS_TOPIC_NAME_PARAMETER}"
}

data "aws_security_group" "cockroach_sg" {
  count = var.ENABLE_COCKROACH_INTEGRATION ? 1 : 0
  name  = "${var.APP}-${var.ENV}-cockroachdb-sg"
}

data "aws_secretsmanager_secret" "cockroach_db_secret" {
  count = var.ENABLE_COCKROACH_INTEGRATION ? 1 : 0
  name  = "${var.APP}-${var.ENV}-cockroach-db-secret"
}


locals {
  VPC_ID                      = data.aws_ssm_parameter.vpc_id.value
  PRIVATE_SUBNETS             = split(",", data.aws_ssm_parameter.vpc_private_subnet_ids.value)
  PUBLIC_SUBNETS              = split(",", data.aws_ssm_parameter.vpc_public_subnet_ids.value)
  MSK_SG_ID                   = var.ENABLE_MSK_INTEGRATION && length(data.aws_security_group.msk_sg) > 0 ? data.aws_security_group.msk_sg[0].id : ""
  ASSETS_BUCKET               = data.aws_s3_bucket.asset_bucket.id
  S3_KMS_ARN                  = data.aws_kms_key.s3_primary_key.arn
  SECRETS_MANAGER_KMS_KEY_ARN = data.aws_kms_key.secrets_manager_kms_key.arn

  # Oracle connection & topic details
  ORACLE_SECRET_ARN  = var.ENABLE_ORACLE_INTEGRATION ? data.aws_secretsmanager_secret.oracle_data_generator_connection[0].arn : ""
  ORACLE_SECRET_NAME = var.ENABLE_ORACLE_INTEGRATION ? data.aws_secretsmanager_secret.oracle_data_generator_connection[0].name : ""

  # Aurora connection & topic details
  AURORA_SECRET_ARN  = var.ENABLE_AURORA_INTEGRATION ? data.aws_secretsmanager_secret.aurora_db_secret[0].arn : ""
  AURORA_SECRET_NAME = var.ENABLE_AURORA_INTEGRATION ? data.aws_secretsmanager_secret.aurora_db_secret[0].name : ""

  # MSK connection & topic details
  MSK_SECRET_ARN                        = var.ENABLE_MSK_INTEGRATION ? data.aws_secretsmanager_secret.msk_source_cluster_bootstrap_secret[0].arn : ""
  MSK_SECRET_NAME                       = var.ENABLE_MSK_INTEGRATION ? data.aws_secretsmanager_secret.msk_source_cluster_bootstrap_secret[0].name : ""
  MSK_FINANCIAL_TRANSACTIONS_TOPIC_NAME = var.ENABLE_MSK_INTEGRATION ? data.aws_ssm_parameter.msk_source_financial_transactions_topic_name[0].value : ""
  MSK_BROKERAGE_TRANSACTIONS_TOPIC_NAME = var.ENABLE_MSK_INTEGRATION ? data.aws_ssm_parameter.msk_source_brokerage_transactions_topic_name[0].value : ""

  # Cockroach connection & topic details
  COCKROACH_SECRET_NAME = var.ENABLE_COCKROACH_INTEGRATION ? data.aws_secretsmanager_secret.cockroach_db_secret[0].name : ""
}
