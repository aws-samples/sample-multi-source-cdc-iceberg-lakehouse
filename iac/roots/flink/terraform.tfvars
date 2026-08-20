# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

APP    = "###APP_NAME###"
ENV    = "###ENV_NAME###"
REGION = "###AWS_PRIMARY_REGION###"

# Flink runtime + scaling defaults
FLINK_RUNTIME                = "FLINK-2_2"
FLINK_PARALLELISM            = 4
FLINK_PARALLELISM_PER_KPU    = 1
FLINK_AUTO_SCALING           = true
FLINK_LOG_LEVEL              = "INFO"
FLINK_CHECKPOINT_INTERVAL_MS = 60000
FLINK_APP_JAR_KEY            = "flink/flink-iceberg-sink-1.0-SNAPSHOT.jar"
