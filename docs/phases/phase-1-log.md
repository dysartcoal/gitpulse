# Phase 1 log — Reliable ingestion of public software-engineering activity data

**Status:** In progress — build underway. T009's NiFi flow caveat closed via hands-on canvas
build (not the original XML import approach, abandoned as unrecoverable — see 2026-09-14/15/17
entries below); as of 2026-09-18 the live pipeline runs end-to-end, GitHub Events API through NiFi
to real Kafka topics, confirmed via `kafka-console-consumer.sh`. Still on `001-setup-foundational`;
branch/task-tracking bookkeeping hasn't kept pace with the actual build — see Next.
**Started:** 2026-09-10
**Completed:** —

## Done

- 2026-09-10 — Worked out the branching/PR strategy for Phase 1 before touching code: one branch
  per `tasks.md` checkpoint (Setup+Foundational, User Story 1, User Story 2, User Story 3, Polish)
  rather than a single long-lived feature branch, since `tasks.md` already defines each checkpoint
  as independently functional and testable — that's the natural PR boundary. Each branches off
  `main` directly and merges back directly; no separate integration branch, since there's no
  coordination overhead to justify one on a solo project (matches the constitution's "repository is
  the portfolio" principle: small, working increments landing on `main`, not one big-bang merge).
  Branches are created locally first, pushed only once there's something to push, rather than
  created on GitHub first.
- 2026-09-10 — Created the `001-setup-foundational` branch locally off `main` (scope: T001-T011).
- 2026-09-10 — Ran `/speckit-analyze` against `spec.md`/`plan.md`/`tasks.md` before starting
  implementation — right after `/speckit-tasks`, not deferred to phase-end, since that's the
  cheapest point to fix a cross-artifact inconsistency. Found: one HIGH inconsistency (`tasks.md`
  T020 offered "route to quarantine" as an alternative for a topic-routing mismatch, contradicting
  `data-model.md`'s scoping of quarantine to structural-validation failures only); one MEDIUM
  underspecification (FR-005/SC-003's "resume through temporary unavailability" named no explicit
  NiFi retry mechanism, unlike the rate-limit backoff path which did); one LOW ambiguity (spec's
  "reasonable, bounded delay" had no concrete number); and one plan.md/tasks.md structure-drift
  finding that turned out to be a false positive — Kim caught that `plan.md` already listed
  `create_topics.py` and `topic-map.properties` in its Project Structure section, ahead of what I'd
  loaded earlier in the session. Zero CRITICAL findings, zero constitution violations.
- 2026-09-10 — Resolved all four analyze findings: removed T020's quarantine alternative (warning
  only, matching `data-model.md`'s scope); added a named `RetryFlowFile` retry mechanism to T009 for
  NiFi connection failures, distinct from the existing rate-limit backoff; set the bound to "within
  5 poll intervals" in `plan.md`'s Performance Goals and Constraints.
- 2026-09-11 — Ran `/speckit-implement`, scoped explicitly to Phase 1 (Setup, T001-T004) and Phase 2
  (Foundational, T005-T011) only, matching the `001-setup-foundational` branch boundary. All 11
  tasks implemented with one commit per task (13 commits total, including a fix-up commit and a
  `tasks.md` checkbox-marking commit): project structure and `pyproject.toml`; ruff config; the
  NiFi+Kafka Docker Compose stack (KRaft mode, health checks, `GITHUB_TOKEN` passthrough); the
  Activity Event envelope JSON Schema plus PushEvent/IssuesEvent/PullRequestEvent payload schemas;
  the shared `config/topic-map.properties` and its `topic_map.py` loader; an idempotent Kafka
  topic-creation script; the NiFi flow definition; and the consumer's config loader and structured
  (JSON) logging setup.
- 2026-09-11 — Verification during implementation (not just writing the code) caught two real bugs:
  the JSON Schemas' `$id` fields pointed at a fake `https://gitpulse.local` domain, which hijacked
  the envelope schema's relative payload `$ref`s so a real `jsonschema` validator tried an actual
  network fetch instead of resolving the sibling schema files — fixed by dropping the `$id`s, then
  confirmed against real cases (valid PushEvent: 0 errors; malformed payload: 4 errors;
  unrecognized-but-well-formed event type: 0 errors, matching `data-model.md`'s rule; missing
  required envelope fields: 4 errors). Separately, `infra/create_topics.py` had a ruff line-length
  violation, fixed. `ruff check`/`ruff format --check` are clean and `topic_map.py`/`config.py`/
  `logging_config.py` were exercised at runtime under Python 3.12 (the local default interpreter is
  3.11; 3.12 was available via `pyenv` and used for every verification step).
- 2026-09-11 — Flagged one known, unresolved caveat: `nifi/flow/github-events-flow.xml` (T009) was
  authored without a running NiFi instance available in-session to import it into and confirm it
  wires up correctly. It's well-formed XML with real NiFi 1.27.0 processor types and property names
  to the best of available knowledge, but is unverified against an actual import — flagged both in
  the file's own header comment and in `tasks.md`'s T009 line, listing what to check (Parameter
  Context setup for `GITHUB_TOKEN`, `PublishKafka`'s exact bundled class name, the two stateful
  `UpdateAttribute` processors' Advanced-UI wiring).
- 2026-09-11 — Added a "Code comments — self-documenting code" section to `CLAUDE.md` at Kim's
  request: every function, class, and non-trivial block gets a comment on its expected outcome or
  the reason a particular approach was taken (not what the code already says), extended to tests
  too — the explicit goal being fewer back-and-forth questions while getting familiar with
  generated code. Retrofitted T001-T011 to the new standard rather than leaving it to apply only
  going forward: `pyproject.toml`, `docker-compose.yml`, all four JSON Schemas, `topic-map.properties`,
  `topic_map.py`/`config.py`/`logging_config.py`, `create_topics.py`, and the NiFi flow's few
  previously-uncommented processors all now explain their reasoning, not just their mechanics.
  Re-verified everything still behaves identically after the pass (same JSON Schema validation
  outcomes, XML/TOML still valid, ruff clean, modules still run under Python 3.12).
- 2026-09-14 — Attempted to close out T009's caveat: brought up the Docker Compose stack and tried
  importing `nifi/flow/github-events-flow.xml`. It failed with a `NullPointerException` inside
  NiFi's `DtoFactory.copySnippetContents`; comparing it against a real NiFi export
  (`exploration/investigations/2026-09-14-compare-nifi-basic-w-claude-generated/`) showed the
  hand-written file's `<processors>`/`<connections>` schema is fundamentally wrong, not missing a
  field or two — confirming the file's own caveat more thoroughly than expected. Decided against
  another hand-typed XML pass (each processor type's exact `relationships` list would be another
  unverified guess, the same category of mistake) in favour of building the flow directly on the
  canvas; wrote `exploration/scratch/2026-09-14-nifi-flow-build/build-guide.md`, a
  processor-by-processor checklist derived from the original file's still-sound design content, as
  the reference for doing that.
- 2026-09-15 — While reviewing a NiFi tutorial, noticed nothing in this repo ever documented *why*
  `infra/docker-compose.yml` pinned `apache/nifi:1.27.0` specifically — checked every ADR and
  `research.md`, found no rationale anywhere, so per Constitution Principle I this was an
  undocumented (and therefore unresolved) decision, not a deliberate one. Researched the
  alternative: confirmed Snowflake Openflow (a managed NiFi offering relevant to this project's
  job-market-driven skills goal) is built on NiFi 2.0, and that 1.x's Template XML mechanism —
  already the thing that broke above — is removed entirely in 2.0, not just deprecated. Verified
  compatibility empirically against the real `apache/nifi:2.12.0` image before switching (not
  assumed): `NIFI_WEB_HTTPS_HOST`/`SINGLE_USER_CREDENTIALS_*` env var handling is identical to
  1.27.0; `InvokeHTTP`, `RouteOnAttribute`, `EvaluateJsonPath`, `SplitJson`, `RetryFlowFile`,
  `LogAttribute`, `LookupAttribute`, `UpdateAttribute`, `PropertiesFileLookupService`, and
  `EnvironmentVariableParameterProvider` are all present under the same class names. One real
  breaking change found: NiFi 2.x restructures Kafka publishing around a required `Kafka
  Connection Service` controller service (`Kafka3ConnectionService`, holding `bootstrap.servers`)
  rather than `PublishKafka` holding `bootstrap.servers` directly — the processor itself simplifies
  to an unversioned `PublishKafka` class. Updated `infra/docker-compose.yml` to `apache/nifi:2.12.0`
  (with the reasoning recorded in a comment there, closing the original undocumented-decision gap),
  `docs/runbooks/nifi-flow-import.md` (its old "Import the template" section described a UI menu
  that no longer exists in 2.x — restructured to point at the build guide instead), the build
  guide's `Publish to Kafka` step (Kafka Connection Service, `Failure Strategy` replacing `Delivery
  Guarantee`), and the hand-written flow XML's header comment (marked superseded, pointing at the
  build guide rather than describing an import path NiFi 2.x's UI no longer offers). First start
  attempt against the new image crash-looped — not assumed clean, actually run: NiFi 2.x failed to
  parse the `nifi-conf` volume's leftover 1.27.0 flow state (`flow.xml.gz`-era XML) as its new
  JSON-based `VersionedDataflow` format (`JsonParseException: Unexpected character ('<'...)`),
  since the two major versions use incompatible persisted-state formats with no in-container
  migration. Kim tore the stack down, removed the `infra_nifi-conf`/`infra_nifi-state` volumes
  (nothing of value in them — no flow had ever successfully been built in that container), and
  brought it back up; both `kafka` and `nifi` now report `healthy`, confirmed via `docker compose
  ps`, not assumed from a clean-looking log.

- 2026-09-17 — Resumed the hands-on build from `exploration/scratch/2026-09-14-nifi-flow-build/build-guide.md`. Caught and fixed a real bug via NiFi's REST API rather than the UI: response headers land as plain lowercase attribute names (`x-ratelimit-remaining`, `etag`) in NiFi 2.x, not the `invokehttp.response.header.X` convention the original 1.x-era design assumed — confirmed by querying live provenance directly (`exploration/notes/2026-09-17-nifi-rest-api-debugging.md` records the technique), not by trusting the UI. Also found the build guide's "Advanced → Stateful Usage" instruction for `Track ETag and rate-limit headers` doesn't exist as a UI screen in 2.x (real mechanism: a `Store State` property + `getStateValue()`, confirmed against NiFi's own bundled docs) — and, working through *why* state was even needed, realised it wasn't: the ETag loop-back connection already carries `previous.etag` forward as a plain FlowFile attribute, so the processor only needs a Basic Usage property, not real state (`exploration/notes/2026-09-17-nifi-scoping-concepts.md`). Separately confirmed empirically (config + live provenance timestamps) that `InvokeHTTP` processes exactly one FlowFile per 60s trigger, never a batch drain.
- 2026-09-17 — Investigated a real architecture question raised about `InvokeHTTP` having two independent incoming connections (the ETag loop-back and the retry loop-back): confirmed via NiFi's own docs that there's no ordering guarantee across multiple connections feeding one processor, only per-connection FIFO — a genuine, evidence-backed risk (not hypothetical), but bounded to efficiency (a stale ETag just costs a wasted `200` instead of a `304`), not correctness or data loss. Chose an explicit, low `Back Pressure Object Threshold` plus a `FirstInFirstOutPrioritizer` on the retry connection over a topology redesign (`exploration/notes/2026-09-17-nifi-queue-ordering-and-backpressure.md`). Separately decided, while configuring `Publish to Kafka`'s `Failure Strategy`, to deliberately design for Kafka outages up to ~1 hour: `Rollback` (queue and retry, not drop) at the Kafka-publish step specifically, kept decoupled from `Poll GitHub Events API` so a Kafka outage can never pause polling and risk events scrolling out of GitHub's 300-event/30-day window — recorded in the build guide's "Kafka outage design scope" section, including the explicitly accepted limit beyond ~1 hour.
- 2026-09-17 — Accidentally deleted every processor and connection in the flow attempting to delete a single connection. Recovered via NiFi's own `conf/archive/` snapshots (a save on nearly every UI change) — identified the exact pre-deletion snapshot by a sharp file-size drop (~3400 bytes to ~1500) confirmed against processor/connection counts, not by guessing a timestamp. First restore attempt crash-looped NiFi (`insufficient read/write privileges` — the helper container used to copy the archived file into the Docker volume wrote it as `root`, but NiFi runs as a non-root `nifi` user inside its container); fixed by re-copying with the correct uid/gid. Both the ownership gotcha and the general restore procedure written up (`exploration/notes/2026-09-17-nifi-config-file-ownership.md`) before rebuilding the lost processors by hand from the archive-restored state plus the build guide.
- 2026-09-17 — Given the sheer amount of REST-API-based diagnosis this day required (and an explicit ask to prefer terminal diagnostics over one-item-at-a-time UI clicking going forward), built the first version of a proper toolkit rather than continuing with one-off `curl`/Python snippets: `nifi/scripts/` — `common.sh` (shared auth), `flow-status.sh` (processor/connection state in one view), `queue-list.sh` (actual queue contents including penalization), `provenance-search.sh`, `process-groups-list.sh`, `set-processor-state.sh` — each with a README documenting the pattern for adding more, and a documented gotcha already: NiFi's provenance search-term field names (`FlowFile UUID` with a space; `Component Name` accepted without error but silently matched nothing) didn't behave as their names suggest.
- 2026-09-18 — Extended the toolkit as new needs came up rather than reaching for one-off commands again: `controller-services-list.sh` (controller services can be scoped per-process-group or instance-wide, and it's easy to be unsure which — this checks everywhere at once), `archive-list.sh`/`restore-flow-config.sh` (scripting yesterday's manual disaster-recovery procedure, including the ownership fix baked in), and `infra/kafka-commands.md` (a parallel plain-command reference for Kafka's own already-ergonomic CLI tools, rather than wrapping them in scripts the way NiFi's REST API needed). Renamed two scripts for naming consistency (`processor-state.sh` → `set-processor-state.sh`, `list-process-groups.sh` → `process-groups-list.sh` — verb-first only for the one script that mutates state, noun-first for every read-only one).
- 2026-09-18 — `infra/create_topics.py` failed with `ModuleNotFoundError: No module named 'confluent_kafka'` — no Python virtual environment existed yet for the project at all, and the default `python3` (3.11 via `pyenv`) didn't satisfy `pyproject.toml`'s `requires-python = ">=3.12"` either. Created `.venv/` against Python 3.12.7 explicitly and `pip install -e .`; confirmed `create_topics.py` now runs and all four Kafka topics exist. Recorded the real setup command in `CLAUDE.md` (which had explicitly said to update it once implementation began) and a conceptual note on venvs/editable installs for future reference (`exploration/notes/2026-09-18-python-virtual-environments.md`).
- 2026-09-18 — Debugged `Publish to Kafka` not draining its incoming queue — three independent, stacked bugs, each fix revealing the next behind an identical-looking symptom (full write-up: `exploration/notes/2026-09-18-publish-to-kafka-debugging.md`): (1) `Transactions Enabled = true` with no transactional ID set, making the Kafka client refuse to construct a producer at all (`ConfigException: Cannot set a transactional.id without also enabling idempotence`) — fixed by turning transactions off, since this design never needed exactly-once semantics; (2) the Kafka Connection Service's `security.protocol` defaulted to `SSL` against a broker with zero security configured, dropping every connection mid-handshake — fixed to `PLAINTEXT`; (3) `infra/docker-compose.yml`'s `KAFKA_ADVERTISED_LISTENERS` advertised `localhost`, which is only ever correct for same-container or genuinely host-native clients, not `gitpulse-nifi` (a different container) — every existing Kafka CLI command had masked this for weeks because they all ran via `docker exec` *inside* the Kafka container itself, where `localhost` genuinely does mean itself. Fixed to advertise the Compose service name (`kafka:9092`) instead. **First successful end-to-end run**: confirmed via `kafka-console-consumer.sh` that real GitHub Events JSON is landing in `github-events.code-activity`, not just leaving NiFi's own queues.

## Next

- Save the working flow definition JSON into `nifi/flow/` (replacing the superseded hand-written
  XML) and commit — in progress as of this log update.
- Decide how the now-working NiFi flow reconciles with the original `001-setup-foundational`
  branch/`tasks.md` T009-T021 scope: the actual build has run well ahead of formal task-checkbox
  bookkeeping (real end-to-end publishing to Kafka is functionally User Story 1 territory, T012+),
  while still sitting on the Setup+Foundational branch. Reconcile via `/speckit-converge` (diff
  actual state against `tasks.md`, append what's missing) rather than trying to reconstruct which
  individual task boxes should now be ticked from memory.
- Once reconciled: finish whatever of `tasks.md`'s remaining scope is still genuinely outstanding
  (raw/quarantine store writing, the Python consumer side, tests), open the PR, branch onward per
  the original per-checkpoint plan.

Other outstanding items, not blocking the above:

- Add branch protection on `main` once Phase 1's first CI check (`T027`, User Story 3) actually
  exists to require — still just a task, not implemented code.
- Configure a NiFi Git-backed Flow Registry Client (GitHub) once the remaining NiFi flow
  processors are built and stable, and start version control on the GitHub Events Flow process
  group — real commit messages and a diffable history for deliberate flow edits, rather than
  relying only on `nifi/scripts/archive-list.sh`'s undirected timestamp snapshots (which stay in
  place regardless, as the crash/accident safety net — see that script's README section
  "`archive-list.sh`/`restore-flow-config.sh` vs. NiFi's own version control" for the reasoning).
  Not yet set up or verified hands-on as of 2026-09-18 — needs a deliberate decision on how to
  scope the GitHub PAT it would use before configuring it.

## Decisions / notes

- Branch/PR granularity settled on "one branch per `tasks.md` checkpoint," not one branch per task
  (too many round trips for 33 tasks) and not one long-lived branch for all of Phase 1 (too coarse
  to review, and `tasks.md`'s own checkpoints already double as natural PR boundaries — no need to
  invent a different granularity).
- `/speckit-analyze` is worth running every time right after `/speckit-tasks`, before any
  implementation — it caught a real contradiction (T020 vs. `data-model.md`'s quarantine scope) at
  the cost of a doc edit, not a code rewrite.
- The Kim-caught false positive on plan.md's Project Structure (I2) is a reminder to re-read a
  document immediately before citing its contents as evidence in a finding, rather than relying on
  what was loaded earlier in a long session — the file had already been brought up to date.
- Actually exercising what's testable during implementation (real `jsonschema` validation runs, not
  just writing schema files and trusting them, and running the local interpreter that actually
  matches the plan's stated Python version) caught a real bug — the fake schema `$id` — that neither
  writing careful JSON nor `py_compile`/ruff alone would have caught. Worth repeating at every future
  checkpoint rather than treating "the code was written carefully" as equivalent to "the code was
  tested."
- One artefact — the NiFi flow XML — genuinely can't be verified without a running NiFi instance in
  this kind of session; flagged as a caveat rather than silently presented as trustworthy. Worth
  deciding explicitly (see Next) whether to close that gap now or defer it to the existing
  quickstart validation step.
