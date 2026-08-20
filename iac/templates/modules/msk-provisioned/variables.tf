# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

variable "CLUSTER_NAME" {
  description = "Name of the cluster"
  type        = string
}

variable "SUBNET_IDS" {
  type        = list(string)
  description = "List of subnet ids"
}

variable "SECURITY_GROUP_IDS" {
  type        = list(string)
  description = "List of security group ids"
}

variable "KAFKA_VERSION" {
  description = "Kafka version to use"
  type        = string
  default     = "3.9.x"
}

variable "INSTANCE_TYPE" {
  type        = string
  description = "Type of the instance to be used for cluster nodes"
  default     = "kafka.m5.large"
}

variable "STORAGE_SIZE" {
  type        = number
  description = "Size of the storage in GiB"
  default     = 1000
}

variable "ENHANCED_MONITORING_LEVEL" {
  type        = string
  description = "Level of enhanced monitoring"
  default     = "PER_TOPIC_PER_PARTITION"
}

variable "ENABLE_SASL_SCRAM_AUTH" {
  description = "Enable SASL/SCRAM authentication"
  type        = bool
  default     = true
}

variable "SASL_SCRAM_USERNAME" {
  description = "Username for SASL/SCRAM authentication"
  type        = string
  default     = "admin"
}

variable "APP" {
  description = "Application name"
  type        = string
}

variable "ENV" {
  description = "Environment name"
  type        = string
}

variable "KAFKA_KMS_KEY_ARN" {
  description = "Kafka KMS key ARN for encryption (required)"
  type        = string
}

variable "SECRETS_MANAGER_KMS_KEY_ARN" {
  description = "Secrets Manager KMS key ARN for encryption (required)"
  type        = string
}
