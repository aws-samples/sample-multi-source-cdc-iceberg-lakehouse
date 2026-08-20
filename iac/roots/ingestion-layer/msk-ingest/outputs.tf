# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

output "msk_cluster_arn" {
  description = "ARN of the MSK cluster"
  value       = module.msk_cluster.cluster_arn
}

output "msk_cluster_name" {
  description = "Name of the MSK cluster"
  value       = module.msk_cluster.cluster_name
}

output "msk_bootstrap_brokers_tls" {
  description = "TLS connection host:port pairs"
  value       = module.msk_cluster.bootstrap_brokers_tls
}

output "msk_bootstrap_brokers_sasl_scram" {
  description = "SASL/SCRAM connection host:port pairs"
  value       = module.msk_cluster.bootstrap_brokers_sasl_scram
}

output "msk_bootstrap_brokers_sasl_iam" {
  description = "SASL/IAM connection host:port pairs"
  value       = module.msk_cluster.bootstrap_brokers_sasl_iam
}

output "msk_zookeeper_connect_string" {
  description = "Zookeeper connection string"
  value       = module.msk_cluster.zookeeper_connect_string
}

output "msk_secrets_manager_secret_arn" {
  description = "ARN of the Secrets Manager secret containing SASL/SCRAM credentials"
  value       = module.msk_cluster.secrets_manager_secret_arn
}

output "msk_cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = module.msk_cluster.cloudwatch_log_group_name
}

output "msk_instance_id" {
  description = "ID of the MSK configuration EC2 instance"
  value       = module.ec2.instance_id
}

output "msk_instance_private_ip" {
  description = "Private IP address of the MSK configuration EC2 instance"
  value       = module.ec2.private_ip
}

output "msk_instance_host_parameter" {
  description = "SSM parameter name containing the MSK ingest config host IP"
  value       = aws_ssm_parameter.msk_instance_host.name
}
