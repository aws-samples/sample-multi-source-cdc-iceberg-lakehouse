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


variable "cluster_identifier" {
  description = "Identifier of the cluster"
  type        = string
  default     = ""
}

variable "cluster_engine" {
  description = "Name of the engine"
  type        = string
  default     = ""
}

variable "engine_version" {
  description = "Aurora PostgreSQL engine version"
  type        = string
  default     = "16.4"
}

variable "database_name" {
  description = "Name of the database"
  type        = string
  default     = ""
}

variable "master_username" {
  description = "Username of the master account"
  type        = string
  default     = ""
}

variable "subnet_ids" {
  type        = list(string)
  default     = []
  description = "List of subnet id(s) to which RDS should be attached"
}

variable "security_group_ids" {
  type        = list(string)
  default     = []
  description = "List of security group id(s) to which RDS should be attached"
}

variable "instance_class" {
  type        = string
  default     = ""
  description = "Instance type of rds instance"
}

variable "engine_mode" {
  type        = string
  default     = "provisioned"
  description = "Engine mode of the rds instance"
}

variable "port" {
  type        = string
  default     = "5533"
  description = "Port on which to connect to the DB cluster"
}

# Bastion Host Configuration
variable "enable_bastion_host" {
  type        = bool
  default     = false
  description = "Whether to deploy a bastion host for Aurora access"
}

variable "bastion_instance_type" {
  type        = string
  default     = "t3.micro"
  description = "Instance type for the bastion host"
}

variable "vpc_id" {
  type        = string
  default     = ""
  description = "VPC ID for creating bastion host security group (required only if enable_bastion_host = true)"
}

variable "vpc_cidr_block" {
  type        = string
  default     = ""
  description = "VPC CIDR block for bastion host security group rules (required only if enable_bastion_host = true)"
}

variable "secrets_manager_kms_key" {
  type        = string
  default     = ""
  description = "KMS key for secrets manager (required only if enable_bastion_host = true)"
}

variable "ssm_kms_key" {
  type        = string
  default     = ""
  description = "KMS key for SSM parameters (required only if enable_bastion_host = true)"
}
