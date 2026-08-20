# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

resource "aws_security_group" "msk_sg" {
  name        = "${var.APP}-${var.ENV}-msk-sg"
  description = "Security group for MSK Cluster"
  vpc_id      = local.VPC_ID
  tags = {
    "Name" = "${var.APP}-${var.ENV}-msk-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "msk_sg_in_rule_1" {
  ip_protocol       = "tcp"
  security_group_id = aws_security_group.msk_sg.id
  from_port         = 0
  to_port           = 65535
  cidr_ipv4         = data.aws_vpc.vpc.cidr_block
  description       = "Allow all TCP traffic from VPC for MSK cluster access"
}

resource "aws_vpc_security_group_egress_rule" "msk_sg_out_rule_1" {
  ip_protocol       = "-1"
  security_group_id = aws_security_group.msk_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  description       = "Allow all outbound traffic for MSK cluster"
}
