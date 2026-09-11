# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

GitPulse is a self-directed data engineering learning project: it ingests GitHub's public event
stream and moves it through a full medallion architecture (raw → curated → gold), exposed via an
API and an AI interface, operated the way a production platform would be. It is built and
documented in the open — every phase maps to a named skills gap, and the repository itself
(README, ADRs, phase logs) is meant to be read by a hiring manager, not just run.

**Current state**: Phase 0 (Foundations) is complete. No application code exists yet — the repo is
currently all specs, ADRs, and docs. Phase 1 (local streaming pipeline: NiFi → Kafka → a Python
consumer → raw/quarantine stores) is spec'd out in full under
`specs/001-github-events-ingestion/` and ready for `/speckit-implement`, but not yet built. Check
`docs/phases/phase-0-log.md` and `docs/phases/phase-1-log.md` (once it exists) for the live,
up-to-date status before assuming anything described below has been implemented — the plan below
is the *design*, not yet the code.

## Governing rules — read `.specify/memory/constitution.md`

Every decision in this repo is expected to trace back to the project constitution
(`.specify/memory/constitution.md`, v1.0.0). The five principles that most affect day-to-day work:

- **Evidence Over Assumption** — a significant technical decision gets an ADR in `docs/adr/`
  (Context/Decision/Consequences) before or as it's acted on. A decision without a written reason
  is treated as unresolved, even if code implementing it already exists.
- **Security by Enforcement, Not Convention** — long-lived AWS credentials are avoided wherever a
  temporary/federated alternative exists; where unavoidable, blast radius is constrained by policy
  (e.g. `RequireMFAForAllActions`), not discipline. Secrets are never committed — enforced via
  `.gitignore`, not retrofitted later.
- **Cost Is a Design Constraint** — this runs on a self-funded, credit-limited AWS account.
  Budgets/billing alarms exist before any billable service is touched. Compute defaults to
  local/serverless; anything billed hourly regardless of use is a deliberate, time-boxed exception.
- **Test and Validate at the Layer Where Data Changes** — tests are written alongside each phase
  as it's built, not bolted on afterward, with tooling chosen per layer (`pytest` +
  `testcontainers` for code that moves data, `dbt` tests where `dbt` models it, etc.).
- **The Repository Is the Portfolio** — README is a narrative front door; every ADR is a
  standalone readable file; every phase gets a live working log while in progress and a short
  retrospective once done, in `docs/phases/`; real work lands via feature branch + PR.

**Any AI-facing or external-facing interface reads from the gold layer only** (ADR-0001) — this
constraint applies regardless of which phase or feature is being touched.

## Spec Kit workflow

This project uses [GitHub Spec Kit](https://github.com/github/spec-kit) to specify each phase
before implementing it, rather than specifying the whole project upfront. The skills are invoked
in this order per phase/feature:

1. `/speckit-constitution` — project-level, already run once (only re-run to amend the constitution).
2. `/speckit-specify` — turn a feature description into `specs/<NNN-slug>/spec.md`.
3. `/speckit-clarify` — resolve any `[NEEDS CLARIFICATION]` markers in the spec.
4. `/speckit-plan` — produce `plan.md`, `research.md`, `data-model.md`, `contracts/`, `quickstart.md`.
5. `/speckit-tasks` — produce dependency-ordered `tasks.md` from the plan artifacts.
6. `/speckit-analyze` — non-destructive cross-artifact consistency check across spec/plan/tasks.
7. `/speckit-implement` — execute `tasks.md`. Resolves the active feature via `.specify/feature.json`,
   **not** the current branch name, though branches are conventionally named to match the spec folder
   (e.g. `001-github-events-ingestion`).
8. `/speckit-converge` — after implementation, diff the actual codebase against spec/plan/tasks and
   append any unbuilt remainder as new tasks.

Each Spec Kit stage is a genuine review opportunity, not a formality — this repo's history has
already caught real design bugs (a duplicated NiFi/Python routing table, a misplaced credential)
only at the `/speckit-tasks` granularity, after `/speckit-plan` had looked coherent.

## Repository structure

- `docs/adr/` — architecture decision records (Context/Decision/Consequences template in
  `docs/adr/0000-template.md`). Read the relevant ADR before revisiting a decision it covers.
- `docs/phases/` — one live working log per in-progress phase, one retrospective per completed
  phase. This is the authoritative "what's actually done" source — more current than this file.
- `docs/runbooks/` — operational procedures (AWS credentials, cost guardrails, the GitHub Events
  volume check) written to be followed step by step, with "Configured:" lines filled in once a
  step has actually been done in the real AWS console, not just documented.
- `specs/<NNN-feature-slug>/` — Spec Kit artifacts per phase/feature (spec, plan, research,
  data-model, contracts, tasks, quickstart). `specs/001-github-events-ingestion/` is Phase 1.
- `exploration/` — gitignored ad hoc investigation output and scratch work (e.g. API volume
  checks), kept separate from the formal `tests/` suite once it exists. Only each folder's
  `README.md` is tracked; everything else is disposable or evidence-only.
- `.specify/` — Spec Kit tooling itself (constitution, templates, workflow scripts). Not
  hand-edited directly except via the `/speckit-*` skills.

## Planned Phase 1 architecture (not yet implemented)

Per `specs/001-github-events-ingestion/plan.md`: Apache NiFi polls the GitHub public Events API
(`InvokeHTTP`, ETag caching, PAT via `EnvironmentVariableParameterProvider`) and publishes onto
Apache Kafka (KRaft mode, no separate ZooKeeper); a Python 3.12 consumer reads from Kafka,
validates each event structurally against `jsonschema` definitions, de-duplicates via a durable
on-disk seen-index keyed on event id, and writes valid events to a local raw store / invalid
events + reason to a local quarantine store. Both NiFi and Kafka run self-hosted via Docker
Compose — the whole stack is local-first and zero ongoing cost (Spark and cloud storage are
explicitly deferred to Phase 2).

`config/topic-map.properties` (planned, not yet created) is the single source of truth for
event-type → Kafka topic routing, read natively by both NiFi (`PropertiesFileLookupService`/
`LookupAttribute`) and the consumer (as a defensive cross-check) — deliberately not duplicated
between the two.

Planned layout once Phase 1 lands (see `plan.md`'s Project Structure for the full rationale):

```text
infra/            # docker-compose.yml (NiFi + Kafka), create_topics.py, LocalStack Terraform
nifi/flow/        # exported NiFi flow definition
config/           # topic-map.properties
src/schemas/      # JSON Schema for the GitHub event envelope and per-type payloads
src/consumer/     # parsing, idempotency, raw_writer, quarantine_writer, topic_map, config, main
tests/unit/       # pytest — parsing, idempotency, writers
tests/integration/# testcontainers-backed real-Kafka test
data/             # gitignored — local raw/ and quarantine/ stores written at runtime
```

**Testing approach once code exists**: `pytest` for unit tests, `testcontainers-python`'s Kafka
module for integration tests against a real local broker (never a mock, per ADR-0006) — GitHub
Actions runs lint, unit tests, and the integration test on every PR. There is no build/lint/test
command to run yet; check `specs/001-github-events-ingestion/quickstart.md` and `tasks.md` once
implementation begins, and update this file with the real commands at that point.
