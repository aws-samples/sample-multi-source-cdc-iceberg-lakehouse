# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

# Bastion host user data script
locals {
  bastion_user_data = var.enable_bastion_host ? templatefile("${path.module}/bastion-user-data.sh", {
    app_name      = var.APP
    env_name      = var.ENV
    aurora_port   = var.port
    database_name = var.database_name
    username      = var.master_username
  }) : ""
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_kms_key" "ssm_key" {
  key_id = "alias/${var.APP}-${var.ENV}-systems-manager-secret-key"
}

data "aws_kms_key" "rds_key" {
  key_id = "alias/aws/rds"

}

data "aws_iam_policy_document" "monitoring_role_policy" {

  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

data "aws_iam_policy" "monitoring_policy" {

  name = "AmazonRDSEnhancedMonitoringRole"
}

resource "random_password" "db_password" {

  length           = 16
  override_special = "!#$&*()-_=[]{}<>:?"
}

resource "aws_db_subnet_group" "subnet_group" {

  name       = "${var.APP}-${var.ENV}-${var.cluster_identifier}-subnet-group"
  subnet_ids = var.subnet_ids
}

resource "aws_rds_cluster" "aurora" {
  #checkov:skip=CKV_AWS_96:Deletion protection disabled for simplicity
  #checkov:skip=CKV_AWS_139:Deletion protection disabled for this sample
  #checkov:skip=CKV2_AWS_8:AWS Backup not used for simplicity in this sample

  engine                              = var.cluster_engine
  engine_version                      = var.engine_version
  cluster_identifier                  = "${var.APP}-${var.ENV}-${var.cluster_identifier}"
  database_name                       = var.database_name
  master_username                     = var.master_username
  master_password                     = random_password.db_password.result # pragma: allowlist secret
  db_subnet_group_name                = aws_db_subnet_group.subnet_group.name
  db_cluster_parameter_group_name     = aws_rds_cluster_parameter_group.aurora_parameters.name
  engine_mode                         = var.engine_mode
  port                                = var.port
  vpc_security_group_ids              = var.security_group_ids
  skip_final_snapshot                 = true
  iam_database_authentication_enabled = true
  storage_encrypted                   = true
  kms_key_id                          = data.aws_kms_key.rds_key.arn
  apply_immediately                   = true
  copy_tags_to_snapshot               = true
  enabled_cloudwatch_logs_exports     = ["postgresql"]
}

resource "aws_rds_cluster_instance" "cluster_instances" {
  #checkov:skip=CKV_AWS_354:Performance Insights KMS encryption not required for this sample
  count                        = 2
  cluster_identifier           = aws_rds_cluster.aurora.id
  identifier                   = "${var.APP}-${var.ENV}-instance-${count.index}"
  engine                       = aws_rds_cluster.aurora.engine
  instance_class               = var.instance_class
  engine_version               = aws_rds_cluster.aurora.engine_version
  monitoring_role_arn          = aws_iam_role.monitoring_role.arn
  monitoring_interval          = 5
  auto_minor_version_upgrade   = true
  performance_insights_enabled = true
}

resource "aws_rds_cluster_parameter_group" "aurora_parameters" {

  name   = "${var.APP}-${var.ENV}-aurora-parameters"
  family = "aurora-postgresql16"

  parameter {
    name         = "synchronous_commit"
    value        = "on"
    apply_method = "immediate"
  }

  parameter {
    name         = "rds.logical_replication"
    value        = "1"
    apply_method = "pending-reboot"
  }

  parameter {
    name         = "log_statement"
    value        = "all"
    apply_method = "immediate"
  }

  parameter {
    name         = "log_min_duration_statement"
    value        = "0"
    apply_method = "immediate"
  }

  parameter {
    name         = "shared_preload_libraries"
    value        = "pglogical"
    apply_method = "pending-reboot"
  }
}

resource "aws_iam_role" "monitoring_role" {

  name_prefix        = "${aws_rds_cluster.aurora.cluster_identifier}-mon-"
  assume_role_policy = data.aws_iam_policy_document.monitoring_role_policy.json
}

resource "aws_iam_role_policy_attachment" "attachment" {

  role       = aws_iam_role.monitoring_role.name
  policy_arn = data.aws_iam_policy.monitoring_policy.arn
}

module "db_secret" {

  source      = "../secrets-manager"
  APP         = var.APP
  ENV         = var.ENV
  SECRET_NAME = "aurora-db-secret" # pragma: allowlist secret
  SECRET_STRING = jsonencode({
    username = var.master_username
    password = random_password.db_password.result # pragma: allowlist secret
    host     = aws_rds_cluster.aurora.endpoint
    port     = var.port
    dbname   = var.database_name
    engine   = "postgres"
  })
}

module "reader_endpoint_secret" {

  source        = "../secrets-manager"
  APP           = var.APP
  ENV           = var.ENV
  SECRET_NAME   = "reader-endpoint" # pragma: allowlist secret
  SECRET_STRING = aws_rds_cluster.aurora.reader_endpoint
}

# SSM Parameters for Aurora cluster information
resource "aws_ssm_parameter" "aurora_cluster_endpoint" {

  name        = "/${var.APP}/${var.ENV}/aurora-cluster-endpoint"
  description = "Aurora cluster writer endpoint"
  type        = "SecureString"
  value       = aws_rds_cluster.aurora.endpoint
  key_id      = data.aws_kms_key.ssm_key.arn

  tags = {
    Application = var.APP
    Environment = var.ENV
    Component   = "aurora"
  }
}

resource "aws_ssm_parameter" "aurora_cluster_port" {

  name        = "/${var.APP}/${var.ENV}/aurora-cluster-port"
  description = "Aurora cluster port"
  type        = "SecureString"
  value       = var.port
  key_id      = data.aws_kms_key.ssm_key.arn

  tags = {
    Application = var.APP
    Environment = var.ENV
    Component   = "aurora"
  }
}

resource "aws_ssm_parameter" "aurora_database_name" {
  name        = "/${var.APP}/${var.ENV}/aurora-database-name"
  description = "Aurora database name"
  type        = "SecureString"
  value       = var.database_name
  key_id      = data.aws_kms_key.ssm_key.arn

  tags = {
    Application = var.APP
    Environment = var.ENV
    Component   = "aurora"
  }
}

#==============================================================================
# Bastion Host for Aurora Access (Optional)
#==============================================================================

# Security group for bastion host
resource "aws_security_group" "bastion_sg" {
  #checkov:skip=CKV2_AWS_5:Security group conditionally attached to bastion host when enabled
  count = var.enable_bastion_host ? 1 : 0

  name        = "${var.APP}-${var.ENV}-aurora-bastion-sg"
  description = "Security group for Aurora bastion host"
  vpc_id      = var.vpc_id

  # Allow outbound PostgreSQL connections to Aurora
  egress {
    from_port   = var.port
    to_port     = var.port
    protocol    = "tcp"
    cidr_blocks = ["${var.vpc_cidr_block}"] # Private VPC ranges
    description = "Aurora PostgreSQL access"
  }

  # Allow outbound HTTPS for SSM
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS for SSM and package updates"
  }

  # Allow outbound HTTP for package updates
  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP for package updates"
  }

  tags = {
    Name        = "${var.APP}-${var.ENV}-aurora-bastion-sg"
    Application = var.APP
    Environment = var.ENV
    Component   = "aurora-bastion"
  }
}

# Update Aurora security group to allow bastion access
resource "aws_vpc_security_group_ingress_rule" "aurora_bastion_access" {
  count = var.enable_bastion_host && length(var.security_group_ids) > 0 ? 1 : 0

  security_group_id            = var.security_group_ids[0] # Aurora SG
  referenced_security_group_id = aws_security_group.bastion_sg[0].id
  from_port                    = var.port
  to_port                      = var.port
  ip_protocol                  = "tcp"
  description                  = "Aurora access from bastion host"
}

# Bastion host EC2 instance
module "bastion_host" {
  count = var.enable_bastion_host ? 1 : 0

  source = "../ec2"

  APP                    = var.APP
  ENV                    = var.ENV
  instance_name          = "aurora-bastion"
  subnet_id              = var.subnet_ids[0]
  vpc_security_group_ids = [aws_security_group.bastion_sg[0].id]
  instance_type          = var.bastion_instance_type
  user_data              = local.bastion_user_data
  public_ip              = false

  depends_on = [aws_rds_cluster_instance.cluster_instances]
}

# IAM policy for bastion host to access Secrets Manager and SSM
resource "aws_iam_policy" "bastion_policy" {
  count = var.enable_bastion_host ? 1 : 0

  name        = "${var.APP}-${var.ENV}-aurora-bastion-policy"
  description = "IAM policy for Aurora bastion host to access AWS services"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          "arn:aws:secretsmanager:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:secret:${var.APP}-${var.ENV}-aurora-db-secret-*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = [
          "arn:aws:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter/${var.APP}/${var.ENV}/aurora-*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = compact([
          var.secrets_manager_kms_key != "" ? var.secrets_manager_kms_key : "",
          var.ssm_kms_key != "" ? var.ssm_kms_key : ""
        ])
      }
    ]
  })
}

# Attach policy to bastion host IAM role
resource "aws_iam_role_policy_attachment" "bastion_policy_attachment" {
  count = var.enable_bastion_host ? 1 : 0

  role       = module.bastion_host[0].iam_role_name
  policy_arn = aws_iam_policy.bastion_policy[0].arn
}

# Store bastion host information in SSM
resource "aws_ssm_parameter" "bastion_host_id" {
  count = var.enable_bastion_host ? 1 : 0

  name        = "/${var.APP}/${var.ENV}/aurora-bastion-host"
  description = "Aurora bastion host IP address"
  type        = "SecureString"
  value       = module.bastion_host[0].private_ip
  key_id      = var.secrets_manager_kms_key

  tags = {
    Application = var.APP
    Environment = var.ENV
    Component   = "aurora-bastion"
  }
}
