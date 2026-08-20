# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

resource "aws_security_group" "msk_sg" {

  name        = "${var.APP}-${var.ENV}-msk-ingest-sg"
  description = "Security group for MSK Cluster"
  vpc_id      = local.VPC_ID
  tags = {
    "Name" = "${var.APP}-${var.ENV}-msk-ingest-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "msk_sg_in_rule_2" {
  #checkov:skip=CKV_AWS_23:MSK security group rule for EC2 access
  ip_protocol                  = "-1"
  security_group_id            = aws_security_group.msk_sg.id
  referenced_security_group_id = aws_security_group.ec2_sg.id
}

resource "aws_vpc_security_group_ingress_rule" "msk_sg_in_rule_dms" {

  ip_protocol       = "tcp"
  security_group_id = aws_security_group.msk_sg.id
  # referenced_security_group_id = data.aws_ssm_parameter.vpc_sg.value
  cidr_ipv4   = data.aws_vpc.vpc.cidr_block
  from_port   = 9096 # MSK SASL/IAM port
  to_port     = 9098
  description = "Allow DMS to connect to MSK via SASL/IAM"
}

resource "aws_security_group" "ec2_sg" {

  name        = "${var.APP}-${var.ENV}-ec2-ingest-sg"
  description = "Security group for msk config EC2"
  vpc_id      = local.VPC_ID
  tags = {
    "Name" = "${var.APP}-${var.ENV}-ec2-ingest-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ec2_sg_in_rule_1" {
  #checkov:skip=CKV_AWS_23:EC2 security group rule for self-referencing access
  ip_protocol                  = "-1"
  security_group_id            = aws_security_group.ec2_sg.id
  referenced_security_group_id = aws_security_group.ec2_sg.id

}

resource "aws_vpc_security_group_egress_rule" "ec2_sg_out_rule_1" {
  #checkov:skip=CKV_AWS_23:EC2 security group rule for outbound internet access
  ip_protocol       = "-1"
  security_group_id = aws_security_group.ec2_sg.id
  cidr_ipv4         = "0.0.0.0/0"
}
