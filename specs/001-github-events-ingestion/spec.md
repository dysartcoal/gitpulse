# Feature Specification: Reliable ingestion of public software-engineering activity data

**Feature Branch**: `001-github-events-ingestion`

**Created**: 2026-08-22

**Status**: Draft

**Input**: User description: "Phase 1 of the GitPulse project plan — a local, zero-ongoing-cost streaming pipeline that continuously captures public GitHub activity events into a durable, validated raw store, tested from day one, as the foundation the rest of the medallion architecture (Phase 2 onward) will build on."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Continuous, trustworthy raw data lands automatically (Priority: P1)

As the project owner, I need a continuously running ingestion process that captures public
software-engineering activity events into a durable raw store, so that later phases have real,
trustworthy data to build the medallion architecture on.

**Why this priority**: Nothing else in this project can proceed without raw data actually landing
reliably. This is the foundation every later phase depends on.

**Independent Test**: Can be fully tested by running the ingestion process against the live public
event feed for a sustained period and confirming a growing, non-duplicated set of valid records
accumulates in the raw store with no manual intervention.

**Acceptance Scenarios**:

1. **Given** the ingestion process is running, **When** a burst of new public activity occurs
   upstream, **Then** corresponding events appear in the raw store within a reasonable, bounded
   delay.
2. **Given** the upstream source is temporarily unavailable or rate-limits requests, **When** the
   ingestion process retries, **Then** no events are lost and no duplicate records are created once
   the source recovers.

---

### User Story 2 - Malformed data is quarantined, not trusted silently (Priority: P2)

As the project owner, I need malformed or unexpected events to be quarantined rather than silently
written into the raw store, so that later phases can trust that anything reaching raw is at least
structurally valid.

**Why this priority**: Protects data quality before curated/gold layers exist to catch problems.
Prevents a whole class of downstream debugging pain that's much harder to trace once the pipeline
has more stages.

**Independent Test**: Can be tested by injecting a deliberately malformed event and confirming it
lands in a quarantine location, not raw, with a recorded reason.

**Acceptance Scenarios**:

1. **Given** an event that doesn't match the expected structure for its type, **When** it's
   processed, **Then** it is written to a quarantine location along with the reason it failed, and
   the trusted raw store is unaffected.

---

### User Story 3 - Changes to the pipeline can be made with confidence (Priority: P3)

As the project owner, I need the ingestion pipeline's correctness to be verified automatically on
every change, so that I can make changes with confidence rather than manually re-checking behaviour
each time.

**Why this priority**: Valuable, but the pipeline can run without it in the very short term — it's
what makes *ongoing* changes safe, not what makes the first version work at all.

**Independent Test**: Can be tested by deliberately introducing a change that breaks parsing or
duplicate-handling logic and confirming the automated checks catch it before it can be merged.

**Acceptance Scenarios**:

1. **Given** a change is proposed to the ingestion code, **When** the automated checks run,
   **Then** a broken parsing or duplicate-handling change is caught before it can be merged.

---

### Edge Cases

- What happens when the upstream source's rate limit is exhausted mid-run?
- How does the system handle the same event being delivered more than once by the upstream source?
- If the ingestion process is stopped and restarted, does it resume without gaps or duplicates?
- How does the system handle an event type it hasn't encountered before?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST continuously retrieve new public activity events from the upstream
  source without requiring manual intervention.
- **FR-002**: The system MUST avoid re-processing events it has already retrieved when the
  upstream source is polled again (idempotent ingestion).
- **FR-003**: The system MUST validate every event against its expected structure before it is
  considered part of the trusted raw dataset.
- **FR-004**: The system MUST route any event that fails validation to a separate quarantine
  location, retaining the original event and the reason it failed.
- **FR-005**: The system MUST continue operating without data loss through temporary upstream
  unavailability or rate-limiting, resuming automatically once the source is available again.
- **FR-006**: The system MUST persist retrieved events durably, in a location later phases can
  build on without needing to re-ingest.
- **FR-007**: The system MUST have automated checks that verify its core parsing and idempotency
  behaviour, run automatically on every proposed change.
- **FR-008**: The system's automated checks MUST include at least one test that exercises the real
  transport layer between retrieval and storage, not only unit-level logic in isolation.

### Key Entities

- **Activity Event**: a single occurrence of public software-engineering activity (e.g. a code
  contribution, a discussion, a review action), uniquely identified, timestamped, and typed by the
  kind of activity it represents.
- **Raw Record**: the durable, validated representation of an Activity Event once it has passed
  structural validation, stored for downstream phases to consume.
- **Quarantined Record**: an event that failed validation, stored separately along with the reason
  for rejection, for later inspection.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The ingestion process runs continuously for at least 24 hours without manual
  intervention, with zero events lost and zero duplicate records in the raw store.
- **SC-002**: 100% of events that fail structural validation are quarantined with a recorded
  reason, and none of them appear in the trusted raw dataset.
- **SC-003**: A temporary interruption of the upstream source does not require manual recovery —
  ingestion resumes automatically and catches up without gaps once the source is available again.
- **SC-004**: A deliberately introduced defect in the parsing or idempotency logic is caught by
  the automated checks before it can be merged, every time it's exercised by the test suite.

## Assumptions

- Near-real-time delivery is sufficient; sub-minute latency is not required. A polling-based
  approach with a reasonable interval is acceptable, consistent with the project's ADR-0002
  decision to accept polling-based integration over a persistent push-stream connection.
- The upstream source is GitHub's public Events API (ADR-0002) — publicly available,
  unauthenticated by default, with documented, well-understood rate limits.
- "Later phases" refers to this project's own roadmap (Phase 2's curated/gold layers), not an
  external consuming team.
- A single project owner is both the operator and the primary user of this system at this phase;
  no multi-user access control is required yet.
- Local or free-tier storage is acceptable for the raw store at this phase, consistent with the
  project's local-first, cost-conscious approach (ADR-0003).
