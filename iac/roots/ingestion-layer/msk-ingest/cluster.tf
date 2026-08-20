# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

resource "aws_ssm_parameter" "oracle_financial_transactions_topic_name" {
  name   = "/${var.APP}/${var.ENV}/topic-dms-oracle-fin"
  type   = "SecureString"
  value  = var.ORACLE_FINANCIAL_TRANSACTIONS_TOPIC_NAME
  key_id = data.aws_kms_key.ssm_key.arn
}

resource "aws_ssm_parameter" "aurora_financial_transactions_topic_name" {
  name   = "/${var.APP}/${var.ENV}/topic-dms-aurora-fin"
  type   = "SecureString"
  value  = var.AURORA_FINANCIAL_TRANSACTIONS_TOPIC_NAME
  key_id = data.aws_kms_key.ssm_key.arn
}

resource "aws_ssm_parameter" "cockroach_financial_transactions_topic_name" {
  name   = "/${var.APP}/${var.ENV}/topic-crdb-fin"
  type   = "SecureString"
  value  = var.COCKROACH_FINANCIAL_TRANSACTIONS_TOPIC_NAME
  key_id = data.aws_kms_key.ssm_key.arn
}

resource "aws_ssm_parameter" "oracle_brokerage_transactions_topic_name" {
  name   = "/${var.APP}/${var.ENV}/topic-dms-oracle-brk"
  type   = "SecureString"
  value  = var.ORACLE_BROKERAGE_TRANSACTIONS_TOPIC_NAME
  key_id = data.aws_kms_key.ssm_key.arn
}

resource "aws_ssm_parameter" "aurora_brokerage_transactions_topic_name" {
  name   = "/${var.APP}/${var.ENV}/topic-dms-aurora-brk"
  type   = "SecureString"
  value  = var.AURORA_BROKERAGE_TRANSACTIONS_TOPIC_NAME
  key_id = data.aws_kms_key.ssm_key.arn
}

resource "aws_ssm_parameter" "cockroach_brokerage_transactions_topic_name" {
  name   = "/${var.APP}/${var.ENV}/topic-crdb-brk"
  type   = "SecureString"
  value  = var.COCKROACH_BROKERAGE_TRANSACTIONS_TOPIC_NAME
  key_id = data.aws_kms_key.ssm_key.arn
}

resource "aws_ssm_parameter" "connect_oracle_financial_transactions_topic_name" {
  name   = "/${var.APP}/${var.ENV}/topic-dbz-oracle-fin"
  type   = "SecureString"
  value  = var.CONNECT_ORACLE_FINANCIAL_TRANSACTIONS_TOPIC_NAME
  key_id = data.aws_kms_key.ssm_key.arn
}

resource "aws_ssm_parameter" "connect_oracle_brokerage_transactions_topic_name" {
  name   = "/${var.APP}/${var.ENV}/topic-dbz-oracle-brk"
  type   = "SecureString"
  value  = var.CONNECT_ORACLE_BROKERAGE_TRANSACTIONS_TOPIC_NAME
  key_id = data.aws_kms_key.ssm_key.arn
}

resource "aws_ssm_parameter" "connect_aurora_financial_transactions_topic_name" {
  name   = "/${var.APP}/${var.ENV}/topic-dbz-aurora-fin"
  type   = "SecureString"
  value  = var.CONNECT_AURORA_FINANCIAL_TRANSACTIONS_TOPIC_NAME
  key_id = data.aws_kms_key.ssm_key.arn
}

resource "aws_ssm_parameter" "connect_aurora_brokerage_transactions_topic_name" {
  name   = "/${var.APP}/${var.ENV}/topic-dbz-aurora-brk"
  type   = "SecureString"
  value  = var.CONNECT_AURORA_BROKERAGE_TRANSACTIONS_TOPIC_NAME
  key_id = data.aws_kms_key.ssm_key.arn
}

module "msk_cluster" {

  source             = "../../../templates/modules/msk-provisioned"
  APP                = var.APP
  ENV                = var.ENV
  CLUSTER_NAME       = var.MSK_CLUSTER_NAME
  SUBNET_IDS         = local.PRIVATE_SUBNETS
  SECURITY_GROUP_IDS = [aws_security_group.msk_sg.id]

  ENABLE_SASL_SCRAM_AUTH = var.ENABLE_MSK_SASL_AUTH
  SASL_SCRAM_USERNAME    = var.MSK_SASL_USERNAME

  KAFKA_KMS_KEY_ARN           = data.aws_kms_key.msk_key.arn
  SECRETS_MANAGER_KMS_KEY_ARN = data.aws_kms_key.secrets_manager_key.arn

  KAFKA_VERSION = var.KAFKA_VERSION
  INSTANCE_TYPE = var.KAFKA_INSTANCE_TYPE
  STORAGE_SIZE  = var.KAFKA_STORAGE_SIZE
}

module "cluster_scram_endpoint_secret" {
  source        = "../../../templates/modules/secrets-manager"
  APP           = var.APP
  ENV           = var.ENV
  SECRET_NAME   = "msk-ingest-bootstrap-servers-sasl-scram"       # pragma: allowlist secret
  SECRET_STRING = module.msk_cluster.bootstrap_brokers_sasl_scram # pragma: allowlist secret
}

module "cluster_iam_endpoint_secret" {
  source        = "../../../templates/modules/secrets-manager"
  APP           = var.APP
  ENV           = var.ENV
  SECRET_NAME   = "msk-ingest-bootstrap-servers-sasl-iam"       # pragma: allowlist secret
  SECRET_STRING = module.msk_cluster.bootstrap_brokers_sasl_iam # pragma: allowlist secret
}

resource "aws_msk_cluster_policy" "policy" {
  cluster_arn = module.msk_cluster.cluster_arn
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kafka:CreateVpcConnection",
        ]
        Resource = [
          module.msk_cluster.cluster_arn,
        ]
        Principal = {
          "Service" : "firehose.amazonaws.com"
        }
      }
    ]
    }
  )
}

#
# SSM Parameters for MSK bootstrap servers (for DMS and other services)
#
resource "aws_ssm_parameter" "msk_bootstrap_servers_sasl_scram" {

  count  = var.ENABLE_MSK_SASL_AUTH ? 1 : 0
  name   = "/${var.APP}/${var.ENV}/msk-ingest-cluster-bootstrap-servers-sasl-scram"
  type   = "SecureString"
  value  = module.msk_cluster.bootstrap_brokers_sasl_scram
  key_id = data.aws_kms_key.ssm_key.arn

  tags = {
    Name        = "${var.APP}-${var.ENV}-msk-bootstrap-servers-sasl-scram"
    Application = var.APP
    Environment = var.ENV
  }
}

resource "aws_ssm_parameter" "msk_bootstrap_servers_sasl_iam" {
  name   = "/${var.APP}/${var.ENV}/msk-ingest-cluster-bootstrap-servers-sasl-iam"
  type   = "SecureString"
  value  = module.msk_cluster.bootstrap_brokers_sasl_iam
  key_id = data.aws_kms_key.ssm_key.arn

  tags = {
    Name        = "${var.APP}-${var.ENV}-msk-bootstrap-servers-sasl-iam"
    Application = var.APP
    Environment = var.ENV
  }
}

resource "aws_ssm_parameter" "msk_cluster_arn" {
  name   = "/${var.APP}/${var.ENV}/msk-ingest-cluster-arn"
  type   = "SecureString"
  value  = module.msk_cluster.cluster_arn
  key_id = data.aws_kms_key.ssm_key.arn

  tags = {
    Name        = "${var.APP}-${var.ENV}-msk-cluster-arn"
    Application = var.APP
    Environment = var.ENV
  }
}

