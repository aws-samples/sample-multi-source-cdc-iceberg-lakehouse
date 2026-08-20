# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

data "aws_ami" "amazon_linux_2" {

  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

module "ec2" {

  source                 = "../../../templates/modules/ec2"
  APP                    = var.APP
  ENV                    = var.ENV
  ami_id                 = data.aws_ami.amazon_linux_2.id
  instance_name          = "oracle"
  instance_type          = var.ORACLE_INSTANCE_TYPE
  subnet_id              = split(",", data.aws_ssm_parameter.private_subnet_ids.value)[0]
  vpc_security_group_ids = [aws_security_group.oracle_sg.id]

  ebs_volumes = [
    {
      device_name           = "/dev/sdb"
      volume_type           = "gp3"
      volume_size           = var.ORACLE_VOLUME_SIZE
      kms_key_id            = data.aws_kms_key.ebs_kms_key.arn
      encrypted             = true
      delete_on_termination = true
    }
  ]

  user_data = base64gzip(templatefile("${path.module}/scripts/user_data.sh", {
    ORACLE_SID                      = var.ORACLE_SID,
    ORACLE_PDB                      = var.ORACLE_PDB,
    ORACLE_USER                     = var.ORACLE_USER,
    ORACLE_PORT                     = var.ORACLE_PORT,
    ORACLE_VERSION                  = var.ORACLE_VERSION,
    AWS_REGION                      = var.AWS_PRIMARY_REGION,
    ORACLE_CDC_PASSWORD_SECRET_ARN  = aws_secretsmanager_secret.oracle_cdc_password.arn,
    ORACLE_USER_PASSWORD_SECRET_ARN = aws_secretsmanager_secret.oracle_user_password.arn,
  }))

  depends_on = [aws_secretsmanager_secret_version.oracle_cdc_password]
}

# Attach additional IAM policies to the EC2 module's role for Secrets Manager access
resource "aws_iam_role_policy" "oracle_secrets_manager_policy" {

  name = "${var.APP}-${var.ENV}-oracle-secrets-manager-policy"
  role = module.ec2.iam_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        // nosemgrep:
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:PutSecretValue",
          "secretsmanager:UpdateSecret"
        ]
        Effect = "Allow"
        Resource = [
          aws_secretsmanager_secret.oracle_cdc_password.arn,
          aws_secretsmanager_secret.oracle_user_password.arn,
          aws_secretsmanager_secret.oracle_data_generator_connection.arn
        ]
      },
      {
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ]
        Effect   = "Allow"
        Resource = data.aws_kms_key.secrets_manager_kms_key.arn
      },
      {
        Action = [
          "secretsmanager:ListSecrets"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# Store Oracle connection information in SSM Parameter Store
resource "aws_ssm_parameter" "oracle_host" {

  name        = "/${var.APP}/${var.ENV}/oracle-host"
  description = "Oracle database host"
  type        = "SecureString"
  value       = module.ec2.private_ip
  key_id      = data.aws_kms_key.ssm_kms_key.arn

  tags = local.tags
}

resource "aws_ssm_parameter" "oracle_port" {

  name        = "/${var.APP}/${var.ENV}/oracle-port"
  description = "Oracle database port"
  type        = "SecureString"
  value       = tostring(var.ORACLE_PORT)
  key_id      = data.aws_kms_key.ssm_kms_key.arn

  tags = local.tags
}

resource "aws_ssm_parameter" "oracle_sid" {

  name        = "/${var.APP}/${var.ENV}/oracle-sid"
  description = "Oracle database SID"
  type        = "SecureString"
  value       = var.ORACLE_SID # Oracle XE uses XE as the SID
  key_id      = data.aws_kms_key.ssm_kms_key.arn

  tags = local.tags
}

resource "aws_ssm_parameter" "oracle_pdb" {

  name        = "/${var.APP}/${var.ENV}/oracle-pdb"
  description = "Oracle pluggable database name"
  type        = "SecureString"
  value       = var.ORACLE_PDB
  key_id      = data.aws_kms_key.ssm_kms_key.arn

  tags = local.tags
}

resource "aws_ssm_parameter" "oracle_connection_string" {

  name        = "/${var.APP}/${var.ENV}/oracle-connection-string"
  description = "Oracle database connection string"
  type        = "SecureString"
  value       = "(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=${module.ec2.private_ip})(PORT=${var.ORACLE_PORT}))(CONNECT_DATA=(SID=${var.ORACLE_SID})))"
  key_id      = data.aws_kms_key.ssm_kms_key.arn

  tags = local.tags
}

resource "aws_ssm_parameter" "oracle_pdb_connection_string" {

  name        = "/${var.APP}/${var.ENV}/oracle-pdb-connection-string"
  description = "Oracle pluggable database connection string"
  type        = "SecureString"
  value       = "(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=${module.ec2.private_ip})(PORT=${var.ORACLE_PORT}))(CONNECT_DATA=(SERVICE_NAME=${var.ORACLE_PDB})))"
  key_id      = data.aws_kms_key.ssm_kms_key.arn

  tags = local.tags
}

resource "aws_ssm_parameter" "oracle_user" {

  name        = "/${var.APP}/${var.ENV}/oracle-user"
  description = "Oracle user name for application data access"
  type        = "SecureString"
  value       = var.ORACLE_USER
  key_id      = data.aws_kms_key.ssm_kms_key.arn

  tags = local.tags
}
