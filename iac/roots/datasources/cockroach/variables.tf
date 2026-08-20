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

variable "EBS_KMS_KEY_ALIAS" {
  description = "KMS key alias for EBS volume encryption"
  type        = string
}

variable "INSTANCE_TYPE" {
  description = "EC2 instance type for CockroachDB nodes"
  type        = string
  default     = "m6i.xlarge"
}

variable "MGMT_INSTANCE_TYPE" {
  description = "EC2 instance type for CockroachDB management instance"
  type        = string
  default     = "t3.medium"
}

variable "NODE_COUNT" {
  description = "Number of CockroachDB nodes to deploy"
  type        = number
  default     = 3
}

variable "DATA_VOLUME_SIZE" {
  description = "Size of the data volume in GB"
  type        = number
  default     = 200
}

variable "KEY_NAME" {
  description = "Name of the EC2 key pair for SSH access (optional - SSM Session Manager is recommended)"
  type        = string
  default     = ""
}

variable "SSH_CIDR_BLOCK" {
  description = "CIDR block for SSH access"
  type        = string
  default     = "10.0.0.0/8" # Restrict to VPC CIDR by default
}

variable "APPLICATION_CIDR_BLOCK" {
  description = "CIDR block for application access to CockroachDB SQL port"
  type        = string
  default     = "10.0.0.0/8" # Restrict to VPC CIDR by default
}

variable "ADMIN_UI_CIDR_BLOCK" {
  description = "CIDR block for access to CockroachDB Admin UI"
  type        = string
  default     = "10.0.0.0/8" # Restrict to VPC CIDR by default
}
