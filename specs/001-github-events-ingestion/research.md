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
header from the start. Also respect the documented `X-Poll-Interval` response header (typically
60s) rather than inventing a poll interval independently — GitHub expects callers to honour it,
and it isn't mentioned in the project plan as written.

**The 300-event/30-day window is a hard ceiling, and it isn't just an outage-recovery concern**:
GitHub's own docs cap the public `/events` timeline at 300 events, covering only the last 30 days,
with documented event latency of "30s to 6h." ADR-0002 justified choosing GitHub Events over
Wikipedia EventStreams partly on "lower volume," but that comparison was made for the *global*
public firehose without checking real numbers — and GitHub's global public activity is exactly
what the long-running GH Archive project exists to archive, which suggests real volume may not be
as low as assumed. If genuine global activity between polls regularly exceeds 300 events, SC-001's
"zero events lost" and SC-003's "catches up without gaps" could fail under completely normal
operation, not only during a rate-limit incident — because events would already be falling out of
the API's own window before the pipeline ever sees them, which no amount of retry logic can
recover. This needs an empirical check against the live API before it's treated as safe (see
`docs/runbooks/github-events-volume-check.md`), consistent with Constitution Principle I
("Evidence Over Assumption") — and a detection mechanism at runtime regardless, since even a
currently-safe margin could erode as GitHub's own traffic grows over the life of this project: if
a poll response returns exactly 300 events (the documented maximum), that's a reliable, cheap
signal that the window may have already truncated real data before this poll even ran, and it's
worth logging as a warning (with a running count) rather than treated as an ordinary full page.

**Kafka topic strategy**: The project plan leaves this open ("topic'd sensibly... decide once you
see real volume"). A reasonable Phase 1 default is one topic per broad event category (e.g. code
activity, discussion activity, review activity) rather than one topic per individual GitHub event
type (of which there are ~15+) or a single firehose topic — this keeps consumer logic
type-aware without needing dozens of topics for a single-consumer Phase 1 workload. This is a
task-level decision to make concrete during implementation, not a spec-level one.

**Idempotency key, and why the store must be durable**: GitHub Events API events carry a unique,
stable `id` field. The original note here treated an on-disk and an in-memory seen-set as
interchangeable ("e.g."), but they aren't: an in-memory-only set is wiped on every consumer
restart, and the Kafka contract commits the offset only *after* a durable write — meaning a crash
between the write and the commit genuinely redelivers that message. An empty in-memory set would
then wave the redelivered event through as if it were new, producing a real duplicate in the raw
store and breaking both FR-002 and the raw store contract's own "no duplicate `event_id`"
guarantee — and directly contradicting the spec's own edge case ("if the ingestion process is
stopped and restarted, does it resume without gaps or duplicates?").

**Decision**: the idempotency check is a durable, on-disk index of `event_id`s already written to
the raw store — a simple persisted structure (an append-only ids file, or one small SQLite table;
not a new database service), not the raw store's own `.jsonl` files themselves, which would need
scanning on every lookup and wouldn't scale. That index is loaded fully into memory once at
consumer startup, so lookups during normal operation are in-memory-speed, then written through
(disk and memory together) as each new event is processed. This isn't really an on-disk-versus-
in-memory trade-off: the on-disk copy is the durable source of truth that survives a restart, and
the in-memory copy is that same data held ready for fast lookups while running — both at once, not
a choice between them.

**On the efficiency question directly**: there's very little to gain from an in-memory-only set at
this phase's realistic scale, and for a reason worth being explicit about — throughput here is
capped by GitHub's own API window (at most 300 events per poll; see the new volume note below), so
this is a handful of lookups per second at most, nowhere near a volume where disk I/O on every
check would be a real bottleneck. The "hydrate into memory at startup" step is essentially free
insurance at this scale, not a meaningful engineering cost, so there's no real reason to skip it —
but it's genuinely the durability, not the speed, that's the requirement being solved here.

**A simplification this unlocks**: the original note also called for "a bounded retention window
matching the realistic re-delivery window" for the seen-set, without saying how long that should
be. Once the index is durable rather than a capped in-memory cache, that problem mostly disappears
— there's no memory-pressure reason to evict old ids at Phase 1's realistic volume, so the index
can simply keep growing alongside the raw store itself, with compaction/retention deferred to
Phase 2 exactly as the raw store contract's own "out of scope" section already treats compaction
and retention for the raw data. One thing worth keeping in mind regardless of storage: GitHub's own
docs note event latency can run "30s to 6h," so even a time-bounded window, if one were ever
reintroduced, would need to be sized in hours, not poll intervals.

**`testcontainers` Kafka pattern**: `testcontainers-python`'s Kafka module starts a real
single-broker Kafka container per test run; the integration test publishes a representative sample
event (both a valid one and a deliberately malformed one, per spec User Story 2) and asserts the
consumer routes each to the correct store. This is the concrete shape of ADR-0006's "real local
Kafka in CI, not a mock" requirement (FR-008).

## Outstanding NEEDS CLARIFICATION

None. All Technical Context fields are resolved above or directly stated in the spec's Assumptions.
