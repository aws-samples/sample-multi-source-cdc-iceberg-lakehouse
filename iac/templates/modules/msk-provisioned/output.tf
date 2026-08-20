# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0


output "zookeeper_connect_string" {
  description = "Zookeeper connection string"
  value       = aws_msk_cluster.cluster.zookeeper_connect_string
}

output "bootstrap_brokers_tls" {
  description = "TLS connection host:port pairs"
  value       = aws_msk_cluster.cluster.bootstrap_brokers_tls
}

output "bootstrap_brokers_sasl_scram" {
  description = "SASL/SCRAM connection host:port pairs"
  value       = aws_msk_cluster.cluster.bootstrap_brokers_sasl_scram
}

output "bootstrap_brokers_sasl_iam" {
  description = "SASL/IAM connection host:port pairs"
  value       = aws_msk_cluster.cluster.bootstrap_brokers_sasl_iam
}

output "cluster_arn" {
  description = "Amazon Resource Name (ARN) of the MSK cluster"
  value       = aws_msk_cluster.cluster.arn
}

output "cluster_name" {
  description = "Name of the MSK cluster"
  value       = aws_msk_cluster.cluster.cluster_name
}

output "kms_key_arn" {
  description = "ARN of the Kafka KMS key used for encryption"
  value       = var.KAFKA_KMS_KEY_ARN
}

output "secrets_manager_secret_arn" {
  description = "ARN of the Secrets Manager secret containing SASL/SCRAM credentials"
  value       = try(aws_secretsmanager_secret.msk_secret[0].arn, null)
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.msk_logs.name
}
