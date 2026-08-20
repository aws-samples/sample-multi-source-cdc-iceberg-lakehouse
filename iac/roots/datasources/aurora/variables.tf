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

# Bastion Host Configuration
variable "ENABLE_BASTION_HOST" {
  type        = bool
  default     = false
  description = "Whether to deploy a bastion host for Aurora access via SSM Session Manager"
}

variable "BASTION_INSTANCE_TYPE" {
  type        = string
  default     = "t3.micro"
  description = "Instance type for the Aurora bastion host"
}
