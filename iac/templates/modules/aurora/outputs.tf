# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

output "cluster_arn" {
  value       = aws_rds_cluster.aurora.arn
  description = "ARN of the rds cluster"
}

output "cluster_identifier" {
  value       = aws_rds_cluster.aurora.id
  description = "Cluster identifier of the rds cluster"
}

output "cluster_resource" {
  value       = aws_rds_cluster.aurora.cluster_resource_id
  description = "Cluster resource id of the rds cluster"
}

output "cluster_instances" {
  value       = aws_rds_cluster.aurora.cluster_members
  description = "List of instances that are part of the rds cluster"
}

output "instance_id" {
  value       = aws_rds_cluster_instance.cluster_instances[*].id
  description = "ID of the rds instances"
}

output "writer_endpoint" {
  value       = aws_rds_cluster.aurora.endpoint
  description = "The writer endpoint"
}

output "reader_endpoint" {
  value       = aws_rds_cluster.aurora.reader_endpoint
  description = "The reader endpoint"
}

# Bastion Host Outputs
output "bastion_instance_id" {
  value       = var.enable_bastion_host ? module.bastion_host[0].instance_id : null
  description = "Instance ID of the Aurora bastion host"
}

output "bastion_private_ip" {
  value       = var.enable_bastion_host ? module.bastion_host[0].private_ip : null
  description = "Private IP of the Aurora bastion host"
}

output "bastion_security_group_id" {
  value       = var.enable_bastion_host ? aws_security_group.bastion_sg[0].id : null
  description = "Security group ID of the Aurora bastion host"
}

output "bastion_connection_command" {
  value       = var.enable_bastion_host ? "aws ssm start-session --target ${module.bastion_host[0].instance_id}" : null
  description = "SSM command to connect to the bastion host"
}
