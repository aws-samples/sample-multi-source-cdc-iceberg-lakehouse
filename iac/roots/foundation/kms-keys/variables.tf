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

variable "AWS_PRIMARY_REGION" {
  description = "Primary AWS region for resource deployment"
  type        = string
}



