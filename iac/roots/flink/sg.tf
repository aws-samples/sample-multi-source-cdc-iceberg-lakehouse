# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

# -----------------------------------------------------------------------------
# Flink Security Group
#
# Flink initiates all outbound connections (MSK, S3, Glue, CloudWatch, KMS),
# so no ingress rules are required.
# -----------------------------------------------------------------------------

resource "aws_security_group" "flink" {
  #checkov:skip=CKV2_AWS_5:Security group is attached to Flink application via vpc_configuration.security_group_ids
  #checkov:skip=CKV_AWS_382:Flink needs all outbound traffic for AWS service APIs (MSK, S3, Glue, CloudWatch, KMS)
  name_prefix            = "${var.APP}-${var.ENV}-flink-"
  description            = "Security group for Managed Flink applications"
  vpc_id                 = local.vpc_id
  revoke_rules_on_delete = true

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic to AWS services"
  }

  tags = {
    Name = "${var.APP}-${var.ENV}-flink-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}
