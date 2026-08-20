# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

# Create security group for Oracle
resource "aws_security_group" "oracle_sg" {

  name        = "${var.APP}-${var.ENV}-oracle-sg"
  description = "Security group for Oracle database"
  vpc_id      = data.aws_ssm_parameter.vpc_id.value

  tags = merge(local.tags, {
    Name = "${var.APP}-${var.ENV}-oracle-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Allow Oracle port inbound from VPC CIDR
resource "aws_vpc_security_group_ingress_rule" "oracle_port" {

  security_group_id            = aws_security_group.oracle_sg.id
  description                  = "Oracle database port"
  from_port                    = var.ORACLE_PORT
  to_port                      = var.ORACLE_PORT
  ip_protocol                  = "tcp"
  referenced_security_group_id = data.aws_ssm_parameter.vpc_sg.value
}

# Allow SSH inbound from VPC CIDR
resource "aws_vpc_security_group_ingress_rule" "ssh" {
  #checkov:skip=CKV_AWS_24:SSH access properly restricted to self-referencing security group

  security_group_id            = aws_security_group.oracle_sg.id
  description                  = "SSH access"
  from_port                    = 22
  to_port                      = 22
  ip_protocol                  = "tcp"
  referenced_security_group_id = data.aws_ssm_parameter.vpc_sg.value
}

# Allow all outbound traffic
resource "aws_vpc_security_group_egress_rule" "all_outbound" {

  security_group_id = aws_security_group.oracle_sg.id
  description       = "Allow all outbound traffic"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}
