# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0


# Get VPC and subnet information from SSM parameters
data "aws_ssm_parameter" "vpc_id" {
  name = "/${var.APP}/${var.ENV}/vpc-id"
}

data "aws_vpc" "main" {
  id = data.aws_ssm_parameter.vpc_id.value
}

data "aws_ssm_parameter" "private_subnet_ids" {
  name = "/${var.APP}/${var.ENV}/vpc-private-subnet-ids"
}

data "aws_ssm_parameter" "availability_zone_names" {
  name = "/${var.APP}/${var.ENV}/vpc-availability-zone-names"
}

# Get KMS key for EBS encryption
data "aws_kms_key" "ebs_kms_key" {
  key_id = "alias/${var.EBS_KMS_KEY_ALIAS}"
}

# Get KMS key for SSM parameters
data "aws_kms_key" "ssm_kms_key" {
  key_id = "alias/${var.APP}-${var.ENV}-systems-manager-secret-key"
}

# Get latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_ssm_parameter" "cockroachdb_role_arn" {
  name = "/${var.APP}/${var.ENV}/cockroachdb-role-arn"
}

data "aws_ssm_parameter" "cockroachdb_role_name" {
  name = "/${var.APP}/${var.ENV}/cockroachdb-role-name"
}

data "aws_ssm_parameter" "cockroachdb_instance_profile_name" {
  name = "/${var.APP}/${var.ENV}/cockroachdb-instance-profile-name"
}

data "aws_ssm_parameter" "cockroachdb_instance_profile_arn" {
  name = "/${var.APP}/${var.ENV}/cockroachdb-instance-profile-arn"
}

data "aws_iam_role" "cockroach_db_role" {
  name = data.aws_ssm_parameter.cockroachdb_role_name.value
}

locals {
  cluster_name = "${var.APP}-${var.ENV}-msk-source-cluster"
}

locals {
  private_subnet_ids = split(",", data.aws_ssm_parameter.private_subnet_ids.value)
  availability_zones = split(",", data.aws_ssm_parameter.availability_zone_names.value)

  # For single AZ deployment, use only the first subnet and AZ
  cockroach_subnet_id = local.private_subnet_ids[0]
  cockroach_az        = local.availability_zones[0]
}
