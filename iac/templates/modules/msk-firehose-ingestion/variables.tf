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

variable "TOPIC_NAME" {
  type        = string
  description = "MSK TOPIC NAME for ingestion"
}

variable "MSK_CLUSTER_ARN" {
  type        = string
  description = "ARN of the MSK cluster to read from"
}

variable "MSK_CLUSTER_NAME" {
  type        = string
  description = "Name of the MSK cluster"
}

variable "S3_BUCKET_ARN" {
  type        = string
  description = "ARN of the S3 bucket for storing Iceberg data"
}

variable "S3_KMS_ARN" {
  type        = string
  description = "ARN of the KMS key used for S3 encryption"
}

variable "GLUE_DATABASE_NAME" {
  type        = string
  description = "Name of the Glue database for the Iceberg table"
}

variable "GLUE_TABLE_NAME" {
  type        = string
  description = "Name of the Glue table for the Iceberg data"
}

variable "FIREHOSE_STREAM_NAME" {
  type        = string
  description = "Suffix for the Firehose delivery stream name"
}

variable "LOG_RETENTION_DAYS" {
  type        = number
  description = "Number of days to retain CloudWatch logs"
  default     = 30
}

variable "BUFFERING_SIZE" {
  type        = number
  description = "Buffer size in MB for Firehose"
  default     = 1
}

variable "BUFFERING_INTERVAL" {
  type        = number
  description = "Buffer interval in seconds for Firehose"
  default     = 30
}
variable "ENABLE_LAMBDA_TRANSFORMATION" {
  type        = bool
  description = "Enable Lambda transformation for data processing"
  default     = false
}

variable "LAMBDA_TRANSFORMER_ARN" {
  type        = string
  description = "ARN of the Lambda function for data transformation"
  default     = ""

  validation {
    condition     = var.ENABLE_LAMBDA_TRANSFORMATION == false || (var.ENABLE_LAMBDA_TRANSFORMATION == true && var.LAMBDA_TRANSFORMER_ARN != "")
    error_message = "LAMBDA_TRANSFORMER_ARN must be provided when ENABLE_LAMBDA_TRANSFORMATION is true."
  }
}

variable "TABLE_TYPE" {
  type        = string
  description = "Type of table to create: 'financial' or 'brokerage'"

  validation {
    condition     = contains(["financial", "brokerage"], var.TABLE_TYPE)
    error_message = "TABLE_TYPE must be either 'financial' or 'brokerage'."
  }
}

variable "FIREHOSE_KMS_ARN" {
  type        = string
  description = "KMS key ARN for Firehose stream encryption"
  default     = null
}

variable "CATALOG_ARN" {
  type        = string
  description = "Override the Glue catalog ARN. Set to arn:aws:glue:<region>:<account>:catalog/s3tablescatalog for S3 Tables mode. Empty = regular Glue catalog."
  default     = ""
}

variable "ENABLE_S3_TABLES_OUTPUT" {
  type        = bool
  description = "Enable S3 Tables IAM permissions (s3tables:*, Glue federated catalog, LakeFormation)"
  default     = false
}

variable "S3_TABLES_BUCKET_ARN" {
  type        = string
  description = "ARN of the S3 Tables table bucket for IAM permissions"
  default     = ""

  validation {
    condition     = var.ENABLE_S3_TABLES_OUTPUT == false || (var.ENABLE_S3_TABLES_OUTPUT == true && var.S3_TABLES_BUCKET_ARN != "")
    error_message = "S3_TABLES_BUCKET_ARN must be provided when ENABLE_S3_TABLES_OUTPUT is true."
  }
}
