# Contract: Raw store interface (this feature → later phases)

This is the interface Phase 2's medallion-architecture build reads from — the boundary between
this feature and the rest of the project's own roadmap. It is the contract later phases can rely
on without needing to know how ingestion works internally.

## Layout

Local filesystem, partitioned by event type and ingestion date:

```text
data/raw/event_type=<EventType>/date=<YYYY-MM-DD>/*.jsonl
```

Each line is one Raw Record (see `data-model.md`), newline-delimited JSON, append-only.

## Guarantees this feature makes to consumers of the raw store

- Every record present has already passed structural validation (FR-003) — a Phase 2 reader never
  needs to re-validate envelope structure.
- No duplicate `event_id` values within the store (FR-002) — a Phase 2 reader never needs to
  de-duplicate on read.
- Records are never modified or deleted once written — append-only, so a Phase 2 batch job can
  safely read a full partition without a concurrent-write race.
- `event_type` and `ingested_at`-derived `date` partitions are stable, predictable, and match this
  contract exactly — Phase 2 can enumerate partitions without querying application state.

## Explicitly out of scope for this feature

- Compaction, retention, or archival of old raw partitions.
- Schema evolution handling for future GitHub event-type payload changes (flagged as a risk for
  Phase 2 to pick up, not solved here).
