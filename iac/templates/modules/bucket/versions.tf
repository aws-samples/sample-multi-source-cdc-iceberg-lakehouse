# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

terraform {
  required_version = ">= 0.12"
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws.primary]
    }
  }
}
