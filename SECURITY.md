# Security

This document describes the security posture of this sample and the changes
required before deploying it to any real environment.

For instructions on how to **report a vulnerability**, see
[CONTRIBUTING.md#security-issue-notifications](CONTRIBUTING.md#security-issue-notifications).

## Sample Security Limitations

This sample is designed as a prototype/development environment. Multiple
Checkov controls are intentionally suppressed and multiple defaults are
relaxed to keep the sample simple, cheap, and easy to tear down. These are
**not passed controls** — they are **explicitly accepted for sample use only**
and must be addressed before any production deployment.

### CockroachDB runs in insecure mode

The CockroachDB cluster starts with `--insecure` — no TLS, no
authentication, no authorization — and its SQL port (26257) is reachable
from the entire VPC CIDR. Anyone with a network path into the VPC can
connect as `root` with no credentials. See
[iac/roots/datasources/cockroach/README.md](iac/roots/datasources/cockroach/README.md)
for the module-level notice.

### Wildcard IAM permissions

Rules suppressed: `CKV_AWS_290`, `CKV_AWS_355`, `CKV_AWS_356`,
`CKV_AWS_108`.

Several roles (Managed Flink VPC ENI creation, Glue data-lake operations,
DMS MSK discovery, MSK SASL secret access) use `Resource: "*"` because the
AWS service either requires it at validation time or discovers resources
dynamically. For production, scope each policy to specific ARNs where the
service allows it and document the required-wildcard cases explicitly.

### Egress and security-group rules

Rules suppressed: `CKV_AWS_382`, `CKV2_AWS_5`, `CKV_AWS_23`, `CKV_AWS_24`,
`CKV_AWS_25`, `CKV_AWS_260`.

Some security groups permit `0.0.0.0/0` egress (Flink needs unrestricted
outbound to reach MSK, S3, Glue, CloudWatch, and KMS endpoints). Some SG
findings are false positives — self-referencing ingress or groups attached
via `vpc_configuration.security_group_ids` that Checkov cannot follow. For
production, use VPC endpoints where available and tighten egress to
specific service prefix lists.

### CloudWatch log encryption and retention

Rules suppressed: `CKV_AWS_158`, `CKV_AWS_338`.

Log groups are not encrypted with a customer-managed KMS key and retention
is set to 7-30 days. For production, encrypt log groups with a CMK and set
retention according to your compliance requirements.

### Secrets Manager rotation

Rule suppressed: `CKV2_AWS_57`.

Sample database and MSK SASL secrets do not have automatic rotation
configured. For production, enable rotation with a Lambda rotator
appropriate to each secret type.

### Backups and deletion protection

Rules suppressed: `CKV_AWS_96`, `CKV_AWS_139`, `CKV2_AWS_8`, `CKV_AWS_150`,
`CKV_AWS_354`.

RDS/Aurora deletion protection is disabled, AWS Backup is not attached,
NLB deletion protection is disabled, and Performance Insights KMS
encryption is not configured. These make sample teardown fast. For
production, enable each protection.

### S3 access logging, lifecycle, replication, notifications

Rules suppressed: `CKV_AWS_18`, `CKV2_AWS_61`, `CKV2_AWS_62`,
`CKV_AWS_144`, `CKV2_AWS_65`, `CKV2_AWS_67`.

Sample buckets have no access logs, no lifecycle rules, no event
notifications, no cross-region replication, and use
`BucketOwnerPreferred` (BucketOwnerEnforced is not compatible with one of
the destinations in the sample). For production, enable access logging to
a dedicated log bucket, define lifecycle rules that match your data
retention policy, and evaluate whether `BucketOwnerEnforced` is viable in
your deployment.

### DMS endpoint encryption (data-in-transit)

Rules suppressed: `CKV_AWS_296`, `CKV2_AWS_49`.

DMS endpoints in this sample do not use `ssl_mode = "require"`. The DBs
sit in a private VPC and DMS runs in the same VPC, so the traffic never
leaves AWS-managed networking, but this is still a defense-in-depth gap.
For production, generate certificates for each source/target and set
`ssl_mode = "verify-ca"` or `"verify-full"`.

### Miscellaneous prototype trade-offs

Rules suppressed: `CKV_AWS_50` (X-Ray), `CKV_AWS_116` (Lambda DLQ),
`CKV_AWS_272` (Lambda code signing), `CKV_AWS_152` (NLB cross-zone),
`CKV_AWS_91` (ALB access logs), `CKV_AWS_241` (Firehose CMK),
`CKV_AWS_240` (Firehose SSE), `CKV_AWS_79/126/135/8`, `CKV2_AWS_41`
(EC2 defaults configured via launch template — Checkov false positive),
`CKV2_AWS_34` (SSM parameter encryption for non-sensitive metadata),
`CKV_AWS_130` (public subnet — intentional).

Enable each of these controls according to your production observability,
resilience, and encryption requirements.

## Path to Production

The Checkov suppressions above cover the specific rules the scanner
flagged. This section captures the broader set of changes required
before deploying this sample outside a throwaway environment.

### Encryption & Data Protection

- Enable S3 bucket encryption with customer-managed KMS keys
- Enable RDS encryption at rest for Aurora and Oracle databases
- Configure MSK encryption in transit and at rest
- Implement S3 bucket versioning and MFA delete protection
- Enable CloudWatch Logs KMS encryption
- Enable Firehose stream-level SSE with a CMK

### Access Control & IAM

- Replace wildcard IAM permissions with least-privilege policies where the
  underlying AWS service permits scoping
- Implement resource-specific IAM policies instead of broad service
  permissions
- Configure VPC Flow Logs for network monitoring
- Restrict security group rules to specific application source SGs and
  ports

### Data Source Security

- **CockroachDB**: migrate to secure mode (`--certs-dir`), issue node and
  client certificates, create authenticated users with least-privilege
  `GRANT`s, and restrict the SG to specific application source SGs on port
  26257.
- **DMS**: set `ssl_mode = "verify-ca"` or `"verify-full"` on all source
  and target endpoints; provision the corresponding certificates.
- **Aurora / Oracle**: enable IAM database authentication where the engine
  supports it; require TLS on every connection.

### Monitoring & Compliance

- Configure CloudWatch detailed monitoring for all resources
- Enable S3 access logging and CloudTrail for audit trails
- Enable X-Ray tracing on Lambda and Managed Flink
- Configure Lambda DLQs
- Enable Lambda code signing

### High Availability & Resilience

- Deploy across multiple Availability Zones
- Enable RDS Multi-AZ deployments
- Configure MSK cluster with multiple brokers
- Implement proper backup and disaster recovery procedures
- Enable deletion protection for critical resources
- Attach AWS Backup plans to Aurora, Oracle, and other stateful stores
- Enable NLB deletion protection and cross-zone load balancing

### Supply Chain

The following artifacts are downloaded and executed by `user_data` scripts
or `Makefile` targets. Current verification posture:

| Artifact | Origin | Version pin | SHA-256 pin |
|---|---|---|---|
| Debezium Oracle connector plugin | Maven Central (`repo1.maven.org`) | yes | **yes** |
| Debezium PostgreSQL connector plugin | Maven Central (`repo1.maven.org`) | yes | **yes** |
| Oracle JDBC driver `ojdbc8` | Maven Central (`repo1.maven.org`) | yes | **yes** |
| `compat-openssl10` RPM | Rocky Linux (`dl.rockylinux.org`) | yes | **yes** |
| CockroachDB Linux tarball | `binaries.cockroachdb.com` | yes | no |
| Oracle Database XE RPM | `download.oracle.com` | yes | no |
| Oracle preinstall RPM | `yum.oracle.com` | yes | no |
| Apache Kafka tarball | `archive.apache.org` | yes | no |
| MSK IAM auth jar | `github.com/aws/aws-msk-iam-auth/releases` | yes | no |

For production, add SHA-256 verification to every remaining unpinned
download (see the same `sha256sum -c` / `shasum -a 256 -c` pattern used in
`iac/roots/datasources/oracle/scripts/user_data.sh` and
`Makefile:setup-connector-plugins`). Do not rely on version pins alone —
they do not detect upstream artifact replacement or account compromise.

- Generate and review `THIRD-PARTY-LICENSES`
