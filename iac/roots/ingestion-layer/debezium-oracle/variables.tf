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
  description = "Name of the financial transactions table in Oracle"
  type        = string
  default     = "FINANCIAL_TRANSACTIONS"
}

variable "BROKERAGE_TRANSACTIONS_TABLE_NAME" {
  description = "Name of the brokerage transactions table in Oracle"
  type        = string
  default     = "BROKERAGE_TRANSACTIONS"
}

variable "ORACLE_FINANCIAL_TOPIC_NAME_PARAMETER" {
  description = "SSM parameter suffix for Oracle financial transactions topic name"
  type        = string
}

variable "ORACLE_BROKERAGE_TOPIC_NAME_PARAMETER" {
  description = "SSM parameter suffix for Oracle brokerage transactions topic name"
  type        = string
}

variable "DEBEZIUM_ORACLE_PLUGIN_S3_KEY" {
  description = "S3 object key for the Debezium Oracle plugin ZIP file"
  type        = string
  default     = "debezium-oracle-plugin.zip"
}

variable "KAFKACONNECT_VERSION" {
  description = "Kafka Connect version"
  type        = string
  default     = "2.7.1"
}

variable "USE_PROVISIONED_CAPACITY" {
  description = "Use provisioned (fixed) capacity instead of autoscaling. Required for Debezium Oracle which only supports 1 task."
  type        = bool
  default     = true
}

variable "WORKER_COUNT" {
  description = "Number of workers when using provisioned capacity"
  type        = number
  default     = 1
}

variable "MCU_COUNT" {
  description = "Number of MCUs per worker (1 MCU = 1 vCPU + 4GB)"
  type        = number
  default     = 1
}
