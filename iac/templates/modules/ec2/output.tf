# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

output "arn" {
  description = "ARN of the instance"
  value       = aws_instance.ec2.arn
}

output "private_dns" {
  description = "Private DNS of the instance"
  value       = aws_instance.ec2.private_dns
}

output "public_ip" {
  description = "Public IP of the instance"
  value       = aws_instance.ec2.public_ip
}

output "public_dns" {
  description = "Public DNS of the instance"
  value       = aws_instance.ec2.public_dns
}

output "iam_role_arn" {
  description = "ARN of EC2 IAM role"
  value       = aws_iam_role.ec2_iam_role.arn
}

output "iam_role_name" {
  description = "Name of EC2 IAM role"
  value       = aws_iam_role.ec2_iam_role.name
}

output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.ec2.id
}

output "private_ip" {
  description = "Private IP address of the EC2 instance"
  value       = aws_instance.ec2.private_ip
}

output "root_block_device" {
  description = "Root block device information"
  value       = aws_instance.ec2.root_block_device
}

output "ebs_block_devices" {
  description = "EBS block devices information"
  value       = aws_instance.ec2.ebs_block_device
}


