# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

locals {
  min_az_count_required = 3
  max_az_count          = min(4, length(data.aws_availability_zones.available.names))
}

# VPC
resource "aws_vpc" "main" {

  cidr_block           = "10.38.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.APP}-${var.ENV}-vpc"
    Application = var.APP
    Environment = var.ENV
  }

  # Before creating the VPC, first check if it supports the minimum # of required availability zones
  lifecycle {
    precondition {
      condition     = length(data.aws_availability_zones.available.zone_ids) >= local.min_az_count_required
      error_message = "Region must have at least ${local.min_az_count_required} availability zones."
    }
  }
}

# Restrict default security group to deny all traffic
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id

  # No ingress or egress rules - deny all traffic
  tags = {
    Name        = "${var.APP}-${var.ENV}-default-sg-restricted"
    Application = var.APP
    Environment = var.ENV
  }
}

# VPC Flow Logs
resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  #checkov:skip=CKV_AWS_338:Log retention set to 30 days for cost optimization in this sample
  name              = "/aws/vpc/flowlogs/${var.APP}-${var.ENV}"
  retention_in_days = 30
  kms_key_id        = data.aws_kms_key.cloudwatch_kms_key.arn

  tags = {
    Name        = "${var.APP}-${var.ENV}-vpc-flow-logs"
    Application = var.APP
    Environment = var.ENV
  }
}

resource "aws_iam_role" "vpc_flow_logs_role" {
  name = "${var.APP}-${var.ENV}-vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.APP}-${var.ENV}-vpc-flow-logs-role"
    Application = var.APP
    Environment = var.ENV
  }
}

resource "aws_iam_role_policy" "vpc_flow_logs_policy" {
  name = "${var.APP}-${var.ENV}-vpc-flow-logs-policy"
  role = aws_iam_role.vpc_flow_logs_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "${aws_cloudwatch_log_group.vpc_flow_logs.arn}:*"
      }
    ]
  })
}

resource "aws_flow_log" "vpc_flow_log" {
  iam_role_arn    = aws_iam_role.vpc_flow_logs_role.arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_logs.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.main.id

  tags = {
    Name        = "${var.APP}-${var.ENV}-vpc-flow-log"
    Application = var.APP
    Environment = var.ENV
  }
}

# Save the VPC Id in SSM Parameter Store
resource "aws_ssm_parameter" "vpc_id" {
  name   = "/${var.APP}/${var.ENV}/vpc-id"
  type   = "SecureString"
  value  = aws_vpc.main.id
  key_id = data.aws_kms_key.ssm_kms_key.key_id

  tags = {
    Application = var.APP
    Environment = var.ENV
  }
}

# Save the VPC CIDR block in SSM Parameter Store
resource "aws_ssm_parameter" "vpc_cidr" {
  name   = "/${var.APP}/${var.ENV}/vpc-cidr-block"
  type   = "SecureString"
  value  = aws_vpc.main.cidr_block
  key_id = data.aws_kms_key.ssm_kms_key.key_id

  tags = {
    Application = var.APP
    Environment = var.ENV
  }
}
