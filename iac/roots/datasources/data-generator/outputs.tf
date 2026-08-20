# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

output "oracle_integration_enabled" {
  description = "Whether Oracle integration is enabled"
  value       = var.ENABLE_ORACLE_INTEGRATION
}

output "aurora_integration_enabled" {
  description = "Whether Aurora integration is enabled"
  value       = var.ENABLE_AURORA_INTEGRATION
}

output "msk_integration_enabled" {
  description = "Whether MSK integration is enabled"
  value       = var.ENABLE_MSK_INTEGRATION
}

output "cockroach_integration_enabled" {
  description = "Whether Cockroach integration is enabled"
  value       = var.ENABLE_COCKROACH_INTEGRATION
}

output "data_generator_instance_id" {
  description = "ID of the data generator EC2 instance"
  value       = module.ec2.instance_id
}

output "data_generator_private_ip" {
  description = "Private IP address of the data generator EC2 instance"
  value       = module.ec2.private_ip
}
