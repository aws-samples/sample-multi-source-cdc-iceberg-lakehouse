# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

# Lambda function to transform DMS envelope data in Firehose
module "firehose_lambda_transformer" {

  source = "../../../../templates/modules/firehose-lambda-transformer"

  APP    = var.APP
  ENV    = var.ENV
  SOURCE = "aurora-brokerage"
}
