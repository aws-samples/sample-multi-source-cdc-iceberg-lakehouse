# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

# -----------------------------------------------------------------------------
# Lake Formation grants for the Flink role.
#
# Grants DESCRIBE on databases and SELECT/INSERT/DELETE on the fin + brk tables
# in each Path 2 (c_*) Glue database so Flink can read schema and write data.
# -----------------------------------------------------------------------------

locals {
  # Tables Flink writes to: each c_* database has a `fin` and `brk` table
  flink_table_grants = {
    for pair in flatten([
      for app_key, app in local.apps : [
        { key = "${app_key}_fin", database = app.db, table = "fin" },
        { key = "${app_key}_brk", database = app.db, table = "brk" },
      ]
    ]) : pair.key => pair
  }
}

# Database-level DESCRIBE so Flink can list tables
resource "aws_lakeformation_permissions" "flink_database" {
  for_each = local.apps

  principal   = aws_iam_role.flink_role.arn
  permissions = ["DESCRIBE"]

  database {
    name = each.value.db
  }
}

# Table-level SELECT/INSERT/DELETE on fin + brk for each database
resource "aws_lakeformation_permissions" "flink_table" {
  for_each = local.flink_table_grants

  principal   = aws_iam_role.flink_role.arn
  permissions = ["SELECT", "INSERT", "DELETE", "DESCRIBE", "ALTER"]

  table {
    database_name = each.value.database
    name          = each.value.table
  }
}
