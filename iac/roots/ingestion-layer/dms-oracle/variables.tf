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

variable "DMS_KMS_KEY_ALIAS" {
  description = "KMS key alias for DMS encryption"
  type        = string
}

variable "DMS_REPLICATION_INSTANCE_CLASS" {
  description = "DMS replication instance class"
  type        = string
  default     = "dms.t3.micro"
}

variable "DMS_ALLOCATED_STORAGE" {
  description = "Allocated storage for DMS replication instance in GB"
  type        = number
  default     = 50
}

variable "DMS_ENGINE_VERSION" {
  description = "DMS engine version"
  type        = string
}

variable "DMS_MULTI_AZ" {
  description = "Enable Multi-AZ deployment for DMS replication instance"
  type        = bool
  default     = false
}

variable "DMS_PUBLICLY_ACCESSIBLE" {
  description = "Make DMS replication instance publicly accessible"
  type        = bool
  default     = false
}

variable "DMS_AUTO_MINOR_VERSION_UPGRADE" {
  description = "Enable automatic minor version upgrades"
  type        = bool
  default     = true
}

variable "DMS_APPLY_IMMEDIATELY" {
  description = "Apply changes immediately"
  type        = bool
  default     = false
}

variable "FINANCIAL_TRANSACTIONS_TABLE_NAME" {
  description = "Name of the financial transactions table"
  type        = string
  default     = "financial_transactions"
}

variable "BROKERAGE_TRANSACTIONS_TABLE_NAME" {
  description = "Name of the brokerage transactions table"
  type        = string
  default     = "brokerage_transactions"
}

variable "ORACLE_FINANCIAL_TOPIC_NAME_PARAMETER" {
  description = "Name of the Oracle financial topic parameter"
  type        = string
}

variable "ORACLE_BROKERAGE_TOPIC_NAME_PARAMETER" {
  description = "Name of the Oracle brokerage topic parameter"
  type        = string
}

variable "ORACLE_MSK_MIGRATION_TYPE" {
  description = "Oracle to MSK migration type (full-load, cdc, full-load-and-cdc)"
  type        = string
  default     = "cdc"

  validation {
    condition     = contains(["full-load", "cdc", "full-load-and-cdc"], var.ORACLE_MSK_MIGRATION_TYPE)
    error_message = "Migration type must be one of: full-load, cdc, full-load-and-cdc."
  }
}

variable "MSK_MESSAGE_FORMAT" {
  description = "Message format for MSK target (json-unformatted, json)"
  type        = string
  default     = "json"

  validation {
    condition     = contains(["json-unformatted", "json"], var.MSK_MESSAGE_FORMAT)
    error_message = "MSK message format must be either 'json-unformatted' or 'json'."
  }
}

variable "START_ORACLE_REPLICATION_TASK" {
  description = "Start Oracle replication task after creation"
  type        = bool
  default     = false
}

variable "DMS_MSK_REPLICATION_TASK_SETTINGS" {
  description = "DMS replication task settings JSON for MSK targets (ValidationSettings not supported)"
  type        = string
  default     = null
}
