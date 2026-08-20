# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

# Oracle integration - get Oracle security group and allow connections
data "aws_security_group" "oracle_sg" {

  count = var.ENABLE_ORACLE_INTEGRATION ? 1 : 0
  name  = "${var.APP}-${var.ENV}-oracle-sg"
}

resource "aws_security_group" "data_generator_sg" {

  name        = "${var.APP}-${var.ENV}-data-generator-sg"
  description = "Security group for data generator EC2 instance"
  vpc_id      = local.VPC_ID
  tags = {
    "Name" = "${var.APP}-${var.ENV}-data-generator-sg"
  }
}

# Self-referencing rule for internal communication
resource "aws_vpc_security_group_ingress_rule" "data_generator_sg_self" {

  ip_protocol                  = "-1"
  security_group_id            = aws_security_group.data_generator_sg.id
  referenced_security_group_id = aws_security_group.data_generator_sg.id
  description                  = "Allow all traffic within data generator security group"
}

# Outbound rule for internet access (package downloads, AWS services)
resource "aws_vpc_security_group_egress_rule" "data_generator_sg_outbound" {

  ip_protocol       = "-1"
  security_group_id = aws_security_group.data_generator_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  description       = "Allow all outbound traffic for package downloads and AWS services"
}

# MSK integration - allow data generator to connect to MSK
resource "aws_vpc_security_group_ingress_rule" "msk_sg_from_data_generator" {

  count                        = var.ENABLE_MSK_INTEGRATION && local.MSK_SG_ID != "" ? 1 : 0
  ip_protocol                  = "-1"
  security_group_id            = local.MSK_SG_ID
  referenced_security_group_id = aws_security_group.data_generator_sg.id
  description                  = "Allow data generator access to MSK cluster"
}

resource "aws_vpc_security_group_ingress_rule" "oracle_sg_from_data_generator" {
  count                        = var.ENABLE_ORACLE_INTEGRATION ? 1 : 0
  ip_protocol                  = "tcp"
  from_port                    = 1521
  to_port                      = 1521
  security_group_id            = data.aws_security_group.oracle_sg[0].id
  referenced_security_group_id = aws_security_group.data_generator_sg.id
  description                  = "Allow data generator access to Oracle database"
}

resource "aws_vpc_security_group_ingress_rule" "data_geneartor_ingress_rule_2" {
  count                        = var.ENABLE_COCKROACH_INTEGRATION ? 1 : 0
  ip_protocol                  = "-1"
  security_group_id            = data.aws_security_group.cockroach_sg[0].id
  referenced_security_group_id = aws_security_group.data_generator_sg.id
  description                  = "Allow data generator access to CockroachDB cluster"
}
