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

variable "FINANCIAL_TRANSACTIONS_TABLE_NAME" {
  description = "Name of the financial transactions table in Aurora PostgreSQL"
  type        = string
  default     = "financial_transactions"
}

variable "BROKERAGE_TRANSACTIONS_TABLE_NAME" {
  description = "Name of the brokerage transactions table in Aurora PostgreSQL"
  type        = string
  default     = "brokerage_transactions"
}

variable "AURORA_FINANCIAL_TOPIC_NAME_PARAMETER" {
  description = "SSM parameter suffix for Aurora financial transactions topic name"
  type        = string
}

variable "AURORA_BROKERAGE_TOPIC_NAME_PARAMETER" {
  description = "SSM parameter suffix for Aurora brokerage transactions topic name"
  type        = string
}

variable "DEBEZIUM_POSTGRES_PLUGIN_S3_KEY" {
  description = "S3 object key for the Debezium PostgreSQL plugin ZIP file"
  type        = string
  default     = "debezium-postgres-plugin.zip"
}

variable "KAFKACONNECT_VERSION" {
  description = "Kafka Connect version"
  type        = string
  default     = "2.7.1"
}

variable "MIN_WORKERS" {
  description = "Minimum number of workers for autoscaling"
  type        = number
  default     = 1
}

variable "MAX_WORKERS" {
  description = "Maximum number of workers for autoscaling"
  type        = number
  default     = 2
}

variable "MCU_COUNT" {
  description = "Number of MCUs per worker (1 MCU = 1 vCPU + 4GB)"
  type        = number
  default     = 1
}
