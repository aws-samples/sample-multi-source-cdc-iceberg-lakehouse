# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

# DMS Replication Instance
resource "aws_dms_replication_instance" "main" {

  allocated_storage           = var.dms_allocated_storage
  apply_immediately           = var.dms_apply_immediately
  auto_minor_version_upgrade  = var.dms_auto_minor_version_upgrade
  engine_version              = var.dms_engine_version
  kms_key_arn                 = data.aws_kms_key.dms_kms_key.arn
  multi_az                    = var.dms_multi_az
  publicly_accessible         = var.dms_publicly_accessible
  replication_instance_class  = var.dms_replication_instance_class
  replication_instance_id     = "${local.name_prefix}-${var.replication_instance_suffix}-replication-instance"
  replication_subnet_group_id = aws_dms_replication_subnet_group.main.id

  vpc_security_group_ids = [
    data.aws_ssm_parameter.vpc_sg.value
  ]

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-${var.replication_instance_suffix}-replication-instance"
  })
}
