# Quickstart: Validating the Phase 1 ingestion pipeline

Run these once implementation (`/speckit-implement`, after `/speckit-tasks`) has produced the
Docker Compose stack, NiFi flow, and consumer described in `plan.md`. This guide proves the
feature works end-to-end; it doesn't duplicate the contracts or data model above.

## Prerequisites

- Docker and Docker Compose installed locally.
- Python 3.12 and the project's dependencies installed (`pip install -r requirements.txt` or
  equivalent, once the consumer exists).

## Setup

```bash
cd infra
docker compose up -d
```

Confirm all three services are healthy: NiFi (UI reachable), Kafka (broker accepting connections),
and the consumer (running and connected to Kafka).

## Validation scenarios

**1. Happy path — events flow end to end (User Story 1, SC-001)**

Let the stack run. Within a few poll intervals, confirm new files appear under
`data/raw/event_type=.../date=.../` (see `contracts/raw-store-contract.md`) and that the set of
`event_id` values across all raw files never contains a duplicate.

**2. Malformed data is quarantined (User Story 2, SC-002)**

Publish (or wait for) an event that doesn't match the expected structure. Confirm a corresponding
file appears under `data/quarantine/date=.../` with a specific `reason`, and confirm no matching
`event_id` appears anywhere in the raw store.

**3. Resilience to interruption (Edge Cases, SC-003)**

Stop the consumer container mid-run (`docker compose stop consumer`), wait, then restart it
(`docker compose start consumer`). Confirm ingestion resumes automatically, no previously-seen
`event_id` is duplicated in raw, and no gap exists between the last event before the stop and the
first event after restart (beyond genuine upstream quiet periods).

**4. Automated checks catch a real regression (User Story 3, SC-004)**

Run the test suite:

```bash
pytest tests/unit
pytest tests/integration   # spins up a real local Kafka via testcontainers
```

Then deliberately introduce a defect (e.g. break the idempotency de-duplication key) on a branch,
open a PR, and confirm GitHub Actions' CI run fails before merge is possible.

**5. Volume check — is the poll window actually keeping up? (research.md's open question)**

Once the stack has been running for a meaningful period (at least the first 24–48h of real
operation), work through Part 3 of `docs/runbooks/github-events-volume-check.md`: re-run the
empirical check from that runbook and cross-reference it against any "poll returned the maximum
300 events" warnings logged during the run. This is the review step that confirms ADR-0002's
"lower volume" assumption actually held under real conditions, not just at design time.

## Expected outcome

All five scenarios above hold without manual intervention beyond the deliberate actions described
(stopping/restarting the consumer, introducing the deliberate defect) — matching SC-001 through
SC-004 in `spec.md`, plus the volume check confirming the source API's own 300-event window isn't
silently truncating real data.
