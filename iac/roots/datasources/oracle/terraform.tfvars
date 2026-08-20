# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

APP                           = "###APP_NAME###"
ENV                           = "###ENV_NAME###"
AWS_PRIMARY_REGION            = "###AWS_PRIMARY_REGION###"
SSM_KMS_KEY_ALIAS             = "###APP_NAME###-###ENV_NAME###-systems-manager-secret-key"
EBS_KMS_KEY_ALIAS             = "###APP_NAME###-###ENV_NAME###-ebs-secret-key"
SECRETS_MANAGER_KMS_KEY_ALIAS = "###APP_NAME###-###ENV_NAME###-secrets-manager-secret-key"
ORACLE_INSTANCE_TYPE          = "r5.2xlarge"
ORACLE_VOLUME_SIZE            = 100
ORACLE_VERSION                = "21c"
ORACLE_PORT                   = 1521
ORACLE_SID                    = "XE"
ORACLE_PDB                    = "XEPDB1"
ORACLE_USER                   = "ORACLE_USER"
