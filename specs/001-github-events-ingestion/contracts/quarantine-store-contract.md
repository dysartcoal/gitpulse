# Contract: Quarantine store interface (this feature → manual/operator review)

Unlike the raw store, the quarantine store's primary reader in Phase 1 is a human (the project
owner reviewing why events failed), not an automated downstream phase — so this contract
prioritises inspectability over partition efficiency.

## Layout

Local filesystem, partitioned by ingestion date only (volume is expected to be low relative to
raw — most events should validate):

```text
data/quarantine/date=<YYYY-MM-DD>/*.jsonl
```

Each line is one Quarantined Record (see `data-model.md`): `received_at`, `reason`, and the
untouched `raw_payload`.

## Guarantees this feature makes

- Every record that fails validation appears here exactly once, with a specific, non-generic
  `reason` string (FR-004, SC-002) — not merely "validation failed."
- `raw_payload` is byte-for-byte what was received, even when malformed enough that it can't be
  parsed into the expected structure — so a human reviewing quarantine can always see the actual
  original data, not a best-effort reconstruction.
- Nothing written here is ever also present in the raw store (User Story 2).

## Explicitly out of scope for this feature

- Automated replay of quarantined records back into the raw store after a schema fix — a possible
  future feature, not required by this spec's acceptance scenarios.
