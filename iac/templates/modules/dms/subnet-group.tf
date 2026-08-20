# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

# DMS Replication Subnet Group
resource "aws_dms_replication_subnet_group" "main" {

  replication_subnet_group_description = "DMS replication subnet group for ${var.APP}-${var.ENV}-${var.replication_instance_suffix} instance"
  replication_subnet_group_id          = "${var.APP}-${var.ENV}-dms-subnet-group-${var.replication_instance_suffix}"

  subnet_ids = split(",", data.aws_ssm_parameter.private_subnet_ids.value)

  tags = merge(local.tags, {
    Name = "${var.APP}-${var.ENV}-dms-subnet-group-${var.replication_instance_suffix}"
  })
}
