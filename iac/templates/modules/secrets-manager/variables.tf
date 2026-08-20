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

variable "SECRET_NAME" {
  description = "Name prefix of the secret"
  type        = string
}

variable "SECRET_STRING" {
  description = "Secret string to be stored inside secret"
  type        = string
}

variable "RECOVERY_WINDOW" {
  type        = number
  description = "Number of days that AWS Secrets Manager waits before it can delete the secret. This value can be 0 to force deletion without recovery or range from 7 to 30 days. The default value is 30"
  default     = 0 # Set to 0 for easy teardown in this sample; use 7-30 for production
  validation {
    condition     = var.RECOVERY_WINDOW >= 7 && var.RECOVERY_WINDOW <= 30 || var.RECOVERY_WINDOW == 0
    error_message = "The recovery_window value must be between 7 and 30 days or 0 for force deletion"
  }
}

variable "KMS_KEY_ARN" {
  type        = string
  description = " ARN or Id of the AWS KMS key to be used to encrypt the secret values in the versions stored in this secret.  If you don't specify this value, then Secrets Manager defaults to using the AWS account's default KMS key (the one named aws/secretsmanager) "
  default     = null
}
