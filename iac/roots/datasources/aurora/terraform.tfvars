# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

APP    = "###APP_NAME###"
ENV    = "###ENV_NAME###"
REGION = "###AWS_PRIMARY_REGION###"

# Bastion Host Configuration
# Set to true to deploy a bastion host for Aurora access via SSM Session Manager
ENABLE_BASTION_HOST   = true
BASTION_INSTANCE_TYPE = "t3.micro"
