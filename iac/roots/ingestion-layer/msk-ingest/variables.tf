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

variable "MSK_CLUSTER_NAME" {
  type        = string
  description = "Cluster name for MSK Kafka"
}

variable "ORACLE_FINANCIAL_TRANSACTIONS_TOPIC_NAME" {
  type        = string
  description = "Topic name for Oracle financial transactions"
  default     = "oracle_financial_transactions"
}

variable "AURORA_FINANCIAL_TRANSACTIONS_TOPIC_NAME" {
  type        = string
  description = "Topic name for Aurora financial transactions"
  default     = "aurora_financial_transactions"
}

variable "COCKROACH_FINANCIAL_TRANSACTIONS_TOPIC_NAME" {
  type        = string
  description = "Topic name for Cockroach financial transactions"
  default     = "cockroach_financial_transactions"
}

variable "ORACLE_BROKERAGE_TRANSACTIONS_TOPIC_NAME" {
  type        = string
  description = "Topic name for Oracle brokerage transactions"
  default     = "oracle_brokerage_transactions"
}

variable "AURORA_BROKERAGE_TRANSACTIONS_TOPIC_NAME" {
  type        = string
  description = "Topic name for Aurora brokerage transactions"
  default     = "aurora_brokerage_transactions"
}

variable "COCKROACH_BROKERAGE_TRANSACTIONS_TOPIC_NAME" {
  type        = string
  description = "Topic name for Cockroach brokerage transactions"
  default     = "cockroach_brokerage_transactions"
}

variable "CONNECT_ORACLE_FINANCIAL_TRANSACTIONS_TOPIC_NAME" {
  type        = string
  description = "Connect topic name for Oracle financial transactions"
  default     = "connect_oracle_financial_transactions"
}

variable "CONNECT_ORACLE_BROKERAGE_TRANSACTIONS_TOPIC_NAME" {
  type        = string
  description = "Connect topic name for Oracle brokerage transactions"
  default     = "connect_oracle_brokerage_transactions"
}

variable "CONNECT_AURORA_FINANCIAL_TRANSACTIONS_TOPIC_NAME" {
  type        = string
  description = "Connect topic name for Aurora financial transactions"
  default     = "connect_aurora_financial_transactions"
}

variable "CONNECT_AURORA_BROKERAGE_TRANSACTIONS_TOPIC_NAME" {
  type        = string
  description = "Connect topic name for Aurora brokerage transactions"
  default     = "connect_aurora_brokerage_transactions"
}

variable "KAFKA_VERSION" {
  type        = string
  description = "Kafka version for MSK"
  default     = "3.9.x"
}

variable "KAFKA_CLIENT_VERSION" {
  type        = string
  description = "Kafka client version installed on EC2"
  default     = "3.9.1"
}

variable "KAFKA_STORAGE_SIZE" {
  type        = number
  description = "Storage size per broker in GB"
  default     = 1000
}

variable "KAFKA_INSTANCE_TYPE" {
  type        = string
  description = "Instance type for Kafka brokers"
  default     = "kafka.m5.large"
}

variable "ENABLE_MSK_SASL_AUTH" {
  type        = bool
  description = "Enable SASL/SCRAM authentication for MSK cluster (required for DMS integration)"
  default     = false
}

variable "MSK_SASL_USERNAME" {
  type        = string
  description = "Username for MSK SASL/SCRAM authentication (required if ENABLE_MSK_SASL_AUTH is true)"
  default     = "admin"
}
