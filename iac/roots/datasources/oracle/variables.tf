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

variable "SSM_KMS_KEY_ALIAS" {
  description = "KMS key alias for SSM parameter encryption"
  type        = string
}

variable "EBS_KMS_KEY_ALIAS" {
  description = "KMS key alias for EBS volume encryption"
  type        = string
}

variable "SECRETS_MANAGER_KMS_KEY_ALIAS" {
  description = "KMS key alias for Secrets Manager encryption"
  type        = string
}

variable "ORACLE_INSTANCE_TYPE" {
  description = "EC2 instance type for Oracle database"
  type        = string
  default     = "r5.2xlarge"
}

variable "ORACLE_VOLUME_SIZE" {
  description = "Size of the EBS volume for Oracle database in GB"
  type        = number
  default     = 100
}

variable "ORACLE_VERSION" {
  description = "Oracle database version"
  type        = string
  default     = "21c"
}

variable "ORACLE_PORT" {
  description = "Oracle database port"
  type        = number
  default     = 1521
}

variable "ORACLE_SID" {
  description = "Oracle System Identifier"
  type        = string
  default     = "XE"
}

variable "ORACLE_PDB" {
  description = "Oracle Pluggable Database name"
  type        = string
  default     = "XEPDB1"
}

variable "ORACLE_USER" {
  description = "Oracle user name for application data access"
  type        = string
  default     = "ORACLE_USER"
}

variable "ORACLE_CDC_PASSWORD" {
  description = "Oracle CDC users password (C##DBZUSER, C##DMSUSER)"
  type        = string
  sensitive   = true
  default     = null # Should be provided via secure means, not in tfvars
}

variable "ORACLE_USER_PASSWORD" {
  description = "Oracle database trading user password"
  type        = string
  sensitive   = true
  default     = null # Should be provided via secure means, not in tfvars
}

variable "S3_BUCKET" {
  description = "S3 bucket name for storing Oracle scripts and data files"
  type        = string
  default     = null
}
