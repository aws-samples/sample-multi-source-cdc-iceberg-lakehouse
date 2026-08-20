# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

terraform {
  required_version = ">= 1.8.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
}

# AWS Provider for primary region
provider "aws" {
  region = var.AWS_PRIMARY_REGION
  alias  = "primary"

  default_tags {
    tags = {
      Application = var.APP
      Environment = var.ENV
      Module      = "dms-oracle"
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
