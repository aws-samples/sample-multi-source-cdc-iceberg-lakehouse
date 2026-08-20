# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

data "aws_ssm_parameter" "vpc_id" {
  name = "/${var.APP}/${var.ENV}/vpc-id"
}

data "aws_ssm_parameter" "vpc_sg" {
  name = "/${var.APP}/${var.ENV}/vpc-sg"
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

data "aws_kms_key" "secrets_manager_key" {
  key_id = "alias/${var.APP}-${var.ENV}-secrets-manager-secret-key"
}

data "aws_kms_key" "msk_key" {
  key_id = "alias/${var.APP}-${var.ENV}-msk-secret-key"
}

data "aws_kms_key" "ssm_key" {
  key_id = "alias/${var.APP}-${var.ENV}-systems-manager-secret-key"
}

locals {
  VPC_ID          = data.aws_ssm_parameter.vpc_id.value
  PRIVATE_SUBNETS = split(",", data.aws_ssm_parameter.vpc_private_subnet_ids.value)
  PUBLIC_SUBNETS  = split(",", data.aws_ssm_parameter.vpc_public_subnet_ids.value)
}
