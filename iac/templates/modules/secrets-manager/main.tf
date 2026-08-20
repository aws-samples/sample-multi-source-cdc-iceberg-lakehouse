# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

resource "aws_secretsmanager_secret" "secret" {
  #checkov:skip=CKV2_AWS_57:Automatic rotation not required for this sample
  name                    = "${var.APP}-${var.ENV}-${var.SECRET_NAME}"
  recovery_window_in_days = var.RECOVERY_WINDOW
  kms_key_id              = var.KMS_KEY_ARN
}

resource "aws_secretsmanager_secret_version" "version" {
  secret_id     = aws_secretsmanager_secret.secret.id
  secret_string = var.SECRET_STRING
}
