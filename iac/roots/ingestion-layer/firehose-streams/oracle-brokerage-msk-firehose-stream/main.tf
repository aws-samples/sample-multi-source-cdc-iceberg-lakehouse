# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

terraform {
  required_version = ">= 1.8.0"
}

# Get VPC and networking information
data "aws_ssm_parameter" "vpc_id" {
  name = "/${var.APP}/${var.ENV}/vpc-id"
}

data "aws_ssm_parameter" "private_subnet_ids" {
  name = "/${var.APP}/${var.ENV}/vpc-private-subnet-ids"
}

data "aws_ssm_parameter" "vpc_sg" {
  name = "/${var.APP}/${var.ENV}/vpc-sg"
}

# Get MSK credentials
data "aws_secretsmanager_secret" "msk_credentials" {
  name = "AmazonMSK_${var.APP}-${var.ENV}-msk-ingest-cluster-credentials"
}

data "aws_ssm_parameter" "msk_bootstrap_servers_sasl_scram" {
  name = "/${var.APP}/${var.ENV}/msk-ingest-cluster-bootstrap-servers-sasl-scram"
}
