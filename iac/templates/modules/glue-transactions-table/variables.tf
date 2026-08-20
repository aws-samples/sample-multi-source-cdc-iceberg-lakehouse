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

variable "DATABASE_NAME" {
  type        = string
  description = "The name for database."
}

variable "S3_BUCKET_NAME" {
  type        = string
  description = "The Apache iceberg S3 Bucket"
}

variable "TABLE_NAME" {
  type        = string
  description = "The name for the transactions table"
}

variable "TABLE_TYPE" {
  type        = string
  description = "Type of table to create: 'financial' or 'brokerage'"
  validation {
    condition     = contains(["financial", "brokerage"], var.TABLE_TYPE)
    error_message = "TABLE_TYPE must be either 'financial' or 'brokerage'."
  }
}

variable "UPPERCASE_COLUMNS" {
  description = "Whether to uppercase column names (for Oracle Debezium which produces UPPERCASE field names)"
  type        = bool
  default     = false
}
