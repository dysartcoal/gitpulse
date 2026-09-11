# Phase 1 log — Reliable ingestion of public software-engineering activity data

**Status:** In progress — Setup + Foundational phases (T001-T011) implemented on
`001-setup-foundational`, not yet merged to `main`
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

## Next

- Decide whether to bring up the Docker Compose stack now and attempt the NiFi flow import to close
  out T009's caveat before merging, or leave that to the Polish-phase quickstart validation (T032)
  as originally scoped — not yet decided.
- Open a PR for `001-setup-foundational` into `main` once the above is settled.
- Branch `001-us1-raw-ingestion` for User Story 1 (T012-T021) after Setup+Foundational merges.

Other outstanding items, not blocking the above:

- Add branch protection on `main` once Phase 1's first CI check (`T027`, User Story 3) actually
  exists to require — still just a task, not implemented code.

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
