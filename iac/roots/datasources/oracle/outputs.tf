# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

output "oracle_instance_id" {

  description = "ID of the Oracle EC2 instance"
  value       = module.ec2.instance_id
}

output "oracle_private_ip" {

  description = "Private IP address of the Oracle EC2 instance"
  value       = module.ec2.private_ip
}

output "oracle_connection_string" {

  description = "Oracle database connection string"
  value       = aws_ssm_parameter.oracle_connection_string.value
  sensitive   = true
}

output "oracle_pdb_connection_string" {
  description = "Oracle pluggable database connection string"
  value       = aws_ssm_parameter.oracle_pdb_connection_string.value
  sensitive   = true
}

output "oracle_cdc_secret_arn" {

  description = "ARN of the Secrets Manager secret containing the Oracle CDC users password"
  value       = aws_secretsmanager_secret.oracle_cdc_password.arn
}

output "oracle_cdc_secret_name" {

  description = "Name of the Secrets Manager secret containing the Oracle CDC users password"
  value       = aws_secretsmanager_secret.oracle_cdc_password.name
}

output "oracle_user_secret_arn" {

  description = "ARN of the Secrets Manager secret containing the Oracle trading user password"
  value       = aws_secretsmanager_secret.oracle_user_password.arn
}

output "oracle_user_secret_name" {

  description = "Name of the Secrets Manager secret containing the Oracle trading user password"
  value       = aws_secretsmanager_secret.oracle_user_password.name
}

output "oracle_data_generator_secret_arn" {
  description = "ARN of the Secrets Manager secret containing Oracle connection details for data generator"
  value       = aws_secretsmanager_secret.oracle_data_generator_connection.arn
}

output "oracle_data_generator_secret_name" {
  description = "Name of the Secrets Manager secret containing Oracle connection details for data generator"
  value       = aws_secretsmanager_secret.oracle_data_generator_connection.name
}

output "oracle_ssm_parameters" {

  description = "List of SSM parameters created for Oracle"
  value = [
    aws_ssm_parameter.oracle_host.name,
    aws_ssm_parameter.oracle_port.name,
    aws_ssm_parameter.oracle_sid.name,
    aws_ssm_parameter.oracle_pdb.name,
    aws_ssm_parameter.oracle_connection_string.name,
    aws_ssm_parameter.oracle_pdb_connection_string.name,
  ]
}
