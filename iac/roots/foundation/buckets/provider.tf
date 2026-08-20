# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

terraform {
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
      Terraform   = "true"
    }
  }
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
