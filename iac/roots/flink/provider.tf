# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.13"
    }
  }
}

provider "aws" {
  region = var.REGION
  default_tags {
    tags = {
      Application = var.APP
      Environment = var.ENV
    }
  }
}

# Provider alias without default_tags — used for Kinesis Analytics V2
# applications, which have a known AWS bug where tag registrations linger
# after failed creates, causing ConcurrentModificationException.
provider "aws" {
  alias  = "no_default_tags"
  region = var.REGION
}
