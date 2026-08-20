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

# Oracle connection details
data "aws_ssm_parameter" "oracle_user" {
  name = "/${var.APP}/${var.ENV}/oracle-user"
}

data "aws_ssm_parameter" "oracle_host" {
  name = "/${var.APP}/${var.ENV}/oracle-host"
}

data "aws_ssm_parameter" "oracle_port" {
  name = "/${var.APP}/${var.ENV}/oracle-port"
}

data "aws_ssm_parameter" "oracle_pdb" {
  name = "/${var.APP}/${var.ENV}/oracle-pdb"
}

data "aws_ssm_parameter" "oracle_sid" {
  name = "/${var.APP}/${var.ENV}/oracle-sid"
}

# Oracle CDC users password from Secrets Manager
data "aws_secretsmanager_secret" "oracle_cdc_password" {
  name = "${var.APP}-${var.ENV}-oracle-cdc-password"
}

data "aws_secretsmanager_secret_version" "oracle_cdc_password" {
  secret_id = data.aws_secretsmanager_secret.oracle_cdc_password.id
}

# Topic names for table routing
data "aws_ssm_parameter" "oracle_financial_topic" {
  name = "/${var.APP}/${var.ENV}/${var.ORACLE_FINANCIAL_TOPIC_NAME_PARAMETER}"
}

data "aws_ssm_parameter" "oracle_brokerage_topic" {
  name = "/${var.APP}/${var.ENV}/${var.ORACLE_BROKERAGE_TOPIC_NAME_PARAMETER}"
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

  oracle_user = data.aws_ssm_parameter.oracle_user.value
  oracle_host = data.aws_ssm_parameter.oracle_host.value
  oracle_port = data.aws_ssm_parameter.oracle_port.value
  oracle_sid  = data.aws_ssm_parameter.oracle_sid.value
  oracle_pdb  = data.aws_ssm_parameter.oracle_pdb.value

  msk_bootstrap_servers = data.aws_ssm_parameter.msk_bootstrap_servers_iam.value
  all_private_subnets   = split(",", data.aws_ssm_parameter.private_subnet_ids.value)
  private_subnet_ids    = slice(local.all_private_subnets, 0, min(3, length(local.all_private_subnets))) # MSK Connect requires 2-3 subnets
  vpc_sg                = data.aws_ssm_parameter.vpc_sg.value

  execution_role_arn = data.aws_ssm_parameter.msk_connect_debezium_role_arn.value
  plugins_bucket_arn = data.aws_ssm_parameter.msk_connect_plugins_bucket_arn.value

  financial_topic = data.aws_ssm_parameter.oracle_financial_topic.value
  brokerage_topic = data.aws_ssm_parameter.oracle_brokerage_topic.value
}
