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

variable "REGION" {
  type        = string
  description = "The AWS region"
}

variable "FIREHOSE_STREAM_NAME" {
  type        = string
  description = "Firehose stream name for ingestion"
}

variable "COCKROACH_BROKERAGE_TOPIC_NAME_PARAMETER" {
  type        = string
  description = "MSK topic name for cockroach financial data parameter"
}

variable "BUFFERING_SIZE" {
  description = "Firehose buffering size in MB"
  type        = number
  default     = 5
}

variable "BUFFERING_INTERVAL" {
  description = "Firehose buffering interval in seconds"
  type        = number
  default     = 30
}

variable "LOG_RETENTION_DAYS" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

variable "COCKROACH_DATABASE_NAME_PARAMETER" {
  description = "SSM parameter name for cockroach database name"
  type        = string
}

variable "COCKROACH_BROKERAGE_TABLE_NAME" {
  description = "Cockroach financial table name for Glue catalog"
  type        = string
}
