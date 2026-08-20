# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

.PHONY: help deploy-% destroy-% start-% stop-% setup-% clean-% build-% upload-% connect-% generate-%

## Show available targets
help:
	@echo "Usage: make <target> [args=\"...\"]"
	@echo ""
	@echo "=== End-to-End ==="
	@echo "  deploy-infra-all          Deploy everything (foundation → datasources → ingestion → flink)"
	@echo "  destroy-infra-all         Destroy everything (reverse order)"
	@echo ""
	@echo "=== Foundation ==="
	@echo "  deploy-foundation         IAM, KMS, S3, VPC, Glue DBs, Athena, S3 Tables, Lake Formation"
	@echo "  deploy-tf-backend-cf-stack  Create Terraform state S3 backend"
	@echo ""
	@echo "=== Data Sources ==="
	@echo "  deploy-datasources        Oracle, CockroachDB, Aurora, MSK Source, Data Generator"
	@echo "  setup-source-tables       Create empty tables on all sources (run before DMS/changefeeds)"
	@echo ""
	@echo "=== Path 1: Firehose ==="
	@echo "  deploy-path1              DMS + all Firehose streams"
	@echo "  start-dms-tasks           Start DMS CDC replication"
	@echo ""
	@echo "=== Path 2: Flink ==="
	@echo "  deploy-path2              Debezium connectors + Flink applications"
	@echo "  setup-cockroachdb-changefeeds  Create CockroachDB → MSK changefeeds"
	@echo "  deploy-flink-all          Build JAR, upload, deploy Terraform"
	@echo ""
	@echo "=== Data Generation ==="
	@echo "  generate-data             Generate test data (use args=\"--help\" for options)"
	@echo ""
	@echo "=== Connectivity ==="
	@echo "  connect-to-oracle         SSM session to Oracle EC2"
	@echo "  connect-to-aurora         SSM session to Aurora bastion"
	@echo "  connect-to-cockroach      SSM session to CockroachDB node-1"
	@echo "  connect-to-data-generator SSM session to data generator EC2"
	@echo ""
	@echo "Run 'make <target> args=\"--help\"' for target-specific options."

# Load .env if present (creates APP_NAME, ENV_NAME, AWS_ACCOUNT_ID)
ifneq (,$(wildcard .env))
  include .env
  export
endif

# Required vars (will fail at first use if missing)
APP_NAME ?= $(error APP_NAME is required — copy .env.example to .env and set values)
ENV_NAME ?= $(error ENV_NAME is required — copy .env.example to .env and set values)
AWS_ACCOUNT_ID ?= $(error AWS_ACCOUNT_ID is required — copy .env.example to .env and set values)
LAKE_FORMATION_ADMIN_ROLE ?= $(error LAKE_FORMATION_ADMIN_ROLE is required — set in .env to the IAM role used to deploy this project)

# Defaults for derived/region vars (override via shell export if needed)
AWS_PRIMARY_REGION ?= us-east-1
AWS_DEFAULT_REGION ?= $(AWS_PRIMARY_REGION)
TF_S3_BACKEND_NAME ?= $(APP_NAME)-$(ENV_NAME)-tf-back-end

export APP_NAME ENV_NAME AWS_ACCOUNT_ID
export AWS_PRIMARY_REGION AWS_DEFAULT_REGION
export TF_S3_BACKEND_NAME

#################### Global Constants ####################

# MSK Connect Plugin Versions
DEBEZIUM_VERSION = 2.5.0.Final
PLUGIN_BUCKET_NAME = $(APP_NAME)-$(ENV_NAME)-msk-connect-plugins-primary

# Terraform apply with single retry on failure (handles IAM propagation delays)
define tf_apply_with_retry
	scripts/tf.sh $(1) $(args) || \
	(echo "⟳ Retrying $(1) in 30s..." && sleep 30 && \
	scripts/tf.sh $(1) $(args))
endef

deploy-tf-backend-cf-stack:
	@scripts/deploy-tf-backend.sh

destroy-tf-backend-cf-stack:
	@scripts/empty-s3.sh empty_s3_bucket_by_name "$(TF_S3_BACKEND_NAME)-$(AWS_ACCOUNT_ID)-$(AWS_DEFAULT_REGION)"
	@scripts/deploy-tf-backend.sh destroy

#################### ATHENA WORKGROUP ####################

deploy-athena:
	@echo "Deploying Athena"
	scripts/tf.sh foundation/athena $(args)
	@echo "Finished Deploying Athena"

destroy-athena: clean-athena-workgroup
	@echo "Destroying Athena"
	TF_MODE=destroy scripts/tf.sh foundation/athena $(args)
	@echo "Finished Destroying Athena"

clean-athena-workgroup:
	@echo "Cleaning Athena workgroup $(APP_NAME)-$(ENV_NAME)-workgroup..."
	@aws athena delete-work-group --work-group $(APP_NAME)-$(ENV_NAME)-workgroup --recursive-delete-option || true
	@echo "Athena workgroup cleaned successfully"

#################### IAM ROLES ####################

deploy-iam-roles:
	@echo "Deploying IAM Roles"
	scripts/tf.sh foundation/iam-roles
	@echo "Finished Deploying IAM Roles"

destroy-iam-roles:
	@echo "Destroying IAM Roles"
	TF_MODE=destroy scripts/tf.sh foundation/iam-roles
	@echo "Finished Destroying IAM Roles"

#################### S3 BUCKETS ####################

deploy-buckets:
	@echo "Deploying S3 Buckets"
	scripts/tf.sh foundation/buckets $(args)
	@echo "Finished Deploying S3 Buckets"

destroy-buckets:
	@echo "Destroying Buckets"
	TF_MODE=destroy scripts/tf.sh foundation/buckets $(args)
	@echo "Finished Destroying Buckets"

#################### NETWORK ####################

deploy-network:
	@echo "Deploying Network"
	scripts/tf.sh foundation/network $(args)
	@echo "Finished Deploying Network"

destroy-network:
	@echo "Destroying Network"
	TF_MODE=destroy scripts/tf.sh foundation/network $(args)
	@echo "Finished Destroying Network"

#################### KMS KEYS ####################

deploy-kms-keys:
	@echo "Deploying KMS Keys"
	scripts/tf.sh foundation/kms-keys $(args)
	@echo "Finished Deploying KMS Keys"

destroy-kms-keys:
	@echo "Destroying KMS Keys"
	TF_MODE=destroy scripts/tf.sh foundation/kms-keys $(args)
	@echo "Finished Destroying KMS Keys"

################## GLUE DATABASES ######################

deploy-glue-databases:
	@echo "Deploying Glue Databases"
	scripts/tf.sh foundation/glue-databases $(args)
	@echo "Finished Deploying Glue Databases"

destroy-glue-databases:
	@echo "Destroying Glue Databases"
	TF_MODE=destroy scripts/tf.sh foundation/glue-databases $(args)
	@echo "Finished Destroying Glue Databases"

################## AURORA ######################

deploy-aurora:
	@echo "Deploying Aurora Database"
	scripts/tf.sh datasources/aurora $(args)
	@echo "Finished Deploying Aurora Database"

destroy-aurora:
	@echo "Destroying Aurora Database"
	TF_MODE=destroy scripts/tf.sh datasources/aurora $(args)
	@echo "Finished Destroying Aurora Database"

#################### LAKE FORMATION ####################

# ADMIN ROLE SETUP EXPLANATION:
# 
# The LAKE_FORMATION_ADMIN_ROLE role is required for Lake Formation to function properly in this data lakehouse.
# Here's what it does:
#
# 1. ROLE CREATION: Creates an IAM role named "Admin" that can be assumed by the AWS account root
# 2. PERMISSIONS: Attaches AWSLakeFormationDataAdmin policy for full Lake Formation access
# 3. LAKE FORMATION SETUP: Registers this role as a Lake Formation data lake administrator
# 4. DATA GOVERNANCE: Enables the role to manage data permissions, catalogs, and security policies
# 5. CROSS-SERVICE ACCESS: Allows Lake Formation to work with Glue, S3, and other AWS services
#
# This role is essential for:
# - Managing data lake permissions and access controls
# - Configuring Lake Formation settings and policies  
# - Enabling secure data sharing between services
# - Administering the Glue Data Catalog through Lake Formation
#
# Without this role, Lake Formation cannot manage data permissions effectively.

# Creates the Admin IAM role required for Lake Formation administration
# This role is used to manage Lake Formation data lake settings and permissions
# The role allows the current AWS account root to assume it for administrative tasks
create-lake-formation-admin-role:
	@echo "Setting up Admin role for Lake Formation..."
	@aws iam create-role \
		--role-name "$(LAKE_FORMATION_ADMIN_ROLE)" \
		--assume-role-policy-document '{ \
			"Version": "2012-10-17", \
			"Statement": [{ \
				"Effect": "Allow", \
				"Principal": { "AWS": "arn:aws:iam::$(AWS_ACCOUNT_ID):root" }, \
				"Action": "sts:AssumeRole" \
			}] \
		}' \
		--description "Administrative role for Lake Formation data lake management" \
		2>/dev/null || echo "Admin role already exists"
	@aws iam attach-role-policy \
		--role-name "$(LAKE_FORMATION_ADMIN_ROLE)" \
		--policy-arn "arn:aws:iam::aws:policy/AWSLakeFormationDataAdmin" \
		2>/dev/null || echo "Policy already attached"
	@echo "Admin role setup complete"

# Configures Lake Formation to use the Admin role as a data lake administrator
# This enables the Admin role to manage Lake Formation permissions and settings
# Must be run after create-admin-role to ensure the role exists
setup-lake-formation-admin-role:
	aws lakeformation put-data-lake-settings \
		--cli-input-json "{\"DataLakeSettings\": {\"DataLakeAdmins\": [{\"DataLakePrincipalIdentifier\": \"arn:aws:iam::${AWS_ACCOUNT_ID}:role/${LAKE_FORMATION_ADMIN_ROLE}\"}]}}" \
		--region "${AWS_PRIMARY_REGION}"

#################### ORACLE ####################

deploy-oracle:
	@echo "Deploying Oracle Database"
	scripts/tf.sh datasources/oracle $(args)
	@echo "Finished Deploying Oracle Database"

destroy-oracle:
	@echo "Destroying Oracle Database"
	TF_MODE=destroy scripts/tf.sh datasources/oracle $(args)
	@echo "Finished Destroying Oracle Database"

#################### COCKROACH DB ####################

deploy-cockroach:
	@echo "Deploying Cockroach DB"
	scripts/tf.sh datasources/cockroach
	@echo "Finished Deploying Cockroach DB"

destroy-cockroach:
	@echo "Destroying Cockroach DB"
	TF_MODE=destroy scripts/tf.sh datasources/cockroach
	@echo "Finished Destroying Cockroach DB"

##################### MSK SOURCE (CONFLUENT KAFKA REPLICATOR) ##################

deploy-msk-source:
	@echo "Deploying MSK Source"
	scripts/tf.sh datasources/msk $(args)
	@echo "Finished Deploying MSK Source"

destroy-msk-source:
	@echo "Destroying MSK Source"
	TF_MODE=destroy scripts/tf.sh datasources/msk $(args)
	@echo "Finished Destroying MSK Source"

################### DATA-GENERATOR ####################

CLEANUP_DATA_GENERATOR = echo "" && \
    echo "Cleaning up data generator artifacts..." && \
    rm -f iac/roots/datasources/data-generator/data-generator-source.zip && \
    echo "Removed data-generator-source.zip"

build-java-local:
	@echo "Building Java pom for data generator (locally)"
	cd iac/roots/datasources/data-generator/generator && \
	mvn clean package
	@echo "Finished building Java pom"

deploy-data-generator:
	@echo "Deploying Data Generator"
	scripts/tf.sh datasources/data-generator $(args) && \
	$(CLEANUP_DATA_GENERATOR)
	@echo "Finished Deploying Data Generator"

destroy-data-generator:
	@echo "Destroying Data Generator"
	TF_MODE=destroy scripts/tf.sh datasources/data-generator $(args)
	@echo "Finished Destroying Data Generator" && \
	$(CLEANUP_DATA_GENERATOR)

################## DMS INGESTION ######################

deploy-dms-oracle:
	@echo "Deploying DMS Oracle"
	scripts/tf.sh ingestion-layer/dms-oracle $(args)
	@echo "Finished Deploying DMS Oracle"

destroy-dms-oracle:
	@echo "Destroying DMS Oracle"
	TF_MODE=destroy scripts/tf.sh ingestion-layer/dms-oracle $(args)
	@echo "Finished Destroying DMS Oracle"

deploy-dms-aurora:
	@echo "Deploying DMS Aurora"
	scripts/tf.sh ingestion-layer/dms-aurora $(args)
	@echo "Finished Deploying DMS Aurora"

destroy-dms-aurora:
	@echo "Destroying DMS Aurora"
	TF_MODE=destroy scripts/tf.sh ingestion-layer/dms-aurora $(args)
	@echo "Finished Destroying DMS Aurora"

# Start S3 replication task
start-dms-oracle:
	@echo "Starting DMS replication task for Oracle..."
	@aws dms start-replication-task \
		--replication-task-arn $$(aws dms describe-replication-tasks \
			--filters Name=replication-task-id,Values=$(APP_NAME)-$(ENV_NAME)-oracle-to-msk-task \
			--query 'ReplicationTasks[0].ReplicationTaskArn' \
			--output text) \
		--start-replication-task-type start-replication
	@echo "DMS replication task for Oracle started successfully"

stop-dms-oracle:
	@echo "Stopping DMS replication task for Oracle..."
	@aws dms stop-replication-task \
		--replication-task-arn $$(aws dms describe-replication-tasks \
			--filters Name=replication-task-id,Values=$(APP_NAME)-$(ENV_NAME)-oracle-to-msk-task \
			--query 'ReplicationTasks[0].ReplicationTaskArn' \
			--output text) || true
	@echo "DMS replication task for Oracle stopped successfully"

start-dms-aurora:
	@echo "Starting DMS replication task for Aurora..."
	@aws dms start-replication-task \
		--replication-task-arn $$(aws dms describe-replication-tasks \
			--filters Name=replication-task-id,Values=$(APP_NAME)-$(ENV_NAME)-aurora-to-msk-task \
			--query 'ReplicationTasks[0].ReplicationTaskArn' \
			--output text) \
		--start-replication-task-type start-replication
	@echo "DMS replication task for Aurora started successfully"

stop-dms-aurora:
	@echo "Stopping DMS replication task for Aurora..."
	@aws dms stop-replication-task \
		--replication-task-arn $$(aws dms describe-replication-tasks \
			--filters Name=replication-task-id,Values=$(APP_NAME)-$(ENV_NAME)-aurora-to-msk-task \
			--query 'ReplicationTasks[0].ReplicationTaskArn' \
			--output text) || true
	@echo "DMS replication task for Aurora stopped successfully"

########### MSK INGESTION ####################

deploy-msk-ingest:
	@echo "Deploying MSK Ingest (takes approximately 1hr 40 minutes)"
	scripts/tf.sh ingestion-layer/msk-ingest $(args)
	@echo "Finished Deploying MSK Ingest"

destroy-msk-ingest:
	@echo "Destroying MSK Ingest"
	TF_MODE=destroy scripts/tf.sh ingestion-layer/msk-ingest $(args)
	@echo "Finished Destroying MSK Ingest"

################### ORACLE FIREHOSE STREAMS ####################

deploy-oracle-financial-msk-firehose-stream:
	@echo "Deploying Oracle Financial MSK Firehose Stream"
	$(call tf_apply_with_retry,ingestion-layer/firehose-streams/oracle-financial-msk-firehose-stream)
	@echo "Finished Deploying Oracle Financial MSK Firehose Stream"

destroy-oracle-financial-msk-firehose-stream:
	@echo "Destroying Oracle Financial MSK Firehose Stream"
	TF_MODE=destroy scripts/tf.sh ingestion-layer/firehose-streams/oracle-financial-msk-firehose-stream $(args)
	@echo "Finished Destroying Oracle Financial MSK Firehose Stream"

deploy-oracle-brokerage-msk-firehose-stream:
	@echo "Deploying Oracle Brokerage MSK Firehose Stream"
	$(call tf_apply_with_retry,ingestion-layer/firehose-streams/oracle-brokerage-msk-firehose-stream)
	@echo "Finished Deploying Oracle Brokerage MSK Firehose Stream"

destroy-oracle-brokerage-msk-firehose-stream:
	@echo "Destroying Oracle Brokerage MSK Firehose Stream"
	TF_MODE=destroy scripts/tf.sh ingestion-layer/firehose-streams/oracle-brokerage-msk-firehose-stream $(args)
	@echo "Finished Destroying Oracle Brokerage MSK Firehose Stream"

################### AURORA FIREHOSE STREAMS ####################

deploy-aurora-financial-msk-firehose-stream:
	@echo "Deploying Aurora Financial MSK Firehose Stream"
	$(call tf_apply_with_retry,ingestion-layer/firehose-streams/aurora-financial-msk-firehose-stream)
	@echo "Finished Deploying Aurora Financial MSK Firehose Stream"

destroy-aurora-financial-msk-firehose-stream:
	@echo "Destroying Aurora Financial MSK Firehose Stream"
	TF_MODE=destroy scripts/tf.sh ingestion-layer/firehose-streams/aurora-financial-msk-firehose-stream $(args)
	@echo "Finished Destroying Aurora Financial MSK Firehose Stream"

deploy-aurora-brokerage-msk-firehose-stream:
	@echo "Deploying Aurora Brokerage MSK Firehose Stream"
	$(call tf_apply_with_retry,ingestion-layer/firehose-streams/aurora-brokerage-msk-firehose-stream)
	@echo "Finished Deploying Aurora Brokerage MSK Firehose Stream"

destroy-aurora-brokerage-msk-firehose-stream:
	@echo "Destroying Aurora Brokerage MSK Firehose Stream"
	TF_MODE=destroy scripts/tf.sh ingestion-layer/firehose-streams/aurora-brokerage-msk-firehose-stream $(args)
	@echo "Finished Destroying Aurora Brokerage MSK Firehose Stream"

################### MSK FIREHOSE STREAMS ####################

deploy-msk-financial-firehose-stream:
	@echo "Deploying MSK Financial Firehose Stream"
	$(call tf_apply_with_retry,ingestion-layer/firehose-streams/msk-financial-firehose-stream)
	@echo "Finished Deploying MSK Financial Firehose Stream"

destroy-msk-financial-firehose-stream:
	@echo "Destroying MSK Financial Firehose Stream"
	TF_MODE=destroy scripts/tf.sh ingestion-layer/firehose-streams/msk-financial-firehose-stream $(args)
	@echo "Finished Destroying MSK Financial Firehose Stream"

deploy-msk-brokerage-firehose-stream:
	@echo "Deploying MSK Brokerage Firehose Stream"
	$(call tf_apply_with_retry,ingestion-layer/firehose-streams/msk-brokerage-firehose-stream)
	@echo "Finished Deploying MSK Brokerage Firehose Stream"

destroy-msk-brokerage-firehose-stream:
	@echo "Destroying MSK Brokerage Firehose Stream"
	TF_MODE=destroy scripts/tf.sh ingestion-layer/firehose-streams/msk-brokerage-firehose-stream $(args)
	@echo "Finished Destroying MSK Brokerage Firehose Stream"

################## COCKROACH FIREHOSE STREAMS #############

deploy-cockroach-financial-msk-firehose-stream:
	@echo "Deploying CockroachDB Financial Firehose Stream"
	$(call tf_apply_with_retry,ingestion-layer/firehose-streams/cockroach-financial-msk-firehose-stream)
	@echo "Finished Deploying CockroachDB Financial Firehose Stream"

destroy-cockroach-financial-msk-firehose-stream:
	@echo "Destroying CockroachDB Financial Firehose Stream"
	TF_MODE=destroy scripts/tf.sh ingestion-layer/firehose-streams/cockroach-financial-msk-firehose-stream $(args)
	@echo "Finished Destroying CockroachDB Financial Firehose Stream"

deploy-cockroach-brokerage-msk-firehose-stream:
	@echo "Deploying CockroachDB Brokerage Firehose Stream"
	$(call tf_apply_with_retry,ingestion-layer/firehose-streams/cockroach-brokerage-msk-firehose-stream)
	@echo "Finished Deploying CockroachDB Brokerage Firehose Stream"

destroy-cockroach-brokerage-msk-firehose-stream:
	@echo "Destroying CockroachDB Financial Brokerage Stream"
	TF_MODE=destroy scripts/tf.sh ingestion-layer/firehose-streams/cockroach-brokerage-msk-firehose-stream $(args)
	@echo "Finished Destroying CockroachDB Brokerage Firehose Stream"

################## SSM-CONNECTIONS ######################

connect-to-oracle:
	@echo "Connecting to Oracle instance"
	@ORACLE_IP=$$(aws ssm get-parameter \
		--name "/${APP_NAME}/${ENV_NAME}/oracle-host" \
		--with-decryption \
		--query "Parameter.Value" \
		--output text); \
	INSTANCE_ID=$$(aws ec2 describe-instances \
		--filters "Name=private-ip-address,Values=$$ORACLE_IP" \
		--query "Reservations[0].Instances[0].InstanceId" \
		--output text); \
	aws ssm start-session --target $$INSTANCE_ID

connect-to-aurora:
	@echo "Connecting to Aurora instance"
	@AURORA_IP=$$(aws ssm get-parameter \
		--name "/${APP_NAME}/${ENV_NAME}/aurora-bastion-host" \
		--with-decryption \
		--query "Parameter.Value" \
		--output text); \
	INSTANCE_ID=$$(aws ec2 describe-instances \
		--filters "Name=private-ip-address,Values=$$AURORA_IP" \
		--query "Reservations[0].Instances[0].InstanceId" \
		--output text); \
	aws ssm start-session --target $$INSTANCE_ID

connect-to-data-generator:
	@echo "Connecting to Data Generator instance"
	@DATAGEN_IP=$$(aws ssm get-parameter \
		--name "/${APP_NAME}/${ENV_NAME}/data-generator-host" \
		--with-decryption \
		--query "Parameter.Value" \
		--output text); \
	INSTANCE_ID=$$(aws ec2 describe-instances \
		--filters "Name=private-ip-address,Values=$$DATAGEN_IP" \
		--query "Reservations[0].Instances[0].InstanceId" \
		--output text); \
	aws ssm start-session --target $$INSTANCE_ID

connect-to-cockroach:
	@echo "Connecting to CockroachDB node-1 instance"
	@INSTANCE_ID=$$(aws ec2 describe-instances \
		--filters "Name=tag:Name,Values=${APP_NAME}-${ENV_NAME}-cockroachdb-node-1" \
		           "Name=instance-state-name,Values=running" \
		--query "Reservations[0].Instances[0].InstanceId" \
		--output text); \
	aws ssm start-session --target $$INSTANCE_ID

############## COCKROACHDB CHANGEFEEDS #################

# Set up CockroachDB changefeeds to MSK Ingest cluster
# Prerequisites: run make setup-source-tables first so tables exist
# Usage:
#   make setup-cockroachdb-changefeeds                           # Standard setup
#   make setup-cockroachdb-changefeeds args="--drop-existing"    # Drop and recreate changefeeds
setup-cockroachdb-changefeeds:
	@bash scripts/setup-cockroachdb-changefeeds.sh $(args)

################## TABLE SETUP ####################

# Create database tables on all sources without inserting any data.
# Run this BEFORE start-dms-tasks and setup-cockroachdb-changefeeds
# to avoid DMS DDL-triggered reloads and changefeed table-not-found errors.
setup-source-tables:
	@bash scripts/generate-data.sh --source oracle --count 0 --wait
	@bash scripts/generate-data.sh --source aurora --count 0 --wait
	@bash scripts/generate-data.sh --source cockroach --count 0 --wait

################## DATA GENERATION ####################

# Generate test data across all sources (Oracle, Aurora, CockroachDB, MSK)
# Usage:
#   make generate-data                                       # All sources, 1000 records
#   make generate-data args="--count 500"                    # All sources, 500 records
#   make generate-data args="--source oracle"                # Oracle only
#   make generate-data args="-s aurora -t financial"         # Aurora financial only
#   make generate-data args="--wait"                         # Wait for completion
#   make generate-data args="--interval 100 --threads 4"    # Fast: 100ms delay, 4 threads
#   make generate-data args="-i 0 -T 10 -n 5000"            # Max throughput: no delay, 10 threads
generate-data:
	@bash scripts/generate-data.sh $(args)

# Shorthand targets for individual sources
generate-data-oracle:
	@bash scripts/generate-data.sh --source oracle $(args)

generate-data-aurora:
	@bash scripts/generate-data.sh --source aurora $(args)

generate-data-cockroach:
	@bash scripts/generate-data.sh --source cockroach $(args)

generate-data-msk:
	@bash scripts/generate-data.sh --source msk $(args)

connect-to-msk-config:
	@echo "Connecting to MSK (Ingest) Config instance"
	@MSK_IP=$$(aws ssm get-parameter \
		--name "/${APP_NAME}/${ENV_NAME}/msk-ingest-config-host" \
		--with-decryption \
		--query "Parameter.Value" \
		--output text); \
	INSTANCE_ID=$$(aws ec2 describe-instances \
		--filters "Name=private-ip-address,Values=$$MSK_IP" \
		--query "Reservations[0].Instances[0].InstanceId" \
		--output text); \
	aws ssm start-session --target $$INSTANCE_ID

################## PATH 2: S3 TABLES ####################

deploy-s3-tables:
	@echo "Deploying S3 Tables"
	scripts/tf.sh foundation/s3-tables $(args)
	@echo "Finished Deploying S3 Tables"

clean-s3-tables:
	@echo "Cleaning auto-created tables from S3 Tables namespaces..."
	@TABLE_BUCKET_ARN=$$(aws ssm get-parameter \
		--name "/$(APP_NAME)/$(ENV_NAME)/s3-table-bucket-arn" \
		--with-decryption --query "Parameter.Value" --output text \
		--region "$(AWS_PRIMARY_REGION)" 2>/dev/null || echo ""); \
	if [ -z "$$TABLE_BUCKET_ARN" ] || [ "$$TABLE_BUCKET_ARN" = "None" ]; then \
		echo "SSM lookup failed — trying S3 Tables API directly..."; \
		TABLE_BUCKET_ARN=$$(aws s3tables list-table-buckets \
			--query "tableBuckets[?name=='$(APP_NAME)-$(ENV_NAME)-iceberg-table-bucket'].arn | [0]" \
			--output text \
			--region "$(AWS_PRIMARY_REGION)" 2>/dev/null || echo ""); \
	fi; \
	if [ -z "$$TABLE_BUCKET_ARN" ] || [ "$$TABLE_BUCKET_ARN" = "None" ]; then \
		echo "No S3 Tables bucket found — skipping cleanup"; \
		exit 0; \
	fi; \
	echo "Table bucket: $$TABLE_BUCKET_ARN"; \
	NAMESPACES=$$(aws s3tables list-namespaces \
		--table-bucket-arn "$$TABLE_BUCKET_ARN" \
		--query "namespaces[].namespace[0]" \
		--output text \
		--region "$(AWS_PRIMARY_REGION)" 2>/dev/null || echo ""); \
	if [ -z "$$NAMESPACES" ]; then \
		echo "No namespaces found — skipping"; \
		exit 0; \
	fi; \
	for ns in $$NAMESPACES; do \
		TABLES=$$(aws s3tables list-tables \
			--table-bucket-arn "$$TABLE_BUCKET_ARN" \
			--namespace "$$ns" \
			--query "tables[].name" \
			--output text \
			--region "$(AWS_PRIMARY_REGION)" 2>/dev/null || echo ""); \
		for tbl in $$TABLES; do \
			echo "  Deleting table: $$ns/$$tbl"; \
			aws s3tables delete-table \
				--table-bucket-arn "$$TABLE_BUCKET_ARN" \
				--namespace "$$ns" \
				--name "$$tbl" \
				--region "$(AWS_PRIMARY_REGION)" 2>&1 || true; \
		done; \
	done; \
	echo "S3 Tables cleanup complete"

destroy-s3-tables: clean-s3-tables
	@echo "Destroying S3 Tables"
	TF_MODE=destroy scripts/tf.sh foundation/s3-tables $(args)
	@echo "Finished Destroying S3 Tables"

# Grant Lake Formation permissions on the S3 Tables federated catalog to the Admin role.
# This enables querying S3 Tables data through Athena/Redshift.
# Must be run AFTER deploy-s3-tables (which creates the catalog and LF resource registration).
#
# KEY INSIGHTS (from reference repo investigation):
#   1. CatalogId for table/database grants MUST include the bucket name:
#      ACCOUNT:s3tablescatalog/BUCKET_NAME  (not just ACCOUNT:s3tablescatalog)
#   2. Wildcard grants ("Name": "*") do NOT work on federated S3 Tables catalogs.
#      Each table must be granted individually.
#   3. The top-level catalog grant uses "Id": "ACCOUNT:s3tablescatalog" (no bucket).
#
# Ref: https://docs.aws.amazon.com/athena/latest/ug/gdc-register-s3-table-bucket-cat.html

setup-s3-tables-lf-permissions:
	@echo "Granting Lake Formation permissions on S3 Tables catalog..."
	@TABLE_BUCKET_ARN=$$(aws ssm get-parameter \
		--name "/$(APP_NAME)/$(ENV_NAME)/s3-table-bucket-arn" \
		--with-decryption --query "Parameter.Value" --output text); \
	TABLE_BUCKET_NAME=$$(aws ssm get-parameter \
		--name "/$(APP_NAME)/$(ENV_NAME)/s3-table-bucket-name" \
		--with-decryption --query "Parameter.Value" --output text); \
	echo "Table bucket ARN:  $$TABLE_BUCKET_ARN"; \
	echo "Table bucket name: $$TABLE_BUCKET_NAME"; \
	CATALOG_ID="$(AWS_ACCOUNT_ID):s3tablescatalog"; \
	BUCKET_CATALOG_ID="$(AWS_ACCOUNT_ID):s3tablescatalog/$$TABLE_BUCKET_NAME"; \
	PRINCIPAL="arn:aws:iam::$(AWS_ACCOUNT_ID):role/$(LAKE_FORMATION_ADMIN_ROLE)"; \
	echo ""; \
	echo "=== Step 1: Grant ALL on top-level catalog ($$CATALOG_ID) ==="; \
	aws lakeformation grant-permissions \
		--region "$(AWS_PRIMARY_REGION)" \
		--principal "DataLakePrincipalIdentifier=$$PRINCIPAL" \
		--resource "{\"Catalog\":{\"Id\":\"$$CATALOG_ID\"}}" \
		--permissions ALL \
		--permissions-with-grant-option ALL 2>&1 || true; \
	echo ""; \
	echo "=== Step 2: Discovering namespaces and tables from S3 Tables API ==="; \
	NAMESPACES=$$(aws s3tables list-namespaces \
		--table-bucket-arn "$$TABLE_BUCKET_ARN" \
		--query "namespaces[].namespace[0]" \
		--output text \
		--region "$(AWS_PRIMARY_REGION)"); \
	echo "Found namespaces: $$NAMESPACES"; \
	echo ""; \
	echo "=== Step 3: Grant ALL on each table ($$BUCKET_CATALOG_ID) ==="; \
	for ns in $$NAMESPACES; do \
		TABLES=$$(aws s3tables list-tables \
			--table-bucket-arn "$$TABLE_BUCKET_ARN" \
			--namespace "$$ns" \
			--query "tables[].name" \
			--output text \
			--region "$(AWS_PRIMARY_REGION)"); \
		for tbl in $$TABLES; do \
			echo "  Granting: $$ns/$$tbl"; \
			aws lakeformation grant-permissions \
				--region "$(AWS_PRIMARY_REGION)" \
				--principal "DataLakePrincipalIdentifier=$$PRINCIPAL" \
				--resource "{\"Table\":{\"CatalogId\":\"$$BUCKET_CATALOG_ID\",\"DatabaseName\":\"$$ns\",\"Name\":\"$$tbl\"}}" \
				--permissions ALL \
				--permissions-with-grant-option ALL 2>&1 || true; \
		done; \
	done; \
	echo ""; \
	echo "Lake Formation permissions granted on S3 Tables catalog"

################## PATH 2: MSK CONNECT DEBEZIUM SOURCE ####################

deploy-debezium-oracle:
	@echo "Deploying Debezium Oracle Source Connector"
	scripts/tf.sh ingestion-layer/debezium-oracle $(args)
	@echo "Finished Deploying Debezium Oracle Source Connector"

destroy-debezium-oracle:
	@echo "Destroying Debezium Oracle Source Connector"
	TF_MODE=destroy scripts/tf.sh ingestion-layer/debezium-oracle $(args)
	@echo "Finished Destroying Debezium Oracle Source Connector"

deploy-debezium-aurora:
	@echo "Deploying Debezium Aurora Source Connector"
	scripts/tf.sh ingestion-layer/debezium-aurora $(args)
	@echo "Finished Deploying Debezium Aurora Source Connector"

destroy-debezium-aurora:
	@echo "Destroying Debezium Aurora Source Connector"
	TF_MODE=destroy scripts/tf.sh ingestion-layer/debezium-aurora $(args)
	@echo "Finished Destroying Debezium Aurora Source Connector"

################## PATH 2: CONNECTOR PLUGIN SETUP ####################

setup-connector-plugins:
	@echo "Setting up MSK Connect connector plugins..."
	@TMPDIR=$$(mktemp -d) && \
	echo "Downloading Debezium Oracle connector v$(DEBEZIUM_VERSION)..." && \
	wget -q -P $$TMPDIR https://repo1.maven.org/maven2/io/debezium/debezium-connector-oracle/$(DEBEZIUM_VERSION)/debezium-connector-oracle-$(DEBEZIUM_VERSION)-plugin.tar.gz && \
	echo "b3e60755bf65deee49cdde08e0cad0f465273a4a5c394476ccd8635747b0cd64  $$TMPDIR/debezium-connector-oracle-$(DEBEZIUM_VERSION)-plugin.tar.gz" | shasum -a 256 -c - && \
	echo "Downloading Debezium PostgreSQL connector v$(DEBEZIUM_VERSION)..." && \
	wget -q -P $$TMPDIR https://repo1.maven.org/maven2/io/debezium/debezium-connector-postgres/$(DEBEZIUM_VERSION)/debezium-connector-postgres-$(DEBEZIUM_VERSION)-plugin.tar.gz && \
	echo "999f2d97e6dfb5f519892016f6da6daf6a7dfc2a5a7ec74c1852250deab2c7c9  $$TMPDIR/debezium-connector-postgres-$(DEBEZIUM_VERSION)-plugin.tar.gz" | shasum -a 256 -c - && \
	echo "Downloading Oracle JDBC driver (ojdbc8)..." && \
	wget -q -P $$TMPDIR https://repo1.maven.org/maven2/com/oracle/database/jdbc/ojdbc8/21.9.0.0/ojdbc8-21.9.0.0.jar && \
	echo "e7bbab05994715e2810fc20e7ac4052905c5b604a0a1fb2b2f8a9d2f9a5c2c84  $$TMPDIR/ojdbc8-21.9.0.0.jar" | shasum -a 256 -c - && \
	echo "Packaging Debezium Oracle plugin..." && \
	mkdir -p $$TMPDIR/debezium-oracle && \
	tar xzf $$TMPDIR/debezium-connector-oracle-$(DEBEZIUM_VERSION)-plugin.tar.gz -C $$TMPDIR/debezium-oracle && \
	echo "Adding Oracle JDBC driver to Debezium Oracle plugin..." && \
	cp $$TMPDIR/ojdbc8-21.9.0.0.jar $$TMPDIR/debezium-oracle/debezium-connector-oracle/ && \
	cd $$TMPDIR/debezium-oracle && zip -r -q $$TMPDIR/debezium-oracle-plugin.zip . && cd - > /dev/null && \
	echo "Packaging Debezium PostgreSQL plugin..." && \
	mkdir -p $$TMPDIR/debezium-postgres && \
	tar xzf $$TMPDIR/debezium-connector-postgres-$(DEBEZIUM_VERSION)-plugin.tar.gz -C $$TMPDIR/debezium-postgres && \
	cd $$TMPDIR/debezium-postgres && zip -r -q $$TMPDIR/debezium-postgres-plugin.zip . && cd - > /dev/null && \
	echo "Uploading plugins to s3://$(PLUGIN_BUCKET_NAME)/..." && \
	aws s3 cp $$TMPDIR/debezium-oracle-plugin.zip s3://$(PLUGIN_BUCKET_NAME)/ && \
	aws s3 cp $$TMPDIR/debezium-postgres-plugin.zip s3://$(PLUGIN_BUCKET_NAME)/ && \
	echo "Cleaning up temp files..." && \
	rm -rf $$TMPDIR && \
	echo "Connector plugins uploaded successfully."

################## PATH 2: COMPOSITE TARGETS ####################

deploy-all-debezium-sources: deploy-debezium-oracle deploy-debezium-aurora
destroy-all-debezium-sources: destroy-debezium-aurora destroy-debezium-oracle

################## DEPLOY ALL AND SHORTCUTS ######################

deploy-foundation: deploy-iam-roles deploy-kms-keys deploy-buckets deploy-network setup-lake-formation-admin-role deploy-glue-databases deploy-athena deploy-s3-tables setup-s3-tables-lf-permissions
destroy-foundation: destroy-s3-tables destroy-athena destroy-glue-databases destroy-network destroy-buckets destroy-kms-keys destroy-iam-roles

deploy-datasources: deploy-oracle deploy-cockroach deploy-aurora deploy-msk-source deploy-data-generator
start-dms-tasks: start-dms-oracle start-dms-aurora

deploy-path1: deploy-dms-oracle deploy-dms-aurora deploy-all-firehose-streams
destroy-path1: destroy-all-firehose-streams destroy-dms-oracle destroy-dms-aurora

deploy-path2: setup-connector-plugins deploy-all-debezium-sources deploy-flink-all
destroy-path2: destroy-flink destroy-all-debezium-sources

deploy-infra-all: deploy-foundation deploy-datasources deploy-msk-ingest deploy-path1 deploy-path2 setup-source-tables start-dms-tasks setup-cockroachdb-changefeeds
destroy-infra-all: destroy-path2 destroy-path1 destroy-msk-ingest destroy-datasources destroy-foundation cleanup-orphaned-resources

cleanup-orphaned-resources:
	@echo "Cleaning up orphaned resources..."
	@aws logs delete-log-group \
		--log-group-name "/aws/vpc/flowlogs/$(APP_NAME)-$(ENV_NAME)" \
		--region $(AWS_PRIMARY_REGION) 2>/dev/null || true
	@echo "Orphaned resource cleanup complete."

clean-lakeformation:
	@echo "Cleaning Lake Formation resources..."
	@aws lakeformation put-data-lake-settings \
		--cli-input-json '{"DataLakeSettings": {"DataLakeAdmins": []}}' \
		--region "$(AWS_PRIMARY_REGION)" 2>/dev/null || true
	@echo "Lake Formation cleaned"

deploy-ofmfs: deploy-oracle-financial-msk-firehose-stream
deploy-obmfs: deploy-oracle-brokerage-msk-firehose-stream

deploy-afmfs: deploy-aurora-financial-msk-firehose-stream
deploy-abmfs: deploy-aurora-brokerage-msk-firehose-stream

deploy-mffs: deploy-msk-financial-firehose-stream
deploy-mbfs: deploy-msk-brokerage-firehose-stream

deploy-cfmfs: deploy-cockroach-financial-msk-firehose-stream
deploy-cbmfs: deploy-cockroach-brokerage-msk-firehose-stream

deploy-all-firehose-streams: deploy-ofmfs deploy-obmfs deploy-afmfs deploy-abmfs deploy-mffs deploy-mbfs deploy-cfmfs deploy-cbmfs
################## DESTROY SHORTCUTS ######################

destroy-datasources: destroy-data-generator destroy-msk-source destroy-aurora destroy-cockroach destroy-oracle
stop-dms-tasks: stop-dms-oracle stop-dms-aurora
	@echo "Waiting 3 minutes for DMS tasks to fully stop..."
	@sleep 180

destroy-ofmfs: destroy-oracle-financial-msk-firehose-stream
destroy-obmfs: destroy-oracle-brokerage-msk-firehose-stream

destroy-afmfs: destroy-aurora-financial-msk-firehose-stream
destroy-abmfs: destroy-aurora-brokerage-msk-firehose-stream

destroy-mffs: destroy-msk-financial-firehose-stream
destroy-mbfs: destroy-msk-brokerage-firehose-stream

destroy-cfmfs: destroy-cockroach-financial-msk-firehose-stream
destroy-cbmfs: destroy-cockroach-brokerage-msk-firehose-stream

destroy-all-firehose-streams: destroy-cbmfs destroy-cfmfs destroy-mbfs destroy-mffs destroy-abmfs destroy-afmfs destroy-obmfs destroy-ofmfs

#################### FLINK ICEBERG SINK ####################

FLINK_JAR_NAME = flink-iceberg-sink-1.0-SNAPSHOT.jar
FLINK_S3_KEY = flink/$(FLINK_JAR_NAME)

build-flink-app:
	@echo "Building Flink Iceberg Sink fat JAR..."
	cd $(CURDIR)/flink && mvn clean package -DskipTests -q
	@echo "Build complete: flink/target/$(FLINK_JAR_NAME)"

upload-flink-app: build-flink-app
	@echo "Uploading Flink JAR to S3..."
	@ASSETS_BUCKET=""; \
	for attempt in 1 2 3; do \
		ASSETS_BUCKET=$$(aws ssm get-parameter --name "/$(APP_NAME)/$(ENV_NAME)/assets-bucket-name" --with-decryption --query 'Parameter.Value' --output text --region $(AWS_PRIMARY_REGION) 2>/dev/null); \
		if [ -n "$$ASSETS_BUCKET" ] && [ "$$ASSETS_BUCKET" != "None" ]; then break; fi; \
		echo "⚠ SSM lookup for assets-bucket-name returned empty (attempt $$attempt of 3) — credentials may be mid-refresh; retrying in 15s..."; \
		sleep 15; \
	done; \
	if [ -z "$$ASSETS_BUCKET" ] || [ "$$ASSETS_BUCKET" = "None" ]; then \
		echo "✖ Could not resolve assets bucket from SSM (/$(APP_NAME)/$(ENV_NAME)/assets-bucket-name)." >&2; \
		echo "  Credentials are likely expired — refresh them and re-run 'make deploy-flink-all'." >&2; \
		exit 1; \
	fi; \
	echo "Resolved assets bucket: $$ASSETS_BUCKET"; \
	aws s3 cp $(CURDIR)/flink/target/$(FLINK_JAR_NAME) s3://$$ASSETS_BUCKET/$(FLINK_S3_KEY) --region $(AWS_PRIMARY_REGION); \
	echo "Uploaded to s3://$$ASSETS_BUCKET/$(FLINK_S3_KEY)"

deploy-flink:
	@echo "Deploying Flink"
	scripts/tf.sh flink $(args)
	@echo "Finished Deploying Flink"

destroy-flink:
	@echo "Destroying Flink"
	TF_MODE=destroy scripts/tf.sh flink $(args)
	@echo "Finished Destroying Flink"

start-flink-apps:
	@echo "Starting Flink applications..."
	@for APP_SUFFIX in oracle aurora cockroach msk_source; do \
		APP_FULL_NAME="$(APP_NAME)-$(ENV_NAME)-flink-$${APP_SUFFIX}"; \
		echo "Starting $${APP_FULL_NAME}..."; \
		aws kinesisanalyticsv2 start-application \
			--application-name "$${APP_FULL_NAME}" \
			--region $(AWS_PRIMARY_REGION) 2>/dev/null || \
			echo "  (already running or not found)"; \
	done
	@echo "All Flink applications started"

stop-flink-apps:
	@echo "Stopping Flink applications..."
	@for APP_SUFFIX in oracle aurora cockroach msk_source; do \
		APP_FULL_NAME="$(APP_NAME)-$(ENV_NAME)-flink-$${APP_SUFFIX}"; \
		echo "Stopping $${APP_FULL_NAME}..."; \
		aws kinesisanalyticsv2 stop-application \
			--application-name "$${APP_FULL_NAME}" \
			--force \
			--region $(AWS_PRIMARY_REGION) 2>/dev/null || \
			echo "  (already stopped or not found)"; \
	done
	@echo "All Flink applications stopped"

deploy-flink-all: upload-flink-app deploy-flink
	@echo "Flink fully deployed (JAR uploaded + infra deployed + apps auto-started by Terraform)"
