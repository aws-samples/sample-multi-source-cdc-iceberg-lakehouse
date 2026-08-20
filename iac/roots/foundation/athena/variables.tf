# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

variable "APP" {
  type        = string
  description = "The App Name prefix"
}

variable "ENV" {
  type        = string
  description = "The name for Environment."
}

variable "AWS_PRIMARY_REGION" {
  type        = string
  description = "The primary AWS region for deployment"
}

variable "WORKGROUP_NAME" {
  type        = string
  description = "Name of the Athena workgroup"
  default     = "primary"
}

variable "ATHENA_OUTPUT_BUCKET" {
  type        = string
  description = "S3 bucket URI for Athena query results"
}

variable "ATHENA_KMS_KEY_ALIAS" {
  type        = string
  description = "Alias of the KMS key for Athena encryption"
}
