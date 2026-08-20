# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

terraform {
  required_version = ">= 1.8.0"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_kms_key" "ssm_kms_key" {

  provider = aws.primary
  key_id   = "alias/${var.SSM_KMS_KEY_ALIAS}"
}

data "aws_kms_key" "cloudwatch_kms_key" {
  provider = aws.primary
  key_id   = "alias/${var.APP}-${var.ENV}-cloudwatch-secret-key"
}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.region
}

# Get all AZs in the current region
data "aws_availability_zones" "available" {

  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}
