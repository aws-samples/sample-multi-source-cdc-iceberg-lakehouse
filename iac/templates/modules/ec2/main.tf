# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

data "aws_iam_policy_document" "ec2_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy" "ssm" {
  name = "AmazonSSMManagedInstanceCore"
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "name"
    values = ["al2023-ami-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_iam_role" "ec2_iam_role" {
  name_prefix        = "${var.APP}-${var.ENV}-${var.instance_name}-"
  assume_role_policy = data.aws_iam_policy_document.ec2_role_policy.json
}

resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ec2_iam_role.name
  policy_arn = data.aws_iam_policy.ssm.arn
}

resource "aws_iam_instance_profile" "instance_profile" {
  name_prefix = "${var.APP}-${var.ENV}-${var.instance_name}-p-"
  role        = aws_iam_role.ec2_iam_role.name
}

resource "aws_instance" "ec2" {
  ami                         = var.ami_id != null ? var.ami_id : data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  associate_public_ip_address = var.public_ip
  iam_instance_profile        = aws_iam_instance_profile.instance_profile.name
  key_name                    = var.key_pair_key_name
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = var.vpc_security_group_ids
  ebs_optimized               = true
  monitoring                  = true
  user_data_base64            = base64encode(var.user_data)
  user_data_replace_on_change = true

  tags = {
    "Name" = "${var.APP}-${var.ENV}-${var.instance_name}"
  }

  root_block_device {
    encrypted = true
  }

  # Dynamic additional EBS volumes
  dynamic "ebs_block_device" {
    for_each = var.ebs_volumes
    content {
      device_name           = ebs_block_device.value.device_name
      volume_size           = ebs_block_device.value.volume_size
      volume_type           = ebs_block_device.value.volume_type
      encrypted             = ebs_block_device.value.encrypted
      kms_key_id            = ebs_block_device.value.kms_key_id
      delete_on_termination = ebs_block_device.value.delete_on_termination
    }
  }

  metadata_options {
    http_endpoint          = "enabled"
    http_tokens            = "required"
    instance_metadata_tags = "enabled"
  }
}
