# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

# Combined DMS Outputs (handles both financial and brokerage transactions)
output "financial_replication_instance_arn" {
  description = "ARN of the Aurora DMS replication instance (handles financial transactions)"
  value       = module.aurora_dms.replication_instance_arn
}

output "financial_replication_instance_id" {
  description = "ID of the Aurora DMS replication instance (handles financial transactions)"
  value       = module.aurora_dms.replication_instance_id
}

output "financial_source_endpoint_arn" {
  description = "ARN of the Aurora source endpoint (handles financial transactions)"
  value       = module.aurora_dms.source_endpoint_arn
}

output "financial_source_endpoint_id" {
  description = "ID of the Aurora source endpoint (handles financial transactions)"
  value       = module.aurora_dms.source_endpoint_id
}

output "financial_msk_target_endpoint_arn" {
  description = "ARN of the MSK target endpoint for Aurora (handles financial transactions)"
  value       = module.aurora_dms.msk_target_endpoint_arn
}

output "financial_msk_target_endpoint_id" {
  description = "ID of the MSK target endpoint for Aurora (handles financial transactions)"
  value       = module.aurora_dms.msk_target_endpoint_id
}

output "financial_replication_task_arn" {
  description = "ARN of the Aurora to MSK replication task (handles financial transactions)"
  value       = module.aurora_dms.replication_task_arn
}

output "financial_replication_task_id" {
  description = "ID of the Aurora to MSK replication task (handles financial transactions)"
  value       = module.aurora_dms.replication_task_id
}

# Brokerage Transactions DMS Outputs (same as financial since using combined module)
output "brokerage_replication_instance_arn" {
  description = "ARN of the Aurora DMS replication instance (handles brokerage transactions)"
  value       = module.aurora_dms.replication_instance_arn
}

output "brokerage_replication_instance_id" {
  description = "ID of the Aurora DMS replication instance (handles brokerage transactions)"
  value       = module.aurora_dms.replication_instance_id
}

output "brokerage_source_endpoint_arn" {
  description = "ARN of the Aurora source endpoint (handles brokerage transactions)"
  value       = module.aurora_dms.source_endpoint_arn
}

output "brokerage_source_endpoint_id" {
  description = "ID of the Aurora source endpoint (handles brokerage transactions)"
  value       = module.aurora_dms.source_endpoint_id
}

output "brokerage_msk_target_endpoint_arn" {
  description = "ARN of the MSK target endpoint for Aurora (handles brokerage transactions)"
  value       = module.aurora_dms.msk_target_endpoint_arn
}

output "brokerage_msk_target_endpoint_id" {
  description = "ID of the MSK target endpoint for Aurora (handles brokerage transactions)"
  value       = module.aurora_dms.msk_target_endpoint_id
}

output "brokerage_replication_task_arn" {
  description = "ARN of the Aurora to MSK replication task (handles brokerage transactions)"
  value       = module.aurora_dms.replication_task_arn
}

output "brokerage_replication_task_id" {
  description = "ID of the Aurora to MSK replication task (handles brokerage transactions)"
  value       = module.aurora_dms.replication_task_id
}
