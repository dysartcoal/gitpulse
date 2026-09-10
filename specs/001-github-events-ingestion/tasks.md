---

description: "Task list template for feature implementation"
---

# Tasks: Reliable ingestion of public software-engineering activity data

**Input**: Design documents from `/specs/001-github-events-ingestion/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md (all present)

**Tests**: Tests ARE requested for this feature (ADR-0006, FR-007, FR-008) and are written alongside
each user story's own implementation tasks, not deferred to a separate later phase — per plan.md's
Technical Context note on ADR-0006 / Constitution Principle IV.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing
of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3)
- Exact file paths are included in each description

## Path Conventions

Single local data-pipeline project per plan.md's Project Structure — no frontend/backend split:

```text
infra/docker-compose.yml
infra/create_topics.py        # idempotent Kafka topic creation (T008)
nifi/flow/
config/topic-map.properties   # shared NiFi/consumer topic-routing source of truth (T007)
src/schemas/
src/consumer/
tests/unit/
tests/integration/
data/                      # gitignored, written at runtime
.github/workflows/ci.yml
```

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure

- [ ] T001 Create project directory structure: `infra/`, `nifi/flow/`, `src/schemas/`, `src/schemas/payloads/`, `src/consumer/`, `tests/unit/`, `tests/integration/` (with `.gitkeep` placeholders as needed), matching plan.md's Project Structure
- [ ] T002 Initialize Python 3.12 project in `pyproject.toml` with dependencies `confluent-kafka`, `jsonschema`, `pytest`, `testcontainers[kafka]`
- [ ] T003 [P] Configure `ruff` linting/formatting in `pyproject.toml` (or `.ruff.toml`)
- [ ] T004 [P] Create `infra/docker-compose.yml` defining NiFi and Kafka (KRaft mode, single broker, no separate ZooKeeper) services with health checks (ADR-0005), passing an optional `GITHUB_TOKEN` from the host environment through to the NiFi service's container environment, for the flow's Parameter Context to pick up

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T005 Define the Activity Event envelope JSON Schema in `src/schemas/activity_event.schema.json` (`id`, `type`, `actor`, `repo`, `payload`, `public`, `created_at` per data-model.md)
- [ ] T006 [P] Define known per-type payload JSON Schemas (`PushEvent`, `IssuesEvent`, `PullRequestEvent`) in `src/schemas/payloads/`, referenced by the envelope schema
- [ ] T007 [P] Create the shared topic-routing config `config/topic-map.properties` (GitHub event `type` → one of `github-events.code-activity`, `github-events.discussion-activity`, `github-events.review-activity`, covering every documented public event type per `contracts/kafka-topic-contract.md`, with an explicit default/fallback for any type not listed) and a thin loader for it in `src/consumer/topic_map.py` — this file is the single source of truth both NiFi (T009) and the consumer read, rather than two independently-maintained mappings
- [ ] T008 [P] Create the three Kafka topics (`github-events.code-activity`, `github-events.discussion-activity`, `github-events.review-activity`, per T007) via a small idempotent script, `infra/create_topics.py` (using `confluent-kafka`'s `AdminClient`), run once against the broker from T004 — one partition, replication factor 1, matching the single-broker setup (ADR-0005) — rather than relying on Kafka's auto-create-on-publish default, so partition count and replication are a deliberate, documented choice, not whatever the broker's defaults happen to be (depends on T004, T007)
- [ ] T009 Create the NiFi flow definition in `nifi/flow/github-events-flow.xml`: `InvokeHTTP` polling the GitHub public Events API with ETag caching (`If-None-Match`), a `RouteOnAttribute` step reading `X-RateLimit-Remaining`/`X-RateLimit-Reset` for backoff, honoring the `X-Poll-Interval` header; extracting each event's `type` into an attribute and resolving it to a topic via a `PropertiesFileLookupService` controller service pointed at `config/topic-map.properties` (T007) and a `LookupAttribute` processor, routing its `unmatched` relationship somewhere visible rather than silently dropping an unrecognized event type; then publishing the unmodified event JSON keyed by the event `id` to the resolved topic via `PublishKafka`'s `${kafka.topic}` expression; also configuring `InvokeHTTP` to send an optional `Authorization: token #{GITHUB_TOKEN}` header, sourced from a Parameter Context populated by NiFi's `EnvironmentVariableParameterProvider` reading the `GITHUB_TOKEN` environment variable (T004) — raising the effective rate limit from 60 to 5,000 requests/hour per research.md when set, and continuing to work unauthenticated when it isn't (depends on T007)
- [ ] T010 [P] Implement the consumer configuration loader in `src/consumer/config.py` (Kafka brokers, topic names, poll settings) — no `GITHUB_TOKEN` handling here: the consumer never calls the GitHub API, only Kafka; the PAT belongs to NiFi's `InvokeHTTP` call (T009)
- [ ] T011 [P] Implement structured logging setup in `src/consumer/logging_config.py`

**Checkpoint**: Foundation ready — user story implementation can now begin

---

## Phase 3: User Story 1 - Continuous, trustworthy raw data lands automatically (Priority: P1) 🎯 MVP

**Goal**: A continuously running ingestion process captures public GitHub activity events into a
durable, non-duplicated raw store, with no manual intervention (FR-001, FR-002, FR-005, FR-006).

**Independent Test**: Run the stack against the live public event feed for a sustained period and
confirm a growing, non-duplicated set of valid records accumulates in `data/raw/`.

### Tests for User Story 1 ⚠️

> Write these tests FIRST, ensure they FAIL before implementation

- [ ] T012 [P] [US1] Unit test envelope validation (valid event, missing required field, unknown-but-well-formed `type` accepted per data-model.md) in `tests/unit/test_parsing.py`
- [ ] T013 [P] [US1] Unit test the durable idempotency index (persists across restart, hydrates fully into memory at startup, detects a duplicate `id`) in `tests/unit/test_idempotency.py`
- [ ] T014 [P] [US1] Unit test the raw writer (partition path `event_type=.../date=...`, append-only, never a duplicate `event_id`) in `tests/unit/test_raw_writer.py`
- [ ] T015 [US1] Integration test using `testcontainers`'s Kafka module: publish a valid Activity Event to a real local Kafka broker and assert it lands correctly in the raw store, in `tests/integration/test_ingestion_pipeline.py`

### Implementation for User Story 1

- [ ] T016 [P] [US1] Implement Activity Event parsing/structural validation against `src/schemas/` in `src/consumer/parsing.py` (per data-model.md: `id`/`type`/`actor`/`repo`/`created_at` required; an unrecognized-but-well-formed `type` is not a failure)
- [ ] T017 [P] [US1] Implement the durable on-disk idempotency index — hydrated fully into memory at startup, written through to disk and memory on each new event — in `src/consumer/idempotency.py` (research.md decision)
- [ ] T018 [US1] Implement the raw writer (append-only newline-delimited JSON, partitioned by `event_type`/date, per `contracts/raw-store-contract.md`) in `src/consumer/raw_writer.py` (depends on T016)
- [ ] T019 [US1] Implement the consumer main loop in `src/consumer/main.py`: consume from the Kafka topics, parse/validate each message, check the idempotency index (a duplicate is silently dropped, not an error), write valid events to raw, and commit the Kafka offset only after the durable write completes (depends on T016, T017, T018)
- [ ] T020 [US1] Implement a routing cross-check in the consumer main loop: for each received event, look up its expected topic from the shared mapping `topic_map.py` loads (T007) using the event's own `type` field, and compare it against the Kafka topic the message actually arrived on; log a warning (or route to quarantine, consistent with US2's malformed-data handling) on a mismatch — this is what actually catches NiFi's routing and the consumer's copy of the shared file drifting apart, rather than just hoping they stay in sync (add a unit test alongside it, per this feature's tests-from-the-outset approach) (depends on T007, T019)
- [ ] T021 [US1] Extend the NiFi flow to log a warning with a running count whenever a poll response returns exactly 300 events, signalling possible window truncation (research.md volume note) in `nifi/flow/github-events-flow.xml` (depends on T009)

**Checkpoint**: User Story 1 is fully functional and independently testable

---

## Phase 4: User Story 2 - Malformed data is quarantined, not trusted silently (Priority: P2)

**Goal**: Events that fail structural validation are routed to quarantine with a recorded reason,
and never reach the raw store (FR-003, FR-004).

**Independent Test**: Inject a deliberately malformed event and confirm it lands in `data/quarantine/`,
not raw, with a recorded reason.

### Tests for User Story 2 ⚠️

- [ ] T022 [P] [US2] Unit test the quarantine writer (`received_at`/`reason`/`raw_payload` fields, partitioned by date only, per `contracts/quarantine-store-contract.md`) in `tests/unit/test_quarantine_writer.py`
- [ ] T023 [US2] Extend the integration test with a deliberately malformed event: assert it lands in quarantine with a specific reason and that no matching `event_id` appears in raw, in `tests/integration/test_ingestion_pipeline.py` (depends on T015)

### Implementation for User Story 2

- [ ] T024 [P] [US2] Implement the quarantine writer (append-only newline-delimited JSON, partitioned by date, fields `received_at`/`reason`/`raw_payload`) in `src/consumer/quarantine_writer.py`
- [ ] T025 [US2] Extend `src/consumer/parsing.py` to surface specific, non-generic failure reasons (`"not valid JSON"`, missing required field, wrong field type) for use by the quarantine writer (depends on T016)
- [ ] T026 [US2] Wire the consumer main loop to route non-JSON messages and validation failures to the quarantine writer with the recorded reason, leaving the raw store unaffected, in `src/consumer/main.py` (depends on T019, T024, T025)

**Checkpoint**: User Stories 1 AND 2 both work independently

---

## Phase 5: User Story 3 - Changes to the pipeline can be made with confidence (Priority: P3)

**Goal**: Automated checks run on every proposed change and catch a broken parsing or
duplicate-handling change before it can be merged (FR-007, FR-008, SC-004).

**Independent Test**: Deliberately introduce a change that breaks parsing or duplicate-handling
logic and confirm the automated checks catch it before it can be merged.

### Implementation for User Story 3

- [ ] T027 [US3] Create `.github/workflows/ci.yml`: run `ruff` lint, `pytest tests/unit`, and the `testcontainers`-backed `pytest tests/integration` on every pull request (depends on T012-T026 existing)
- [ ] T028 [P] [US3] Add pytest configuration in `pyproject.toml` distinguishing unit vs. integration test paths so CI can run/report them as separate steps
- [ ] T029 [US3] Verify CI catches a regression: on a scratch branch, deliberately break the idempotency de-duplication key, open a PR, confirm the CI run fails, then revert (validates SC-004) (depends on T027)

**Checkpoint**: All user stories independently functional; automated checks guard future changes

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [ ] T030 [P] Add `.env.example` documenting the optional `GITHUB_TOKEN` PAT (passed through to NiFi per T004/T009) and poll-interval override
- [ ] T031 [P] Update `README.md` with setup/run instructions referencing `quickstart.md`
- [ ] T032 Run `quickstart.md` validation scenarios 1-4 end to end against the live stack
- [ ] T033 Cross-reference `docs/runbooks/github-events-volume-check.md` Part 3 against logged "300-event" warnings after the first 24-48h of real operation (quickstart scenario 5, research.md's open volume question)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion — BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Foundational completion only
- **User Story 2 (Phase 4)**: Depends on Foundational completion; extends US1's parsing (T016→T025) and integration test (T015→T023), so implement after US1
- **User Story 3 (Phase 5)**: Depends on US1 and US2's tests existing (T012-T026) to have something for CI to run
- **Polish (Phase 6)**: Depends on all desired user stories being complete

### Within Each User Story

- Tests written and expected to FAIL before implementation
- Parsing/schemas before writers; writers before the main loop that wires them together
- Story complete (checkpoint) before moving to the next priority

### Parallel Opportunities

- Setup: T003, T004 in parallel
- Foundational: T006, T007, T010, T011 in parallel (after T005)
- US1 tests: T012, T013, T014 in parallel; T015 after the Kafka/testcontainers setup is in place
- US1 implementation: T016, T017 in parallel; T018 depends on T016; T019 depends on T016-T018
- US2: T022, T024 in parallel with each other; T023/T025/T026 depend on US1 pieces
- US3: T028 in parallel with T027

---

## Parallel Example: User Story 1

```bash
# Launch US1 tests together:
Task: "Unit test envelope validation in tests/unit/test_parsing.py"
Task: "Unit test durable idempotency index in tests/unit/test_idempotency.py"
Task: "Unit test raw writer partitioning in tests/unit/test_raw_writer.py"

# Launch independent US1 implementation pieces together:
Task: "Implement parsing/structural validation in src/consumer/parsing.py"
Task: "Implement durable idempotency index in src/consumer/idempotency.py"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL — blocks all stories)
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: run quickstart.md scenario 1 (SC-001) independently
5. Deploy/demo if ready

### Incremental Delivery

1. Setup + Foundational → Docker Compose stack, NiFi flow, Kafka topics, schemas ready
2. Add User Story 1 → validate quickstart scenario 1 (SC-001) → MVP
3. Add User Story 2 → validate quickstart scenario 2 (SC-002)
4. Add User Story 3 → validate quickstart scenario 4 (SC-004) via CI
5. Polish → validate quickstart scenarios 3 and 5, README/env docs

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Tests are written alongside each story's implementation tasks (ADR-0006), not deferred to Phase 5
- The integration test file (`tests/integration/test_ingestion_pipeline.py`) is created in US1 (T015) and extended in US2 (T023) rather than duplicated — both assertions exercise the same real local Kafka broker per FR-008
- Commit after each task or logical group
- Stop at any checkpoint to validate the story independently
