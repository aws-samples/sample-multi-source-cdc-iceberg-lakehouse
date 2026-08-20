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

variable "CONNECTOR_NAME" {
  description = "Unique name suffix for this connector (e.g., oracle, aurora)"
  type        = string
}

variable "CONNECTOR_CONFIG" {
  description = "Map of connector configuration properties passed to MSK Connect"
  type        = map(string)
}

variable "MSK_BOOTSTRAP_SERVERS" {
  description = "MSK bootstrap servers (IAM endpoint)"
  type        = string
}

variable "VPC_SUBNET_IDS" {
  description = "List of subnet IDs for the MSK Connect connector"
  type        = list(string)
}

variable "VPC_SECURITY_GROUP_IDS" {
  description = "List of security group IDs for the MSK Connect connector"
  type        = list(string)
}

variable "EXECUTION_ROLE_ARN" {
  description = "IAM role ARN for the MSK Connect connector execution"
  type        = string
}

variable "PLUGIN_S3_BUCKET_ARN" {
  description = "S3 bucket ARN containing the Debezium plugin ZIP"
  type        = string
}

variable "PLUGIN_S3_KEY" {
  description = "S3 object key for the Debezium plugin ZIP file"
  type        = string
}

variable "KAFKACONNECT_VERSION" {
  description = "Kafka Connect version"
  type        = string
  default     = "2.7.1"
}

variable "USE_PROVISIONED_CAPACITY" {
  description = "Use provisioned (fixed) capacity instead of autoscaling. Required for connectors that only support 1 task (e.g., Debezium Oracle)."
  type        = bool
  default     = false
}

variable "WORKER_COUNT" {
  description = "Number of workers when using provisioned capacity (USE_PROVISIONED_CAPACITY=true)"
  type        = number
  default     = 1
}

variable "MIN_WORKERS" {
  description = "Minimum number of workers for autoscaling"
  type        = number
  default     = 1
}

variable "MAX_WORKERS" {
  description = "Maximum number of workers for autoscaling"
  type        = number
  default     = 2
}

variable "MCU_COUNT" {
  description = "Number of MCUs per worker (1 MCU = 1 vCPU + 4GB)"
  type        = number
  default     = 1
}

variable "LOG_RETENTION_DAYS" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

variable "SCHEMAS_ENABLE" {
  description = "Enable embedded schemas in the JSON converter output"
  type        = bool
  default     = false
}
