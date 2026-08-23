# Contract: NiFi → Kafka → Consumer message interface

This is the interface between NiFi (producer) and the Python consumer (subscriber) — the
boundary this feature's own components communicate across.

## Topics

One topic per broad event category (see `research.md`), for example:
`github-events.code-activity`, `github-events.discussion-activity`, `github-events.review-activity`.
Exact category boundaries are a task-level decision made against real observed event-type volume,
not fixed here.

## Message key

Kafka message key = the Activity Event's `id`. Guarantees same-event redelivery lands on the same
partition, making idempotency de-duplication straightforward per-partition (FR-002).

## Message value

The full, unmodified Activity Event JSON as received from the GitHub Events API (see
`data-model.md`), UTF-8 encoded JSON. NiFi does not transform or reshape the event before
publishing — validation and shaping into a Raw Record happens downstream in the consumer, so the
quarantine path in the consumer always has the true original payload to store (FR-004).

## Consumer contract

The consumer MUST:
- Deserialize each message as JSON; a message that isn't valid JSON at all routes to quarantine
  with reason `"not valid JSON"` (still using the message key as the best-effort `received_at`
  correlation point).
- Validate the deserialized object against the Activity Event envelope (`data-model.md`); route
  failures to quarantine with a specific reason.
- Check the event `id` against the idempotency store before writing a Raw Record; a duplicate is
  silently dropped (not an error, not a quarantine case) per FR-002.
- Commit the Kafka offset only after the record has been durably written to raw or quarantine —
  never before — so a crash mid-processing re-delivers rather than silently drops (FR-005, FR-006).
