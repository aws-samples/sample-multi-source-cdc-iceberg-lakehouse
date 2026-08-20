# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

module "firehose_lambda_transformer" {

  source = "../../../../templates/modules/firehose-lambda-transformer"

  APP    = var.APP
  ENV    = var.ENV
  SOURCE = "oracle-financial"
}
