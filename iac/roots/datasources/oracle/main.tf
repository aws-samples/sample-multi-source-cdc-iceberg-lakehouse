# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

terraform {
  required_version = ">= 1.8.0"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id  = data.aws_caller_identity.current.account_id
  region      = data.aws_region.current.region
  name_prefix = "${var.APP}-${var.ENV}"
  tags = {
    Application = var.APP
    Environment = var.ENV
  }
}

# Get KMS key for S3 encryption
data "aws_kms_key" "s3_kms_key" {

  key_id = "alias/${var.APP}-${var.ENV}-s3-secret-key"
}

# Get VPC and subnet information from SSM Parameter Store
data "aws_ssm_parameter" "vpc_id" {
  name = "/${var.APP}/${var.ENV}/vpc-id"
}

data "aws_ssm_parameter" "private_subnet_ids" {
  name = "/${var.APP}/${var.ENV}/vpc-private-subnet-ids"
}

data "aws_ssm_parameter" "vpc_sg" {
  name = "/${var.APP}/${var.ENV}/vpc-sg"
}

# Get KMS keys for encryption
data "aws_kms_key" "ssm_kms_key" {
  key_id = "alias/${var.SSM_KMS_KEY_ALIAS}"
}

data "aws_kms_key" "ebs_kms_key" {
  key_id = "alias/${var.EBS_KMS_KEY_ALIAS}"
}

data "aws_kms_key" "secrets_manager_kms_key" {
  key_id = "alias/${var.SECRETS_MANAGER_KMS_KEY_ALIAS}"
}

# Generate a random password for Oracle admin if one is not provided
resource "random_password" "oracle_cdc_password" {

  length           = 16
  special          = true
  override_special = "!#$&*()-_=[]{}<>:?"
  min_lower        = 1
  min_upper        = 1
  min_numeric      = 1
  min_special      = 1
}

# Generate a random password for Oracle trading user
resource "random_password" "oracle_user_password" {

  length           = 16
  special          = true
  override_special = "!#$&*()-_=[]{}<>:?"
  min_lower        = 1
  min_upper        = 1
  min_numeric      = 1
  min_special      = 1
}

# Create a secret for the Oracle admin password
resource "aws_secretsmanager_secret" "oracle_cdc_password" {
  #checkov:skip=CKV2_AWS_57:Automatic rotation not required for this sample

  name                    = "${var.APP}-${var.ENV}-oracle-cdc-password"
  description             = "Oracle CDC users password (C##DBZUSER, C##DMSUSER)"
  kms_key_id              = data.aws_kms_key.secrets_manager_kms_key.arn
  recovery_window_in_days = 0 # Allow immediate deletion of the secret

  tags = merge(local.tags, {
    Name = "${var.APP}-${var.ENV}-oracle-cdc-password"
  })
}

# Create a secret for the Oracle user password
resource "aws_secretsmanager_secret" "oracle_user_password" {
  #checkov:skip=CKV2_AWS_57:Automatic rotation not required for this sample
  name                    = "${var.APP}-${var.ENV}-oracle-user-password"
  description             = "Oracle database user password"
  kms_key_id              = data.aws_kms_key.secrets_manager_kms_key.arn
  recovery_window_in_days = 0 # Allow immediate deletion of the secret

  tags = merge(local.tags, {
    Name = "${var.APP}-${var.ENV}-oracle-user-password"
  })
}

# Create a secret for data generator Oracle connection
resource "aws_secretsmanager_secret" "oracle_data_generator_connection" {
  #checkov:skip=CKV2_AWS_57:Automatic rotation not required for this sample
  name                    = "${var.APP}-${var.ENV}-oracle-db-secret"
  description             = "Oracle database connection details for data generator service"
  kms_key_id              = data.aws_kms_key.secrets_manager_kms_key.arn
  recovery_window_in_days = 0 # Allow immediate deletion of the secret

  tags = merge(local.tags, {
    Name    = "${var.APP}-${var.ENV}-oracle-db-secret"
    Purpose = "DataGenerator"
  })
}

# Store the admin password in Secrets Manager
resource "aws_secretsmanager_secret_version" "oracle_cdc_password" {

  secret_id     = aws_secretsmanager_secret.oracle_cdc_password.id
  secret_string = var.ORACLE_CDC_PASSWORD != null ? var.ORACLE_CDC_PASSWORD : random_password.oracle_cdc_password.result
}

# Store the trading user password in Secrets Manager
resource "aws_secretsmanager_secret_version" "oracle_user_password" {

  secret_id     = aws_secretsmanager_secret.oracle_user_password.id
  secret_string = var.ORACLE_USER_PASSWORD != null ? var.ORACLE_USER_PASSWORD : random_password.oracle_user_password.result
}

# Store the data generator connection details in Secrets Manager
resource "aws_secretsmanager_secret_version" "oracle_data_generator_connection" {

  secret_id = aws_secretsmanager_secret.oracle_data_generator_connection.id
  secret_string = jsonencode({
    username = var.ORACLE_USER
    password = var.ORACLE_USER_PASSWORD != null ? var.ORACLE_USER_PASSWORD : random_password.oracle_user_password.result
    host     = module.ec2.private_ip
    port     = tostring(var.ORACLE_PORT)
    dbname   = var.ORACLE_PDB # Using PDB name (XEPDB1) for service name
    engine   = "oracle"
  })

  # Ensure this is created after the EC2 instance and password are ready
  depends_on = [
    module.ec2,
    aws_secretsmanager_secret_version.oracle_user_password
  ]
}
