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

variable "dms_kms_key_alias" {
  description = "KMS key alias for DMS encryption"
  type        = string
}

variable "dms_replication_instance_class" {
  description = "DMS replication instance class"
  type        = string
  default     = "dms.t3.micro"
}

variable "dms_allocated_storage" {
  description = "Allocated storage for DMS replication instance in GB"
  type        = number
  default     = 50
}

variable "dms_engine_version" {
  description = "DMS engine version"
  type        = string
  default     = "3.5.3"
}

variable "dms_multi_az" {
  description = "Enable Multi-AZ deployment for DMS replication instance"
  type        = bool
  default     = false
}

variable "dms_publicly_accessible" {
  description = "Make DMS replication instance publicly accessible"
  type        = bool
  default     = false
}

variable "dms_auto_minor_version_upgrade" {
  description = "Enable automatic minor version upgrades"
  type        = bool
  default     = true
}

variable "dms_apply_immediately" {
  description = "Apply changes immediately"
  type        = bool
  default     = false
}

variable "source_engine" {
  description = "Source database engine (oracle, aurora-postgresql)"
  type        = string
  validation {
    condition     = contains(["oracle", "aurora-postgresql"], var.source_engine)
    error_message = "Source engine must be either 'oracle' or 'aurora-postgresql'."
  }
}

variable "source_endpoint_config" {
  description = "Source endpoint configuration"
  type = object({
    server_name                 = string
    port                        = number
    database_name               = string
    username                    = string
    password                    = string
    ssl_mode                    = string
    extra_connection_attributes = string
  })
}

variable "msk_message_format" {
  description = "Message format for MSK target (json-unformatted, json)"
  type        = string
  default     = "json"
  validation {
    condition     = contains(["json-unformatted", "json"], var.msk_message_format)
    error_message = "MSK message format must be either 'json-unformatted' or 'json'."
  }
}

variable "migration_type" {
  description = "Migration type (full-load, cdc, full-load-and-cdc)"
  type        = string
  default     = "cdc"
  validation {
    condition     = contains(["full-load", "cdc", "full-load-and-cdc"], var.migration_type)
    error_message = "Migration type must be one of: full-load, cdc, full-load-and-cdc."
  }
}

variable "table_mappings" {
  description = "DMS table mappings JSON"
  type        = string
}

variable "start_replication_task" {
  description = "Start replication task after creation"
  type        = bool
  default     = false
}

variable "replication_task_settings" {
  description = "DMS replication task settings JSON"
  type        = string
  default     = null
}

variable "replication_instance_suffix" {
  description = "Suffix for replication instance naming"
  type        = string
}
