# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

resource "aws_security_group" "vpc_sg" {

  name        = "${var.APP}-${var.ENV}-vpc-sg"
  description = "${var.APP}-${var.ENV}-vpc-sg"
  vpc_id      = aws_vpc.main.id

  tags = {
    Application = var.APP
    Environment = var.ENV
    Name        = "${var.APP}-${var.ENV}-vpc-sg"
  }

  #checkov:skip=CKV2_AWS_5: "Ensure that Security Groups are attached to another resource"
}

# VPC CIDR ingress rule
resource "aws_vpc_security_group_ingress_rule" "vpc_cidr" {

  security_group_id = aws_security_group.vpc_sg.id
  description       = "Allow all traffic From VPC"
  cidr_ipv4         = aws_vpc.main.cidr_block
  from_port         = 0
  to_port           = 65535
  ip_protocol       = "tcp"
}

# Self-referencing ingress rule
resource "aws_vpc_security_group_ingress_rule" "self" {
  #checkov:skip=CKV_AWS_25:Self-referencing security group rule, not open to 0.0.0.0/0
  #checkov:skip=CKV_AWS_24:Self-referencing security group rule, not open to 0.0.0.0/0
  #checkov:skip=CKV_AWS_260:Self-referencing security group rule, not open to 0.0.0.0/0

  security_group_id            = aws_security_group.vpc_sg.id
  description                  = "Self"
  referenced_security_group_id = aws_security_group.vpc_sg.id
  from_port                    = 0
  to_port                      = 65535
  ip_protocol                  = "tcp"
}

# All traffic egress rule
resource "aws_vpc_security_group_egress_rule" "all_traffic" {

  security_group_id = aws_security_group.vpc_sg.id
  description       = "Egress Ports"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"

  #checkov:skip=CKV_AWS_382: "Ensure no security groups allow egress from 0.0.0.0:0 to port -1": "Skipping this for simplicity"
}

resource "aws_ssm_parameter" "vpc_sg_ssm" {

  name        = "/${var.APP}/${var.ENV}/vpc-sg"
  description = "The VPC security group"
  type        = "SecureString"
  value       = aws_security_group.vpc_sg.id
  key_id      = data.aws_kms_key.ssm_kms_key.key_id

  tags = {
    Application = var.APP
    Environment = var.ENV
  }
}
