# 0006 — Testing and data quality are built from Phase 1, not bolted on at the end

**Status:** Accepted
**Date:** 2026-08-20

## Context

Data quality and testing could be treated as a single cross-cutting concern added once the pipeline mostly works, or built into each layer as it's built. The former is more common in practice and a common source of technical debt.

## Decision

Tool choices are matched to where each layer already lives, rather than forcing one framework to cover the whole pipeline:

- **pytest**, with `testcontainers` spinning up a real local Kafka in CI (not a mock), for unit and integration tests on the ingestion/consumer/API code.
- **Great Expectations** for schema, volume and profiling checks on the raw → curated Spark layer — chosen over the lighter Soda Core specifically because it's the more widely recognised name on a data engineering CV.
- **dbt's native test framework**, plus `dbt source freshness`, for the curated → gold layer, since it adds zero extra infrastructure on top of dbt already being used there.

## Consequences

Every layer gets a check appropriate to what it actually is, and quality/testing evidence accumulates from the first commit rather than appearing as a late addition. The cost is more tooling surface area to learn at once (three testing frameworks rather than one) — accepted as a deliberate part of the learning goal, since matching tool to layer is itself the more realistic, hireable skill.
