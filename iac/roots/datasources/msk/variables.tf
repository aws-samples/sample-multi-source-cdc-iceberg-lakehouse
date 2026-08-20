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

variable "CLUSTER_NAME" {
  type        = string
  description = "The name of the MSK cluster"
}

variable "KAFKA_VERSION" {
  type        = string
  description = "The version of Kafka"
  default     = "3.9.x"
}

variable "KAFKA_INSTANCE_TYPE" {
  type        = string
  description = "The instance type of Kafka"
  default     = "kafka.m5.large"
}

variable "KAFKA_STORAGE_SIZE" {
  type        = number
  description = "The storage size of Kafka"
  default     = 1000
}

variable "KAFKA_CLIENT_VERSION" {
  type        = string
  description = "The version of Kafka client"
  default     = "3.9.1"
}

variable "MSK_FINANCIAL_TRANSACTIONS_TOPIC_NAME" {
  type        = string
  description = "The name of the MSK financial transactions topic"
  default     = "msk_src_fin"
}

variable "MSK_BROKERAGE_TRANSACTIONS_TOPIC_NAME" {
  type        = string
  description = "The name of the MSK brokerage transactions topic"
  default     = "msk_src_brk"
}


