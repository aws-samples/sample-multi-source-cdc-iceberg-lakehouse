# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

terraform {
  required_version = ">= 1.8.0"
}

# -----------------------------------------------------------------------------
# Managed Flink Applications (Path 2)
#
# One application per data source (oracle, aurora, cockroach, msk_source).
# Each consumes financial + brokerage topics from MSK Ingest (IAM auth) and
# writes to its own Glue-catalogued Iceberg database (`fin` + `brk` tables).
#
# Per-app config (topics, db, main class) lives in `local.apps` (lookup.tf).
# -----------------------------------------------------------------------------

resource "time_sleep" "iam_propagation" {
  depends_on      = [aws_iam_role_policy.flink_policy]
  create_duration = "30s"
}

resource "aws_kinesisanalyticsv2_application" "flink" {
  for_each = local.apps
  provider = aws.no_default_tags

  depends_on = [time_sleep.iam_propagation]

  name                   = "${var.APP}-${var.ENV}-flink-${each.key}"
  runtime_environment    = var.FLINK_RUNTIME
  service_execution_role = aws_iam_role.flink_role.arn
  start_application      = true
  application_configuration {

    # ---- Application code: JAR in assets bucket -----------------------------
    application_code_configuration {
      code_content_type = "ZIPFILE"
      code_content {
        s3_content_location {
          bucket_arn = "arn:aws:s3:::${local.assets_bucket_name}"
          file_key   = var.FLINK_APP_JAR_KEY
        }
      }
    }

    # ---- Environment properties (3 groups per app) --------------------------
    environment_properties {
      property_group {
        property_group_id = "KafkaSource"
        property_map = {
          "bootstrap.servers" = each.value.bootstrap_servers
          "topic.financial"   = each.value.topic_financial
          "topic.brokerage"   = each.value.topic_brokerage
          "group.id"          = "${var.APP}-${var.ENV}-flink-${each.key}"
        }
      }
      property_group {
        property_group_id = "IcebergSink"
        property_map = {
          "warehouse"          = local.iceberg_warehouse
          "database"           = each.value.db
          "table.financial"    = "fin"
          "table.brokerage"    = "brk"
          "s3tables.warehouse" = local.s3_table_bucket_arn
          "s3tables.database"  = each.value.s3_tables_db
        }
      }
      property_group {
        property_group_id = "FlinkApp"
        property_map = {
          "main.class"             = each.value.main_class
          "checkpoint.interval.ms" = tostring(var.FLINK_CHECKPOINT_INTERVAL_MS)
        }
      }
    }

    # ---- Flink runtime configuration ----------------------------------------
    flink_application_configuration {
      parallelism_configuration {
        configuration_type   = "CUSTOM"
        parallelism          = var.FLINK_PARALLELISM
        parallelism_per_kpu  = var.FLINK_PARALLELISM_PER_KPU
        auto_scaling_enabled = var.FLINK_AUTO_SCALING
      }

      # Use service defaults for checkpointing (exactly-once, 60s default cadence)
      checkpoint_configuration {
        configuration_type = "DEFAULT"
      }

      monitoring_configuration {
        configuration_type = "CUSTOM"
        log_level          = var.FLINK_LOG_LEVEL
        metrics_level      = "APPLICATION"
      }
    }

    # ---- VPC attachment (needed to reach MSK Ingest) ------------------------
    vpc_configuration {
      subnet_ids         = local.private_subnet_ids
      security_group_ids = [aws_security_group.flink.id]
    }
  }

  # ---- CloudWatch logging ---------------------------------------------------
  cloudwatch_logging_options {
    log_stream_arn = aws_cloudwatch_log_stream.flink[each.key].arn
  }

  # Note: tags intentionally omitted from resource creation due to an AWS
  # Kinesis Analytics V2 bug where orphaned tag registrations linger after
  # failed creates, causing ConcurrentModificationException on recreate.
  # default_tags from the provider still apply (Application, Environment).
}
