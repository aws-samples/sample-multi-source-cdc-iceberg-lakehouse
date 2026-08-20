# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

# Default MSK task settings (without ValidationSettings which are not supported for Kafka endpoints)
locals {
  default_msk_task_settings = jsonencode({
    "TargetMetadata" = {
      "TargetSchema"                 = ""
      "SupportLobs"                  = true
      "FullLobMode"                  = false
      "LobChunkSize"                 = 0
      "LimitedSizeLobMode"           = true
      "LobMaxSize"                   = 32
      "InlineLobMaxSize"             = 0
      "LoadMaxFileSize"              = 0
      "ParallelLoadThreads"          = 0
      "ParallelLoadBufferSize"       = 0
      "BatchApplyEnabled"            = false
      "TaskRecoveryTableEnabled"     = false
      "ParallelApplyThreads"         = 32
      "ParallelApplyBufferSize"      = 1000
      "ParallelApplyQueuesPerThread" = 100
    }
    "FullLoadSettings" = {
      "TargetTablePrepMode"             = "DROP_AND_CREATE"
      "CreatePkAfterFullLoad"           = false
      "StopTaskCachedChangesApplied"    = false
      "StopTaskCachedChangesNotApplied" = false
      "MaxFullLoadSubTasks"             = 8
      "TransactionConsistencyTimeout"   = 600
      "CommitRate"                      = 10000
    }
    "Logging" = {
      "EnableLogging" = true
      "LogComponents" = [
        {
          "Id"       = "TRANSFORMATION"
          "Severity" = "LOGGER_SEVERITY_DEFAULT"
        },
        {
          "Id"       = "SOURCE_UNLOAD"
          "Severity" = "LOGGER_SEVERITY_DEFAULT"
        },
        {
          "Id"       = "TARGET_LOAD"
          "Severity" = "LOGGER_SEVERITY_DEFAULT"
        }
      ]
    }
    "ControlTablesSettings" = {
      "historyTimeslotInMinutes"      = 5
      "ControlSchema"                 = ""
      "HistoryTimeslotInMinutes"      = 5
      "HistoryTableEnabled"           = false
      "SuspendedTablesTableEnabled"   = false
      "StatusTableEnabled"            = false
      "FullLoadExceptionTableEnabled" = false
    }
    "StreamBufferSettings" = {
      "StreamBufferCount"        = 8
      "StreamBufferSizeInMB"     = 64
      "CtrlStreamBufferSizeInMB" = 8
    }
    "ChangeProcessingDdlHandlingPolicy" = {
      "HandleSourceTableDropped"   = true
      "HandleSourceTableTruncated" = true
      "HandleSourceTableAltered"   = true
    }
    "ErrorBehavior" = {
      "DataErrorPolicy"                             = "LOG_ERROR"
      "DataTruncationErrorPolicy"                   = "LOG_ERROR"
      "DataErrorEscalationPolicy"                   = "SUSPEND_TABLE"
      "DataErrorEscalationCount"                    = 0
      "TableErrorPolicy"                            = "SUSPEND_TABLE"
      "TableErrorEscalationPolicy"                  = "STOP_TASK"
      "TableErrorEscalationCount"                   = 0
      "RecoverableErrorCount"                       = -1
      "RecoverableErrorInterval"                    = 5
      "RecoverableErrorThrottling"                  = true
      "RecoverableErrorThrottlingMax"               = 1800
      "RecoverableErrorStopRetryAfterThrottlingMax" = true
      "ApplyErrorDeletePolicy"                      = "IGNORE_RECORD"
      "ApplyErrorInsertPolicy"                      = "LOG_ERROR"
      "ApplyErrorUpdatePolicy"                      = "LOG_ERROR"
      "ApplyErrorEscalationPolicy"                  = "LOG_ERROR"
      "ApplyErrorEscalationCount"                   = 0
      "ApplyErrorFailOnTruncationDdl"               = false
      "FullLoadIgnoreConflicts"                     = true
      "FailOnTransactionConsistencyBreached"        = false
      "FailOnNoTablesCaptured"                      = false
    }
    "ChangeProcessingTuning" = {
      "BatchApplyPreserveTransaction" = false
      "BatchApplyTimeoutMin"          = 1
      "BatchApplyTimeoutMax"          = 30
      "BatchApplyMemoryLimit"         = 2000
      "BatchSplitSize"                = 0
      "MinTransactionSize"            = 1000
      "CommitTimeout"                 = 120
      "MemoryLimitTotal"              = 8192
      "MemoryKeepTime"                = 900
      "StatementCacheSize"            = 200
    }
    "PostProcessingRules"        = null
    "CharacterSetSettings"       = null
    "LoopbackPreventionSettings" = null
    "BeforeImageSettings"        = null
  })
}

# DMS Replication Task
resource "aws_dms_replication_task" "main" {

  migration_type           = var.migration_type
  replication_instance_arn = aws_dms_replication_instance.main.replication_instance_arn
  replication_task_id      = "${local.name_prefix}-${var.replication_instance_suffix}-to-msk-task"
  source_endpoint_arn      = aws_dms_endpoint.source.endpoint_arn
  target_endpoint_arn      = aws_dms_endpoint.msk_target.endpoint_arn

  table_mappings            = var.table_mappings
  replication_task_settings = var.replication_task_settings != null ? var.replication_task_settings : local.default_msk_task_settings

  start_replication_task = var.start_replication_task

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-${var.replication_instance_suffix}-to-msk-replication-task"
  })
}
