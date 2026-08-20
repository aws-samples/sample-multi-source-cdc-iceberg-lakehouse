# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

terraform {
  required_version = ">= 1.8.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  alias  = "primary"
  region = var.AWS_PRIMARY_REGION

  default_tags {
    tags = {
      Application = var.APP
      Environment = var.ENV
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.region
}

provider "aws" {

  region = var.AWS_PRIMARY_REGION

  default_tags {
    tags = {
      Application = var.APP
      Environment = var.ENV
    }
  }
}
