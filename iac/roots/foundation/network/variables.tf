# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

variable "APP" {
  description = "Application name"
  type        = string
}

variable "ENV" {
  description = "Environment name (e.g., dev, test, prod)"
  type        = string
}

variable "AWS_PRIMARY_REGION" {
  description = "Primary AWS region for resource deployment"
  type        = string
}

variable "S3_KMS_KEY_ALIAS" {

  description = "KMS key alias for S3 bucket encryption"
  type        = string
}

variable "SSM_KMS_KEY_ALIAS" {

  description = "KMS key alias for SSM parameter encryption"
  type        = string
}

