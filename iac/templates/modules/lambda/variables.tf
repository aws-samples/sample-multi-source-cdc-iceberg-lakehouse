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

variable "function_name" {
  description = "Name of the Lambda function"
  type        = string
  validation {
    condition     = length(var.function_name) > 0 && length(var.function_name) <= 64
    error_message = "Function name must be between 1 and 64 characters."
  }
}

variable "runtime" {
  description = "Lambda runtime"
  type        = string
  default     = "python3.11"
  validation {
    condition = contains([
      "python3.8", "python3.9", "python3.10", "python3.11", "python3.12",
      "nodejs18.x", "nodejs20.x",
      "java8", "java11", "java17", "java21",
      "dotnet6", "dotnet8",
      "go1.x",
      "ruby3.2", "ruby3.3"
    ], var.runtime)
    error_message = "Runtime must be a supported AWS Lambda runtime."
  }
}

variable "handler" {
  description = "Lambda function handler"
  type        = string
  default     = "handler.lambda_handler"
}

variable "timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 30
  validation {
    condition     = var.timeout >= 1 && var.timeout <= 900
    error_message = "Timeout must be between 1 and 900 seconds."
  }
}

variable "memory_size" {
  description = "Lambda function memory size in MB"
  type        = number
  default     = 256
  validation {
    condition     = var.memory_size >= 128 && var.memory_size <= 10240
    error_message = "Memory size must be between 128 and 10240 MB."
  }
}

variable "source_code_path" {
  description = "Path to the source code directory (for zip_file deployment)"
  type        = string
  default     = null
}

variable "zip_file_path" {
  description = "Path to the zip file containing Lambda code"
  type        = string
  default     = null
}

variable "environment_variables" {
  description = "Environment variables for the Lambda function"
  type        = map(string)
  default     = {}
}

variable "create_role" {
  description = "Whether to create an IAM role for the Lambda function"
  type        = bool
  default     = true
}

variable "role_arn" {
  description = "Existing IAM role ARN to use (if create_role is false)"
  type        = string
  default     = null
}

variable "policy_statements" {
  description = "Additional IAM policy statements for the Lambda function"
  type = list(object({
    effect    = string
    actions   = list(string)
    resources = list(string)
    condition = optional(map(object({
      test     = string
      variable = string
      values   = list(string)
    })))
  }))
  default = []
}

variable "managed_policy_arns" {
  description = "List of managed policy ARNs to attach to the Lambda role"
  type        = list(string)
  default     = []
}

variable "reserved_concurrent_executions" {
  description = "The amount of reserved concurrent executions for this lambda function. A value of 0 disables lambda from being triggered and -1 removes any concurrency limitations. Defaults to Unreserved (No Limits)"
  type        = number
  default     = -1
}

variable "layers" {
  description = "List of Lambda layer ARNs"
  type        = list(string)
  default     = []
}

variable "subnet_ids" {
  description = "List of subnet IDs for Lambda VPC configuration"
  type        = list(string)
  default     = []
}

variable "security_group_ids" {
  description = "List of security group IDs for Lambda VPC configuration"
  type        = list(string)
  default     = []
}

variable "exclude" {
  type        = list(string)
  description = "List of files to exclude from the zip file"
  default     = []
}

variable "deployment_method" {
  description = "Method to deploy Lambda code (zip_file or s3_bucket)"
  type        = string
  default     = "zip_file"
  validation {
    condition     = contains(["zip_file", "s3_bucket"], var.deployment_method)
    error_message = "Deployment method must be either zip_file or s3_bucket."
  }
}

variable "s3_bucket" {
  description = "S3 bucket containing the Lambda deployment package"
  type        = string
  default     = null
}

variable "s3_key" {
  description = "S3 key of the Lambda deployment package"
  type        = string
  default     = null
}

variable "s3_object_version" {
  description = "S3 object version of the Lambda deployment package"
  type        = string
  default     = null
}

variable "kms_key_arn" {
  description = "KMS key ARN for Lambda function encryption"
  type        = string
  default     = null
}
