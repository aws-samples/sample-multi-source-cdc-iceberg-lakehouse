# Glue Catalog Databases

## Purpose
Creates AWS Glue catalog databases for organizing metadata from multiple data sources in the Iceberg data lakehouse, enabling unified data discovery and querying across Oracle, Aurora, CockroachDB, and MSK sources.

## What It Creates

**9 Glue Catalog Databases** organized by ingestion path:

- **4 Firehose databases** (Path 1, prefix `f_`): `f_oracle`, `f_aurora`, `f_crdb`, `f_msk_src`
- **4 Connect databases** (Path 2, prefix `c_`): `c_oracle`, `c_aurora`, `c_crdb`, `c_msk_src`

Full name pattern: `{APP}_{ENV}_{prefix}_{source}` (e.g., `da_dev1_f_oracle`)

**Additional resources:**
- **Lake Formation permissions**: IAM-based access grants for Connect databases
- **Pre-created Iceberg tables**: Connect databases include pre-created `fin`/`brk` tables via the `glue-transactions-table` module (with UPPERCASE columns for Oracle)
- **SSM Parameters**: Store database names for cross-component reference (e.g., `/${APP}/${ENV}/db-f-oracle`)

## Why It's Needed
- **Unified Metadata**: Centralizes schema information from all data sources
- **Query Engine Integration**: Enables Athena and other services to discover tables
- **Data Catalog**: Provides searchable metadata for data governance
- **Cross-Reference**: SSM parameters allow other components to reference database names

## Configuration Options

### Basic Configuration (terraform.tfvars)
Database names use shortened conventions defined in `terraform.tfvars` and resolved via CPA placeholders. See `variables.tf` for all database name variables.

## Key Features
- Environment-specific database naming with APP and ENV prefixes
- Consistent tagging across all databases for resource management
- SSM parameter storage for cross-component integration
- Support for multiple data source types in unified catalog

## Dependencies
- AWS Glue service permissions
- Foundation layer (IAM roles, KMS keys)

## Outputs
- Database names and ARNs for all nine transaction databases
- SSM parameter paths for programmatic access
