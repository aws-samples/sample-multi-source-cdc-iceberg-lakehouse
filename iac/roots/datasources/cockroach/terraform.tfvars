# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0


APP                    = "###APP_NAME###"
ENV                    = "###ENV_NAME###"
AWS_PRIMARY_REGION     = "###AWS_PRIMARY_REGION###"
EBS_KMS_KEY_ALIAS      = "###APP_NAME###-###ENV_NAME###-ebs-secret-key"
INSTANCE_TYPE          = "m6i.xlarge"
MGMT_INSTANCE_TYPE     = "t3.medium"
NODE_COUNT             = 3
DATA_VOLUME_SIZE       = 200
KEY_NAME               = ""             # Optional - SSM Session Manager is used for access
SSH_CIDR_BLOCK         = "10.38.0.0/16" # Match VPC CIDR
APPLICATION_CIDR_BLOCK = "10.38.0.0/16" # Match VPC CIDR
ADMIN_UI_CIDR_BLOCK    = "10.38.0.0/16" # Match VPC CIDR
