# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

variable "APP" {
  description = "Application name used for resource naming and tagging"
  type        = string
}

variable "ENV" {
  description = "Environment name (e.g., dev, test, prod) used for resource naming and tagging"
  type        = string
}

variable "REGION" {
  type        = string
  description = "AWS region where the resources will be deployed"
}

variable "FIREHOSE_STREAM_NAME" {
  type        = string
  description = "Firehose stream name for ingestion"
}

variable "MSK_FINANCIAL_TOPIC_NAME_PARAMETER" {
  type        = string
  description = "MSK topic name parameter for financial data"
}

variable "BUFFERING_SIZE" {
  description = "Firehose buffering size in MB"
  type        = number
  default     = 1
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

variable "MSK_DATABASE_NAME_PARAMETER" {
  description = "SSM parameter name for MSK database name"
  type        = string
}

variable "MSK_FINANCIAL_TABLE_NAME" {
  description = "MSK financial table name for Glue catalog"
  type        = string
}
