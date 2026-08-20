# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0


module "aurora" {
  source             = "../../../templates/modules/aurora"
  APP                = var.APP
  ENV                = var.ENV
  subnet_ids         = local.PRIVATE_SUBNETS
  security_group_ids = [aws_security_group.aurora_sg.id]
  database_name      = "equitydb"
  master_username    = "master"
  port               = "5432"
  cluster_identifier = "aurora"
  cluster_engine     = "aurora-postgresql"
  instance_class     = "db.t3.medium"
  engine_mode        = "provisioned"

  # Bastion Host Configuration
  enable_bastion_host     = var.ENABLE_BASTION_HOST
  bastion_instance_type   = var.BASTION_INSTANCE_TYPE
  vpc_id                  = local.VPC_ID
  vpc_cidr_block          = data.aws_vpc.vpc.cidr_block
  secrets_manager_kms_key = data.aws_kms_key.secrets_manager_kms_key.arn
  ssm_kms_key             = data.aws_kms_key.ssm_kms_key.arn
}
