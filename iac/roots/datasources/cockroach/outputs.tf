# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0


output "cockroachdb_endpoint" {
  description = "CockroachDB SQL endpoint"
  value       = aws_ssm_parameter.cockroachdb_endpoint.value
  sensitive   = true
}

output "cockroachdb_ui_endpoint" {
  description = "CockroachDB Admin UI endpoint"
  value       = aws_ssm_parameter.cockroachdb_ui_endpoint.value
  sensitive   = true
}

output "cockroachdb_instance_ids" {
  description = "IDs of the CockroachDB EC2 instances"
  value       = aws_instance.cockroachdb[*].id
}

output "cockroachdb_security_group_id" {
  description = "ID of the CockroachDB security group"
  value       = aws_security_group.cockroachdb_sg.id
}

output "cockroachdb_nlb_dns_name" {
  description = "DNS name of the CockroachDB Network Load Balancer"
  value       = aws_lb.cockroachdb.dns_name
}

output "cockroachdb_private_ips" {
  description = "Private IP addresses of the CockroachDB instances"
  value       = aws_instance.cockroachdb[*].private_ip
}

output "ssm_session_manager_commands" {
  description = "Commands to connect to CockroachDB instances via SSM Session Manager"
  value = [
    for instance in aws_instance.cockroachdb :
    "aws ssm start-session --target ${instance.id} --region ${var.AWS_PRIMARY_REGION}"
  ]
}

output "cockroachdb_connection_info" {
  description = "CockroachDB connection information for insecure deployment"
  value = {
    load_balancer_sql = "${aws_lb.cockroachdb.dns_name}:26257"
    load_balancer_ui  = "http://${aws_lb.cockroachdb.dns_name}:8080"
    node_connections = [
      for i, ip in aws_instance.cockroachdb[*].private_ip :
      {
        node_number  = i + 1
        sql_endpoint = "${ip}:26257"
        ui_endpoint  = "http://${ip}:8080"
        ssm_command  = "aws ssm start-session --target ${aws_instance.cockroachdb[i].id} --region ${var.AWS_PRIMARY_REGION}"
      }
    ]
  }
}

output "cockroachdb_quick_start" {
  description = "Quick start commands for CockroachDB insecure deployment"
  value       = <<-EOT
    Quick Start Commands:
  
    
    1. Connect to database:
       cockroach sql --insecure --host=${aws_lb.cockroachdb.dns_name}:26257
    
    2. Access Admin UI:
       http://${aws_lb.cockroachdb.dns_name}:8080
       
  EOT
}
