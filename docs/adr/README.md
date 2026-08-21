# Architecture Decision Records

One file per significant decision, using a short Context / Decision / Consequences template (see `0000-template.md`). Numbered in the order decisions were made, not necessarily the order phases run.

| ADR | Title |
|---|---|
| [0001](0001-ai-reads-gold-layer-only.md) | AI interface reads from the gold layer only |
| [0002](0002-github-events-over-wikipedia-eventstreams.md) | GitHub Events over Wikipedia EventStreams for the streaming source |
| [0003](0003-local-first-kubernetes-and-compute.md) | Local-first for Kubernetes and compute; cloud spend is deliberate and time-boxed |
| [0004](0004-secrets-manager-and-iam-roles.md) | Credentials via Secrets Manager + IAM roles, never long-lived AWS access keys |
| [0005](0005-nifi-kafka-self-hosted.md) | NiFi and Kafka run self-hosted, not as managed cloud services |
| [0006](0006-per-layer-testing-and-data-quality.md) | Testing and data quality are built from Phase 1, not bolted on at the end |
| [0007](0007-iam-user-with-mfa-over-identity-center.md) | IAM user with MFA and STS session tokens, not IAM Identity Center, for personal admin access |
