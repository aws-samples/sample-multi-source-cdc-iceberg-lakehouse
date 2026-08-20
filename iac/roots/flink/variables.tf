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

variable "REGION" {
  type        = string
  description = "AWS region where the resources will be deployed"
}

# -----------------------------------------------------------------------------
# Flink Runtime / Scaling
# -----------------------------------------------------------------------------

variable "FLINK_RUNTIME" {
  description = "Managed Flink runtime environment"
  type        = string
  default     = "FLINK-2_2"
}

variable "FLINK_PARALLELISM" {
  description = "Initial parallelism for each Flink application"
  type        = number
  default     = 4
}

variable "FLINK_PARALLELISM_PER_KPU" {
  description = "Parallelism units per KPU (Kinesis Processing Unit)"
  type        = number
  default     = 1
}

variable "FLINK_AUTO_SCALING" {
  description = "Enable auto-scaling for Flink applications"
  type        = bool
  default     = true
}

variable "FLINK_LOG_LEVEL" {
  description = "CloudWatch log level (DEBUG | INFO | WARN | ERROR)"
  type        = string
  default     = "INFO"
}

variable "FLINK_CHECKPOINT_INTERVAL_MS" {
  description = "Flink checkpoint interval in milliseconds (passed as app property)"
  type        = number
  default     = 60000
}

variable "FLINK_APP_JAR_KEY" {
  description = "S3 object key (in assets bucket) for the Flink application JAR"
  type        = string
  default     = "flink/flink-iceberg-sink-1.0-SNAPSHOT.jar"
}
