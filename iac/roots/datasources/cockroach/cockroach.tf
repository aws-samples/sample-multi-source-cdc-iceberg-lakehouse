# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

locals {
  name_prefix            = "${var.APP}-${var.ENV}"
  cockroach_cluster_name = "${local.name_prefix}-cockroachdb"
  common_tags = {
    Application = var.APP
    Environment = var.ENV
    Component   = "cockroachdb"
  }
}

locals {
  cockroach_node_ips = aws_instance.cockroachdb[*].private_ip
  cockroach_lb_dns   = aws_lb.cockroachdb.dns_name
}

# Launch template for CockroachDB instances
resource "aws_launch_template" "cockroachdb" {
  name          = "${local.cockroach_cluster_name}-launch-template"
  image_id      = data.aws_ami.amazon_linux_2023.id
  instance_type = var.INSTANCE_TYPE
  key_name      = var.KEY_NAME != "" ? var.KEY_NAME : null

  iam_instance_profile {
    name = data.aws_ssm_parameter.cockroachdb_instance_profile_name.value
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  monitoring {
    enabled = true
  }

  ebs_optimized = true

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_type           = "gp3"
      volume_size           = 20
      encrypted             = true
      delete_on_termination = true
    }
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.cockroachdb_sg.id]
    subnet_id                   = local.cockroach_subnet_id
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 250
      volume_type           = "gp3"
      delete_on_termination = true
      encrypted             = true
      kms_key_id            = data.aws_kms_key.ebs_kms_key.arn
    }
  }

  user_data = base64encode(templatefile("${path.module}/templates/user_data.sh", {
    cluster_name = local.cockroach_cluster_name
    node_count   = var.NODE_COUNT
  }))

  tag_specifications {
    resource_type = "instance"

    tags = merge(
      local.common_tags,
      {
        Name = "${local.cockroach_cluster_name}-node"
      }
    )
  }

  tag_specifications {
    resource_type = "volume"

    tags = merge(
      local.common_tags,
      {
        Name = "${local.cockroach_cluster_name}-volume"
      }
    )
  }

  tags = local.common_tags
}

resource "aws_instance" "cockroachdb" {
  #checkov:skip=CKV_AWS_79:IMDSv2 configured in launch template
  #checkov:skip=CKV_AWS_126:Detailed monitoring configured in launch template
  #checkov:skip=CKV_AWS_135:EBS optimization configured in launch template
  #checkov:skip=CKV_AWS_8:EBS encryption configured in launch template
  #checkov:skip=CKV2_AWS_41:IAM role attached via launch template
  count = var.NODE_COUNT

  launch_template {
    id      = aws_launch_template.cockroachdb.id
    version = "$Latest"
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.cockroach_cluster_name}-node-${count.index + 1}"
    }
  )
}

# Network Load Balancer for CockroachDB
resource "aws_lb" "cockroachdb" { // nosemgrep: 
  #checkov:skip=CKV_AWS_150:Deletion protection disabled for simplicity
  #checkov:skip=CKV_AWS_152:Cross-zone load balancing disabled for simplicity
  #checkov:skip=CKV_AWS_91:Access logging disabled for simplicity
  name               = "${local.cockroach_cluster_name}-nlb"
  internal           = true
  load_balancer_type = "network"
  subnets            = local.private_subnet_ids

  tags = merge(
    local.common_tags,
    {
      Name = "${local.cockroach_cluster_name}-nlb"
    }
  )
}

# Target group for SQL port
resource "aws_lb_target_group" "cockroachdb_sql" {
  name     = "${local.cockroach_cluster_name}-sql"
  port     = 26257
  protocol = "TCP"
  vpc_id   = data.aws_ssm_parameter.vpc_id.value

  health_check {
    protocol            = "HTTP"
    port                = 8080
    path                = "/health?ready=1"
    interval            = 30
    timeout             = 10
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = local.common_tags
}

# Target group for Admin UI
resource "aws_lb_target_group" "cockroachdb_ui" {
  name     = "${local.cockroach_cluster_name}-ui"
  port     = 8080
  protocol = "TCP"
  vpc_id   = data.aws_ssm_parameter.vpc_id.value

  health_check {
    protocol            = "HTTP"
    port                = 8080
    path                = "/health"
    interval            = 30
    timeout             = 10
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = local.common_tags
}

# Register instances with target groups
resource "aws_lb_target_group_attachment" "cockroachdb_sql" {
  count            = var.NODE_COUNT
  target_group_arn = aws_lb_target_group.cockroachdb_sql.arn
  target_id        = aws_instance.cockroachdb[count.index].id
  port             = 26257
}

resource "aws_lb_target_group_attachment" "cockroachdb_ui" {
  count            = var.NODE_COUNT
  target_group_arn = aws_lb_target_group.cockroachdb_ui.arn
  target_id        = aws_instance.cockroachdb[count.index].id
  port             = 8080
}

# ALB listeners
resource "aws_lb_listener" "cockroachdb_sql" {
  load_balancer_arn = aws_lb.cockroachdb.arn
  port              = 26257
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.cockroachdb_sql.arn
  }
}

resource "aws_lb_listener" "cockroachdb_ui" {
  load_balancer_arn = aws_lb.cockroachdb.arn
  port              = 8080
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.cockroachdb_ui.arn
  }
}

resource "aws_ssm_parameter" "cockroachdb_endpoint" {
  #checkov:skip=CKV2_AWS_34:SSM parameter encryption not required for non-sensitive endpoint data
  name        = "/${var.APP}/${var.ENV}/cockroachdb-endpoint"
  description = "CockroachDB SQL endpoint"
  type        = "String"
  value       = "${local.cockroach_lb_dns}:26257"

  tags = local.common_tags
}

resource "aws_ssm_parameter" "cockroachdb_ui_endpoint" {
  #checkov:skip=CKV2_AWS_34:SSM parameter encryption not required for non-sensitive endpoint data
  name        = "/${var.APP}/${var.ENV}/cockroachdb-ui-endpoint"
  description = "CockroachDB Admin UI endpoint"
  type        = "String"
  value       = "${local.cockroach_lb_dns}:8080"

  tags = local.common_tags
}

resource "random_password" "db_password" {
  length           = 16
  override_special = "!#$&*()-_=[]{}<>:?"
}

module "db_secret" {
  source      = "../../../templates/modules/secrets-manager"
  APP         = var.APP
  ENV         = var.ENV
  SECRET_NAME = "cockroach-db-secret" # pragma: allowlist secret
  SECRET_STRING = jsonencode({
    username = "root"
    password = random_password.db_password.result
    host     = local.cockroach_lb_dns
    port     = 26257
    dbname   = "defaultdb"
    engine   = "cockroach"
  })
}
