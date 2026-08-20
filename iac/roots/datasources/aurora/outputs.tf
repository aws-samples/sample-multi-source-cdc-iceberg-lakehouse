# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0


# Aurora Cluster Outputs
output "cluster_arn" {
  value       = module.aurora.cluster_arn
  description = "ARN of the Aurora cluster"
}

output "cluster_identifier" {
  value       = module.aurora.cluster_identifier
  description = "Cluster identifier of the Aurora cluster"
}

output "writer_endpoint" {
  value       = module.aurora.writer_endpoint
  description = "Aurora cluster writer endpoint"
}

output "reader_endpoint" {
  value       = module.aurora.reader_endpoint
  description = "Aurora cluster reader endpoint"
}

# Bastion Host Outputs (conditional)
output "bastion_instance_id" {
  value       = module.aurora.bastion_instance_id
  description = "Instance ID of the Aurora bastion host (null if not deployed)"
}

output "bastion_connection_command" {
  value       = module.aurora.bastion_connection_command
  description = "SSM command to connect to the bastion host (null if not deployed)"
}

output "bastion_enabled" {
  value       = var.ENABLE_BASTION_HOST
  description = "Whether the bastion host is enabled"
}
