# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# VPC and networking
data "aws_ssm_parameter" "vpc_id" {
  name = "/${var.APP}/${var.ENV}/vpc-id"
}

data "aws_ssm_parameter" "private_subnet_ids" {
  name = "/${var.APP}/${var.ENV}/vpc-private-subnet-ids"
}

data "aws_ssm_parameter" "vpc_sg" {
  name = "/${var.APP}/${var.ENV}/vpc-sg"
}

# MSK Ingest cluster — IAM bootstrap endpoint (Path 2 uses IAM auth)
data "aws_ssm_parameter" "msk_bootstrap_servers_iam" {
  name = "/${var.APP}/${var.ENV}/msk-ingest-cluster-bootstrap-servers-sasl-iam"
}

# Aurora connection details (created by Aurora module)
data "aws_ssm_parameter" "aurora_cluster_endpoint" {
  name = "/${var.APP}/${var.ENV}/aurora-cluster-endpoint"
}

data "aws_ssm_parameter" "aurora_cluster_port" {
  name = "/${var.APP}/${var.ENV}/aurora-cluster-port"
}

data "aws_ssm_parameter" "aurora_database_name" {
  name = "/${var.APP}/${var.ENV}/aurora-database-name"
}

# Aurora credentials from Secrets Manager
data "aws_secretsmanager_secret" "aurora_credentials" {
  name = "${var.APP}-${var.ENV}-aurora-db-secret"
}

data "aws_secretsmanager_secret_version" "aurora_credentials" {
  secret_id = data.aws_secretsmanager_secret.aurora_credentials.id
}

# Topic names for table routing
data "aws_ssm_parameter" "aurora_financial_topic" {
  name = "/${var.APP}/${var.ENV}/${var.AURORA_FINANCIAL_TOPIC_NAME_PARAMETER}"
}

data "aws_ssm_parameter" "aurora_brokerage_topic" {
  name = "/${var.APP}/${var.ENV}/${var.AURORA_BROKERAGE_TOPIC_NAME_PARAMETER}"
}

# MSK Connect execution role
data "aws_ssm_parameter" "msk_connect_debezium_role_arn" {
  name = "/${var.APP}/${var.ENV}/msk-connect-debezium-role-arn"
}

# MSK Connect plugins bucket
data "aws_ssm_parameter" "msk_connect_plugins_bucket_arn" {
  name = "/${var.APP}/${var.ENV}/msk-connect-plugins-bucket-arn"
}

locals {
  account_id  = data.aws_caller_identity.current.account_id
  region      = data.aws_region.current.region
  name_prefix = "${var.APP}-${var.ENV}"

  aurora_credentials = jsondecode(data.aws_secretsmanager_secret_version.aurora_credentials.secret_string)
  aurora_endpoint    = data.aws_ssm_parameter.aurora_cluster_endpoint.value
  aurora_port        = data.aws_ssm_parameter.aurora_cluster_port.value
  aurora_database    = data.aws_ssm_parameter.aurora_database_name.value

  msk_bootstrap_servers = data.aws_ssm_parameter.msk_bootstrap_servers_iam.value
  all_private_subnets   = split(",", data.aws_ssm_parameter.private_subnet_ids.value)
  private_subnet_ids    = slice(local.all_private_subnets, 0, min(3, length(local.all_private_subnets))) # MSK Connect requires 2-3 subnets
  vpc_sg                = data.aws_ssm_parameter.vpc_sg.value

  execution_role_arn = data.aws_ssm_parameter.msk_connect_debezium_role_arn.value
  plugins_bucket_arn = data.aws_ssm_parameter.msk_connect_plugins_bucket_arn.value

  financial_topic = data.aws_ssm_parameter.aurora_financial_topic.value
  brokerage_topic = data.aws_ssm_parameter.aurora_brokerage_topic.value
}
