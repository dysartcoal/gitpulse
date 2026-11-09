# Phase 1 Data Model: Reliable ingestion of public software-engineering activity data

Extends the Key Entities named in `spec.md` with concrete fields, grounded in the GitHub public
Events API's own event envelope (ADR-0002). Per-type `payload` sub-structure varies by event type;
Phase 1 validates the envelope and known payload shapes, per FR-003.

## Activity Event (as received from the source)

| Field | Type | Notes |
|---|---|---|
| `id` | string | Unique per event, stable across redelivery. Used as the idempotency key (FR-002). |
| `type` | string | The GitHub event type, e.g. `PushEvent`, `IssuesEvent`, `PullRequestEvent`. |
| `actor` | object | Who performed the activity — id, login, display name. |
| `repo` | object | The repository the activity occurred in — id, name, url. |
| `payload` | object | Type-specific detail; structure depends on `type`. |
| `public` | boolean | Always true for events reachable via the public Events API. |
| `created_at` | timestamp | When the activity occurred upstream. |

**Validation rules** (FR-003): `id`, `type`, `actor`, `repo`, and `created_at` must be present and
correctly typed for an event to be considered structurally valid. An event whose `type` is not one
of the currently-handled types is not itself a validation failure (see spec Edge Cases — "an event
type it hasn't encountered before"); it is still validated against the common envelope fields and
persisted, since rejecting genuinely unknown-but-well-formed event types would put SC-002 at odds
with FR-006. Only envelope-level or known-payload-level structural failures route to quarantine.

## Raw Record (durable, validated representation)

| Field | Type | Notes |
|---|---|---|
| `event_id` | string | Copied from the source Activity Event's `id`. |
| `event_type` | string | Copied from the source Activity Event's `type`. |
| `ingested_at` | timestamp | When this consumer wrote the record, distinct from `created_at`. |
| `source_event` | object | The full, unmodified Activity Event as received. |

**Relationships**: One Raw Record per successfully validated Activity Event — 1:1, never
many-to-one (idempotency, FR-002) and never dropped (durability, FR-006).

**Storage shape**: Partitioned by `event_type` and the date portion of `ingested_at`, so later
phases (Phase 2 medallion build) can read a bounded, predictable subset without scanning the whole
raw store.

## Quarantined Record (failed validation)

| Field | Type | Notes |
|---|---|---|
| `received_at` | timestamp | When the consumer received the event, before validation. |
| `reason` | string | Human-readable description of why validation failed (FR-004). |
| `raw_payload` | object or string | The original event exactly as received, unmodified — even if malformed enough that it can't be parsed as the expected structure. |

**Relationships**: One Quarantined Record per event that fails structural validation — never
written to the Raw Record store (User Story 2's "the trusted raw store is unaffected").

**State transitions**: None in Phase 1 — quarantine is a terminal state for this phase (no
automated replay/promotion path back to raw). Manual inspection and reprocessing, if needed, is
out of scope for this feature.
