# 0005 — NiFi and Kafka run self-hosted, not as managed cloud services

**Status:** Accepted
**Date:** 2026-08-20

## Context

Managed alternatives exist for parts of this stack — Amazon MSK/MSK Serverless for Kafka, though no direct managed NiFi equivalent on AWS — but they bill continuously or per-use in ways that work against the cost approach in ADR-0003.

## Decision

Both NiFi and Kafka run self-hosted: Docker Compose locally in Phase 1 for fast iteration, migrated onto the `kind`/Kubernetes cluster via Helm charts in Phase 4 as part of productionising the platform.

## Consequences

This keeps Phase 1 free to run indefinitely, and produces a genuine "evolved this from local Docker to Kubernetes via Helm" story in Phase 4 — a stronger, more specific interview answer than having started on Kubernetes from day one. The trade-off is operating Kafka and NiFi's own reliability characteristics directly rather than delegating them to a managed service, which is itself part of the intended learning.
