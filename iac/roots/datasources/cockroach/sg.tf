# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0


resource "aws_security_group" "cockroachdb_sg" {
  name        = "${local.cockroach_cluster_name}-sg"
  description = "Security group for CockroachDB cluster"
  vpc_id      = data.aws_ssm_parameter.vpc_id.value
  tags = {
    Name = "${local.cockroach_cluster_name}-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "cockroachdb_sql_internode" {
  security_group_id            = aws_security_group.cockroachdb_sg.id
  description                  = "CockroachDB SQL port for inter-node communication"
  from_port                    = 26257
  to_port                      = 26257
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.cockroachdb_sg.id
}

# Load balancer and application access to SQL port (combined since CIDR blocks are the same)
resource "aws_vpc_security_group_ingress_rule" "cockroachdb_sql_lb" {
  security_group_id = aws_security_group.cockroachdb_sg.id
  description       = "CockroachDB SQL port for load balancer and application access"
  from_port         = 26257
  to_port           = 26257
  ip_protocol       = "tcp"
  cidr_ipv4         = data.aws_vpc.main.cidr_block
}

# Inter-node communication on UI port
resource "aws_vpc_security_group_ingress_rule" "cockroachdb_ui_internode" {
  security_group_id            = aws_security_group.cockroachdb_sg.id
  description                  = "CockroachDB Admin UI for inter-node communication"
  from_port                    = 8080
  to_port                      = 8080
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.cockroachdb_sg.id
}

# Network access and load balancer health check to UI port (combined since CIDR blocks are the same)
resource "aws_vpc_security_group_ingress_rule" "cockroachdb_ui_network" {
  security_group_id = aws_security_group.cockroachdb_sg.id
  description       = "CockroachDB Admin UI for network access and load balancer health checks"
  from_port         = 8080
  to_port           = 8080
  ip_protocol       = "tcp"
  cidr_ipv4         = var.ADMIN_UI_CIDR_BLOCK
}

# SSH access (optional - SSM Session Manager is recommended)
resource "aws_vpc_security_group_ingress_rule" "cockroachdb_ssh" {
  security_group_id = aws_security_group.cockroachdb_sg.id
  description       = "SSH access (optional - SSM Session Manager recommended)"
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  cidr_ipv4         = var.SSH_CIDR_BLOCK
}

# Allow all outbound traffic
resource "aws_vpc_security_group_egress_rule" "cockroachdb_egress" {
  security_group_id = aws_security_group.cockroachdb_sg.id
  description       = "Allow all outbound traffic"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}
