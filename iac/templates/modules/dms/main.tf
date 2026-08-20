# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

terraform {
  required_version = ">= 1.8.0"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id  = data.aws_caller_identity.current.account_id
  region      = data.aws_region.current.region
  name_prefix = "${var.APP}-${var.ENV}"
  tags = {
    Application = var.APP
    Environment = var.ENV
  }
}

# Get VPC and subnet information from SSM Parameter Store
data "aws_ssm_parameter" "vpc_id" {
  name = "/${var.APP}/${var.ENV}/vpc-id"
}

data "aws_ssm_parameter" "private_subnet_ids" {
  name = "/${var.APP}/${var.ENV}/vpc-private-subnet-ids"
}

data "aws_ssm_parameter" "vpc_sg" {
  name = "/${var.APP}/${var.ENV}/vpc-sg"
}

# Get KMS keys for encryption
data "aws_kms_key" "dms_kms_key" {
  key_id = "alias/${var.dms_kms_key_alias}"
}

# MSK - Get bootstrap servers from SSM Parameter Store (created by MSK module)
data "aws_ssm_parameter" "msk_bootstrap_servers_sasl_scram" {
  name = "/${var.APP}/${var.ENV}/msk-ingest-cluster-bootstrap-servers-sasl-scram"
}

# MSK - Get SASL/SCRAM credentials from Secrets Manager (created by MSK module)
data "aws_secretsmanager_secret" "msk_credentials" {
  name = "AmazonMSK_${var.APP}-${var.ENV}-msk-ingest-cluster-credentials"
}

data "aws_secretsmanager_secret_version" "msk_credentials" {
  secret_id = data.aws_secretsmanager_secret.msk_credentials.id
}

locals {
  # Parse MSK credentials from JSON
  msk_credentials        = jsondecode(data.aws_secretsmanager_secret_version.msk_credentials.secret_string)
  sasl_scram_broker_list = data.aws_ssm_parameter.msk_bootstrap_servers_sasl_scram.value
}
