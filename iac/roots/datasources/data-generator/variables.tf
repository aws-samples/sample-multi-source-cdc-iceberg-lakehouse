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
  type = string
}

variable "ENABLE_ORACLE_INTEGRATION" {
  type        = bool
  description = "Enable Oracle database integration for data generation"
  default     = false
}

variable "ENABLE_MSK_INTEGRATION" {
  type        = bool
  description = "Enable MSK (Kafka) integration for data generation"
  default     = false
}

variable "ENABLE_AURORA_INTEGRATION" {
  type        = bool
  description = "Enable Aurora (PostgreSQL) integration for data generation"
  default     = false
}

variable "ENABLE_COCKROACH_INTEGRATION" {
  type        = bool
  description = "Enable CockroachDB integration for data generation"
  default     = false
}

variable "ORACLE_FINANCIAL_TRANSACTIONS_TABLE_NAME" {
  type        = string
  description = "The name of the Oracle financial transactions table"
  default     = "financial_transactions"
}

variable "ORACLE_BROKERAGE_TRANSACTIONS_TABLE_NAME" {
  type        = string
  description = "The name of the Oracle brokerage transactions table"
  default     = "brokerage_transactions"
}

variable "AURORA_FINANCIAL_TRANSACTIONS_TABLE_NAME" {
  type        = string
  description = "The name of the Aurora financial transactions table"
  default     = "financial_transactions"
}

variable "AURORA_BROKERAGE_TRANSACTIONS_TABLE_NAME" {
  type        = string
  description = "The name of the Aurora brokerage transactions table"
  default     = "brokerage_transactions"
}

variable "COCKROACH_FINANCIAL_TRANSACTIONS_TABLE_NAME" {
  type        = string
  description = "The name of the CockroachDB financial transactions table"
  default     = "financial_transactions"
}

variable "COCKROACH_BROKERAGE_TRANSACTIONS_TABLE_NAME" {
  type        = string
  description = "The name of the CockroachDB brokerage transactions table"
  default     = "brokerage_transactions"
}

variable "MSK_FINANCIAL_TRANSACTIONS_TOPIC_NAME_PARAMETER" {
  type        = string
  description = "The name of the MSK financial transactions topic parameter"
}

variable "MSK_BROKERAGE_TRANSACTIONS_TOPIC_NAME_PARAMETER" {
  type        = string
  description = "The name of the MSK brokerage transactions topic parameter"
}
