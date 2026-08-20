# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

# -----------------------------------------------------------------------------
# CloudWatch Log Group + per-app log streams for Managed Flink
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "flink" {
  #checkov:skip=CKV_AWS_158:KMS encryption for logs not configured in this sample
  #checkov:skip=CKV_AWS_338:Retention set to 30 days for this sample
  name              = "/aws/kinesis-analytics/${var.APP}-${var.ENV}-flink"
  retention_in_days = 7

  tags = {
    Name = "${var.APP}-${var.ENV}-flink-logs"
  }
}

resource "aws_cloudwatch_log_stream" "flink" {
  for_each = local.apps

  name           = "${var.APP}-${var.ENV}-flink-${each.key}"
  log_group_name = aws_cloudwatch_log_group.flink.name
}
