# Phase 0 Research: Reliable ingestion of public software-engineering activity data

## Decision: Consumer language — Python

**Decision**: The Kafka consumer, its parsing/validation/idempotency logic, and its tests are
written in Python 3.12.

**Rationale**: The project plan explicitly leaves this open ("a small consumer (Python or a first
bit of Spark Structured Streaming — your choice)"), but two existing decisions already point one
way. First, ADR-0006 commits to `pytest` with `testcontainers` spinning up a real local Kafka for
"unit and integration tests on the ingestion/consumer/API code" — a Python-native testing stack.
Second, the project's own skills-priority table places Apache Spark in Phase 2 (the medallion
build), deliberately separate from Phase 1's ingestion work. Choosing Spark Structured Streaming
here would pull a Phase 2 skill forward for no requirement in this spec, and would fight the
testing approach already decided in ADR-0006.

**Alternatives considered**: Spark Structured Streaming — rejected for Phase 1 specifically
because it's already scoped to Phase 2, and a single-consumer, single-topic-family workload at
this scale doesn't need a distributed processing engine; introducing it here would be complexity
without a corresponding requirement (Constitution Check would flag this as unjustified).

## Decision: Raw and quarantine store location — local filesystem

**Decision**: Both the raw store and the quarantine store are local filesystem directories in
Phase 1, not S3.

**Rationale**: The spec's Assumptions already state "local or free-tier storage is acceptable...
consistent with the project's local-first, cost-conscious approach (ADR-0003)." Free-tier S3 is
still a real AWS resource — it means AWS credentials and IAM permissions exist for something this
feature does not require, ahead of when Terraform/`kind` work in this same phase will need them
anyway. Local filesystem storage satisfies every FR and SC in the spec (durability for later
phases to build on, quarantine separation, resumability) without pulling cloud dependencies
forward. This keeps ADR-0003's "AWS Budgets and a billing alarm before touching any other AWS
service" spirit intact — Phase 1's ingestion pipeline touches no AWS service at all.

**Alternatives considered**: Amazon S3 (free tier) — rejected for now, not permanently. Revisit in
Phase 2 when the medallion architecture needs a shared, durable object store multiple phases read
from; Phase 1's own success criteria don't require it.

## Best-practice notes (not open decisions — informing task breakdown)

**NiFi `InvokeHTTP` against a rate-limited, ETag-cacheable API**: Configure `InvokeHTTP` to send
the previous response's `ETag` as an `If-None-Match` header on each poll; a `304 Not Modified`
response costs nothing against the GitHub rate-limit budget, unlike a full `200` response. Read
the `X-RateLimit-Remaining` and `X-RateLimit-Reset` response headers and route on them (e.g. a
`RouteOnAttribute` processor) so the flow backs off automatically as the limit is approached,
rather than discovering exhaustion via a `403`. Starting unauthenticated (60 req/hour) and moving
to a PAT (5,000 req/hour) is a config change, not a flow redesign, if it's wired as an optional
header from the start.

**Kafka topic strategy**: The project plan leaves this open ("topic'd sensibly... decide once you
see real volume"). A reasonable Phase 1 default is one topic per broad event category (e.g. code
activity, discussion activity, review activity) rather than one topic per individual GitHub event
type (of which there are ~15+) or a single firehose topic — this keeps consumer logic
type-aware without needing dozens of topics for a single-consumer Phase 1 workload. This is a
task-level decision to make concrete during implementation, not a spec-level one.

**Idempotency key**: GitHub Events API events carry a unique, stable `id` field. De-duplication on
that id (e.g. an on-disk or in-memory seen-set, keyed on id, with a bounded retention window
matching the realistic re-delivery window) satisfies FR-002 without needing an external
deduplication store for a single-consumer Phase 1 workload.

**`testcontainers` Kafka pattern**: `testcontainers-python`'s Kafka module starts a real
single-broker Kafka container per test run; the integration test publishes a representative sample
event (both a valid one and a deliberately malformed one, per spec User Story 2) and asserts the
consumer routes each to the correct store. This is the concrete shape of ADR-0006's "real local
Kafka in CI, not a mock" requirement (FR-008).

## Outstanding NEEDS CLARIFICATION

None. All Technical Context fields are resolved above or directly stated in the spec's Assumptions.
