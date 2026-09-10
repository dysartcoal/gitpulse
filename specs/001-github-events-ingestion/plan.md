# Implementation Plan: Reliable ingestion of public software-engineering activity data

**Branch**: `001-github-events-ingestion` | **Date**: 2026-08-23 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/001-github-events-ingestion/spec.md`

## Summary

Build a local, zero-ongoing-cost streaming pipeline that continuously captures public GitHub
activity events into a durable, validated raw store. Apache NiFi polls the GitHub public Events
API and publishes onto Apache Kafka; a Python consumer reads from Kafka, validates each event
against its expected structure, and writes valid events to a local raw store and invalid events
to a local quarantine store with a recorded reason. Both NiFi and Kafka run self-hosted via Docker
Compose (ADR-0005), matching the local-first, cost-conscious approach set out in ADR-0003. The
pipeline is tested from the first commit (ADR-0006): pytest unit tests on parsing/idempotency
logic, plus a `testcontainers`-backed integration test that exercises a real local Kafka in CI.

## Technical Context

**Language/Version**: Python 3.12 for the consumer and its tests. (Apache Spark is deliberately
out of scope for Phase 1 — the project plan reserves Spark for Phase 2's medallion-architecture
build, and ADR-0006's pytest/testcontainers testing approach is written for a Python
ingestion/consumer codebase.)

**Primary Dependencies**: Apache NiFi (Docker image, `InvokeHTTP` processor against the GitHub
Events API); Apache Kafka (Docker Compose, KRaft mode — no separate ZooKeeper container needed);
a Kafka client library for Python (`confluent-kafka`, the client the `testcontainers-python` Kafka
module is built to exercise); `jsonschema` for structural validation against the GitHub event
envelope.

**Storage**: Local filesystem for both the raw store and the quarantine store in Phase 1 (append-only,
partitioned by event type and date). Free-tier S3 is a documented future swap-in (the project plan
names it as an option) but isn't needed to satisfy any Phase 1 requirement, and introducing it now
would mean AWS credentials and cost exposure before Phase 1 needs either — deferred to Phase 2 when
the medallion architecture actually requires shared, durable object storage.

**Testing**: `pytest` for unit tests (parsing, structural validation, idempotency logic);
`testcontainers-python`'s Kafka module for an integration test that publishes a sample event to a
real local Kafka broker in CI and asserts it lands correctly in the raw store — not a mock, per
ADR-0006. GitHub Actions runs lint, unit tests, and the integration test on every pull request.
**Tests are written alongside each user story's own implementation tasks as it's built (Story 1's
polling/parsing/idempotency/raw-writer, Story 2's quarantine routing), not deferred to a separate
later phase** — this is what "tested from the first commit" (ADR-0006, Constitution Principle IV)
actually means in practice, and `/speckit-tasks` should generate task lists accordingly rather than
treating User Story 3 as the only place tests appear.

**Target Platform**: Developer laptop and GitHub Actions CI runner, both via Docker Compose on
Linux containers. No cloud compute is required for Phase 1.

**Project Type**: Single local data pipeline project (NiFi + Kafka + a Python consumer), not a
web service — there is no user-facing frontend in this feature.

**Performance Goals**: No throughput target beyond what the GitHub Events API itself allows —
ingestion is source-rate-limited, not a target the pipeline needs to hit independently. Newly
polled events should appear in the raw store within a small, bounded number of poll intervals
(see Constraints).

**Constraints**: Zero ongoing cloud cost (ADR-0003) — the entire Phase 1 stack runs on Docker
Compose with no billed cloud resource. Must run unattended for at least 24 continuous hours with
zero event loss and zero duplication (SC-001). Poll interval and NiFi `InvokeHTTP` scheduling
respect GitHub's published unauthenticated/PAT-authenticated rate limits with headroom, using
ETag caching to avoid burning rate-limit budget on unchanged responses.

**Scale/Scope**: Single GitHub Events API feed, single operator, single-node self-hosted NiFi and
Kafka (no clustering). Not multi-tenant; no per-user access control (per spec Assumptions).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **I. Evidence Over Assumption** — PASS. The architecturally significant choices this feature
  depends on (GitHub Events as the source, self-hosted NiFi/Kafka, local-first compute, per-layer
  testing) are already captured in ADR-0002, ADR-0005, ADR-0003, and ADR-0006 respectively. The two
  choices resolved during this plan (consumer language, raw/quarantine storage location) are
  implementation details within those existing decisions, not new architecturally significant
  decisions — recorded in `research.md` rather than a new ADR, consistent with "a decision without
  a documented reason is treated as unresolved," since a reason now exists and is written down.
- **II. Security by Enforcement, Not Convention** — PASS (not yet applicable). Phase 1 requires no
  AWS credentials at all — NiFi, Kafka, and the consumer are entirely local. ADR-0004/ADR-0007's
  credential-handling rules apply from Phase 1's Terraform/LocalStack and `kind` practice work
  onward if and when real cloud credentials are touched, but no gate is triggered by this feature.
- **III. Cost Is a Design Constraint, Not an Afterthought** — PASS. Every component in this plan
  (NiFi, Kafka, the consumer, local storage) runs at zero ongoing cost, matching ADR-0003 and the
  project's guardrails-before-any-billable-service rule.
- **IV. Test and Validate at the Layer Where Data Changes** — PASS. Testing approach matches
  ADR-0006 exactly: pytest for the ingestion/consumer layer, `testcontainers` exercising a real
  Kafka rather than a mock.
- **V. The Repository Is the Portfolio** — PASS. This plan, its research/data-model/contracts, and
  the eventual implementation land via the existing `specs/`, `docs/adr/`, and `docs/phases/`
  structure and the PR-based workflow already in place.

No violations. Complexity Tracking is not needed for this feature.

## Project Structure

### Documentation (this feature)

```text
specs/001-github-events-ingestion/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
infra/
├── docker-compose.yml     # NiFi + Kafka (KRaft mode) local stack
└── terraform/             # LocalStack-targeted Terraform, for IaC practice without cloud risk

nifi/
└── flow/                  # Exported NiFi flow definition (InvokeHTTP -> routing -> Kafka publish)

src/
├── schemas/                # JSON Schema definitions for the GitHub event envelope and per-type payloads
└── consumer/
    ├── parsing.py           # Structural validation against src/schemas
    ├── idempotency.py        # De-duplication logic keyed on event id
    ├── raw_writer.py          # Writes valid events to the local raw store
    └── quarantine_writer.py   # Writes invalid events + reason to the local quarantine store

tests/
├── unit/                   # parsing, idempotency, and writer unit tests (pytest)
└── integration/            # testcontainers-backed real-Kafka integration test

data/                      # gitignored: local raw/ and quarantine/ stores written at runtime

.github/workflows/ci.yml   # lint, unit tests, Kafka integration test on every PR
```

**Structure Decision**: Single project layout (no frontend/backend split — this feature has no
user-facing application). NiFi's flow configuration and the Docker Compose stack are kept
separate from the Python consumer code so each can be iterated and tested independently, matching
the constitution's per-layer testing principle.

## Complexity Tracking

*No Constitution Check violations — this section is not applicable.*
