# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

variable "APP" {
  description = "Application name"
  type        = string
}

variable "ENV" {
  description = "Environment name"
  type        = string
}

variable "AWS_PRIMARY_REGION" {
  description = "Primary AWS region"
  type        = string
}

variable "ORACLE_TRANSACTIONS_DATABASE_NAME" {
  description = "Name of the Oracle transactions database"
  type        = string
}

variable "AURORA_TRANSACTIONS_DATABASE_NAME" {
  description = "Name of the Aurora transactions database"
  type        = string
}

variable "COCKROACH_TRANSACTIONS_DATABASE_NAME" {
  description = "Name of the CockroachDB transactions database"
  type        = string
}

variable "MSK_TRANSACTIONS_DATABASE_NAME" {
  description = "Name of the MSK transactions database"
  type        = string
}

variable "CONNECT_ORACLE_TRANSACTIONS_DATABASE_NAME" {
  description = "Name of the Connect Oracle transactions database"
  type        = string
}

variable "CONNECT_AURORA_TRANSACTIONS_DATABASE_NAME" {
  description = "Name of the Connect Aurora transactions database"
  type        = string
}

variable "CONNECT_COCKROACH_TRANSACTIONS_DATABASE_NAME" {
  description = "Name of the Connect CockroachDB transactions database"
  type        = string
}

variable "CONNECT_MSK_TRANSACTIONS_DATABASE_NAME" {
  description = "Name of the Connect MSK transactions database"
  type        = string
}
