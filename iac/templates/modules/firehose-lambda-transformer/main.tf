# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

locals {
  function_name = "${var.SOURCE}-fh-lambda-xfmr"
}

# Create a zip file with the transformer function
data "archive_file" "transformer_zip" {
  type        = "zip"
  output_path = "/tmp/${var.APP}-${var.ENV}-${local.function_name}.zip"

  source {
    content  = file("${path.module}/transformer_function.py")
    filename = "index.py"
  }
}

# Use the reusable Lambda module
module "dms_transformer_lambda" {
  source = "../lambda"

  APP           = var.APP
  ENV           = var.ENV
  function_name = local.function_name

  # Lambda configuration
  runtime     = "python3.11"
  handler     = "index.handler"
  timeout     = 60
  memory_size = 256

  # Code deployment using pre-built zip file
  deployment_method = "zip_file"
  zip_file_path     = data.archive_file.transformer_zip.output_path

  # IAM configuration - use the module's built-in role creation
  create_role = true

  environment_variables = {}

  policy_statements = []
}
