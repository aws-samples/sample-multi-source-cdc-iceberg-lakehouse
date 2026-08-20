# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

locals {

  function_name = "${var.APP}-${var.ENV}-${var.function_name}"
  role_name     = "${local.function_name}-role"
  use_zip_file  = var.deployment_method == "zip_file"
  use_s3_bucket = var.deployment_method == "s3_bucket"
}
data "archive_file" "lambda_zip" {
  count       = local.use_zip_file && var.source_code_path != null ? 1 : 0
  type        = "zip"
  source_dir  = var.source_code_path
  output_path = var.zip_file_path
  excludes    = var.exclude
}

resource "aws_cloudwatch_log_group" "lambda_logs" { // nosemgrep:
  #checkov:skip=CKV_AWS_338:Log retention set to 30 days for cost optimization in this sample
  #checkov:skip=CKV_AWS_158:CloudWatch log encryption not required for this sample
  name              = "/aws/lambda/${local.function_name}"
  retention_in_days = 30
}

resource "aws_iam_role" "lambda_role" {
  count = var.create_role ? 1 : 0
  name  = local.role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  count      = var.create_role ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_role[0].name
}

resource "aws_iam_role_policy_attachment" "managed_policies" {
  count      = var.create_role ? length(var.managed_policy_arns) : 0
  policy_arn = var.managed_policy_arns[count.index]
  role       = aws_iam_role.lambda_role[0].name
}

resource "aws_iam_role_policy" "lambda_custom_policy" {
  count = var.create_role && length(var.policy_statements) > 0 ? 1 : 0
  name  = "${local.role_name}-custom-policy"
  role  = aws_iam_role.lambda_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      for stmt in var.policy_statements : merge(
        {
          Effect   = stmt.effect
          Action   = stmt.actions
          Resource = stmt.resources
        },
        stmt.condition != null ? { Condition = stmt.condition } : {}
      )
    ]
  })
}

resource "aws_lambda_function" "main" { // nosemgrep:
  #checkov:skip=CKV_AWS_50:X-Ray tracing disabled for this sample to reduce costs
  #checkov:skip=CKV_AWS_116:DLQ not required for this sample
  #checkov:skip=CKV_AWS_272:Code signing not required for this sample

  function_name                  = local.function_name
  role                           = var.create_role ? aws_iam_role.lambda_role[0].arn : var.role_arn
  handler                        = var.handler
  runtime                        = var.runtime
  timeout                        = var.timeout
  memory_size                    = var.memory_size
  package_type                   = "Zip"
  architectures                  = ["x86_64"]
  filename                       = local.use_zip_file && var.source_code_path != null ? data.archive_file.lambda_zip[0].output_path : (local.use_zip_file ? var.zip_file_path : null)
  source_code_hash               = local.use_zip_file && var.source_code_path != null ? data.archive_file.lambda_zip[0].output_base64sha256 : null
  s3_bucket                      = local.use_s3_bucket ? var.s3_bucket : null
  s3_key                         = local.use_s3_bucket ? var.s3_key : null
  s3_object_version              = local.use_s3_bucket ? var.s3_object_version : null
  reserved_concurrent_executions = var.reserved_concurrent_executions
  kms_key_arn                    = var.kms_key_arn // nosemgrep:

  logging_config {
    application_log_level = "INFO"
    log_format            = "JSON"
    log_group             = aws_cloudwatch_log_group.lambda_logs.name
  }

  dynamic "environment" {
    for_each = length(var.environment_variables) > 0 ? [1] : []
    content {
      variables = var.environment_variables
    }
  }

  dynamic "vpc_config" {
    for_each = length(var.subnet_ids) > 0 && length(var.security_group_ids) > 0 ? [1] : []
    content {
      subnet_ids         = var.subnet_ids
      security_group_ids = var.security_group_ids
    }
  }

  layers     = var.layers
  depends_on = [aws_cloudwatch_log_group.lambda_logs]
}
resource "aws_iam_role_policy_attachment" "lambda_vpc_access" {
  count      = var.create_role && length(var.subnet_ids) > 0 && length(var.security_group_ids) > 0 ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
  role       = aws_iam_role.lambda_role[0].name
}
