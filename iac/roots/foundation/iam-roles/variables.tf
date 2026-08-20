# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

variable "APP" {

  type = string
}

variable "ENV" {

  type = string
}

variable "AWS_PRIMARY_REGION" {

  type = string
}

variable "SSM_KMS_KEY_ALIAS" {

  type = string
}

variable "EBS_KMS_KEY_ALIAS" {

  type = string
}

variable "SECRETS_MANAGER_KMS_KEY_ALIAS" {

  type = string
}

variable "MSK_SOURCE_CLUSTER_NAME" {

  type = string
}
