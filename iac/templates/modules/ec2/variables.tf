# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

variable "APP" {
  type        = string
  description = "The App Name prefix"
}

variable "ENV" {
  type        = string
  description = "The name for Environment."
}

variable "instance_name" {
  type        = string
  description = "The name for the instance."
}

variable "ami_id" {
  description = "AMI of the EC2 instance. Optional, pulls latest linux AMI by default."
  type        = string
  default     = null
}

variable "instance_type" {
  description = "Type of the instance"
  type        = string
  default     = "t3.small"
}

variable "subnet_id" {
  description = "Subnet in which the instance will be deployed"
  type        = string
}

variable "vpc_security_group_ids" {
  description = "List of security group id(s) to which EC2 should be attached"
  type        = list(string)
  default     = []
}

variable "public_ip" {
  description = "Associate a public IP to the instance"
  type        = string
  default     = "false"
}

variable "user_data" {
  description = "User data of the instance"
  type        = string
  default     = ""
}

variable "key_pair_key_name" {
  description = "Key pair the instance"
  type        = string
  default     = ""
}

variable "ebs_volumes" {
  description = "List of additional EBS volumes to attach"
  type = list(object({
    device_name           = string
    volume_size           = number
    volume_type           = string
    encrypted             = bool
    kms_key_id            = string
    delete_on_termination = bool
  }))
  default = []
}
