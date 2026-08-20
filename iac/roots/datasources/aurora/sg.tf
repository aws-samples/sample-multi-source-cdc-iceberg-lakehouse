# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0


resource "aws_security_group" "aurora_sg" {
  name        = "${var.APP}-${var.ENV}-aurora-sg"
  description = "Security group for Aurora Cluster"
  vpc_id      = local.VPC_ID
  tags = {
    "Name" = "${var.APP}-${var.ENV}-aurora-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "aurora_sg_in_rule_1" {
  ip_protocol       = "tcp"
  security_group_id = aws_security_group.aurora_sg.id
  from_port         = 5432
  to_port           = 5432
  cidr_ipv4         = data.aws_vpc.vpc.cidr_block
  description       = "Allow PostgreSQL access from VPC"
}
