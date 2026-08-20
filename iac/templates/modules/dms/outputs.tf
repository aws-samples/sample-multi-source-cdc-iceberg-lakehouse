# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

output "replication_instance_arn" {
  description = "ARN of the DMS replication instance"
  value       = aws_dms_replication_instance.main.replication_instance_arn
}

output "replication_instance_id" {
  description = "ID of the DMS replication instance"
  value       = aws_dms_replication_instance.main.replication_instance_id
}

output "source_endpoint_arn" {
  description = "ARN of the source endpoint"
  value       = aws_dms_endpoint.source.endpoint_arn
}

output "source_endpoint_id" {
  description = "ID of the source endpoint"
  value       = aws_dms_endpoint.source.endpoint_id
}

output "msk_target_endpoint_arn" {
  description = "ARN of the MSK target endpoint"
  value       = aws_dms_endpoint.msk_target.endpoint_arn
}

output "msk_target_endpoint_id" {
  description = "ID of the MSK target endpoint"
  value       = aws_dms_endpoint.msk_target.endpoint_id
}

output "replication_task_arn" {
  description = "ARN of the DMS replication task"
  value       = aws_dms_replication_task.main.replication_task_arn
}

output "replication_task_id" {
  description = "ID of the DMS replication task"
  value       = aws_dms_replication_task.main.replication_task_id
}

output "subnet_group_id" {
  description = "ID of the DMS subnet group"
  value       = aws_dms_replication_subnet_group.main.id
}
